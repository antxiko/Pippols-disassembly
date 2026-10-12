# The music

Everything you hear here comes from running the cartridge's own sound engine (`PASO_DE_SONIDO`, 0x4987, and `PIDE_SONIDO`, 0x48F4, which hands it the channels; the interrupt calls it) on an emulated Z80, frame by frame at 60 per second, just as the game calls it. What the engine writes to the PSG is turned into sound with an AY-3-8910 (`tools/musica.py`). Each MP3 is the whole piece up to where it starts again, plus 8 seconds of the repeat fading out; those that do not repeat end where the engine ends.

## Checked against openMSX

The PSG writes have been compared frame by frame with those of openMSX (C-BIOS MSX1 japonés). In every frame the PSG ends up the same:

- the start-up tune (0x8F), its first 219 frames and, as the game asks for it, another 385 of 386;
- track 0x87, its first 219 frames.

The timbre is not checked: it is a textbook AY-3-8910, not a recording of the emulator. The probes are `tools/omsx_psg.tcl` and `tools/coteja_psg.py`.

## How a piece is asked for

`PIDE_SONIDO` takes the number in A. The low six bits pick the channels: below 7 is a one-channel effect, from there up, two or three. Each record takes fourteen bytes from 0xE010 and 0xE03A holds the copy of the PSG mixer, which start-up leaves at 0xB8. The tracks marked «in the table» are in the track table but no routine asks for them with an `ld a`; the music `ELIGE_MUSICA` asks for by stage comes from a computed number, and the longest ones (0x88, 0x8A, 0x9C to 0xA0, 0xA2 and 0xA3) are left out.

## The tunes

**The start-up tune** (0x8F)

Asked for by `EST_MUSICA_DE_ARRANQUE`: suena y se esperan 0x50 fotogramas; lasts 6.4 s.

<audio controls preload="none" src="audio/musica_8F.mp3?v=a88e04a9"></audio>

**The walking tune** (0x89)

Asked for by `MUSICA_DEL_PASEO`: la de andar, o la del escudo si lo lleva; lasts 2.2 s.

<audio controls preload="none" src="audio/musica_89.mp3?v=e7d0c6fe"></audio>

**The goal tune** (0x92)

Asked for by `ELIGE_MUSICA` y `META_PARA_TODO`; lasts 6.4 s.

<audio controls preload="none" src="audio/musica_92.mp3?v=98d764d7"></audio>

**The throne** (0x95)

Asked for by `TRONO_APARECE`; lasts 0.9 s and starts again at second 0.0.

<audio controls preload="none" src="audio/musica_95.mp3?v=5d576bdb"></audio>

**Game over** (0x98)

Asked for by `EST_FIN_DE_PARTIDA`; lasts 3.2 s.

<audio controls preload="none" src="audio/musica_98.mp3?v=93df8ddf"></audio>

**Reaching the end** (0xA1)

Asked for by `FINAL_LLEGA`; lasts 9.0 s and starts again at second 0.0.

<audio controls preload="none" src="audio/musica_A1.mp3?v=02b2e743"></audio>

**Table track 0x87** (0x87)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 12.8 s.

<audio controls preload="none" src="audio/musica_87.mp3?v=221d8925"></audio>

**Table track 0x8E** (0x8E)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 6.4 s.

<audio controls preload="none" src="audio/musica_8E.mp3?v=d1d71933"></audio>

**Table track 0x90** (0x90)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 6.4 s.

<audio controls preload="none" src="audio/musica_90.mp3?v=cd25ec59"></audio>

**Table track 0x91** (0x91)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 6.4 s.

<audio controls preload="none" src="audio/musica_91.mp3?v=d9fa4bcc"></audio>

**Table track 0x93** (0x93)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 7.3 s and starts again at second 6.4.

<audio controls preload="none" src="audio/musica_93.mp3?v=f562c282"></audio>

**Table track 0x94** (0x94)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 7.3 s and starts again at second 6.4.

<audio controls preload="none" src="audio/musica_94.mp3?v=99e02cfc"></audio>

**Table track 0x96** (0x96)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 4.2 s and starts again at second 3.2.

<audio controls preload="none" src="audio/musica_96.mp3?v=235839e4"></audio>

**Table track 0x97** (0x97)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 4.2 s and starts again at second 3.2.

<audio controls preload="none" src="audio/musica_97.mp3?v=932780c7"></audio>

**Table track 0x99** (0x99)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 3.2 s.

<audio controls preload="none" src="audio/musica_99.mp3?v=8aae3e4f"></audio>

**Table track 0x9A** (0x9A)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 3.2 s.

<audio controls preload="none" src="audio/musica_9A.mp3?v=3e408929"></audio>
