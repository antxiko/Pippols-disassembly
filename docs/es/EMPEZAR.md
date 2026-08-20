# Empezar

## Lo que hace falta

`pasmo` y `z80dasm` para ensamblar y desensamblar, y Python 3 para las
herramientas. Nada más.

El cartucho no viaja con este repositorio: hay que poner el propio, con el
nombre `pippols.rom` en la raíz del proyecto. Son 16384 bytes exactos, con este
sha256:

    ad011203f1295bf75fc30423cead68e12f96169ffeb9f13474303d9a553e41f7

Con cualquier otro volcado el listado no vuelve a ensamblar. `make comprueba`
lo dice en una línea.

## Los comandos

```sh
make          # traza, genera el listado y lo comprueba todo
make verify   # ensambla el listado y compara su sha256 con el del cartucho
make sanity   # lo que el reensamblado no puede cazar
make test     # los 28 tests sobre el listado, que no necesitan el cartucho
make imagenes # rehace las imágenes reconstruidas
make medir    # mide en openMSX lo que cuesta el scroll
make web      # las imágenes y estas páginas
```

`make` encadena los cuatro primeros. Si todo va bien, la línea que importa es
ésta:

```
  ensamblado : 16384 bytes  ad011203...553e41f7
  original   : 16384 bytes  ad011203...553e41f7
OK: reproducible byte a byte
```

## Qué hay en cada carpeta

| | |
|---|---|
| `src/pippols.asm` | el listado comentado, generado; nunca se edita a mano |
| `src/pippols.notes` | las anotaciones: etiquetas, comentarios, cabeceras y rangos de datos, ancladas a direcciones |
| `src/pippols.entries` | los puntos de entrada que el trazado no puede deducir, cada uno con su justificación |
| `src/pippols.nocode` | las zonas que el trazador no debe leer como código |
| `tools/` | el trazador, el generador del listado, las comprobaciones y las herramientas de dibujo |
| `tests/` | 28 tests sobre el listado, las anotaciones y la web |
| `docs/` | esta web |
| `work/` | lo que `make` va dejando por el camino |

## Cómo se lee el listado

Cada rutina tiene un nombre en mayúsculas y un comentario que dice qué hace y
qué recibe. Los bloques de datos se llaman `DATA_<uso>`, llevan la anchura de
su estructura y una explicación de qué son y de cómo se sabe. Las direcciones
son las de verdad del cartucho en la página 1: 0x4000-0x7FFF.

Para cambiar cualquier cosa se edita `src/pippols.notes` y se vuelve a lanzar
`make`: el listado se regenera y las comprobaciones dicen si sigue en pie.

## Cómo está hecho

El trazador (`tools/z80trace.py`) sigue el flujo desde el punto de entrada de
la cabecera y desde lo que declara `pippols.entries`: la interrupción y los
destinos de los despachadores, que saltan por tablas. Lo que no es código se
deja como hueco, y cada hueco se cierra buscando la instrucción que lo lee
(`tools/quien_apunta.py`, `tools/refs.py`) y comprobando que el formato encaja
con lo que hace el código que lo consume.

Lo que no se puede leer, se mide. `tools/graficos.py` rehace en Python el fondo
—las tiras, el generador de los 192 caracteres, el descompresor del mapa y el
volcado de la tabla de nombres— y dibuja la pantalla: si la lectura estuviera
mal, saldría ruido. Y `tools/omsx_scroll.tcl` mide en openMSX, con el reloj del
Z80 emulado, lo que cuesta cada fotograma.

## Reproducibilidad

- ensamblar devuelve el sha256 del cartucho
- ningún rango declarado como datos sale como código en el trazado
- ningún punto de entrada cae dentro de un rango de datos
- los 16384 bytes están asignados: 9099 de código, 7285 de datos, 0 sin identificar
