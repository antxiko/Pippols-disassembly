#!/usr/bin/env python3
"""Genera la portada de la web, en los dos idiomas.

El diseno es el compartido por la serie (tools/estilo_web.py) y la pagina sale
autocontenida, con las imagenes embebidas como data URI.

Ni el rotulo de la cabecera ni la galeria son ilustraciones traidas de fuera, y
tampoco son capturas: salen de repetir, paso a paso, lo que hace el propio
cartucho. tools/graficos.py reconstruye la memoria de video con las copias de la
ROM -las tiras del fondo, el generador de los 192 caracteres, el descompresor
del mapa- y dibuja con eso; si un rango estuviera mal etiquetado, la galeria
saldria ruido.

Uso: make_web.py <docs/imagenes> <salida.html> <idioma>
"""
import base64
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from estilo_web import ESTILO                                   # noqa: E402

# Las cifras de la portada salen de contar sobre el listado generado, no de
# escribirlas aqui a ojo: 16384 = 9099 + 7285, que es lo que imprime
# tools/presupuesto.py (make sanity). Los rotulos se formatean a partir de
# estos numeros para que no puedan quedarse desfasados por su cuenta.
CODIGO = 9099
DATOS = 7285
PANTALLAS = 18                      # las del mapa del mundo (0x7B62 y 0x7B84)
CARACTERES = 192                    # los 8 desplazamientos x 24 del fondo


def mil(n, idioma):
    return f"{n:,}".replace(",", "." if idioma == "es" else ",")


TXT = {
    "es": dict(
        titulo="Pippols (1985) — desensamblado comentado",
        aviso="<b>Aquí no hay ni una captura de pantalla.</b> Todas las "
              "imágenes están dibujadas repitiendo lo que hace el cartucho: se "
              "reconstruye la memoria de vídeo con sus mismas copias y se "
              "vuelven a montar los caracteres y el mapa con sus mismas "
              "tablas. Lo demás —el listado y las cifras— sale del binario y se "
              "reproduce con <code>make</code>.",
        claim="Un cartucho de 16 KB de 1985 que mueve la pantalla de pixel en "
              "pixel en un modo de vídeo que no tiene desplazamiento. Lo "
              "consigue teniendo el fondo ocho veces en la memoria de vídeo y "
              "repintando la pantalla entera cada fotograma, y eso se lleva "
              "tres cuartas partes del tiempo de la máquina.",
        ficha=["Konami · <b>1985</b>", "Cartucho <b>RC-729</b>, 16 KB",
               "MSX1 · <b>página 1</b>", "Volcado <b>ad011203…</b>"],
        nav=[("#numbers", "Las cifras"), ("#findings", "Hallazgos"),
             ("#screens", "Lo que dibuja")],
        docnav=[("EMPEZAR.html", "Empezar"), ("EL-JUEGO.html", "El juego"),
                ("EL-CARTUCHO.html", "El cartucho"),
                ("EL-CODIGO.html", "El código"),
                ("EL-SCROLL-AL-PIXEL.html", "El scroll al pixel"),
                ("HALLAZGOS.html", "Hallazgos"),
                ("PREGUNTAS-ABIERTAS.html", "Preguntas abiertas")],
        otro=("../", "In English"),
        h_num="El juego en cifras", h_find="Lo que apareció al desmontarlo",
        h_scr="Lo que el cartucho dibuja",
        cifras=[("100 %", "del binario explicado"),
                (str(PANTALLAS), "pantallas del mundo"),
                (str(CARACTERES), "caracteres para el scroll"),
                (mil(CODIGO, "es"), "bytes de código"),
                (mil(DATOS, "es"), "bytes de datos"),
                ("0", "bytes sin identificar")],
        nota_scr="Cada una de estas imágenes es el cartucho repetido fuera de "
                 "él: las tiras del fondo se descomprimen como las descomprime "
                 "la ROM, los 192 caracteres se generan con el mismo bucle y el "
                 "mapa se monta con las mismas tablas. Debajo de cada pie está "
                 "la dirección de la rutina de donde sale.",
        pie_leg="Esto es trabajo de documentación y preservación sobre un "
                "juego de 1985: el código y los gráficos siguen siendo de sus "
                "autores y de Konami, y la imagen del cartucho no se "
                "distribuye.",
    ),
    "en": dict(
        titulo="Pippols (1985) — a commented disassembly",
        aviso="<b>There is not one screenshot here.</b> Every picture is drawn "
              "by repeating what the cartridge does: video memory is rebuilt "
              "with its own copies and the characters and the map are put back "
              "together with its own tables. Everything else —the listing and "
              "the numbers— comes from the binary and is reproducible with "
              "<code>make</code>.",
        claim="A 16 KB cartridge from 1985 that moves the screen one pixel at "
              "a time in a video mode with no scrolling at all. It manages it "
              "by keeping the background in video memory eight times over and "
              "repainting the whole screen every frame, and that takes three "
              "quarters of the machine's time.",
        ficha=["Konami · <b>1985</b>", "An <b>RC-729</b> 16 KB cartridge",
               "MSX1 · <b>page 1</b>", "Dump <b>ad011203…</b>"],
        nav=[("#numbers", "The numbers"), ("#findings", "What turned up"),
             ("#screens", "What it draws")],
        docnav=[("GETTING-STARTED.html", "Getting started"),
                ("THE-GAME.html", "The game"),
                ("THE-CARTRIDGE.html", "The cartridge"),
                ("THE-CODE.html", "The code"),
                ("THE-PIXEL-SCROLL.html", "The pixel scroll"),
                ("FINDINGS.html", "Findings"),
                ("OPEN-QUESTIONS.html", "Open questions")],
        otro=("es/", "En castellano"),
        h_num="The game in numbers",
        h_find="What turned up when we took it apart",
        h_scr="What the cartridge draws",
        cifras=[("100%", "of the binary explained"),
                (str(PANTALLAS), "screens in the world"),
                (str(CARACTERES), "characters for the scroll"),
                (mil(CODIGO, "en"), "bytes of code"),
                (mil(DATOS, "en"), "bytes of data"),
                ("0", "bytes unidentified")],
        nota_scr="Each of these pictures is the cartridge replayed outside it: "
                 "the background strips are decompressed the way the ROM "
                 "decompresses them, the 192 characters are generated with the "
                 "same loop and the map is assembled from the same tables. "
                 "Under each caption is the address of the routine it comes "
                 "from.",
        pie_leg="This is documentation and preservation work on a 1985 game: "
                "the code and artwork still belong to their authors and to "
                "Konami, and the cartridge image is not distributed.",
    ),
}

HALLAZGOS = {
    "es": [
        ("El fondo está ocho veces en la memoria de vídeo",
         "<p>SCREEN 2 no tiene registro de desplazamiento, así que Pippols se "
         "lo fabrica: en la VRAM hay <b>192 caracteres</b> (del 0x40 al 0xFF) "
         "que son ocho copias del mismo juego de 24, cada una bajada un pixel "
         "más. Desplazar la pantalla un pixel es sumarle 24 al número de "
         "carácter y volver a escribir la tabla de nombres entera, 24 filas por "
         "22 columnas, cada fotograma; no se toca ni un patrón.</p>"
         "<p>De los doce caracteres de cada mitad, cuatro son <b>costuras</b> "
         "(0x56ED): el final de una tira arriba y el principio de otra abajo. "
         "Sin ellas el dibujo se partiría a media altura en cuanto el "
         "desplazamiento no fuera cero.</p>"),
        ("Todo el mapa del juego cabe en 328 bytes",
         "<p>Una fase son trece tramos de 24 filas; un tramo, seis piezas de "
         "cuatro columnas; y las 44 piezas se montan en RAM pegando grupos de "
         "tres filas de un diccionario de 25 (0x54C0). La lista de índices "
         "—ocho por pieza— son <b>328 bytes</b>, y con eso está descrito el "
         "camino entero.</p>"
         "<p>El bucle de 0x5496, sin embargo, lee 352 índices: las 24 últimas "
         "lecturas caen ya dentro del <b>código</b> de 0x5653, y de ahí salen "
         "tres piezas de basura. No importa, porque ningún tramo apunta a "
         "ellas. A las piezas 0 y 1, que están bien montadas, tampoco.</p>"),
        ("Lo que cuesta, medido en el emulador",
         "<p>En openMSX, sobre un Philips VG-8020 (PAL, 71 591 ciclos por "
         "fotograma) y con 1112 fotogramas de la demo: repintar la tabla de "
         "nombres se lleva <b>32 557 ciclos de media, el 45,5 % del "
         "fotograma</b>, y la interrupción entera <b>52 533, el 73,4 %</b>. "
         "Son 732,7 escrituras al puerto del VDP por fotograma.</p>"
         "<p>Por eso el programa principal no hace nada: se queda en un "
         "<code>jr $</code> de dos bytes en 0x4074 y todo el juego corre dentro "
         "de la interrupción, un paso por fotograma.</p>"),
        ("El marcador miente por diez",
         "<p>Los puntos son tres bytes BCD, pero el panel pinta las seis cifras "
         "y detrás un <b>cero fijo</b>. Lo que se ve es diez veces el contador, "
         "y por eso todas las puntuaciones acaban en cero. La primera vida "
         "extra cae a los 20 000 y luego cada 60 000.</p>"),
        ("Un salto que cae dentro de otra instrucción",
         "<p>En 0x717D hay un <code>jr nz,$+4</code> que va a parar a 0x7181, y "
         "0x7181 no es el principio de nada: es el byte de desplazamiento del "
         "<code>jr z</code> de la línea de arriba. Se ejecuta como "
         "<code>dec b</code>, que ahí da igual porque el bucle de enemigos "
         "guarda BC en la pila, y sigue de largo. Es el único sitio del "
         "cartucho donde se entra a una instrucción por en medio.</p>"),
        ("Dieciocho pantallas y cinco dibujos",
         "<p>Las 18 pantallas del mundo comparten los dibujos del fondo: hay "
         "ocho fases pero sólo cinco juegos de tiras, y lo que cambia de una "
         "pantalla a otra es un <b>intercambio de tres parejas de tintas</b> "
         "(0x577D) sobre los 96 bytes de color. La misma flor sale roja o rosa, "
         "el mismo árbol verde o azul.</p>"
         "<p>Y el recorrido no es una fila: la tabla de 0x7B62 da dos destinos "
         "por pantalla, y se toma uno u otro según se vaya subiendo o "
         "bajando.</p>"),
        ("La bota y el escudo son el mismo dibujo",
         "<p>En la tabla de 0x785A cada objeto lleva su pareja (patrón, color). "
         "El objeto 8 —la bota, que hace andar una vez y media más rápido— y el "
         "9 —el escudo— llevan <b>el mismo patrón, 0xC0</b>, y sólo se "
         "diferencian en el color. Los objetos 1 y 4 hacen lo mismo con el "
         "patrón 0xA4.</p>"),
    ],
    "en": [
        ("The background is in video memory eight times over",
         "<p>SCREEN 2 has no scroll register, so Pippols builds one: VRAM holds "
         "<b>192 characters</b> (0x40 to 0xFF) that are eight copies of the "
         "same set of 24, each one a pixel lower. Scrolling the screen by a "
         "pixel means adding 24 to the character number and writing the whole "
         "name table again, 24 rows by 22 columns, every frame; not one pattern "
         "is touched.</p>"
         "<p>Of the twelve characters in each half, four are <b>seams</b> "
         "(0x56ED): the end of one strip on top and the beginning of another "
         "underneath. Without them the drawing would split halfway down as soon "
         "as the offset was not zero.</p>"),
        ("The game's entire map fits in 328 bytes",
         "<p>A stage is thirteen stretches of 24 rows; a stretch, six pieces of "
         "four columns; and the 44 pieces are built in RAM by gluing groups of "
         "three rows from a dictionary of 25 (0x54C0). The index list —eight "
         "per piece— is <b>328 bytes</b>, and that describes the whole road.</p>"
         "<p>The loop at 0x5496, though, reads 352 indices: the last 24 reads "
         "land inside the <b>code</b> at 0x5653, and out of that come three "
         "junk pieces. It does not matter, because no stretch points at them. "
         "Nor at pieces 0 and 1, which are properly built.</p>"),
        ("What it costs, measured in the emulator",
         "<p>In openMSX, on a Philips VG-8020 (PAL, 71,591 cycles per frame) "
         "over 1112 frames of the demo: repainting the name table takes "
         "<b>32,557 cycles on average, 45.5 % of the frame</b>, and the whole "
         "interrupt <b>52,533, or 73.4 %</b>. That is 732.7 writes to the VDP "
         "port per frame.</p>"
         "<p>Which is why the main program does nothing: it sits in a two-byte "
         "<code>jr $</code> at 0x4074 and the entire game runs inside the "
         "interrupt, one step per frame.</p>"),
        ("The score lies by a factor of ten",
         "<p>The score is three BCD bytes, but the panel paints the six digits "
         "and then a <b>fixed zero</b> behind them. What you see is ten times "
         "the counter, which is why every score ends in zero. The first extra "
         "life comes at 20,000 and then every 60,000.</p>"),
        ("A jump that lands inside another instruction",
         "<p>At 0x717D there is a <code>jr nz,$+4</code> that ends up at "
         "0x7181, and 0x7181 is not the start of anything: it is the "
         "displacement byte of the <code>jr z</code> on the line above. It "
         "executes as <code>dec b</code>, which does not matter there because "
         "the creature loop keeps BC on the stack, and carries straight on. It "
         "is the only place in the cartridge where an instruction is entered "
         "halfway through.</p>"),
        ("Eighteen screens and five drawings",
         "<p>The 18 world screens share the background drawings: there are "
         "eight stages but only five sets of strips, and what changes from one "
         "screen to another is a <b>swap of three pairs of inks</b> (0x577D) "
         "over the 96 colour bytes. The same flower comes out red or pink, the "
         "same tree green or blue.</p>"
         "<p>And the route is not a line: the table at 0x7B62 gives two "
         "destinations per screen, and one or the other is taken depending on "
         "whether you are going up or down.</p>"),
        ("The boot and the shield are the same drawing",
         "<p>In the table at 0x785A each object carries its (pattern, colour) "
         "pair. Object 8 —the boot, which makes you walk one and a half times "
         "faster— and object 9 —the shield— carry <b>the same pattern, "
         "0xC0</b>, and differ only in colour. Objects 1 and 4 do the same with "
         "pattern 0xA4.</p>"),
    ],
}

# La galeria: fichero, pie en castellano, pie en ingles. Cada uno lleva la
# direccion de la rutina de donde sale la imagen.
GALERIA = [
    ("ochofases_0.png",
     "0x569E — la misma ventana del fondo en los ocho desplazamientos. Entre "
     "una y la siguiente sólo cambia el número de carácter, en 24",
     "0x569E — the same window of background at the eight offsets. Between one "
     "and the next only the character number changes, by 24"),
    ("fases_0.png",
     "0x56B5 — los 192 caracteres de una fase: cada fila es un desplazamiento, "
     "y las cuatro últimas de cada mitad son las costuras que hacen que el "
     "dibujo siga siendo continuo",
     "0x56B5 — one stage's 192 characters: each row is one offset, and the last "
     "four of each half are the seams that keep the drawing continuous"),
    ("ochofondos.png",
     "0x571E — las ocho fases de fondo, una al lado de otra: cinco juegos de "
     "tiras y un intercambio de tintas (0x577D) para las 18 pantallas",
     "0x571E — the eight background stages side by side: five sets of strips "
     "and an ink swap (0x577D) for the 18 screens"),
    ("pantalla_0_0.png",
     "0x5384 — la fase 0, las flores. La pantalla entera armada con las tablas "
     "del mapa: trece tramos de seis piezas de cuatro columnas",
     "0x5384 — stage 0, the flowers. A whole screen assembled from the map "
     "tables: thirteen stretches of six four-column pieces"),
    ("pantalla_1_0.png",
     "0x5384 — la fase 1, los árboles verdes",
     "0x5384 — stage 1, the green trees"),
    ("pantalla_4_0.png",
     "0x5384 — la fase 4: los mismos árboles con otras tintas, sin un byte de "
     "dibujo nuevo",
     "0x5384 — stage 4: the same trees with different inks, without one new "
     "byte of drawing"),
    ("pantalla_2_0.png",
     "0x5384 — la fase 2, los árboles altos en azul",
     "0x5384 — stage 2, the tall trees in blue"),
    ("pantalla_5_0.png",
     "0x5384 — la fase 5: los mismos, en rojo",
     "0x5384 — stage 5: the same ones, in red"),
    ("pantalla_3_0.png",
     "0x5384 — la fase 3, los moáis, con el camino abriéndose en el centro",
     "0x5384 — stage 3, the moai, with the road opening up in the middle"),
    ("pantalla_6_0.png",
     "0x5384 — la fase 6: los moáis en verde",
     "0x5384 — stage 6: the moai in green"),
    ("pantalla_7_0.png",
     "0x5384 — la fase 7, las flores de dos colores; es el único juego de "
     "tiras con las cuatro distintas",
     "0x5384 — stage 7, the two-colour flowers; the only set of strips with all "
     "four different"),
    ("pantalla_0_4.png",
     "0x5312 — la misma fase 0, cuatro pixeles más abajo. Es todo lo que hay "
     "que cambiar para desplazar la pantalla: el número de carácter",
     "0x5312 — the same stage 0, four pixels lower. That is all it takes to "
     "scroll the screen: the character number"),
    ("sprites.png",
     "0x5E67 — los 64 sprites de 16x16 tal como quedan en la VRAM: el enanito, "
     "los doce bichos, los objetos, los rótulos de puntos y los disparos",
     "0x5E67 — the 64 16x16 sprites as they end up in VRAM: the little fellow, "
     "the twelve creatures, the objects, the points labels and the shots"),
]


def img64(ruta):
    with open(ruta, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def main(argv):
    if len(argv) < 4:
        print(__doc__)
        return 2
    imgdir, salida, idioma = argv[1:4]
    t = TXT[idioma]

    ruta_logo = os.path.join(imgdir, "logo.png")
    cabecera = (f'<img src="{img64(ruta_logo)}" alt="Pippols (1985)">'
                if os.path.exists(ruta_logo) else "<h1>Pippols (1985)</h1>")

    nav = "".join(f'<a href="{h}">{x}</a>' for h, x in t["nav"])
    nav += "".join(f'<a href="{h}">{x}</a>' for h, x in t["docnav"])
    nav += (f'<a href="{t["otro"][0]}" style="margin-left:auto;color:var(--oro)">'
            f'{t["otro"][1]}</a>')

    cifras = "".join(f'<div class="cifra"><b>{v}</b><span>{e}</span></div>'
                     for v, e in t["cifras"])
    halls = "".join(f'<div class="hall"><h3>{tit}</h3>{cuerpo}</div>'
                    for tit, cuerpo in HALLAZGOS[idioma])
    imgs = ""
    faltan = []
    for fich, es, en in GALERIA:
        ruta = os.path.join(imgdir, fich)
        if not os.path.exists(ruta):
            faltan.append(fich)
            continue
        pie = es if idioma == "es" else en
        imgs += (f'<figure><img src="{img64(ruta)}" alt="{pie}">'
                 f'<figcaption>{pie}</figcaption></figure>')
    if faltan:
        print("  (faltan %d imagenes: %s)" % (len(faltan), " ".join(faltan)))

    html = f"""<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{t['titulo']}</title>
<style>{ESTILO}</style>
<header class="top">
  {cabecera}
  <p class="claim">{t['claim']}</p>
  <p class="ficha">{' · '.join(t['ficha'])}</p>
</header>
<p class="ficha" style="border:1px solid var(--oro);padding:.8em 1em;margin:1.5em 0">
{t['aviso']}</p>
<nav>{nav}</nav>
<section id="numbers">
  <h2>{t['h_num']}</h2>
  <div class="cifras">{cifras}</div>
</section>
<section id="findings"><h2>{t['h_find']}</h2>{halls}</section>
<section id="screens">
  <h2>{t['h_scr']}</h2>
  <p class="n">{t['nota_scr']}</p>
  <div class="galeria">{imgs}</div>
</section>
<footer><p>{t['pie_leg']}</p></footer>
"""
    with open(salida, "w", encoding="utf-8") as f:
        f.write(html)
    print("  %s: %d KB (%s)" % (salida, len(html) // 1024, idioma))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
