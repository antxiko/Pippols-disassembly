# Pippols' pixel scroll

Pippols (Konami, RC-729, 1985) moves the background **one pixel at a time** on an
MSX1, in SCREEN 2, a mode with no scroll register at all. This document explains
how it is done, with the cartridge's addresses alongside and the figures measured
in the emulator.

Everything below comes from reading the listing (`src/pippols.asm`) and from two
independent checks:

* `tools/graficos.py` **rebuilds in Python** what the ROM does -the same strips,
  the same character generator, the same name table- and draws the screen. If the
  model were wrong, the game would not come out.
* `tools/omsx_scroll.tcl` **measures in openMSX** what it costs, with the
  emulated Z80 clock (`work/omsx/scroll.log`).

---

## 1. The problem

In SCREEN 2 the screen is 24 x 32 **characters** of 8 x 8 pixels. The name table
says which character goes in each cell, and the pattern table says what each
character looks like. There is no hardware scrolling, and three further
complications:

* The pattern table is split into **three thirds** (rows 0-7, 8-15 and 16-23) and
  each third has its own 256 characters.
* There are only **256 characters** per third.
* Moving a third's 256 patterns every frame would be 2048 bytes through the VDP
  port: impossible at 50 frames a second.

So smooth scrolling has to be manufactured.

## 2. The idea: the same drawing eight times

Pippols puts **eight copies of its background characters into VRAM, each one a
pixel lower than the last**:

    characters 0x40-0x57   the background as it is    (offset 0)
    characters 0x58-0x6F   the same, one pixel down   (offset 1)
    characters 0x70-0x87   ...two pixels down
    ...
    characters 0xE8-0xFF   ...seven pixels down

That is **8 x 24 = 192 characters**, from 0x40 to 0xFF, so 1536 bytes of patterns
and another 1536 of colour, and they take up exactly what is left of a third from
0x2200 to 0x2800. The first 64 characters (0x00-0x3F) are left for the panel, the
font and the ground.

With that, scrolling the screen by a pixel is **adding 24 to every character
number in the name table**. Not a single pattern is touched.

Here is the same window of background at the eight offsets, rebuilt by
`tools/graficos.py`:

![The eight offsets](imagenes/ochofases_0.png)

And stage 1's 192 characters (each row is one offset):

![The 192 characters](imagenes/fases_0.png)

## 3. How the 192 characters are generated

What the cartridge holds, compressed, is **four 24-byte strips** (`0x5840` and
following), which are four columns of three characters stacked vertically.
`CARGA_TIRAS` (0x571E) brings them to 0xEA00, and `CAMBIA_TINTAS` (0x577D) swaps
three pairs of inks so that the same shape comes out in a different colour on
each screen of the world.

`OCHO_DESPLAZAMIENTOS` (0x569E) is the generator: for each offset `p` from 0 to 7
it calls `DOCE_CARACTERES` (0x56B5) twice, once per half. The left half comes
from strips 1 and 2, and the right from 3 and 4. That is why, when the name table
is dumped, a character and the one **12 further along** are always written
together: they are the two columns of the same pair.

The twelve characters of each half, calling A the top strip and B the bottom one:

| index | contents |
|---|---|
| 0 | filler on top + the first 8-p bytes of A |
| 1, 2 | the rest of A, dropped p pixels |
| 3 | the end of A + filler underneath |
| 4-7 | the same with strip B |
| 8 | the end of A on top, the start of A underneath (**A repeating**) |
| 9 | the end of A on top, the start of B underneath (**A-B seam**) |
| 10 | the end of B on top, the start of A underneath (**B-A seam**) |
| 11 | the end of B on top, the start of B underneath (**B repeating**) |

The last four are built by `CARACTER_DE_COSTURA` (0x56ED), and **they are what
makes this work.** A character dropped three pixels leaves three rows of pixels
free at the top, and what has to show there is *the end of the character above
it*. Since the background is built by repeating and alternating two strips, only
four combinations are needed (A over A, A over B, B over A, B over B) and the
drawing comes out continuous at any of the eight offsets.

The filler in characters 0-7 is the byte **0x11**, which in the SCREEN 2 colour
table means *ink 1 on background 1*: black on black. Whatever the pattern says
underneath, it cannot be seen.

The 192 characters are generated **once per screen**, in `GENERA_FONDO` (0x566D),
and copied to the three thirds identically so that the same character number is
valid on any row.

## 4. The whole name table, every frame

`VUELCA_NOMBRES` (0x5312) repaints **all 24 rows x 22 columns** of the play area
on every frame. Column 0 and column 23 onwards are not touched: that is where the
border and the score panel live.

A row is not stored as 22 character numbers but as **6 bytes** in a RAM buffer
(0xE060-0xE0EF, 24 rows of 6). Each byte describes four columns, that is two
pairs:

| buffer byte | what comes out |
|---|---|
| less than 0x0F | fixed pair (no offset) + empty pair |
| 0x0F to 0x7F | pair `n` offset + empty pair |
| 0x80 to 0xDF | pair `n-0x80` offset, **twice** |
| 0xE0 and up | a seam (8, 9, 10 or 11) and a cap (0, 3, 4 or 7), chosen by the bottom three bits |

The offset is applied by adding to each character number the value computed by
`FASE_DEL_SCROLL` (0x5306):

    L = 24 * (position_in_pixels and 7)

and the output loop writes, for each buffer byte, `A`, `A+12`, `H` and `H+12`.
The sixth byte only has room for two columns: 5 x 4 + 2 = 22.

Characters below 0x0F **do not get the offset added**: they are the plain
background and the fixed decorations, which look the same at all eight offsets.

## 5. And every eight pixels, one row

`PASO_DE_SCROLL` (0x5239) is what keeps count. Every frame it:

1. adds (or subtracts) **one pixel** to the stage position, a 16-bit counter at
   0xE100;
2. stores the offset from 0 to 7 in 0xE11C;
3. if no character boundary has been crossed, calls `VUELCA_NOMBRES` straight
   away with the new offset and that is that;
4. if one has been crossed, **shifts the whole buffer six bytes** (a 138-byte
   `lddr`) and `ARMA_FILA` (0x5293) builds the row coming in.

At that moment the offset goes back to 0, so the row step and the pixel offset
meet without a seam.

## 6. Where the incoming row comes from

`ARMA_FILA` (0x5293) turns a position in pixels into the row's 6 bytes, with
three chained tables:

    position in pixels
      |  DIVIDE (0x5653) by 0xC0 = 192 pixels = 24 rows
      +--> stretch (0..12)  and  row within the stretch (0..23)
             |
             |  0x53A2: 10 plans x 13 stretches -> plan number
             +--> 0x5424: 19 stretches x 6 pieces
                    +--> 0xE500: 44 pieces of 24 rows, one byte per row

So a stage is **thirteen stretches of 24 rows** = 2496 pixels, and each stretch
is a row of **six pieces** laid side by side, each four columns wide. The first
and the last are usually piece 2, which is the edge of the road.

The 44 pieces are not in the cartridge as such: `DESCOMPRIME_PIEZAS` (0x5496)
builds them at 0xE500 by gluing 352 groups of three rows taken from a dictionary
of 25 entries (0x54C0), with the index list at 0x550B. Eight indices per piece.

> One detail: the index list is 328 bytes long and the loop reads 352. The last
> 24 reads land inside the **code** at 0x5653, so pieces 41, 42 and 43 come out
> of junk. No table points at them.

When a screen starts, `ARMA_PANTALLA` (0x5384) does this same thing 24 times
over, bottom to top, to fill the whole buffer.

## 7. What it costs

Measured in openMSX on a **Philips VG-8020** (PAL, Z80 at 3.579545 MHz, that is
71591 cycles per frame), letting the demo run for 150 emulated seconds: 1112 game
frames, `work/omsx/scroll.log`.

| | cycles | % of the frame |
|---|---|---|
| `VUELCA_NOMBRES`, average | 32557 | 45.5 % |
| `VUELCA_NOMBRES`, peak | 33969 | 47.4 % |
| The whole interrupt, average | 52533 | 73.4 % |
| The whole interrupt, peak | 70080 | 97.9 % |

How the 1112 game frames fall out:

    60- 70 % :   146
    70- 80 % :   853
    80- 90 % :   112
    90-100 % :     1

And **732.7 writes to the VDP data port per frame**: 528 are the name table
(24 x 22), around 108 the sprite attribute table (27 sprites of four bytes, and
the three enemy shots only three frames out of four) and the rest -up to 128- the
player's patterns, which are reloaded in full on every frame.

In other words: repainting the name table takes **62 % of the interrupt's time**,
and the interrupt eats three quarters of the frame. The main program does nothing
-it sits in a `jr $` at 0x4074- because there is no time to spare for it.

## 8. Why this way and not another

* **Moving the patterns** (rolling each character's 8 bytes) would cost 1536
  bytes a frame for the background alone, and it has to be done in all three
  thirds: 4608. That is more than twice what repainting the names costs, and on
  top of that you would have to read from VRAM or keep a copy in RAM.
* **Rolling the name table** (leaving the characters still and moving the window)
  does not work in SCREEN 2: as a row passes from one third to another, the same
  character number changes its drawing. Pippols dodges that by loading the three
  thirds identically, but even so it would still move eight pixels at a time, not
  one.
* **The price** of the chosen solution is those 192 characters: three quarters of
  the character set goes on the background. That is why the score lives in a
  panel on the right with its own 42-character font, and why the background has
  only twelve distinct pairs.

## 9. What cannot be claimed

* The measurements are from the **demo**, which plays on its own and does not
  fill the screen with creatures. With ten of them and two shots in flight the
  frame will cost more.
* The single frame that went over 90 % in the sample has not been isolated: it is
  not known whether it is a screen change or a normal peak.
