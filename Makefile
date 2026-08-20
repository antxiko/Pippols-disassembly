# Pippols (Konami, 1985, MSX1) - desensamblado
#
# El orden de las cosas: trazar el flujo -> generar el listado -> comprobar que
# vuelve a dar la ROM byte a byte -> las comprobaciones que el reensamblado NO
# cubre.
#
# La ROM no se distribuye. Hace falta en la raiz como pippols.rom, y
# `make comprueba` verifica el sha256.

ROM      = pippols.rom
SHA      = ad011203f1295bf75fc30423cead68e12f96169ffeb9f13474303d9a553e41f7
SRC      = src
WORK     = work
ORG      = 0x4000
TITULO   = PIPPOLS - Konami (1985) - MSX1 - cartucho RC-729 de 16 KB en la pagina 1

# Los arneses de openMSX (tools/omsx_*.tcl) dejan aqui lo que midan; la web no
# los necesita.
OMSX     = $(WORK)/omsx

all: listado verify sanity test

$(ROM):
	@echo "=================================================================="
	@echo " Falta $(ROM), y este repositorio NO lo distribuye."
	@echo ""
	@echo " Es Pippols (Konami, RC-729, 1985) para MSX, 16384 bytes exactos."
	@echo " Ponlo aqui con ese nombre. Para comprobar que es el mismo:"
	@echo "     shasum -a 256 $(ROM)"
	@echo "     $(SHA)"
	@echo ""
	@echo " Sin el se puede leer el listado ya generado en $(SRC)/, y los"
	@echo " tests que no dependen del binario siguen pasando."
	@echo "=================================================================="
	@false

comprueba: $(ROM)
	@echo "$(SHA)  $(ROM)" | shasum -a 256 -c -

# El trazado sigue el flujo desde los puntos de entrada. Los que no se pueden
# deducir estaticamente -ganchos de interrupcion, destinos de saltos
# indirectos- estan declarados en el .entries, cada uno con su justificacion.
$(WORK)/pippols.trace.json: $(ROM) $(SRC)/pippols.entries $(SRC)/pippols.nocode
	@mkdir -p $(WORK)
	python3 tools/z80trace.py $(ROM) $(ORG) $(SRC)/pippols.entries \
	        $(WORK)/pippols $(SRC)/pippols.nocode

trace: $(WORK)/pippols.trace.json

listado: $(WORK)/pippols.trace.json $(SRC)/pippols.notes
	python3 tools/mkasm.py $(ROM) $(ORG) $(WORK)/pippols.trace.json \
	        $(SRC)/pippols.notes work/msx.sym $(SRC)/pippols.asm "$(TITULO)"

# La prueba que decide si el desensamblado es fiable.
verify: $(SRC)/pippols.asm $(ROM)
	@sh tools/verify_build.sh $(SRC)/pippols.asm $(ROM) $(ORG)

# Lo que el reensamblado NO puede cazar: que unos datos se esten leyendo como
# codigo. El binario sale identico igual, porque los bytes no cambian; lo unico
# que cambia es lo que decimos de ellos.
sanity: $(WORK)/pippols.trace.json
	@echo "=================================================================="
	@echo " ningun byte declarado como datos puede salir como codigo"
	@echo "=================================================================="
	@python3 tools/check_trace.py $(WORK)/pippols.trace.json $(SRC)/pippols.nocode
	@python3 tools/check_datos_como_codigo.py $(WORK) $(SRC)
	@echo "=================================================================="
	@echo " ningun punto de entrada puede caer dentro de una zona de datos"
	@echo "=================================================================="
	@python3 tools/check_entradas.py $(SRC)/pippols.entries $(SRC)/pippols.notes \
	        $(SRC)/pippols.nocode
	@echo "=================================================================="
	@echo " ni un byte del cartucho sin asignar"
	@echo "=================================================================="
	@python3 tools/presupuesto.py $(WORK) $(SRC)

test:
	@echo "=================================================================="
	@echo " Tests"
	@echo "=================================================================="
	@python3 -m unittest discover -s tests -v

clean:
	rm -rf $(WORK)/pippols.trace.json $(WORK)/pippols.map $(WORK)/png

.PHONY: all comprueba trace listado verify sanity test clean imagenes medir web

# ---------------------------------------------------------------------------
# Las imagenes
# ---------------------------------------------------------------------------
# No hacen falta capturas de emulador: tools/graficos.py rehace en Python lo
# que hace el cartucho -las tiras del fondo, el generador de los 192 caracteres
# y la tabla de nombres- y dibuja con eso las pantallas, los ocho
# desplazamientos y los sprites.
imagenes: $(ROM)
	@mkdir -p docs/imagenes work/gfx
	python3 tools/graficos.py $(ROM) work/gfx
	python3 tools/graficos.py $(ROM) work/gfx sprites
	python3 tools/graficos.py $(ROM) work/gfx scroll
	python3 tools/graficos.py $(ROM) work/gfx mundo
	python3 tools/graficos.py $(ROM) work/gfx titulo
	@cp work/gfx/logo.png work/gfx/ochofondos.png work/gfx/sprites.png docs/imagenes/
	@cp work/gfx/ochofases_0.png work/gfx/ochofases_3.png docs/imagenes/
	@cp work/gfx/fases_0.png work/gfx/fases_3.png docs/imagenes/
	@for f in 0 1 2 3 4 5 6 7; do cp work/gfx/pantalla_$${f}_0.png docs/imagenes/; done
	@cp work/gfx/pantalla_0_4.png docs/imagenes/

# ---------------------------------------------------------------------------
# La web
# ---------------------------------------------------------------------------
# Las siete paginas por idioma salen de los .md de docs/. La del scroll al pixel
# NO se escribe dos veces: se copia desde la raiz, que es donde la leen los
# tests, corrigiendo de paso la ruta de las imagenes.
web: imagenes
	@sed 's|docs/imagenes/|../imagenes/|g' EL-SCROLL-AL-PIXEL.md > docs/es/EL-SCROLL-AL-PIXEL.md
	@sed 's|docs/imagenes/|imagenes/|g' THE-PIXEL-SCROLL.md > docs/THE-PIXEL-SCROLL.md
	python3 tools/md2html.py docs en
	python3 tools/md2html.py docs/es es
	python3 tools/make_web.py docs/imagenes docs/index.html en
	python3 tools/make_web.py docs/imagenes docs/es/index.html es
	@touch docs/.nojekyll
	@python3 tools/check_enlaces.py docs

# Lo que cuesta el scroll, medido en openMSX (hace falta tenerlo instalado).
medir: $(ROM)
	@mkdir -p $(OMSX)
	PIP_OUT=$(OMSX) PIP_SEG=150 openmsx -machine Philips_VG_8020 -cart $(ROM) 	    -script tools/omsx_scroll.tcl
	@cat $(OMSX)/scroll.log
