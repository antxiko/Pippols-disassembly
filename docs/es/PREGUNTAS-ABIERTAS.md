# Preguntas abiertas

Lo que el binario no resuelve por sí solo. El cartucho está explicado byte a
byte; esto es lo que queda por medir o por decidir.

## Los nueve bytes del final

Detrás de los 45 bytes de relleno a 0xFF, el cartucho termina con nueve bytes
que no son relleno:

    7FF7  8C A8 B8 9D B8 9A 06 29 AA

Comprobado: ninguna instrucción del listado los lee, ningún puntero de ninguna
tabla cae ahí, y la secuencia no se repite en ningún otro sitio del cartucho.
Podrían ser la cola de algo que se quedó fuera al montar la ROM, pero eso, hoy
por hoy, no se puede demostrar con el binario en la mano.

## Las dos piezas de mapa que nadie usa

`DESCOMPRIME_PIEZAS` (0x5496) monta 44 piezas en 0xE500 y los diecinueve tramos
de 0x5424 sólo apuntan a 39. Tres —la 41, la 42 y la 43— son basura leída del
código, y eso está claro. Las otras dos, la **0** y la **1**, están bien
construidas a partir del diccionario y nadie las nombra. Si son un tramo que se
quitó o simplemente el hueco por el que empieza la numeración, el cartucho no lo
dice.

## El fotograma que se pasó del 90 %

En la medida de openMSX, de 1112 fotogramas de la demo hubo **uno solo** por
encima del 90 % del tiempo disponible (70 080 ciclos de 71 591). No se ha
aislado: puede ser el cambio de pantalla, que rehace los 192 caracteres, o una
punta normal con muchos sprites en juego.

## Las medidas son de la demo

Todo lo que está medido —el coste del volcado de nombres, el de la interrupción,
las escrituras al VDP— sale de dejar correr la **demo**, que juega sola y no
llena la pantalla de enemigos. Con diez bichos y dos disparos en marcha el
fotograma dará más, y no se ha medido una partida de verdad con el mando en la
mano.

## Qué pasa al agotar el mundo

El recorrido tiene dos mitades de nueve pantallas y la tabla de 0x7B62 las
encadena con dos destinos por pantalla. Al llegar al trono se le da la vuelta al
mapa y se empieza la otra mitad; lo que ocurre después de la pantalla final, y si
la dificultad —que sube hasta 0x20 y ahí se queda— deja el juego jugable, hace
falta jugarlo para verlo.
