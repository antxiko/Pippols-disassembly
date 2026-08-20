#!/usr/bin/env python3
"""Convierte los documentos .md a HTML con el estilo del proyecto.

Asi la web de GitHub Pages es navegable entera, sin depender de Jekyll ni de
ninguna gema: se publica HTML plano y ya esta.

Soporta lo que usamos de Markdown: encabezados, parrafos, listas, tablas,
bloques de codigo, citas, enlaces, imagenes, negrita, cursiva, codigo en linea
y separadores.
"""
import html
import os
import re
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from estilo_web import ESTILO  # noqa: E402


# Un menu por idioma. La web se publica en ingles en la raiz de docs/ y en
# castellano bajo docs/es/. Son siete paginas por idioma: las seis de siempre y
# la del scroll al pixel, que es lo que tiene de particular este cartucho.
NAV_EN = [("index.html", "Home"), ("GETTING-STARTED.html", "Start"),
          ("THE-GAME.html", "The game"), ("THE-CARTRIDGE.html", "The cartridge"),
          ("THE-CODE.html", "The code"),
          ("THE-PIXEL-SCROLL.html", "The pixel scroll"),
          ("FINDINGS.html", "Findings"),
          ("OPEN-QUESTIONS.html", "Open questions")]
NAV_ES = [("index.html", "Portada"), ("EMPEZAR.html", "Empezar"),
          ("EL-JUEGO.html", "El juego"), ("EL-CARTUCHO.html", "El cartucho"),
          ("EL-CODIGO.html", "El código"),
          ("EL-SCROLL-AL-PIXEL.html", "El scroll al pixel"),
          ("HALLAZGOS.html", "Hallazgos"),
          ("PREGUNTAS-ABIERTAS.html", "Preguntas abiertas")]

# Cada documento se llama distinto en cada idioma, asi que el selector de idioma
# necesita saber cual es la pareja de cada pagina. Sin esto, cambiar de idioma te
# devuelve a la portada y pierdes por donde ibas.
_PAREJAS = [("GETTING-STARTED.html", "EMPEZAR.html"),
            ("THE-GAME.html", "EL-JUEGO.html"),
            ("THE-CARTRIDGE.html", "EL-CARTUCHO.html"),
            ("THE-CODE.html", "EL-CODIGO.html"),
            ("THE-PIXEL-SCROLL.html", "EL-SCROLL-AL-PIXEL.html"),
            ("FINDINGS.html", "HALLAZGOS.html"),
            ("OPEN-QUESTIONS.html", "PREGUNTAS-ABIERTAS.html")]
PAREJA = {}
for _en, _es in _PAREJAS:
    PAREJA[_en] = _es
    PAREJA[_es] = _en

# El pie va en el idioma de la pagina, y dice lo que el cartucho firma. De donde
# sale: de leer los rotulos. El KONAMI grande que sube al arrancar son los
# caracteres 0x40 en adelante (0x4731), y los dos "(c)KONAMI 1985" pequenos
# estan escritos con la fuente en las listas de 0x4488 y 0x4499. No hay creditos
# ni iniciales en el binario.
PIE = {
    "es": "<em>Pippols</em> lo publico Konami en 1985 para MSX; su numero de "
          "catalogo es RC-729. El cartucho firma tres veces: el <b>KONAMI</b> "
          "grande que sube al arrancar, y dos <b>©KONAMI 1985</b> escritos con "
          "la fuente, uno bajo el titulo y otro al pie del panel del marcador. "
          "No hay creditos ni iniciales en ninguna parte del binario. Todos los "
          "derechos sobre el juego siguen siendo de sus titulares. Este trabajo "
          "es de preservacion, estudio y documentacion.",
    "en": "<em>Pippols</em> was published by Konami in 1985 for the MSX; its "
          "catalogue number is RC-729. The cartridge signs itself three times: "
          "the big <b>KONAMI</b> that rises at boot, and two <b>©KONAMI "
          "1985</b> written in the font, one under the title and one at the "
          "foot of the score panel. There are no credits and no initials "
          "anywhere in the binary. All rights in the game remain with their "
          "holders. This is preservation, study and documentation work.",
}


def enlinea(t):
    """Formato dentro de una linea: codigo, negrita, cursiva, enlaces, imagenes."""
    trozos = re.split(r"(`[^`]+`)", t)
    out = []
    for i, tr in enumerate(trozos):
        if i % 2:                                   # dentro de comillas: literal
            out.append(f"<code>{html.escape(tr[1:-1])}</code>")
            continue
        s = html.escape(tr)
        s = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", r'<img src="\2" alt="\1">', s)
        s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", lambda m:
                   f'<a href="{ruta(m.group(2))}">{m.group(1)}</a>', s)
        s = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", s)
        s = re.sub(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])", r"<em>\1</em>", s)
        out.append(s)
    return "".join(out)


# La web se sirve desde docs/, asi que lo que este fuera de esa carpeta no
# existe para el navegador: esos enlaces se mandan al repositorio. Se puede
# cambiar sin tocar el codigo con la variable de entorno.
REPO = os.environ.get("PIPPOLS_REPO",
                      "https://github.com/antxiko/Pippols-disassembly")


def ruta(href):
    """Los enlaces entre documentos apuntan a .md; en la web van a .html."""
    if href.startswith(("http", "#", "mailto:")):
        return href
    h = href.replace("docs/", "")
    if h.startswith("../") and not h.startswith("../src") and not h.startswith("../tools"):
        return h if h.endswith((".html", ".png", ".txt")) else h.replace("../", "")
    h = h.replace("../", "")
    # Codigo fuente, herramientas y ficheros de la raiz: no estan bajo docs/
    if h.startswith(("src/", "tools/")) or h in (
            "README.md", "README.es.md", "LICENSE", "AVISO-LEGAL.md",
            "LEGAL-NOTICE.md", "Makefile"):
        return f"{REPO}/blob/main/{h}"
    if h.endswith(".md"):
        h = h[:-3] + ".html"
    return h


def ancla(titulo):
    """El id de un encabezado: minusculas, sin acentos y con guiones.

    Es la convencion de GitHub, asi que un enlace a #el-mundo funciona igual en
    la web publicada que en el Markdown de siempre.
    """
    t = unicodedata.normalize("NFKD", titulo)
    t = "".join(c for c in t if not unicodedata.combining(c))
    t = re.sub(r"[*_`\[\]()]", "", t).lower()
    t = re.sub(r"[^a-z0-9]+", "-", t)
    return t.strip("-")


def convierte(texto, titulo, actual, idioma="en"):
    ln = texto.split("\n")
    out, i = [], 0
    while i < len(ln):
        l = ln[i]
        if l.startswith("```"):                     # bloque de codigo
            j = i + 1
            cuerpo = []
            while j < len(ln) and not ln[j].startswith("```"):
                cuerpo.append(ln[j]); j += 1
            out.append("<pre><code>" + html.escape("\n".join(cuerpo)) + "</code></pre>")
            i = j + 1; continue
        if re.match(r"^\s*\|", l) and i + 1 < len(ln) and re.match(r"^\s*\|[\s:|-]+\|?\s*$", ln[i + 1]):
            filas = []                              # tabla
            while i < len(ln) and re.match(r"^\s*\|", ln[i]):
                filas.append([c.strip() for c in ln[i].strip().strip("|").split("|")])
                i += 1
            cab, cuerpo = filas[0], filas[2:]
            t = "<table><tr>" + "".join(f"<th>{enlinea(c)}</th>" for c in cab) + "</tr>"
            for f in cuerpo:
                t += "<tr>" + "".join(f"<td>{enlinea(c)}</td>" for c in f) + "</tr>"
            out.append(t + "</table>"); continue
        m = re.match(r"^(#{1,4})\s+(.*)$", l)
        if m:
            n = len(m.group(1))
            # Con id, para poder enlazar a una seccion concreta desde la portada.
            out.append(f'<h{n} id="{ancla(m.group(2))}">{enlinea(m.group(2))}</h{n}>')
            i += 1; continue
        if re.match(r"^---+\s*$", l):
            out.append("<hr>"); i += 1; continue
        if l.startswith(">"):
            cita = []
            while i < len(ln) and ln[i].startswith(">"):
                cita.append(ln[i].lstrip("> ").rstrip()); i += 1
            out.append(f"<blockquote>{enlinea(' '.join(cita))}</blockquote>"); continue
        if l.lstrip().startswith("<audio "):        # un reproductor puesto a mano
            out.append(l.strip()); i += 1; continue
        if re.match(r"^ {4,}\S", l):                # bloque de codigo indentado
            cuerpo = []
            while i < len(ln) and re.match(r"^ {4,}\S", ln[i]):
                cuerpo.append(ln[i][4:])
                i += 1
                # una linea en blanco no corta el bloque si detras sigue indentado
                if i < len(ln) and not ln[i].strip() and \
                        i + 1 < len(ln) and re.match(r"^ {4,}\S", ln[i + 1]):
                    cuerpo.append(""); i += 1
            out.append("<pre><code>" + html.escape("\n".join(cuerpo)) + "</code></pre>")
            continue
        m = re.match(r"^\s*([-*]|\d+\.)\s+", l)
        if m:
            orden = not m.group(1) in "-*"
            items, sangria = [], []
            while i < len(ln) and (re.match(r"^\s*([-*]|\d+\.)\s+", ln[i]) or
                                   (sangria and ln[i].startswith("  ") and ln[i].strip())):
                mm = re.match(r"^\s*(?:[-*]|\d+\.)\s+(.*)$", ln[i])
                if mm:
                    items.append(mm.group(1)); sangria = True
                else:
                    items[-1] += " " + ln[i].strip()
                i += 1
            tag = "ol" if orden else "ul"
            out.append(f"<{tag}>" + "".join(f"<li>{enlinea(x)}</li>" for x in items) + f"</{tag}>")
            continue
        if not l.strip():
            i += 1; continue
        parr = []                                   # parrafo
        while i < len(ln) and ln[i].strip() and not re.match(
                r"^(#{1,4}\s|```|>|\s*([-*]|\d+\.)\s|---+\s*$|\s*\|)", ln[i]):
            parr.append(ln[i].strip()); i += 1
        out.append(f"<p>{enlinea(' '.join(parr))}</p>")

    menu = NAV_EN if idioma == "en" else NAV_ES
    nav = "".join(f'<a href="{h}"{" style=color:var(--tinta)" if h == actual else ""}>{t}</a>'
                  for h, t in menu)
    # Selector de idioma: lleva al documento equivalente, no a la portada
    otro = PAREJA.get(actual, "index.html")
    if idioma == "en":
        nav += f'<a href="es/{otro}" style="margin-left:auto;color:var(--oro)">Castellano</a>'
    else:
        nav += f'<a href="../{otro}" style="margin-left:auto;color:var(--oro)">English</a>'
    return (f"<title>{html.escape(titulo)}</title>\n<style>{ESTILO}</style>\n"
            f'<div class="w"><nav class="top">{nav}</nav>\n' + "\n".join(out) +
            f'\n<footer><p>{PIE[idioma]}</p></footer></div>\n')


def main(docdir, idioma="en"):
    n = 0
    for fn in sorted(os.listdir(docdir)):
        if not fn.endswith(".md"):
            continue
        src = os.path.join(docdir, fn)
        dst = os.path.join(docdir, fn[:-3] + ".html")
        texto = open(src, encoding="utf-8").read()
        m = re.search(r"^#\s+(.*)$", texto, re.M)
        titulo = (m.group(1) if m else fn[:-3]) + " — Pippols (1985)"
        open(dst, "w", encoding="utf-8").write(
            convierte(texto, titulo, fn[:-3] + ".html", idioma))
        print(f"  {fn} -> {os.path.basename(dst)}")
        n += 1
    print(f"{n} documentos convertidos ({idioma})")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "en")
