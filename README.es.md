# Pippols (Konami, 1985, MSX1) — desensamblado comentado

El cartucho RC-729 de Konami, desmontado byte a byte. Los 16.384 bytes están
acotados y explicados: ni un hueco sin justificar, ni un "bloque de gráficos",
ni una tabla adivinada.

🌐 **[Leerlo como web](https://antxiko.github.io/Pippols-disassembly/es/)**  ·  📄 **[Cómo está hecho el scroll al pixel](EL-SCROLL-AL-PIXEL.md)**

[README in English](README.md)

---

## Qué es esto

*Pippols* es el cartucho de 1985 en el que un enanito sube por un camino que no
para de moverse, esquivando bichos, recogiendo objetos y disparando, hasta
llegar al trono. Aquí está su código, comentado, con las herramientas para
volver a montarlo y comprobar que lo que sale es el original.

La máquina mapea los 16 KB en 0x4000-0x7FFF —la página 1—, la BIOS llama al
punto de entrada 0x404A, y de ahí el programa ya no vuelve: el arranque escribe
un `jp` en el gancho H.KEYI y se mete en un bucle de dos bytes, así que **el
juego entero corre dentro de la interrupción**, un paso por fotograma.

## Lo que tiene de especial

Pippols mueve el fondo **de pixel en pixel** en SCREEN 2, que es un modo sin
ningún registro de desplazamiento. Lo consigue teniendo sus caracteres de fondo
**ocho veces en la memoria de vídeo**, cada copia bajada un pixel más, y
reescribiendo la tabla de nombres entera en cada fotograma con el número de
caracter desplazado. Medido en el emulador, eso se lleva el 45 % del fotograma,
y la interrupción completa el 73 %.

Está contado con detalle, con las direcciones y las medidas, en
**[EL-SCROLL-AL-PIXEL.md](EL-SCROLL-AL-PIXEL.md)**.

## Por qué esto se puede creer

`make` traza el flujo, construye el listado y exige que al ensamblarlo salga
exactamente el original:

```
  ensamblado : 16384 bytes  ad011203...553e41f7
  original   : 16384 bytes  ad011203...553e41f7
OK: reproducible byte a byte
```

Un listado puede reensamblar perfectamente y estar mal —si se leen dibujos como
instrucciones, los bytes no cambian—, así que corren dos comprobaciones más:
ningún rango declarado como datos puede salir como código, y ningún punto de
entrada puede caer dentro de uno.

Y los gráficos se comprueban por una tercera vía: `tools/graficos.py` **rehace
en Python** lo que hace el cartucho —las tiras del fondo, el generador de los
192 caracteres, el descompresor del mapa y el volcado de la tabla de nombres— y
dibuja la pantalla. Si la lectura del binario estuviera mal, no saldría el
juego; sale.

## El juego en cifras

| | |
|---|---|
| bytes de código | 9.099 |
| bytes de datos | 7.285 |
| bytes sin identificar | **0** |
| etiquetas con nombre | 676 |
| comentarios anclados | 470 |
| rangos de datos con explicación | 174 |

## Algunas cosas que han salido

- **Los 192 caracteres del fondo** (del 0x40 al 0xFF) son ocho copias del mismo
  dibujo, cada una un pixel más abajo. Se generan en RAM al empezar cada
  pantalla a partir de **cuatro tiras de 24 bytes**, y cuatro de los doce
  caracteres de cada mitad son *costuras*: el final de una tira arriba y el
  principio de otra abajo, que es lo que hace que el dibujo siga siendo
  continuo a media altura.
- **El mapa cabe en 328 bytes.** Una fase son trece tramos de 24 filas, cada
  tramo son seis piezas de cuatro columnas, y las 44 piezas se montan pegando
  grupos de tres filas de un diccionario de 25. El descompresor **lee 24
  entradas de más** y se sale al código de 0x5653: las tres últimas piezas son
  basura y ninguna tabla apunta a ellas.
- **Hay un salto que cae dentro de otra instrucción.** El `jr nz` de 0x717D va
  a 0x7181, que es el byte de desplazamiento del `jr z` de la línea de arriba;
  se ejecuta como `dec b` —inofensivo, porque BC está en la pila— y sigue de
  largo. Es el único sitio del cartucho donde pasa.
- **El marcador miente por diez.** Los puntos son tres bytes BCD, pero el panel
  pinta un cero fijo pegado detrás, así que lo que se ve es diez veces el
  contador. Recoger da 100, 500, 1000 o 2000; la primera vida extra cae a los
  20.000 y luego cada 60.000.
- **El orden de los sprites cambia cada fotograma** (0x7F83): un fotograma van
  primero los enemigos y al siguiente los objetos, para que el límite de cuatro
  sprites por línea no tape siempre a los mismos.
- **La misma forma con otras tintas.** Las 18 pantallas del mundo comparten los
  dibujos del fondo: lo que cambia es un intercambio de tres parejas de tintas
  (0x577D) sobre los 96 bytes de color.
- **0xE126 se escribe y no la lee nadie.** Se guarda en 0x59EF en cada
  fotograma y no aparece ninguna lectura en todo el cartucho.
- **Los nueve bytes del final** (0x7FF7, detrás del relleno de 0xFF) no los lee
  nada ni los apunta nadie. Se quedan como pregunta abierta.

## Cómo empezar

Hacen falta `pasmo`, `z80dasm` y Python 3. La imagen del cartucho **no** se
distribuye aquí: pon la tuya en la raíz como `pippols.rom`, 16384 bytes,
sha256 `ad011203f1295bf75fc30423cead68e12f96169ffeb9f13474303d9a553e41f7`.

```sh
make          # traza, construye el listado y lo comprueba todo
make verify   # ensambla y compara con el cartucho
make sanity   # lo que el reensamblado no puede cazar
make imagenes # rehace las imágenes reconstruidas
make medir    # mide el coste del scroll en openMSX
make web      # rehace la web de docs/
```

## Licencia y atribución

El juego no es nuestro: *Pippols* es de Konami, y todos los derechos siguen
siendo de sus titulares. Lo que sí es nuestro —las herramientas, los
comentarios y la documentación— se publica con la licencia de `LICENSE`. La
imagen del cartucho no se distribuye. Ver [AVISO-LEGAL.md](AVISO-LEGAL.md).
