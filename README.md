# Pippols (Konami, 1985, MSX1) — commented disassembly

Konami's RC-729 cartridge, taken apart byte by byte. All 16,384 bytes are
accounted for and explained: no unjustified gaps, no "graphics blob", no
guessed table.

🌐 **[Read it as a website](https://antxiko.github.io/Pippols-disassembly/)**  ·  📄 **[How the pixel scroll works](THE-PIXEL-SCROLL.md)**

[README en español](README.es.md)

---

## What this is

*Pippols* is the 1985 cartridge where a little fellow walks up a road that never
stops moving, dodging creatures, picking things up and shooting, all the way to
the throne. This is its code, commented, with the tools to rebuild it and check
that what comes out is the original.

The machine maps the 16 KB at 0x4000-0x7FFF —page 1—, the BIOS calls the entry
point at 0x404A, and the program never returns from it: startup writes a `jp`
into the H.KEYI hook and drops into a two-byte loop, so **the whole game runs
inside the interrupt**, one step per frame.

## What makes it interesting

Pippols scrolls its background **one pixel at a time** in SCREEN 2, a mode with
no scroll register at all. It does it by keeping its background characters in
video memory **eight times over**, each copy shifted one pixel further down, and
rewriting the whole name table every frame with the shifted character number.
Measured in the emulator, that eats 45 % of the frame, and the complete
interrupt 73 %.

The full story, with addresses and measurements, is in
**[THE-PIXEL-SCROLL.md](THE-PIXEL-SCROLL.md)**.

## Why you can believe this

`make` traces the flow, builds the listing and demands that assembling it gives
back exactly the original:

```
  ensamblado : 16384 bytes  ad011203...553e41f7
  original   : 16384 bytes  ad011203...553e41f7
OK: reproducible byte a byte
```

A listing can reassemble perfectly and still be wrong —if you read pictures as
instructions, the bytes do not change— so two more checks run: no range declared
as data may come out as code, and no entry point may fall inside one.

The graphics get a third, independent check: `tools/graficos.py` **redoes in
Python** what the cartridge does —the background strips, the generator for the
192 characters, the map decompressor and the name-table dump— and draws the
screen. If the reading of the binary were wrong, the game would not come out;
it does.

## The game in numbers

| | |
|---|---|
| bytes of code | 9,099 |
| bytes of data | 7,285 |
| unidentified bytes | **0** |
| named labels | 676 |
| anchored comments | 998 |
| explained data ranges | 174 |

## A few things that turned up

- **The 192 background characters** (0x40 to 0xFF) are eight copies of the same
  drawing, each one pixel lower. They are generated in RAM at the start of every
  screen from **four 24-byte strips**, and four of the twelve characters in each
  half are *seams*: the end of one strip on top and the start of another below,
  which is what keeps the drawing continuous at half height.
- **The map fits in 328 bytes.** A stage is thirteen sections of 24 rows, each
  section is six four-column pieces, and the 44 pieces are assembled by gluing
  three-row groups from a 25-entry dictionary. The decompressor **reads 24
  entries too many** and runs into the code at 0x5653: the last three pieces are
  garbage and nothing points at them.
- **There is a jump that lands inside another instruction.** The `jr nz` at
  0x717D goes to 0x7181, which is the displacement byte of the `jr z` on the
  line above; it executes as `dec b` —harmless, because BC is on the stack— and
  carries on. It is the only place in the cartridge where this happens.
- **The score lies by a factor of ten.** Points are three BCD bytes, but the
  panel paints a fixed zero right after them, so what you see is ten times the
  counter. Pickups give 100, 500, 1000 or 2000; the first extra life lands at
  20,000 and then every 60,000.
- **Sprite order alternates every frame** (0x7F83): one frame the enemies go
  first, the next one the objects, so the four-sprites-per-line limit does not
  always hide the same ones.
- **Same shapes, different inks.** The 18 screens of the world share the
  background drawings: what changes is a swap of three ink pairs (0x577D) over
  the 96 colour bytes.
- **0xE126 is written and nobody reads it.** It is stored at 0x59EF every frame
  and there is no read anywhere in the cartridge.
- **The nine bytes at the end** (0x7FF7, behind the 0xFF padding) are read by
  nothing and pointed at by nobody. They stay an open question.

## Getting started

You need `pasmo`, `z80dasm` and Python 3. The cartridge image is **not**
distributed here: put yours in the root as `pippols.rom`, 16384 bytes,
sha256 `ad011203f1295bf75fc30423cead68e12f96169ffeb9f13474303d9a553e41f7`.

```sh
make          # trace, build the listing and check everything
make verify   # assemble and compare against the cartridge
make sanity   # what reassembling cannot catch
make imagenes # redraw the reconstructed images
make medir    # measure the cost of the scroll in openMSX
make web      # rebuild the site under docs/
```

## Licence and attribution

The game is not ours: *Pippols* belongs to Konami, and all rights remain with
its holders. What is ours —the tools, the comments and the documentation— is
published under the licence in `LICENSE`. The cartridge image is not
distributed. See [LEGAL-NOTICE.md](LEGAL-NOTICE.md).
