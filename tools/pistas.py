#!/usr/bin/env python3
"""Pistas para el trazador: lo que un trazado estatico no ve, sacado del codigo
que SI ha trazado.

    python3 tools/pistas.py <imagen> <org> <trace.json> [entries] [ocupado.bin]

Tres cosas, y cada una con la instruccion que la justifica, para copiarla tal
cual al fichero .entries:

  1. `ld hl,NN` seguido de `push hl`: NN es una direccion de RETORNO puesta a
     mano; algun `ret` de mas abajo acaba ahi. (Tambien `ld de/bc,NN` + push.)
  2. `ld (X),hl` / `ld (X),a` donde X cae sobre el OPERANDO de un `call` o un
     `jp` del codigo trazado: destino automodificado. Se lista la instruccion
     modificada y, si el valor se ve en un `ld hl,NN` justo antes, el destino.
  3. Para cada `jp (hl)` / `jp (ix)`, la tabla que lo alimenta, mirando hacia
     atras un `ld hl,NN` o el par `add a,LO / adc a,HI` que apunta a la base.

Solo se recorren los inicios de instruccion del trazado, con la misma tabla de
longitudes del trazador: leer desde mitad de una instruccion inventa punteros.
Se descartan destinos fuera de las zonas ocupadas (si se da ocupado.bin) y los
que ya son puntos de entrada.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from z80trace import BASE_LEN, ED_LEN4  # noqa: E402


def longitud(img, a):
    op = img[a]
    if op in (0xDD, 0xFD):
        sig = img[a + 1]
        if sig == 0xCB:
            return 4
        if sig in (0xDD, 0xFD):
            return 1
        return 1 + longitud(img, a + 1)
    if op == 0xCB:
        return 2
    if op == 0xED:
        return 4 if img[a + 1] in ED_LEN4 else 2
    return BASE_LEN[op]


def main():
    imgpath, org, trpath = sys.argv[1:4]
    org = int(org, 0)
    img = open(imgpath, "rb").read()
    tr = json.load(open(trpath))
    entradas = set()
    if len(sys.argv) > 4 and os.path.exists(sys.argv[4]):
        for ln in open(sys.argv[4]):
            ln = ln.split("#")[0].strip()
            if ln:
                entradas.add(int(ln.split()[0], 0))
    ocupado = None
    if len(sys.argv) > 5:
        ocupado = open(sys.argv[5], "rb").read()

    def dentro(a):
        if ocupado is not None:
            return 0 <= a < len(ocupado) and ocupado[a]
        return org <= a < org + len(img)

    # inicios de instruccion, en orden
    inicios = []
    for k, a, b in tr["blocks"]:
        if k != "c":
            continue
        p = a
        while p < b:
            inicios.append(p)
            p += longitud(img, p - org)
    es_inicio = set(inicios)
    w = lambda p: img[p - org] | (img[p + 1 - org] << 8)

    print("== 1. direcciones de retorno empujadas (ld rr,NN / push rr)")
    for i, p in enumerate(inicios[:-1]):
        op = img[p - org]
        if op in (0x01, 0x11, 0x21) and img[inicios[i + 1] - org] in (0xC5, 0xD5, 0xE5):
            reg = {0x01: "bc", 0x11: "de", 0x21: "hl"}[op]
            pr = {0xC5: "bc", 0xD5: "de", 0xE5: "hl"}[img[inicios[i + 1] - org]]
            if reg != pr:
                continue
            nn = w(p + 1)
            if not dentro(nn):
                continue
            marca = "" if nn not in entradas else "   (ya en entries)"
            print(f"  {p:#06x}: ld {reg},{nn:#06x} / push {reg}  -> {nn:#06x}{marca}")

    print("== 2. operandos de call/jp que alguien escribe (automodificacion)")
    operandos = {}
    for p in inicios:
        op = img[p - org]
        if op in (0xCD, 0xC3, 0xC4, 0xCC, 0xD4, 0xDC, 0xE4, 0xEC, 0xF4, 0xFC,
                  0xC2, 0xCA, 0xD2, 0xDA, 0xE2, 0xEA, 0xF2, 0xFA):
            operandos[p + 1] = p
            operandos[p + 2] = p
    for i, p in enumerate(inicios):
        op = img[p - org]
        if op in (0x22, 0x32, 0xED):
            if op == 0xED and img[p + 1 - org] not in (0x43, 0x53, 0x73):
                continue
            x = w(p + 2) if op == 0xED else w(p + 1)
            if x in operandos:
                ins = operandos[x]
                # el valor: un ld hl,NN justo antes
                val = ""
                for q in inicios[max(0, i - 3):i]:
                    if img[q - org] == 0x21:
                        val = f"  valor visto: {w(q+1):#06x} (ld hl en {q:#06x})"
                print(f"  {p:#06x} escribe en {x:#06x} = operando de {ins:#06x} "
                      f"(op {img[ins-org]:#04x}){val}")

    print("== 3. jp (hl) / jp (ix) / jp (iy) y su tabla")
    for i, p in enumerate(inicios):
        op = img[p - org]
        es = op == 0xE9 or (op in (0xDD, 0xFD) and img[p + 1 - org] == 0xE9)
        if not es:
            continue
        pista = []
        for q in inicios[max(0, i - 12):i]:
            o = img[q - org]
            if o == 0x21:
                pista.append(f"ld hl,{w(q+1):#06x} en {q:#06x}")
            if o == 0xC6:
                # add a,LO ... adc a,HI (con un ld l,a en medio o no): base LO/HI
                for r in inicios[i - 12:i]:
                    if q < r <= q + 4 and img[r - org] == 0xCE:
                        base = img[q + 1 - org] | (img[r + 1 - org] << 8)
                        pista.append(f"add a,{img[q+1-org]:#04x} en {q:#06x} / adc a,{img[r+1-org]:#04x} en {r:#06x} -> base {base:#06x}")
            if o == 0x2A:
                pista.append(f"ld hl,({w(q+1):#06x}) en {q:#06x}")
        print(f"  {p:#06x}: " + ("; ".join(pista) if pista else "sin pista cerca"))


if __name__ == "__main__":
    main()
