#!/usr/bin/env python3
"""Saca la marca que Konami escondio al final de algunos cartuchos de MSX.

El hallazgo no es nuestro: lo destapo Manuel Pazos (@ManuelPazosMSX) en
septiembre de 2021. Gracias a el se sabe que hay que mirar ahi.

Detras del relleno 0xFF, leyendo hacia el final del fichero:

    [titulo, N bytes, EN ORDEN INVERSO]  [N]  [las dos ultimas cifras del RC en
    BCD]  [0xAA]

El titulo va en katakana con el codigo de la casa: indice = byte - 0x80, y los
indices 0 a 44 son el gojuon corrido, sin WO. El 0x00 es un espacio.

Del 45 en adelante van los signos, y cinco estan CONFIRMADOS leyendo los
cartuchos de la serie -no adivinados-:

  51  YO pequena     )  los dos salen de Antarctic (RC-701), cuyo titulo es
  53  TSU pequena    )  KE-TSU-KI-YO-KU NA-N-KI-YO-KU TA"-I-HO"-U-KE-N,
  55  dakuten        )  o sea KEKKYOKU NANKYOKU DAIBOUKEN, que es el nombre
                     )  real del juego. TA+dakuten = DA y HO+dakuten = BO.
  56  handakuten     )  sale de Hyper Rally (RC-718): HA-I-HA+56-58-RA-RI-58,
  58  alargamiento   )  que es HAIPAA RARII, "Hyper Rally". HA+56 = PA, y el
                     )  58 es la barra que alarga la vocal.

Los indices 45-50, 52, 54 y 57 no aparecen en ninguna ROM de las que hay a
mano, asi que se dejan como estan: se imprimen en crudo, <XX>.

Uso: marca_konami.py <rom> [<rom> ...]
Sale con 1 si ninguna de las ROM lleva marca.
"""
import os
import sys
import unicodedata

# El gojuon corrido, que es el orden en el que Konami numero los caracteres.
KANA = ("A I U E O KA KI KU KE KO SA SI SU SE SO TA TI TU TE TO "
        "NA NI NU NE NO HA HI HU HE HO MA MI MU ME MO YA YU YO "
        "RA RI RU RE RO WA N").split()
SILABA = ("アイウエオカキクケコ"
          "サシスセソタチツテト"
          "ナニヌネノハヒフヘホ"
          "マミムメモヤユヨ"
          "ラリルレロワン")

# Signos confirmados leyendo los cartuchos (ver el docstring). Los dos que
# MODIFICAN a la silaba de delante van aparte, porque no ocupan hueco propio.
MODIFICA = {55: "゙", 56: "゚"}          # dakuten y handakuten
EXTRA = {51: ("yo", "ョ"), 53: ("tsu", "ッ"), 58: ("-", "ー")}

# Lo que el dakuten (") y el handakuten (o) le hacen a la silaba de delante.
SONORA = dict(zip("KA KI KU KE KO SA SI SU SE SO TA TI TU TE TO "
                  "HA HI HU HE HO".split(),
                  "GA GI GU GE GO ZA JI ZU ZE ZO DA JI ZU DE DO "
                  "BA BI BU BE BO".split()))
EXPLOSIVA = dict(zip("HA HI HU HE HO".split(), "PA PI PU PE PO".split()))


def transcribe(titulo):
    """Los bytes del titulo, del derecho -> (romaji, katakana).

    Los signos 55 y 56 no son caracteres: se comen la silaba anterior y la
    cambian, que es justo lo que hace la escritura japonesa.
    """
    romaji, kana = [], []
    for v in titulo:
        if v == 0:
            romaji.append(" ")
            kana.append("　")
            continue
        i = v - 0x80
        if i in MODIFICA and romaji:
            tabla = SONORA if i == 55 else EXPLOSIVA
            romaji[-1] = tabla.get(romaji[-1], romaji[-1] + ("\"" if i == 55 else "o"))
            kana[-1] = unicodedata.normalize("NFC", kana[-1] + MODIFICA[i])
        elif 0 <= i < len(KANA):
            romaji.append(KANA[i])
            kana.append(SILABA[i])
        elif i in EXTRA:
            romaji.append(EXTRA[i][0])
            kana.append(EXTRA[i][1])
        else:
            romaji.append("<%02X>" % v)
            kana.append("<%02X>" % v)
    return " ".join(romaji), "".join(kana)


def marca(rom):
    """(rc, cuantos, titulo ya puesto del derecho) o None si no la lleva."""
    i = len(rom) - 1
    while i > 0 and rom[i] == 0xFF:
        i -= 1
    if i < 3 or rom[i] != 0xAA:
        return None
    rc, n = rom[i - 1], rom[i - 2]
    if n == 0 or n > i - 2:
        return None
    return rc, n, bytes(reversed(rom[i - 2 - n:i - 2]))


def escribe(linea):
    """Igual que print, pero sin morir si la consola no sabe de katakana."""
    try:
        print(linea)
    except UnicodeEncodeError:
        print(linea.encode("ascii", "replace").decode("ascii"))


def main():
    alguna = False
    for fn in sys.argv[1:]:
        with open(fn, "rb") as f:
            m = marca(f.read())
        nombre = os.path.basename(fn)
        if not m:
            print("  %-58s sin marca" % nombre[:58])
            continue
        alguna = True
        rc, n, tit = m
        romaji, kana = transcribe(tit)
        print("  %-58s RC-7%02X  %d bytes" % (nombre[:58], rc, n))
        escribe("  %-58s %s" % ("", kana))
        print("  %-58s %s" % ("", romaji))
    sys.exit(0 if alguna else 1)


if __name__ == "__main__":
    main()
