#!/usr/bin/env python3
"""Comprobaciones sobre el listado generado.

Ninguna de estas necesita el cartucho: se hacen sobre src/pippols.asm y
src/pippols.notes, que van en el repositorio. Lo que vigilan es que el listado
no se degrade sin que nadie se entere: que no desaparezcan comentarios, que no
vuelvan a aparecer bloques de datos sin identificar, y que las cifras que se
publican sean las del arbol.
"""
import os
import re
import unittest

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASM = os.path.join(RAIZ, "src", "pippols.asm")
NOTES = os.path.join(RAIZ, "src", "pippols.notes")
SCROLL = os.path.join(RAIZ, "EL-SCROLL-AL-PIXEL.md")
SCROLL_EN = os.path.join(RAIZ, "THE-PIXEL-SCROLL.md")
DOCS = os.path.join(RAIZ, "docs")

OTROS_JUEGOS = ("Pitfall", "Temptations", "Stardust", "Ale Hop", "Colt 36",
                "Middle Earth", "Monkey", "F-1 Spirit", "Athletic",
                "Antarctic")

ORG, FIN = 0x4000, 0x8000


def asm():
    with open(ASM, encoding="utf-8") as f:
        return f.read()


def notas():
    with open(NOTES, encoding="utf-8") as f:
        return f.read().splitlines()


def directivas(clave):
    return [l for l in notas() if l.startswith(clave + " ")]


def direcciones_vivas():
    """Las direcciones del cartucho que existen de verdad en el listado.

    Son las que mkasm.py escribe en la columna de la derecha, mas las de los
    `equ` de la cabecera: los destinos que caen dentro de otra instruccion no
    tienen linea propia y aun asi son direcciones buenas.
    """
    texto = asm()
    vivas = set(re.findall(r";([0-9a-f]{4})(?:\s|$)", texto, re.M))
    vivas |= set(re.findall(r"^\s*(?:defb|defw).*?;\s*([0-9a-f]{4})",
                            texto, re.M))
    vivas |= {d[-4:].lower()
              for d in re.findall(r"equ\s+0x0?([0-9A-Fa-f]{4,5})", texto)}
    # y las que nombran las propias anotaciones: las bases de tabla que caen
    # dentro de una instruccion (0x6B58, 0x7652...) son direcciones buenas y no
    # tienen linea propia en el listado
    todas_las_notas = chr(10).join(notas())
    vivas |= {d.lower()
              for d in re.findall(r"0x([0-9A-Fa-f]{4})", todas_las_notas)}
    vivas.add("7fff")                       # el ultimo byte del cartucho
    return vivas


class TestListado(unittest.TestCase):

    def test_ningun_bloque_de_datos_sin_identificar(self):
        """Cada zona de datos tiene que tener nombre y explicacion."""
        n = asm().count("DATOS sin identificar")
        self.assertEqual(n, 0, "hay %d bloques de datos sin identificar" % n)

    def test_todas_las_rutinas_con_call_tienen_nombre(self):
        """Si algo se llama con CALL es una rutina, y una rutina se bautiza."""
        sueltas = sorted(set(re.findall(
            r"\bcall (?:n?[zc],|p[oe],|[mp],)?(L_[0-9A-F]{4})", asm())))
        self.assertEqual(sueltas, [], "rutinas llamadas y sin nombre: %s"
                         % " ".join(sueltas[:12]))

    def test_no_queda_ninguna_etiqueta_sin_bautizar(self):
        """Aqui se bautizaron las 676, incluidos los destinos de salto."""
        sueltas = sorted(set(re.findall(r"\bL_[0-9A-F]{4}\b", asm())))
        self.assertEqual(sueltas, [], "etiquetas sin nombre: %s"
                         % " ".join(sueltas[:12]))

    def test_ninguna_etiqueta_declarada_dos_veces(self):
        """Dos etiquetas con el mismo nombre y el ensamblador se queja."""
        nombres = re.findall(r"^([A-Za-z_][\w]*):", asm(), re.M)
        repetidas = sorted({n for n in nombres if nombres.count(n) > 1})
        self.assertEqual(repetidas, [], "etiquetas repetidas: %s"
                         % " ".join(repetidas))

    def test_ningun_comentario_de_linea_repetido(self):
        """Dos C en la misma direccion: la segunda pisa a la primera."""
        dirs = [l.split()[1].upper() for l in directivas("C")]
        repes = sorted({d for d in dirs if dirs.count(d) > 1})
        self.assertEqual(repes, [], "comentarios repetidos en %s" % " ".join(repes))

    def test_ninguna_direccion_bautizada_dos_veces(self):
        """Dos L para la misma direccion: una de las dos se pierde en silencio."""
        dirs = [l.split()[1] for l in directivas("L")]
        repes = sorted({d for d in dirs if dirs.count(d) > 1})
        self.assertEqual(repes, [], "direcciones con dos nombres: %s"
                         % " ".join(repes))

    def test_todos_los_comentarios_llegan_al_listado(self):
        """Un comentario anclado a una direccion que ya no existe se pierde."""
        vivas = set(re.findall(r";([0-9a-f]{4})(?:\s|$)", asm(), re.M))
        perdidos = [l.split()[1] for l in directivas("C")
                    if l.split()[1][2:].lower() not in vivas]
        self.assertEqual(perdidos, [], "comentarios que no llegan: %s"
                         % " ".join(perdidos[:12]))

    def test_todas_las_cabeceras_llegan_al_listado(self):
        """Igual con las cabeceras de bloque."""
        vivas = set(re.findall(r";([0-9a-f]{4})(?:\s|$)", asm(), re.M))
        perdidas = sorted({l.split()[1] for l in directivas("B")
                           if l.split()[1][2:].lower() not in vivas})
        self.assertEqual(perdidas, [], "cabeceras que no llegan: %s"
                         % " ".join(perdidas[:12]))

    def test_todas_las_etiquetas_llegan_al_listado(self):
        """Una L cuyo nombre no aparece definido en el .asm es una L perdida."""
        texto = asm()
        perdidas = [l.split()[2] for l in directivas("L")
                    if not re.search(r"^%s:" % re.escape(l.split()[2]), texto, re.M)
                    and not re.search(r"^%s:\s+equ" % re.escape(l.split()[2]),
                                      texto, re.M)]
        self.assertEqual(perdidas, [], "etiquetas que no llegan: %s"
                         % " ".join(perdidas[:12]))

    def test_los_rangos_no_se_solapan(self):
        """Dos D que pisan los mismos bytes: uno de los dos esta mal."""
        rangos = sorted((int(l.split()[1], 16), int(l.split()[2], 16),
                         l.split()[3]) for l in directivas("D"))
        for (a1, b1, n1), (a2, b2, n2) in zip(rangos, rangos[1:]):
            self.assertLessEqual(b1, a2, "%s (%04X-%04X) pisa a %s (%04X-%04X)"
                                 % (n1, a1, b1, n2, a2, b2))

    def test_todos_los_rangos_van_al_derecho_y_dentro(self):
        """Un rango acaba despues de empezar, y cae dentro del cartucho."""
        for l in directivas("D"):
            a, b, nombre = int(l.split()[1], 16), int(l.split()[2], 16), l.split()[3]
            self.assertLess(a, b, "%s va del reves" % nombre)
            self.assertGreaterEqual(a, ORG, "%s empieza fuera" % nombre)
            self.assertLessEqual(b, FIN, "%s acaba fuera" % nombre)

    def test_todos_los_rangos_estan_explicados(self):
        """Un nombre no basta: cada D lleva su explicacion detras."""
        pelados = [l.split()[3] for l in directivas("D") if len(l.split()) < 5]
        self.assertEqual(pelados, [], "rangos sin explicacion: %s"
                         % " ".join(pelados))

    def test_cada_anchura_cae_en_un_rango(self):
        """Una F cuya direccion no es el principio de una D no hace nada."""
        inicios = {l.split()[1].lower() for l in directivas("D")}
        sueltas = [l.split()[1] for l in directivas("F")
                   if l.split()[1].lower() not in inicios]
        self.assertEqual(sueltas, [], "anchuras sin rango: %s"
                         % " ".join(sueltas[:12]))

    def test_el_listado_lo_genera_la_herramienta(self):
        """El .asm no se edita a mano: sale de mkasm.py."""
        self.assertIn("Generado por tools/mkasm.py", asm())

    def test_no_queda_nada_por_repartir(self):
        """Mientras haya un 'formato pendiente' el trabajo no esta hecho."""
        pendientes = [l for l in notas()
                      if "formato pendiente" in l or "reparto por" in l]
        self.assertEqual(pendientes, [], "quedan %d zonas por repartir"
                         % len(pendientes))

    def test_el_listado_no_habla_de_otro_juego(self):
        """Los comentarios prestados de otro desensamblado se cuelan solos."""
        for juego in OTROS_JUEGOS:
            self.assertNotIn(juego, asm(), "el listado nombra %s" % juego)

    def test_la_raiz_no_habla_de_otro_juego(self):
        """Ni el README, ni el aviso legal, ni los documentos del scroll."""
        otros = OTROS_JUEGOS
        for fichero in ("README.md", "README.es.md", "AVISO-LEGAL.md",
                        "LEGAL-NOTICE.md", "LICENSE", "EL-SCROLL-AL-PIXEL.md",
                        "THE-PIXEL-SCROLL.md"):
            ruta = os.path.join(RAIZ, fichero)
            if not os.path.exists(ruta):
                continue
            with open(ruta, encoding="utf-8") as f:
                texto = f.read()
            for juego in otros:
                self.assertNotIn(juego, texto, "%s nombra %s" % (fichero, juego))

    def test_las_cifras_publicadas_son_las_del_arbol(self):
        """Las cifras de los README se cuentan aqui: si cambian, saltan."""
        cuentas = {
            "etiquetas": len(directivas("L")),
            "comentarios": len(directivas("C")),
            "rangos": len(directivas("D")),
            "cabeceras": len({l.split()[1].upper() for l in directivas("B")}),
        }
        esperado = {"etiquetas": 676, "comentarios": 807, "rangos": 174,
                    "cabeceras": 65}
        self.assertEqual(cuentas, esperado,
                         "las cifras del arbol han cambiado: hay que "
                         "actualizar README.md y README.es.md")

    def test_cada_cifra_se_publica_en_los_dos_readme(self):
        """Y estan escritas en los dos idiomas, sin que se olvide uno."""
        for fichero, sep in (("README.md", ","), ("README.es.md", ".")):
            ruta = os.path.join(RAIZ, fichero)
            if not os.path.exists(ruta):
                continue
            with open(ruta, encoding="utf-8") as f:
                texto = f.read()
            for cifra in ("9%s099" % sep, "7%s285" % sep, "676", "807", "174"):
                self.assertIn(cifra, texto, "%s no publica %s" % (fichero, cifra))


class TestScroll(unittest.TestCase):
    """El documento del scroll tiene que seguir cuadrando con el listado."""

    def documento(self):
        with open(SCROLL, encoding="utf-8") as f:
            return f.read()

    def test_las_rutinas_del_scroll_existen_con_ese_nombre(self):
        texto = asm()
        for nombre in ("PASO_DE_SCROLL", "ARMA_FILA", "FASE_DEL_SCROLL",
                       "VUELCA_NOMBRES", "ARMA_PANTALLA", "GENERA_FONDO",
                       "DOCE_CARACTERES", "CARACTER_DE_COSTURA", "CARGA_TIRAS",
                       "DESCOMPRIME_PIEZAS", "DIVIDE"):
            self.assertRegex(texto, r"(?m)^%s:" % nombre,
                             "%s no esta en el listado" % nombre)
            self.assertIn(nombre, self.documento(),
                          "%s no sale en el documento del scroll" % nombre)

    def test_el_documento_no_inventa_direcciones(self):
        """Cada 0xNNNN del documento tiene que existir en el listado."""
        vivas = direcciones_vivas()
        # las direcciones de VRAM y de RAM no estan en el listado; solo se
        # comprueban las del cartucho
        for d in set(re.findall(r"0x([0-9A-F]{4})", self.documento())):
            if 0x4000 <= int(d, 16) < 0x8000:
                self.assertIn(d.lower(), vivas,
                              "el documento nombra 0x%s y no existe" % d)


class TestWeb(unittest.TestCase):
    """La web es bilingue y se genera: lo que se vigila es que no se separe."""

    PAGINAS = [("GETTING-STARTED.md", "EMPEZAR.md"),
               ("THE-GAME.md", "EL-JUEGO.md"),
               ("THE-CARTRIDGE.md", "EL-CARTUCHO.md"),
               ("THE-CODE.md", "EL-CODIGO.md"),
               ("THE-PIXEL-SCROLL.md", "EL-SCROLL-AL-PIXEL.md"),
               ("FINDINGS.md", "HALLAZGOS.md"),
               ("OPEN-QUESTIONS.md", "PREGUNTAS-ABIERTAS.md")]

    def test_cada_pagina_tiene_su_pareja_en_el_otro_idioma(self):
        """Una pagina en un solo idioma deja media web coja."""
        for en, es in self.PAGINAS:
            if en == "THE-PIXEL-SCROLL.md":      # esta se copia desde la raiz
                self.assertTrue(os.path.exists(os.path.join(RAIZ, en)))
                self.assertTrue(os.path.exists(os.path.join(RAIZ, es)))
                continue
            self.assertTrue(os.path.exists(os.path.join(DOCS, en)),
                            "falta docs/%s" % en)
            self.assertTrue(os.path.exists(os.path.join(DOCS, "es", es)),
                            "falta docs/es/%s" % es)

    def test_las_paginas_no_hablan_de_otro_juego(self):
        """Los parrafos prestados de otro desensamblado se cuelan solos."""
        for raiz, _, ficheros in os.walk(DOCS):
            for fn in ficheros:
                if not fn.endswith(".md"):
                    continue
                with open(os.path.join(raiz, fn), encoding="utf-8") as f:
                    texto = f.read()
                for juego in OTROS_JUEGOS:
                    self.assertNotIn(juego, texto,
                                     "%s nombra %s" % (fn, juego))

    def test_las_herramientas_de_la_web_no_hablan_de_otro_juego(self):
        """El texto de la portada viaja dentro de make_web.py y md2html.py."""
        for fn in ("make_web.py", "md2html.py"):
            with open(os.path.join(RAIZ, "tools", fn), encoding="utf-8") as f:
                texto = f.read()
            for juego in OTROS_JUEGOS:
                self.assertNotIn(juego, texto, "tools/%s nombra %s"
                                 % (fn, juego))

    def test_la_portada_publica_las_cifras_del_arbol(self):
        """Las cifras de la portada son las que cuenta make sanity."""
        with open(os.path.join(RAIZ, "tools", "make_web.py"),
                  encoding="utf-8") as f:
            texto = f.read()
        self.assertIn("CODIGO = 9099", texto)
        self.assertIn("DATOS = 7285", texto)

    def test_las_paginas_no_inventan_direcciones(self):
        """Cada 0xNNNN del cartucho que se cite tiene que existir."""
        vivas = direcciones_vivas()
        for raiz, _, ficheros in os.walk(DOCS):
            for fn in ficheros:
                if not fn.endswith(".md"):
                    continue
                with open(os.path.join(raiz, fn), encoding="utf-8") as f:
                    pagina = f.read()
                for d in set(re.findall(r"0x([0-9A-F]{4})", pagina)):
                    if 0x4000 <= int(d, 16) < 0x8000:
                        self.assertIn(d.lower(), vivas,
                                      "%s nombra 0x%s y no existe" % (fn, d))


class TestScrollEnIngles(unittest.TestCase):
    """La version inglesa del documento del scroll no puede irse por su lado."""

    def texto(self, ruta):
        with open(ruta, encoding="utf-8") as f:
            return f.read()

    def test_las_dos_versiones_citan_las_mismas_direcciones(self):
        es = set(re.findall(r"0x([0-9A-F]{4})", self.texto(SCROLL)))
        en = set(re.findall(r"0x([0-9A-F]{4})", self.texto(SCROLL_EN)))
        self.assertEqual(es, en,
                         "las dos versiones del documento del scroll citan "
                         "direcciones distintas: %s"
                         % sorted(es ^ en))

    def test_las_dos_versiones_dan_las_mismas_medidas(self):
        for cifra in ("32557", "33969", "52533", "70080", "71591", "1112",
                      "732.7"):
            self.assertIn(cifra, self.texto(SCROLL),
                          "falta %s en el documento" % cifra)
            self.assertIn(cifra, self.texto(SCROLL_EN),
                          "falta %s en la version inglesa" % cifra)


if __name__ == "__main__":
    unittest.main()
