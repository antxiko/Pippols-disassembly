# La música

Todo lo que suena aquí sale de ejecutar el motor de sonido del cartucho (`PASO_DE_SONIDO`, 0x4987, y `PIDE_SONIDO`, 0x48F4, que le reparte los canales; lo llama la interrupción) en un Z80 emulado, cuadro a cuadro y a 60 por segundo, igual que lo llama el juego. Lo que el motor escribe en el PSG pasa a sonido con un AY-3-8910 (`tools/musica.py`). Cada MP3 es la pieza entera hasta donde vuelve a empezar, más 8 segundos de la vuelta apagándose; las que no se repiten acaban donde acaba el motor.

## Cotejado con openMSX

Las escrituras al PSG se han comparado cuadro a cuadro con las de openMSX (C-BIOS MSX1 japonés). En todos los cuadros el PSG queda igual:

- la música de arranque (0x8F), sus primeros 219 cuadros y, tal como el juego la pide, otros 385 de 386;
- la pista 0x87, sus primeros 219 cuadros.

El timbre no está cotejado: es el de un AY-3-8910 de manual, no una grabación del emulador. Las sondas están en `tools/omsx_psg.tcl` y `tools/coteja_psg.py`.

## Cómo se pide una pieza

`PIDE_SONIDO` recibe el número en A. Con los seis bits bajos elige los canales: menos de 7 es un efecto de un solo canal y de ahí en adelante, dos o tres. Cada ficha ocupa catorce bytes desde 0xE010 y 0xE03A guarda la copia del mezclador del PSG, que el arranque deja en 0xB8. Las pistas «de la tabla» están en la tabla de pistas pero ninguna rutina las pide con un `ld a`; la música que `ELIGE_MUSICA` pide según la fase sale de un número calculado, y se omiten las más largas (0x88, 0x8A, 0x9C a 0xA0, 0xA2 y 0xA3).

## Las músicas

**La música de arranque** (0x8F)

Lo pide `EST_MUSICA_DE_ARRANQUE`: suena y se esperan 0x50 fotogramas; dura 6,4 s.

<audio controls preload="none" src="../audio/musica_8F.mp3?v=a88e04a9"></audio>

**La música de andar** (0x89)

Lo pide `MUSICA_DEL_PASEO`: la de andar, o la del escudo si lo lleva; dura 2,2 s.

<audio controls preload="none" src="../audio/musica_89.mp3?v=e7d0c6fe"></audio>

**La música de la meta** (0x92)

Lo pide `ELIGE_MUSICA` y `META_PARA_TODO`; dura 6,4 s.

<audio controls preload="none" src="../audio/musica_92.mp3?v=98d764d7"></audio>

**El trono** (0x95)

Lo pide `TRONO_APARECE`; dura 0,9 s y vuelve a empezar en el segundo 0,0.

<audio controls preload="none" src="../audio/musica_95.mp3?v=5d576bdb"></audio>

**Game over** (0x98)

Lo pide `EST_FIN_DE_PARTIDA`; dura 3,2 s.

<audio controls preload="none" src="../audio/musica_98.mp3?v=93df8ddf"></audio>

**La llegada al final** (0xA1)

Lo pide `FINAL_LLEGA`; dura 9,0 s y vuelve a empezar en el segundo 0,0.

<audio controls preload="none" src="../audio/musica_A1.mp3?v=02b2e743"></audio>

**Pista 0x87 de la tabla** (0x87)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 12,8 s.

<audio controls preload="none" src="../audio/musica_87.mp3?v=221d8925"></audio>

**Pista 0x8E de la tabla** (0x8E)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 6,4 s.

<audio controls preload="none" src="../audio/musica_8E.mp3?v=d1d71933"></audio>

**Pista 0x90 de la tabla** (0x90)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 6,4 s.

<audio controls preload="none" src="../audio/musica_90.mp3?v=cd25ec59"></audio>

**Pista 0x91 de la tabla** (0x91)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 6,4 s.

<audio controls preload="none" src="../audio/musica_91.mp3?v=d9fa4bcc"></audio>

**Pista 0x93 de la tabla** (0x93)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 7,3 s y vuelve a empezar en el segundo 6,4.

<audio controls preload="none" src="../audio/musica_93.mp3?v=f562c282"></audio>

**Pista 0x94 de la tabla** (0x94)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 7,3 s y vuelve a empezar en el segundo 6,4.

<audio controls preload="none" src="../audio/musica_94.mp3?v=99e02cfc"></audio>

**Pista 0x96 de la tabla** (0x96)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 4,2 s y vuelve a empezar en el segundo 3,2.

<audio controls preload="none" src="../audio/musica_96.mp3?v=235839e4"></audio>

**Pista 0x97 de la tabla** (0x97)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 4,2 s y vuelve a empezar en el segundo 3,2.

<audio controls preload="none" src="../audio/musica_97.mp3?v=932780c7"></audio>

**Pista 0x99 de la tabla** (0x99)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 3,2 s.

<audio controls preload="none" src="../audio/musica_99.mp3?v=8aae3e4f"></audio>

**Pista 0x9A de la tabla** (0x9A)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 3,2 s.

<audio controls preload="none" src="../audio/musica_9A.mp3?v=3e408929"></audio>
