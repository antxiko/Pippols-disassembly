# Hallazgos

Lo que aparece al desmontarlo y no se ve jugando. Cada cosa con su dirección; lo
que está medido, con la medida.

## El fondo está ocho veces en la memoria de vídeo

SCREEN 2 no tiene registro de desplazamiento, así que Pippols se lo fabrica: en
la VRAM hay **192 caracteres** (del 0x40 al 0xFF) que son ocho copias del mismo
juego de 24, cada una bajada un pixel más. Desplazar la pantalla un pixel es
sumarle 24 al número de carácter y volver a escribir la tabla de nombres; no se
toca ni un patrón.

![Los ocho desplazamientos](../imagenes/ochofases_0.png)

Los 192 se generan **en RAM al empezar cada pantalla** (0x566D) a partir de
cuatro tiras de 24 bytes, y de los doce caracteres de cada mitad hay **cuatro que
son costuras**: el final de una tira arriba y el principio de otra abajo. Sin
ellas el dibujo se partiría a media altura en cuanto el desplazamiento no fuera
cero. Está contado entero en [El scroll al pixel](EL-SCROLL-AL-PIXEL.html).

## Todo el mapa del juego cabe en 328 bytes

Una fase son trece tramos de 24 filas; un tramo, seis piezas de cuatro columnas;
y las 44 piezas se montan en RAM pegando grupos de tres filas de un diccionario
de 25. La lista de índices —ocho por pieza— son **328 bytes**, y con eso está
descrito el camino entero de las diez fases.

## El descompresor del mapa se sale al código, y sobran piezas

El bucle de 0x5496 arma 44 piezas, o sea 352 lecturas, pero la lista de índices
sólo tiene 328 bytes. Las 24 últimas caen ya dentro del **código** de 0x5653, que
es la rutina de división, y de ahí salen tres piezas de basura: la 41, la 42 y la
43. No importa, porque ningún tramo apunta a ellas.

Lo curioso es que tampoco apunta nadie a las piezas **0 y 1**, que sí están bien
montadas. De las 44 que se construyen, el juego usa 39.

## El marcador miente por diez

Los puntos son tres bytes BCD, pero el panel pinta las seis cifras y detrás un
**cero fijo**. Lo que se ve es diez veces el contador, y por eso todas las
puntuaciones acaban en cero. Recoger da 100, 500, 1000 o 2000 de los que se ven;
la bota y el escudo, 5000; la meta y el trono, 3000. La primera vida extra cae a
los 20 000 y luego cada 60 000.

## La bota y el escudo son el mismo dibujo

En la tabla de 0x785A cada objeto lleva su pareja (patrón, color). El objeto 8
—la bota, que hace andar una vez y media más rápido— y el 9 —el escudo— llevan
**el mismo patrón, 0xC0**, y sólo se diferencian en el color: 9 uno y 5 el otro.
Los objetos 1 y 4 hacen lo mismo con el patrón 0xA4.

![Los sprites del cartucho](../imagenes/sprites.png)

## Un salto que cae dentro de otra instrucción

En 0x717D hay un `jr nz,$+4` que va a parar a 0x7181, y 0x7181 no es el principio
de nada: es el byte de desplazamiento del `jr z` de la línea de arriba. Se
ejecuta como `dec b`, que ahí da igual porque el bucle de enemigos guarda BC en
la pila (`push bc` en 0x6B2C, `pop bc` en 0x6B41), y sigue en el `ld c,002h` de
0x7182. Es el único sitio del cartucho donde se entra a una instrucción por en
medio.

## Los sprites se turnan el orden cada fotograma

El MSX sólo puede enseñar cuatro sprites en una misma línea, y el quinto
desaparece. Pippols lo reparte: la rutina que monta la tabla (0x7F83) escribe un
fotograma primero los bichos y luego los objetos, y al siguiente al revés. Así
lo que se pierde va cambiando en vez de tocarle siempre al mismo.

## Dieciocho pantallas y cinco dibujos

Las 18 pantallas del mundo comparten los dibujos del fondo: hay ocho fases pero
sólo cinco juegos de tiras, y lo que cambia de una pantalla a otra es un
**intercambio de tres parejas de tintas** (0x577D) sobre los 96 bytes de color.
La misma flor sale roja o rosa, el mismo árbol verde o azul.

![Las ocho fases de fondo](../imagenes/ochofondos.png)

El recorrido tampoco es una fila de pantallas: la tabla de 0x7B62 da **dos
destinos por cada una** y se toma uno u otro según se vaya subiendo o bajando, de
modo que dos partidas distintas no ven las mismas pantallas.

## Los tres tercios de la pantalla, cargados iguales

En SCREEN 2 cada tercio de la pantalla tiene sus propios 256 patrones. Pippols
carga los tres con lo mismo, byte por byte, y sólo por eso puede correr las filas
del fondo de arriba abajo sin que un carácter cambie de dibujo al cruzar la fila
8 o la 16. Es tres veces la memoria a cambio de que el número de carácter
signifique siempre lo mismo.

## Lo que cuesta el scroll, medido

En openMSX, sobre un Philips VG-8020 (PAL, 71 591 ciclos por fotograma) y con
1112 fotogramas de la demo:

| | ciclos | % del fotograma |
|---|---|---|
| volcar la tabla de nombres, media | 32 557 | 45,5 % |
| volcar la tabla de nombres, máximo | 33 969 | 47,4 % |
| la interrupción entera, media | 52 533 | 73,4 % |
| la interrupción entera, máximo | 70 080 | 97,9 % |

Y 732,7 escrituras al puerto de datos del VDP por fotograma. Repintar la tabla de
nombres se lleva el 62 % del tiempo de la interrupción, y la interrupción se come
tres cuartas partes del fotograma: por eso el programa principal es un `jr $`.

## Una dirección que se escribe y no lee nadie

0xE126 se escribe en 0x59EF en cada paso del jugador, y en los 16 384 bytes del
cartucho no hay ni una instrucción que la lea.

## THE HOLLY GEM

El texto que sale al llegar al trono está en 0x7C5C, en caracteres de la fuente
del propio cartucho: BRING BACK / THE HOLLY GEM / THE WORLD IS / WAITING FOR YOU.
Con dos eles, tal cual.
