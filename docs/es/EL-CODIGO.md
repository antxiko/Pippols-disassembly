# El código

Nueve mil bytes de Z80, con 152 rutinas a las que alguien llama por su nombre y
un armazón que Konami repetía en sus cartuchos de aquellos años: la interrupción
como programa, un despachador que salta por tablas y un reproductor de sonido de
tres canales.

## La interrupción es el programa

INIT (0x404A) prepara el VDP, carga los caracteres fijos, escribe `jp 0x4010` en
el gancho H.KEYI de la BIOS y se mete en un `jr $` de dos bytes en 0x4074. A
partir de ahí el bucle principal no hace absolutamente nada: **todo** —el
sonido, el mando, el jugador, los bichos, los objetos y el scroll— ocurre dentro
de la interrupción, un paso por fotograma.

Lo primero de la interrupción es leer el estado del VDP, que es lo que baja la
petición, y lo último es volver a leerlo por si ha llegado otra mientras tanto.
En medio hay un candado (0xE005): si el paso anterior aún no ha terminado, el
nuevo se limita a dar un paso de sonido y se va. Así la música no se corta
aunque el fotograma se pase de largo, que es algo que aquí pasa a menudo: la
interrupción entera se lleva de media el 73 % del fotograma.

## El despachador

```
	call DESPACHA
	defw destino_0, destino_1, ...
```

`DESPACHA` (0x4043) son seis instrucciones: `add a,a` porque el índice va en
palabras, `pop hl` para recoger la dirección de retorno —que es justo donde
empieza la tabla—, leer de ahí la palabra número A y `jp (hl)`. Se entra con
`call` y no se vuelve nunca. Lo usan cuatro sitios: los estados del programa
(0x4092), los cuatro pasos del final de fase (0x7A70), los seis del trono
(0x7B99) y los seis de la pantalla final (0x7CEB).

Hay un segundo despachador, más barato, para las cosas que van por tipo: un
`push bc / ret` con la tabla **dos bytes por debajo** de su base, para que el
índice pueda empezar en 1 en vez de en 0. Las tres tablas de enemigos (0x6861,
0x6894, 0x68B4) y la de las rutinas de cada fotograma (0x6B58) van así.

## Los ocho estados

0xE000 dice en qué anda el programa, y 0xE001 es un subestado que cada estado va
gastando con `djnz`:

| estado | qué hace |
|---|---|
| 0 | el logotipo de KONAMI subiendo tres filas cada dos fotogramas |
| 1 | el título en pantalla, con su cuenta atrás |
| 2 | el menú: PUSH SPACE KEY parpadeando |
| 3 | arranca la demo |
| 4 | empieza la fase: borra, pinta el marcador y la monta |
| 5 | **jugando**: un paso de partida por fotograma |
| 6 | fin de partida, con el sonido 0x98 |
| 7 | GAME OVER y vuelta al título |

Los estados 0, 1 y 2 se meten en la pila el retorno 0x4184 antes de despachar,
que es un truco para que los tres compartan el manejo del menú sin repetirlo:
al volver, ese trozo mira el mando y arranca la partida si se ha pulsado espacio.

## El paso de la partida

`PASO_DE_PARTIDA` (0x5087) es lo que corre en cada fotograma mientras se juega, y
en este orden: la tabla de sprites, el mando, el jugador, los bichos, los
disparos —los propios y los de ellos—, los objetos, el scroll y los choques. Al
final, `ELIGE_MUSICA` (0x5168) mira en qué anda el jugador y pide la música que
toca; como en cada canal manda el número más alto, se puede pedir cada fotograma
sin miedo a cortar lo que ya suena.

## El sonido

Tres canales de 14 bytes cada uno en 0xE010, y una tabla de **40 sonidos** en
0x4AD8 que apunta a **36 pistas**. El número de sonido dice además cuántos
canales pide: por debajo de 7, sólo el canal C, que es el de los efectos; de 7 a
14, dos; de 15 en adelante, los tres. Y si en un canal ya suena algo con un
número más alto, el nuevo no le quita el sitio.

Una pista es una tira de bytes: el nibble alto es la nota y el bajo la duración,
`0x2n` cambia la duración de las que vengan detrás, 0xFF calla el canal y 0xFE
es fin o salto —con una cuenta de vueltas, que es como se hacen los bucles—. Las
notas salen de quince períodos del PSG (0x4AC9), una octava y tres notas de más,
cada uno el anterior multiplicado por 0,944, que es el semitono; leyendo tres
bytes antes se baja tres semitonos de golpe, y eso es lo que hace el bit 6 del
canal.

## El fondo y el mapa

Aquí está lo que distingue a este cartucho, y tiene su propia página: **[El
scroll al pixel](EL-SCROLL-AL-PIXEL.html)**. En resumen: los caracteres del
fondo están ocho veces en la VRAM, cada copia bajada un pixel más, y desplazar
la pantalla es sumarle 24 al número de carácter y volver a escribir la tabla de
nombres entera, 24 filas por 22 columnas, en cada fotograma.

El camino no se guarda como pantallas, sino en cuatro pisos:

```
posición en pixeles
  --> tramo (0..12) y fila dentro del tramo (0..23)
        --> plano (0x53A2): 10 planos x 13 tramos
              --> tramo (0x5424): 19 tramos x 6 piezas
                    --> pieza (0xE500): 44 piezas de 24 filas
```

Una fase mide trece tramos de 24 filas, o sea 2496 pixeles, y cada tramo son seis
piezas de cuatro columnas puestas una al lado de otra. Las 44 piezas se montan en
RAM pegando grupos de tres filas sacados de un diccionario de 25, con la lista de
índices en 0x550B: **328 bytes para todo el mapa del juego**.

## El jugador y los bichos

El estado del jugador (0xE120) sale directamente del mando por una tabla de
dieciséis entradas (0x5D32), y de ahí cuelga todo: la animación, el sprite que se
carga y hacia dónde sale el disparo. Antes de moverse se mira el carácter que hay
delante con cuatro sondas (0x5B6A), y la comparación se hace contra
`0x40 + 24 × fase` porque los caracteres del fondo cambian de número con el
desplazamiento.

Los bichos son diez fichas de 16 bytes con velocidad en coma fija de 8.8, y doce
rutinas, una por tipo. El motor de persecución (0x6B72) no gira en seco: **acerca
poco a poco** la velocidad actual a la que llevaría al objetivo, y por eso los
bichos describen esas curvas en vez de ir en línea recta al jugador.
