# Getting started

## What you need

`pasmo` and `z80dasm` to assemble and disassemble, and Python 3 for the tools.
Nothing else.

The cartridge is not distributed with this repository: you need your own copy,
named `pippols.rom` in the project root. It is exactly 16384 bytes with this
sha256:

    ad011203f1295bf75fc30423cead68e12f96169ffeb9f13474303d9a553e41f7

With any other dump the listing will not reassemble. `make comprueba` tells you
in one line.

## The commands

```sh
make          # trace, generate the listing and check everything
make verify   # assemble the listing and compare its sha256 with the cartridge
make sanity   # what reassembly cannot catch
make test     # the 28 tests on the listing, which do not need the cartridge
make imagenes # redraw the reconstructed pictures
make medir    # measure what the scroll costs, in openMSX
make web      # the pictures and these pages
```

`make` chains the first four. If all goes well, the line that matters is this
one:

```
  ensamblado : 16384 bytes  ad011203...553e41f7
  original   : 16384 bytes  ad011203...553e41f7
OK: reproducible byte a byte
```

## What is in each folder

| | |
|---|---|
| `src/pippols.asm` | the commented listing, generated; never edited by hand |
| `src/pippols.notes` | the annotations: labels, comments, headers and data ranges, anchored to addresses |
| `src/pippols.entries` | the entry points the trace cannot deduce, each with its justification |
| `src/pippols.nocode` | the zones the tracer must not read as code |
| `tools/` | the tracer, the listing generator, the checks and the drawing tools |
| `tests/` | 28 tests on the listing, the notes and the site |
| `docs/` | this site |
| `work/` | what `make` produces along the way |

## How to read the listing

Every routine has an uppercase name and a comment saying what it does and what
it takes. Data blocks are labelled `DATA_<use>`, with the width of their
structure, and each has an explanation of what it is and how that is known.
Addresses are the real ones of the cartridge in page 1: 0x4000-0x7FFF.

To change anything, edit `src/pippols.notes` and run `make` again: the listing is
regenerated and the checks say whether it still holds.

## How it was done

The tracer (`tools/z80trace.py`) follows the flow from the header's entry point
and from what `pippols.entries` declares: the interrupt and the targets of the
dispatchers, which jump through tables. Whatever is not code is left as a gap,
and every gap is closed by finding the instruction that reads it
(`tools/quien_apunta.py`, `tools/refs.py`) and checking that the format matches
what the consuming code does with it.

What cannot be read is measured. `tools/graficos.py` rebuilds the background in
Python —the strips, the generator of the 192 characters, the map decompressor and
the name table dump— and draws the screen: if the reading were wrong, it would
come out as noise. And `tools/omsx_scroll.tcl` measures in openMSX, with the
emulated Z80's clock, what each frame costs.

## Reproducibility

- assembling returns the cartridge's sha256
- no range declared as data comes out as code in the trace
- no entry point falls inside a data range
- all 16384 bytes are assigned: 9099 of code, 7285 of data, 0 unidentified
