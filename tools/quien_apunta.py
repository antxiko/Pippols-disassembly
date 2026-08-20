#!/usr/bin/env python3
"""Para cada hueco sin explicar, quien lo apunta desde el codigo ya trazado.

    python3 tools/quien_apunta.py <work_dir> <src_dir>

Un rango de datos no se declara porque sobre, se declara porque hay una
instruccion identificada que lo lee. Esta herramienta busca esa instruccion:
recorre el codigo que el trazador SI alcanza, se queda con los operandos
inmediatos de 16 bits -`ld hl,nn`, `ld de,nn`, `ld bc,nn` y `ld (nn),..` con
sus variantes indexadas- y dice cuales caen dentro de cada hueco.

Con eso, cerrar el presupuesto deja de ser adivinar donde empieza un bloque:
el sitio lo dice quien lo usa. Lo que la herramienta NO hace es decidir donde
ACABA; eso sale de lo que venga detras, y de pasar el bloque por el interprete
o el descompresor que lo consume.

Los huecos que salgan SIN NADIE que los apunte son los interesantes: o son
datos encadenados que se consumen uno detras de otro, o son codigo al que no
llega nadie.
"""
import json
import os
import sys

ORG = 0x4000

# Instrucciones con un inmediato de 16 bits, por opcode. Solo las que en este
# cartucho apuntan a datos; no hace falta el juego entero para esto.
INMEDIATO = {
    0x21: "ld hl,nn", 0x11: "ld de,nn", 0x01: "ld bc,nn", 0x31: "ld sp,nn",
    0x22: "ld (nn),hl", 0x2A: "ld hl,(nn)", 0x32: "ld (nn),a", 0x3A: "ld a,(nn)",
    0xC3: "jp nn", 0xCD: "call nn",
}


def huecos(blocks, notas):
    """Lo que no es codigo trazado ni cae en una directiva D."""
    marca = bytearray(0x4000)
    for tipo, a, b in blocks:
        if tipo == "c":
            for i in range(a - ORG, b - ORG):
                marca[i] = 1
    for a, b in notas:
        for i in range(max(0, a - ORG), min(0x4000, b - ORG)):
            marca[i] = 2
    out, ini = [], None
    for i in range(0x4000):
        if marca[i] == 0 and ini is None:
            ini = i
        elif marca[i] != 0 and ini is not None:
            out.append((ORG + ini, ORG + i))
            ini = None
    if ini is not None:
        out.append((ORG + ini, ORG + 0x4000))
    return out


def rangos_d(path):
    import re
    out = []
    with open(path, encoding="utf-8") as f:
        for ln in f:
            m = re.match(r"^D\s+(0x[0-9A-Fa-f]+)\s+(0x[0-9A-Fa-f]+)", ln)
            if m:
                out.append((int(m.group(1), 16), int(m.group(2), 16)))
    return out


def inmediatos(d, blocks):
    """(direccion_de_la_instruccion, mnemonico, valor) del codigo trazado.

    Se recorre byte a byte dentro de cada bloque de codigo. No es un
    desensamblador: puede coger algun operando por casualidad, y por eso lo que
    saca es una PISTA que hay que mirar, no una conclusion.
    """
    out = []
    for tipo, a, b in blocks:
        if tipo != "c":
            continue
        for p in range(a, b - 2):
            op = d[p - ORG]
            if op in INMEDIATO:
                v = d[p + 1 - ORG] | d[p + 2 - ORG] << 8
                out.append((p, INMEDIATO[op], v))
    return out


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 1
    work, src = sys.argv[1], sys.argv[2]
    traza = json.load(open(os.path.join(work, "pippols.trace.json")))
    blocks = traza["blocks"]
    notas = rangos_d(os.path.join(src, "pippols.notes"))

    rom = "pippols.rom"
    with open(rom, "rb") as f:
        d = f.read()

    hs = huecos(blocks, notas)
    imm = inmediatos(d, blocks)

    print("Huecos sin explicar: %d, %d bytes"
          % (len(hs), sum(b - a for a, b in hs)))
    print()
    for a, b in hs:
        dentro = sorted(set((v, p, m) for p, m, v in imm if a <= v < b))
        print("0x%04X..0x%04X  (%d bytes)" % (a, b, b - a))
        if not dentro:
            print("    NADIE LO APUNTA: o es una cadena que se consume seguida,")
            print("    o es codigo al que no llega nadie.")
        for v2, p, m in dentro:
            print("    0x%04X  <- %-10s en 0x%04X" % (v2, m, p))
        if False:
            print("    ... y %d mas" % (len(dentro) - 8))
        print()
    if traza.get("blind"):
        print("SALTOS CIEGOS (JP (HL)), que suelen ser el otro despachador:")
        for a, q in traza["blind"]:
            print("    %s  %s" % (a, q))
    return 0


if __name__ == "__main__":
    sys.exit(main())
