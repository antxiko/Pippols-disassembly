#!/usr/bin/env python3
"""La musica del cartucho, ejecutando su motor de sonido (ver motor_musica.py).

Pide el sonido con `PIDE_SONIDO` (0x48F4, A = numero) y corre `PASO_DE_SONIDO`
(0x4987), que la interrupcion llama cada cuadro. Tres fichas de 14 bytes desde
0xE010; la copia del registro 7 del PSG, en 0xE03A.
Uso:  musica.py registros 0x8F [cuadros] | mp3 0x8F f.mp3 | todas docs/audio
      musica.py barrido 0x80 0xBF | emu
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import motor_musica  # noqa: E402
from motor_musica import P  # noqa: E402

TABLA = "ninguna llamada directa: está en la tabla de pistas"

PIEZAS = [
    P(0x8F, "La música de arranque", "The start-up tune",
      "`EST_MUSICA_DE_ARRANQUE`: suena y se esperan 0x50 fotogramas"),
    P(0x89, "La música de andar", "The walking tune",
      "`MUSICA_DEL_PASEO`: la de andar, o la del escudo si lo lleva"),
    P(0x92, "La música de la meta", "The goal tune",
      "`ELIGE_MUSICA` y `META_PARA_TODO`"),
    P(0x95, "El trono", "The throne", "`TRONO_APARECE`"),
    P(0x98, "Game over", "Game over", "`EST_FIN_DE_PARTIDA`"),
    P(0xA1, "La llegada al final", "Reaching the end", "`FINAL_LLEGA`"),
] + [P(n, "Pista 0x%02X de la tabla" % n, "Table track 0x%02X" % n, TABLA)
     for n in (0x87, 0x8E, 0x90, 0x91, 0x93, 0x94, 0x96, 0x97, 0x99, 0x9A)]

PAGINA = motor_musica.pagina_basica(
    "`PASO_DE_SONIDO`, 0x4987, y `PIDE_SONIDO`, 0x48F4, que le reparte los "
    "canales; lo llama la interrupción",
    "`PASO_DE_SONIDO`, 0x4987, and `PIDE_SONIDO`, 0x48F4, which hands it the "
    "channels; the interrupt calls it",
    "C-BIOS MSX1 japonés",
    [("la música de arranque (0x8F), sus primeros 219 cuadros y, tal como el "
      "juego la pide, otros 385 de 386",
      "the start-up tune (0x8F), its first 219 frames and, as the game asks "
      "for it, another 385 of 386"),
     ("la pista 0x87, sus primeros 219 cuadros",
      "track 0x87, its first 219 frames")],
    [("Cómo se pide una pieza",
      "`PIDE_SONIDO` recibe el número en A. Con los seis bits bajos elige "
      "los canales: menos de 7 es un efecto de un solo canal y de ahí en "
      "adelante, dos o tres. Cada ficha ocupa catorce bytes desde 0xE010 y "
      "0xE03A guarda la copia del mezclador del PSG, que el arranque deja "
      "en 0xB8. Las pistas «de la tabla» están en la tabla de pistas pero "
      "ninguna rutina las pide con un `ld a`; la música que `ELIGE_MUSICA` "
      "pide según la fase sale de un número calculado, y se omiten las más "
      "largas (0x88, 0x8A, 0x9C a 0xA0, 0xA2 y 0xA3).",
      "How a piece is asked for",
      "`PIDE_SONIDO` takes the number in A. The low six bits pick the "
      "channels: below 7 is a one-channel effect, from there up, two or "
      "three. Each record takes fourteen bytes from 0xE010 and 0xE03A holds "
      "the copy of the PSG mixer, which start-up leaves at 0xB8. The tracks "
      "marked «in the table» are in the track table but no routine asks for "
      "them with an `ld a`; the music `ELIGE_MUSICA` asks for by stage comes "
      "from a computed number, and the longest ones (0x88, 0x8A, 0x9C to "
      "0xA0, 0xA2 and 0xA3) are left out.")])

CFG = dict(rom="pippols.rom", org=0x4000, frame=0x4987, pide=0x48F4,
           ram=(0xE010, 0xE03B), ram0=[(0xE03A, 0xB8)],
           excluye=[0xE019, 0xE027, 0xE035], hz=60, psg0={7: 0xB8},
           piezas=PIEZAS, pagina=PAGINA,
           cotejado=[(0x8F, 386, None), (0x87, 770, None)])

if __name__ == "__main__":
    sys.exit(motor_musica.main(CFG, sys.argv[1:]))
