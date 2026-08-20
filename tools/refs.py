#!/usr/bin/env python3
"""Busca que instrucciones apuntan a un rango, sin inventarse punteros.

Buscar a lo bruto los bytes de una direccion por todo el binario NO vale, y
cuesta caro creerselo. Dos formas de equivocarse, las dos vistas ya en esta
serie de desensamblados:

  - Una tira de bytes repetidos parece un puntero. Donde hay `6e 6e 6e 6e`,
    leido como palabras sale 0x6E6E; en una zona de graficos aparecieron asi
    208 "punteros internos" que no existen.
  - Leer desde el byte de en medio de una instruccion inventa direcciones.
    Donde hay un `ld bc,0180h`, empezando a leer un byte mas alla sale un
    `ld bc` de otro valor que nadie escribio nunca.

Asi que esto recorre SOLO los inicios de instruccion que da el trazado, con la
misma tabla de longitudes que usa el trazador, y mira el operando de 16 bits de
las instrucciones que de verdad llevan uno.

Uso: refs.py <rom> <trace.json> <ini> [fin]

Con un solo valor busca esa direccion exacta; con dos, todo el rango.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from z80trace import BASE_LEN, ED_LEN4                # noqa: E402

ORG = 0x4000

# Instrucciones de tres bytes cuyo operando ES una direccion o un valor de 16
# bits. Las de salto condicional van incluidas: tambien apuntan.
CON_OPERANDO = {
    0x01: "ld bc,", 0x11: "ld de,", 0x21: "ld hl,", 0x31: "ld sp,",
    0x22: "ld (),hl", 0x2A: "ld hl,()", 0x32: "ld (),a", 0x3A: "ld a,()",
    0xC3: "jp", 0xCD: "call",
    0xC2: "jp nz,", 0xCA: "jp z,", 0xD2: "jp nc,", 0xDA: "jp c,",
    0xE2: "jp po,", 0xEA: "jp pe,", 0xF2: "jp p,", 0xFA: "jp m,",
    0xC4: "call nz,", 0xCC: "call z,", 0xD4: "call nc,", 0xDC: "call c,",
    0xE4: "call po,", 0xEC: "call pe,", 0xF4: "call p,", 0xFC: "call m,",
}


def longitud(rom, a):
    op = rom[a - ORG]
    if op in (0xDD, 0xFD):
        sig = rom[a + 1 - ORG]
        if sig == 0xCB:
            return 4
        if sig in (0xDD, 0xFD):
            return 1
        return 1 + longitud(rom, a + 1)
    if op == 0xCB:
        return 2
    if op == 0xED:
        return 4 if rom[a + 1 - ORG] in ED_LEN4 else 2
    return BASE_LEN[op]


def busca(rom, trace, ini, fin):
    out = []
    for k, a, b in trace["blocks"]:
        if k != "c":
            continue
        p = a
        while p < b:
            n = longitud(rom, p)
            op = rom[p - ORG]
            if op in CON_OPERANDO and n >= 3:
                v = rom[p + n - 2 - ORG] | (rom[p + n - 1 - ORG] << 8)
                if ini <= v < fin:
                    out.append((p, CON_OPERANDO[op], v))
            p += n
    return out


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    with open(sys.argv[1], "rb") as f:
        rom = f.read()
    with open(sys.argv[2]) as f:
        trace = json.load(f)
    ini = int(sys.argv[3], 0)
    fin = int(sys.argv[4], 0) if len(sys.argv) > 4 else ini + 1

    r = busca(rom, trace, ini, fin)
    print("  referencias a 0x%04X-0x%04X: %d" % (ini, fin - 1, len(r)))
    for p, nm, v in r:
        print("     %04X  %-9s %04X" % (p, nm, v))
    if not r:
        print("     NINGUNA instruccion apunta ahi con una direccion inmediata.")
        print("     O se llega por calculo, o se consume en cadena desde otro sitio.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
