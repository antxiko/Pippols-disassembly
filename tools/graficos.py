#!/usr/bin/env python3
"""Reconstruye lo que Pippols pinta, repitiendo lo que hace el cartucho.

    python3 tools/graficos.py pippols.rom work/gfx

No inventa nada: es la lista de copias y bucles de la ROM pasada a Python.

  - CARGA_TIRAS (0x571E) trae las cuatro tiras de 24 bytes de patrones y los
    cuatro bloques de color (RLE) a 0xEA00 / 0xEA60.
  - CAMBIA_COLORES (0x577D) hace el cambio de tinta de la pantalla.
  - EXPANDE_FASES (0x56B5) genera los 192 caracteres: 8 desplazamientos
    verticales x 24 caracteres, que es la clave del scroll al pixel.
  - El mapa: 0x5496 descomprime las 44 piezas a 0xE500, 0x5293 arma una fila
    de 6 bytes y 0x5312 la convierte en 22 caracteres de la tabla de nombres.
"""
import os
import struct
import sys
import zlib

ORG = 0x4000
PAL = [(0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120), (84, 85, 237), (125, 118, 252),
       (212, 82, 77), (66, 235, 245), (252, 85, 84), (255, 121, 120), (212, 193, 84),
       (230, 206, 128), (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255)]


def png(w, h, px, fn):
    raw = b"".join(b"\x00" + bytes(v for p in row for v in p) for row in px)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(fn, "wb").write(b"\x89PNG\r\n\x1a\n"
                         + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                         + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


# ---------------------------------------------------------------------------
# Los caracteres del fondo
# ---------------------------------------------------------------------------

def rle_color(rom, a):
    """El descompresor de 0x5752: 0 fin, n<0x80 repite n veces, n>=0x80 copia n&0x7F."""
    out = bytearray()
    p = a - ORG
    while True:
        n = rom[p]
        p += 1
        if n == 0:
            break
        if n & 0x80:
            k = n & 0x7F
            out += rom[p:p + k]
            p += k
        else:
            out += bytes([rom[p]]) * n
            p += 1
    return bytes(out)


def carga_tiras(rom, fase):
    """CARGA_TIRAS (0x571E): 96 bytes de patrones y 96 de color para la fase."""
    juego = rom[0x57E8 - ORG + fase]
    base = 0x57F0 + 16 * juego
    ptr = [rom[base - ORG + 2 * i] | (rom[base - ORG + 2 * i + 1] << 8) for i in range(8)]
    pat = bytearray()
    for i in range(4):
        o = ptr[i] - ORG
        pat += rom[o:o + 24]
    col = bytearray()
    for i in range(4, 8):
        col += rle_color(rom, ptr[i])
    return bytes(pat), bytes(col), juego, ptr


def cambia_colores(rom, col, pantalla):
    """CAMBIA_COLORES (0x577D): tres intercambios de tinta segun la pantalla."""
    n = rom[0x57D6 - ORG + pantalla]
    if n == 0:
        return col
    p = 0x57CA - ORG + 3 * n
    col = bytearray(col)
    for i in range(3):
        b = rom[p + i]
        d, e = b & 0xF0, b & 0x0F
        nb, nc = (e << 4) & 0xF0, (d >> 4) & 0x0F
        for j in range(0x60):
            if col[j] & 0xF0 == d:
                col[j] = (col[j] & 0x0F) | nb
            if col[j] & 0x0F == e:
                col[j] = (col[j] & 0xF0) | nc
    return bytes(col)


def expande_fases(src96):
    """EXPANDE_FASES (0x569E/0x56B5): 8 desplazamientos x 24 caracteres = 1536 bytes.

    Cada llamada a 0x56B5 trabaja sobre 48 bytes = dos tiras de 3 caracteres
    (A = u0,u1,u2 y B = u3,u4,u5) y suelta 12 caracteres:
        0..3   la tira A suelta, con relleno arriba y abajo
        4..7   la tira B suelta
        8      costura A sobre A     9  costura A sobre B
        10     costura B sobre A    11  costura B sobre B
    El relleno es 0x11, que en la tabla de color es negro sobre negro.
    """
    out = bytearray()
    for c in range(8):          # desplazamiento vertical, 0..7 pixeles
        for mitad in (0, 0x30):  # 0x00 = columna izquierda, 0x30 = columna derecha
            s = src96[mitad:mitad + 0x30]
            blk = bytes([0x11]) * c + s[0x00:0x18] + bytes([0x11]) * (8 - c)
            out += blk                                        # 0..3
            blk = bytes([0x11]) * c + s[0x18:0x30] + bytes([0x11]) * (8 - c)
            out += blk                                        # 4..7
            for alto, bajo in ((0x18, 0x00), (0x18, 0x18), (0x30, 0x00), (0x30, 0x18)):
                out += s[alto - c:alto] + s[bajo:bajo + 8 - c]  # 8..11
    return bytes(out)            # 8 x (12 izq + 12 der) = 192 caracteres


# ---------------------------------------------------------------------------
# El mapa
# ---------------------------------------------------------------------------

def piezas(rom):
    """0x5496: 352 grupos de 3 bytes desde el diccionario 0x54C0 -> 1056 bytes."""
    out = bytearray()
    p = 0x550B - ORG
    for _ in range(0x160):
        i = rom[p]
        p += 1
        o = 0x54C0 - ORG + 3 * i
        out += rom[o:o + 3]
    return bytes(out)            # 44 piezas de 24 filas


def fila_mapa(rom, tabla, plano, pos):
    """0x5293: los 6 bytes de la fila que hay en la posicion `pos` (en pixeles)."""
    seg, resto = divmod(pos & 0xFFFF, 0xC0)      # 0x5653: division por 0xC0
    col = (resto >> 3) & 0x1F                    # fila dentro del tramo, 0..23
    idx = rom[0x53A2 - ORG + 13 * plano + (seg & 0xFF)]
    base = 0x5424 - ORG + 6 * idx
    return [tabla[24 * rom[base + i] + col] for i in range(6)], col, seg


def nombres_fila(bytes6, fase_px):
    """0x5312: los 22 caracteres de la fila (columnas 1..22)."""
    L = (fase_px & 7) * 24
    out = []
    b = 6
    for v in bytes6:
        h = 0
        if v >= 0x80:
            a = v & 0x7F
            if a >= 0x60:
                n = a & 7
                if n & 1:
                    h = 0x47 if (n >> 1) & 2 else 0x43
                else:
                    h = 0x44 if (n >> 1) & 1 else 0x40
                h = (h + L) & 0xFF
                a = (0x48 + (n >> 1) + L) & 0xFF
            else:
                a = (a + L) & 0xFF
                h = a
        else:
            if v >= 0x0F:
                a = (v + L) & 0xFF
            else:
                a = v
        out.append(a)
        out.append((a + 0x0C) & 0xFF)
        b -= 1
        if b == 0:
            break
        out.append(h)
        out.append((h + 0x0C) & 0xFF)
    return out


# ---------------------------------------------------------------------------
# Pintado
# ---------------------------------------------------------------------------

def pinta(pat, col, nombres, filas, cols, esc=2):
    """pat/col: 256 caracteres (2048 bytes cada uno). nombres: lista de filas."""
    w, h = cols * 8 * esc, filas * 8 * esc
    px = [[(0, 0, 0)] * w for _ in range(h)]
    for r in range(filas):
        for c in range(cols):
            t = nombres[r][c] if c < len(nombres[r]) else 0
            for y in range(8):
                p = pat[t * 8 + y]
                k = col[t * 8 + y]
                fg, bg = PAL[k >> 4], PAL[k & 15]
                for x in range(8):
                    v = fg if p & (0x80 >> x) else bg
                    for dy in range(esc):
                        row = px[(r * 8 + y) * esc + dy]
                        for dx in range(esc):
                            row[(c * 8 + x) * esc + dx] = v
    return w, h, px


def main():
    rom = open(sys.argv[1], "rb").read()
    out = sys.argv[2] if len(sys.argv) > 2 else "work/gfx"
    os.makedirs(out, exist_ok=True)
    tabla = piezas(rom)

    for fase in range(8):
        pat96, col96, juego, ptr = carga_tiras(rom, fase)
        col96 = cambia_colores(rom, col96, fase)
        pat = bytearray(0x800)
        colt = bytearray(0x800)
        pat[0x200:0x800] = expande_fases(pat96)
        colt[0x200:0x800] = expande_fases(col96)
        print("fase %d: juego %d  patrones %s  color %d bytes"
              % (fase, juego, ' '.join('%04X' % p for p in ptr[:4]), len(col96)))

        # los 192 caracteres del fondo, 24 por fila (una fila = un desplazamiento)
        nom = [[0x40 + 24 * f + k for k in range(24)] for f in range(8)]
        w, h, px = pinta(pat, colt, nom, 8, 24, 3)
        png(w, h, px, os.path.join(out, "fases_%d.png" % fase))

        # una pantalla entera
        for despl in (0, 4):
            pos = 0x00C0 + despl
            nom = []
            for r in range(24):
                b6, _, _ = fila_mapa(rom, tabla, fase, pos + 8 * (23 - r))
                nom.append([0] + nombres_fila(b6, pos))
            w, h, px = pinta(pat, colt, nom, 24, 23, 2)
            png(w, h, px, os.path.join(out, "pantalla_%d_%d.png" % (fase, despl)))
    print("escrito en", out)


if __name__ == "__main__":
    main()


# ---------------------------------------------------------------------------
# Los sprites (se llama aparte: python3 tools/graficos.py rom dir sprites)
# ---------------------------------------------------------------------------

def rle_vram(rom, a, vram, dst=None):
    """RLE_A_VRAM (0x43B4). Con dst=None lee la direccion de la cabecera."""
    p = a - ORG
    if dst is None:
        dst = rom[p] | (rom[p + 1] << 8)
        p += 2
    dst &= 0x3FFF
    while True:
        n = rom[p]
        p += 1
        if n == 0:
            break
        if n & 0x80:
            k = n & 0x7F
            if k == 0:
                dst = (rom[p] | (rom[p + 1] << 8)) & 0x3FFF
                p += 2
                continue
            vram[dst:dst + k] = rom[p:p + k]
            dst += k
            p += k
        else:
            vram[dst:dst + n] = bytes([rom[p]]) * n
            dst += n
            p += 1
    return dst


def pinta_sprites(rom, fn, esc=3):
    v = bytearray(0x4000)
    rle_vram(rom, 0x5E6D, v)                       # 0x5E67: los comunes, a 0x1880
    for i in range(26):                            # y los 26 bloques del jugador
        pt = rom[0x643A - ORG + 2 * i] | (rom[0x643B - ORG + 2 * i] << 8)
        if i < 4:
            rle_vram(rom, pt, v, 0x1800 + 32 * i)
    n = 64
    cols = 16
    filas = (n + cols - 1) // cols
    w, h = cols * 16 * esc, filas * 16 * esc
    px = [[(20, 20, 20)] * w for _ in range(h)]
    for s in range(n):
        base = 0x1800 + 32 * s
        cx, cy = (s % cols) * 16, (s // cols) * 16
        for q in range(4):
            ox, oy = (q // 2) * 8, (q % 2) * 8
            for y in range(8):
                b = v[base + q * 8 + y]
                for x in range(8):
                    if b & (0x80 >> x):
                        for dy in range(esc):
                            for dx in range(esc):
                                px[(cy + oy + y) * esc + dy][(cx + ox + x) * esc + dx] = (255, 255, 255)
    png(w, h, px, fn)


if len(sys.argv) > 3 and sys.argv[3] == "sprites":
    _rom = open(sys.argv[1], "rb").read()
    os.makedirs(sys.argv[2], exist_ok=True)
    pinta_sprites(_rom, os.path.join(sys.argv[2], "sprites.png"))
    print("sprites.png")


def tira_de_fases(rom, fase, fn, filas=8, cols=8, esc=3):
    """La misma ventana del fondo en los ocho desplazamientos, una al lado de otra."""
    pat96, col96, _, _ = carga_tiras(rom, fase)
    col96 = cambia_colores(rom, col96, fase)
    pat = bytearray(0x800)
    colt = bytearray(0x800)
    pat[0x200:0x800] = expande_fases(pat96)
    colt[0x200:0x800] = expande_fases(col96)
    tabla = piezas(rom)
    hueco = 6
    w = (cols * 8 * 8 + 7 * hueco) * esc
    h = filas * 8 * esc
    px = [[(40, 40, 40)] * w for _ in range(h)]
    for p in range(8):
        pos = 0x00C0 + p
        nom = []
        for r in range(filas):
            b6, _, _ = fila_mapa(rom, tabla, fase, pos + 8 * (filas - 1 - r))
            nom.append(nombres_fila(b6, pos)[:cols])
        _, _, sub = pinta(pat, colt, nom, filas, cols, esc)
        ox = p * (cols * 8 + hueco) * esc
        for y in range(h):
            px[y][ox:ox + cols * 8 * esc] = sub[y]
    png(w, h, px, fn)


if len(sys.argv) > 3 and sys.argv[3] == "scroll":
    _rom = open(sys.argv[1], "rb").read()
    os.makedirs(sys.argv[2], exist_ok=True)
    for _f in (0, 3):
        tira_de_fases(_rom, _f, os.path.join(sys.argv[2], "ochofases_%d.png" % _f))
    print("ochofases_*.png")


# ---------------------------------------------------------------------------
# Las ocho fases una al lado de otra (python3 tools/graficos.py rom dir mundo)
# ---------------------------------------------------------------------------

def contacto(rom, fn, esc=1, filas=24, cols=23):
    """Las ocho fases de fondo en una sola tira, para verlas de un golpe."""
    tabla = piezas(rom)
    hueco = 8
    w = (8 * cols * 8 + 7 * hueco) * esc
    h = filas * 8 * esc
    px = [[(24, 24, 24)] * w for _ in range(h)]
    for fase in range(8):
        pat96, col96, _, _ = carga_tiras(rom, fase)
        col96 = cambia_colores(rom, col96, fase)
        pat = bytearray(0x800)
        colt = bytearray(0x800)
        pat[0x200:0x800] = expande_fases(pat96)
        colt[0x200:0x800] = expande_fases(col96)
        pos = 0x00C0
        nom = []
        for r in range(filas):
            b6, _, _ = fila_mapa(rom, tabla, fase, pos + 8 * (filas - 1 - r))
            nom.append(([0] + nombres_fila(b6, pos))[:cols])
        _, _, sub = pinta(pat, colt, nom, filas, cols, esc)
        ox = fase * (cols * 8 + hueco) * esc
        for y in range(h):
            px[y][ox:ox + cols * 8 * esc] = sub[y]
    png(w, h, px, fn)


if len(sys.argv) > 3 and sys.argv[3] == "mundo":
    _rom = open(sys.argv[1], "rb").read()
    os.makedirs(sys.argv[2], exist_ok=True)
    contacto(_rom, os.path.join(sys.argv[2], "ochofondos.png"))
    print("ochofondos.png")


# ---------------------------------------------------------------------------
# El rotulo PIPPOLS de la pantalla de titulo
# (python3 tools/graficos.py rom dir titulo)
# ---------------------------------------------------------------------------

def rotulo_del_titulo(rom, fn, esc=4):
    """PINTA_TITULO (0x47C8) sube el dibujo y 0x47DC coloca los caracteres."""
    v = bytearray(0x4000)
    rle_vram(rom, 0x481A, v)                       # patrones a 0x2600, color a 0x0600
    # la lista de 0x47E8, en el formato de ESCRIBE_ROTULO: palabra de direccion,
    # caracteres, 0xFE cambia de renglon, 0xFF termina
    p = 0x47E8 - ORG
    celdas = {}
    dst = (rom[p] | (rom[p + 1] << 8)) & 0x3FFF
    p += 2
    while True:
        c = rom[p]
        p += 1
        if c == 0xFF:
            break
        if c == 0xFE:
            dst = (rom[p] | (rom[p + 1] << 8)) & 0x3FFF
            p += 2
            continue
        celdas[dst - 0x3800] = c
        dst += 1
    f0 = min(celdas) // 32
    f1 = max(celdas) // 32
    c0 = min(k % 32 for k in celdas)
    c1 = max(k % 32 for k in celdas)
    filas, cols = f1 - f0 + 1, c1 - c0 + 1
    nom = [[0x00] * cols for _ in range(filas)]
    for k, c in celdas.items():
        nom[k // 32 - f0][k % 32 - c0] = c
    w, h, px = pinta(v[0x2000:0x2800], v[0x0000:0x0800], nom, filas, cols, esc)
    png(w, h, px, fn)


if len(sys.argv) > 3 and sys.argv[3] == "titulo":
    _rom = open(sys.argv[1], "rb").read()
    os.makedirs(sys.argv[2], exist_ok=True)
    rotulo_del_titulo(_rom, os.path.join(sys.argv[2], "logo.png"))
    print("logo.png")
