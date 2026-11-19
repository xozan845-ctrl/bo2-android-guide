#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""
verificar_tu18.py — comprueba si un Title Update de Xbox 360 es el TU18
que acepta el port de Black Ops II para Android.

Cómo funciona (igual que el port):
  abre el paquete STFS, recorre el árbol de directorios, extrae
  "default_mp.xexp" y compara su SHA-256 con los hashes aceptados.

Uso:
  python3 verificar_tu18.py RUTA_DEL_TU
  python3 verificar_tu18.py RUTA --verbose
  python3 verificar_tu18.py RUTA --extraer default_mp.xexp   # guarda el xexp

Códigos de salida:
  0 = TU18 válido   1 = no válido   2 = error de lectura/estructura

Port del lector STFS de StfsPatchVerifier (proyecto BO2-Android-xbox360).
"""

import argparse
import hashlib
import os
import struct
import sys

BLOCK = 4096
END = 0xFFFFFF
LEVEL1 = 170 * 170
MAX_PATCH = 32 * 1024 * 1024
MAX_IO = 48 * 1024 * 1024

TU18_HASHES = {
    "5d5780970f6e639b17c0570bae0e52a13bd1038e23c969428aef9d0c7d78681b",
    "7f4ee5e4b5ccfe71786ddc073a0363558e89634bb26c2929335aeb7f883c9499",
}


class StfsError(Exception):
    pass


class Stfs:
    def __init__(self, path):
        self.path = path
        self.f = open(path, "rb")
        self.file_size = os.path.getsize(path)
        self.bytes_read = 0
        self.tables = {}
        head = self.read(0, 0x3AD)
        self.head = head

        self.content_type = self.u32(head, 0x344)
        self.media_id = self.u32(head, 0x354)
        self.version = self.u32(head, 0x358)
        self.base_version = self.u32(head, 0x35C)
        self.title_id = self.u32(head, 0x360)
        self.volume_type = self.u32(head, 0x3A9)

        if self.content_type != 0x000B0000:
            raise StfsError(
                "no es un paquete de Title Update (contentType=0x%X)" % self.content_type
            )
        if self.volume_type != 0:
            raise StfsError("tipo de volumen STFS no soportado (%X)" % self.volume_type)
        if head[0x379] != 0x24:
            raise StfsError("descriptor de volumen STFS inválido (0x%02X)" % head[0x379])
        if self.title_id != 0x415608C3:
            raise StfsError("title id 0x%08X, no es Black Ops II (415608C3)" % self.title_id)

        self.header_size = self.u32(head, 0x340)
        if not (0x3AD <= self.header_size <= self.file_size):
            raise StfsError("tamaño de cabecera STFS inválido")
        self.base = (self.header_size + BLOCK - 1) & ~(BLOCK - 1)

        flags = head[0x37B]
        self.read_only = bool(flags & 1)
        self.root_active = bool(flags & 2)
        self.backing = 1 if self.read_only else 2

        self.table_count = head[0x37C] | (head[0x37D] << 8)
        self.table_start = self.u24(head, 0x37E)
        self.total_blocks = self.u32(head, 0x395)
        if not (1 <= self.table_count <= 256 and 1 <= self.total_blocks <= 0xFFFFFF):
            raise StfsError("tablas/bloques STFS fuera de rango")

    # -- utilidades de lectura -------------------------------------------------
    @staticmethod
    def u24(d, o):
        return d[o] | (d[o + 1] << 8) | (d[o + 2] << 16)

    @staticmethod
    def u32(d, o):
        return struct.unpack(">I", d[o : o + 4])[0]

    def read(self, off, count):
        if off < 0 or count < 0 or off > self.file_size - count:
            raise StfsError("datos STFS truncados")
        if self.bytes_read + count > MAX_IO:
            raise StfsError("se excedió el presupuesto de lectura")
        self.f.seek(off)
        data = self.f.read(count)
        if len(data) != count:
            raise StfsError("lectura incompleta del archivo")
        self.bytes_read += count
        return data

    # -- mapeo de bloques ------------------------------------------------------
    def data_offset(self, index):
        physical = index
        group = 170
        for _ in range(3):
            physical += ((index + group) // group) * self.backing
            if index < group:
                break
            group *= 170
        return self.base + physical * BLOCK

    def hash_offset(self, index, level):
        step0 = 170 + self.backing
        step1 = LEVEL1 + 171 * self.backing
        if level == 0:
            if index < 170:
                block = 0
            else:
                block = (index // 170) * step0 + (index // LEVEL1 + 1) * self.backing
                if index >= LEVEL1:
                    block += self.backing
        elif level == 1:
            block = step0 if index < LEVEL1 else (index // LEVEL1) * step1 + self.backing
        else:
            block = step1
        return self.base + block * BLOCK

    def hash_table(self, off):
        table = self.tables.get(off)
        if table is None:
            table = self.read(off, BLOCK)
            self.tables[off] = table
        return table

    def check_block(self, block):
        if block < 0 or block >= self.total_blocks or block == END:
            raise StfsError("bloque STFS fuera del volumen declarado")

    def next_block(self, block):
        self.check_block(block)
        secondary = BLOCK if (not self.read_only and self.root_active) else 0
        if not self.read_only and self.total_blocks > 170:
            if self.total_blocks > LEVEL1:
                upper = self.hash_table(self.hash_offset(block, 2) + secondary)
                rec = (block // LEVEL1) % 170
                secondary = BLOCK if (upper[rec * 24 + 20] & 0x40) else 0
            upper = self.hash_table(self.hash_offset(block, 1) + secondary)
            rec = (block // 170) % 170
            secondary = BLOCK if (upper[rec * 24 + 20] & 0x40) else 0
        table = self.hash_table(self.hash_offset(block, 0) + secondary)
        return self.u32(table, (block % 170) * 24 + 20) & 0xFFFFFF

    # -- recorrido del sistema de archivos -------------------------------------
    def list_files(self, verbose=False):
        block = self.table_start
        files = []
        visited = set()
        for i in range(self.table_count):
            self.check_block(block)
            if block in visited:
                raise StfsError("ciclo en la cadena de directorios")
            visited.add(block)
            table = self.read(self.data_offset(block), BLOCK)
            for row in range(64):
                off = row * 64
                if table[off] == 0:
                    break
                flags = table[off + 0x28]
                length = flags & 0x3F
                if length < 1 or length > 40:
                    raise StfsError("longitud de nombre inválida")
                if flags & 0x80:
                    continue
                parent = (table[off + 0x32] << 8) | table[off + 0x33]
                name = table[off : off + length].decode("ascii", "replace")
                entry = {
                    "name": name,
                    "parent": parent,
                    "start": self.u24(table, off + 0x2F),
                    "allocated": self.u24(table, off + 0x2C),
                    "size": self.u32(table, off + 0x34),
                }
                files.append(entry)
                if verbose:
                    print(
                        "  %-26s %10d bytes  (bloque %d)"
                        % (name, entry["size"], entry["start"])
                    )
            if i + 1 < self.table_count:
                block = self.next_block(block)
                if block == END:
                    raise StfsError("la cadena de directorios terminó antes")
        return files

    def extract(self, entry, out=None):
        digest = hashlib.sha256()
        block = entry["start"]
        remaining = entry["size"]
        if remaining < 24 or remaining > MAX_PATCH:
            raise StfsError("tamaño de parche fuera de rango")
        if (remaining + BLOCK - 1) // BLOCK != entry["allocated"]:
            raise StfsError("el número de bloques no coincide con el tamaño")
        visited = set()
        while remaining > 0:
            self.check_block(block)
            if block in visited:
                raise StfsError("ciclo en la cadena del parche")
            visited.add(block)
            count = min(BLOCK, remaining)
            data = self.read(self.data_offset(block), count)
            digest.update(data)
            if out is not None:
                out.write(data)
            remaining -= count
            if remaining > 0:
                block = self.next_block(block)
                if block == END:
                    raise StfsError("la cadena del parche terminó antes")
        return digest.hexdigest()


def main():
    ap = argparse.ArgumentParser(
        description="Verifica si un archivo de Title Update es el TU18 de Black Ops II."
    )
    ap.add_argument("tu", help="ruta del archivo tuXXXXXXXX_XXXXXXXX")
    ap.add_argument("--verbose", "-v", action="store_true", help="lista el contenido")
    ap.add_argument(
        "--extraer",
        metavar="NOMBRE",
        help="guarda un archivo del paquete (ej. default_mp.xexp)",
    )
    args = ap.parse_args()

    try:
        stfs = Stfs(args.tu)
    except (OSError, StfsError) as e:
        print("ERROR: %s" % e)
        return 2

    print(
        "Paquete: title=0x%08X mediaId=0x%08X version=%d.%d contentType=0x%X"
        % (
            stfs.title_id,
            stfs.media_id,
            stfs.version,
            stfs.base_version,
            stfs.content_type,
        )
    )
    print("Bloques: %d  tablas: %d" % (stfs.total_blocks, stfs.table_count))

    try:
        files = stfs.list_files(verbose=args.verbose)
    except StfsError as e:
        print("ERROR: %s" % e)
        return 2

    if args.extraer:
        match = [f for f in files if f["name"].lower() == args.extraer.lower()]
        if not match:
            print("ERROR: %s no está en el paquete" % args.extraer)
            return 2
        dest = os.path.basename(args.extraer)
        with open(dest, "wb") as out:
            sha = stfs.extract(match[0], out)
        print("\nExtraído: %s (%d bytes)" % (dest, match[0]["size"]))
        print("SHA-256 : %s" % sha)
        return 0 if sha in TU18_HASHES else 1

    print()
    target = [f for f in files if f["name"].lower() == "default_mp.xexp"]
    if not target:
        print("RESULTADO: NO SIRVE — no contiene default_mp.xexp (no es un TU de BO2).")
        return 1

    try:
        sha = stfs.extract(target[0])
    except StfsError as e:
        print("ERROR: %s" % e)
        return 2

    print("default_mp.xexp: %d bytes" % target[0]["size"])
    print("SHA-256       : %s" % sha)
    if sha in TU18_HASHES:
        print("\nRESULTADO: OK — es un TU18 aceptado por el port.")
        return 0
    print("\nRESULTADO: NO SIRVE — ese TU no es el TU18 que pide el port.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
