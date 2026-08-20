#!/usr/bin/env python3
"""Presupuesto del cartucho: ni un byte sin explicar.

Por que este control y no el porcentaje de codigo trazado: buena parte de estos
16 KB son datos y graficos, asi que un porcentaje de codigo bajo suena a trabajo
a medias cuando puede estar entero. Lo que mide el avance de verdad es que cada
byte sea una de estas dos cosas:

  - codigo que el trazador alcanza de verdad siguiendo el flujo desde los
    puntos de entrada, o
  - un byte dentro de un rango de datos IDENTIFICADO con una directiva D del
    fichero de notas, o sea con nombre y explicacion.

Y ES UN CONTROL DISTINTO DEL DE REPRODUCIBILIDAD. Un byte puede reensamblar
perfecto y estar sin explicar; o peor, estar mal explicado: si unos graficos se
marcan como codigo, el binario reensamblado sigue saliendo identico -los bytes
no cambian, solo su lectura- y el listado miente igual.

LO QUE AQUI ES MAS FACIL QUE EN UNA CINTA: esto es un cartucho, o sea una sola
foto de la memoria. Son 16384 bytes mapeados en 0x8000-0xBFFF (la pagina 2),
sin cargador, sin bloques y sin solapes, asi que el presupuesto se hace sobre
una imagen unica y no hay que ir sumando trozos que en memoria nunca conviven.

Uso: presupuesto.py <directorio_work> <directorio_src>
"""
import json
import os
import sys

ORG = 0x4000
TAM = 0x4000                      # 16 KB exactos, de 0x4000 a 0x7FFF
TRAZA = "pippols.trace.json"
NOTAS = "pippols.notes"

SIN_EXPLICAR, CODIGO, DATOS = 0, 1, 2


def rangos_de_notas(path):
    """Los rangos de datos declarados con la directiva D del fichero .notes."""
    out = []
    for ln in open(path, encoding="utf-8"):
        ln = ln.strip()
        if not ln.startswith("D "):
            continue
        p = ln.split(None, 3)
        out.append((int(p[1], 0), int(p[2], 0)))
    return out


def reparte(work, src):
    """Marca cada byte del cartucho como codigo, datos con nombre, o nada."""
    estado = bytearray(TAM)

    traza = json.load(open(os.path.join(work, TRAZA)))
    for tipo, a, b in traza["blocks"]:
        if tipo != "c":
            continue
        for i in range(max(0, a - ORG), min(TAM, b - ORG)):
            estado[i] = CODIGO

    for a, b in rangos_de_notas(os.path.join(src, NOTAS)):
        for i in range(max(0, a - ORG), min(TAM, b - ORG)):
            if estado[i] == SIN_EXPLICAR:
                estado[i] = DATOS

    return estado


def huecos(estado):
    """Agrupa los bytes sin explicar en rangos, para poder ir a mirarlos."""
    out, ini = [], None
    for i, v in enumerate(estado):
        if v == SIN_EXPLICAR and ini is None:
            ini = i
        elif v != SIN_EXPLICAR and ini is not None:
            out.append((ORG + ini, ORG + i))
            ini = None
    if ini is not None:
        out.append((ORG + ini, ORG + TAM))
    return out


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    work, src = sys.argv[1], sys.argv[2]

    estado = reparte(work, src)
    codigo = estado.count(CODIGO)
    datos = estado.count(DATOS)
    sin = estado.count(SIN_EXPLICAR)
    explicado = codigo + datos

    print("  %-24s %7s %8s" % ("", "bytes", "del total"))
    print("  " + "-" * 42)
    for etiqueta, n in (("codigo trazado", codigo),
                        ("datos identificados", datos),
                        ("sin explicar", sin)):
        print("  %-24s %7d %7.2f %%" % (etiqueta, n, 100.0 * n / TAM))
    print("  " + "=" * 42)
    print("  %-24s %7d %7.2f %%" % ("explicado", explicado,
                                    100.0 * explicado / TAM))

    pendientes = huecos(estado)
    if pendientes:
        print()
        print("  Sin explicar, por rangos:")
        for a, b in pendientes:
            print("    0x%04X..0x%04X  (%d bytes)" % (a, b - 1, b - a))
        print()
        print("  Cada uno de estos rangos tiene que acabar dentro de una")
        print("  directiva D del fichero de notas, con una explicacion de que")
        print("  es y de como se sabe.")
        return 1

    print()
    print("  OK: ni un byte del cartucho sin asignar")
    return 0


if __name__ == "__main__":
    sys.exit(main())
