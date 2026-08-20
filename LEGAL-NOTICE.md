# Legal notice and attribution

*(También disponible [en castellano](AVISO-LEGAL.md).)*

## Who owns what

**The game is not ours.** *Pippols* was published by **Konami** in 1985
as the RC-729 cartridge for the MSX. All rights over the game remain with their
holders.

**What is ours** are this repository's tools, the comments in the listing, the
analysis and the documentation. That is published under the licence in
`LICENSE`.

## What is in this repository

The file `src/pippols.asm` is the commented disassembly of the cartridge. It
is published for the **preservation, study and documentation** of a 1985 title
that is part of MSX software history.

The cartridge image (`.rom`) is **not** distributed here. Anyone who wants to
rebuild the listing has to supply their own, and the `Makefile` checks its
sha256 before doing anything.

The images produced by `tools/graficos.py` are not illustrations brought in
from outside: they are the game's own video memory, rebuilt by replaying the
copies the cartridge makes —the same addresses and the same order that are in
the listing— and drawn as they come. They are part of the proof that the
reading of the binary is right: if it were wrong, they would come out as noise.

## What it rests on

Nobody else's work. Everything stated here comes from reading this binary, and
each claim carries its evidence next to it: the instruction that reads a datum,
the table that ends exactly where it has to end, or the arithmetic that works
out. What is not settled is said not to be.

## If you are one of the authors

If you worked on *Pippols* or hold rights over the game, and you would
rather this material were not published, **say so and it comes down, no
argument**. The intent of this work is the opposite of harming you: it is to
put on record how it was made.
