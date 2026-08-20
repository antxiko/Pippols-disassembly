# Open questions

What the binary does not settle on its own. The whole cartridge is explained byte
by byte; this is what remains to be measured or decided.

## The nine bytes at the end

Behind the 45 padding bytes of 0xFF, the cartridge finishes with nine bytes that
are not padding:

    7FF7  8C A8 B8 9D B8 9A 06 29 AA

Checked: no instruction in the listing reads them, no pointer in any table lands
there, and the sequence does not repeat anywhere else in the cartridge. They
could be the tail of something left over from building the ROM, but that, as
things stand, cannot be shown with the binary in hand.

## The two map pieces nobody uses

`DESCOMPRIME_PIEZAS` (0x5496) builds 44 pieces at 0xE500 and the nineteen
stretches at 0x5424 only point at 39. Three of them —41, 42 and 43— are junk read
out of the code, and that much is clear. The other two, **0** and **1**, are
properly built from the dictionary and nobody names them. Whether they are a
stretch that was dropped or simply where the numbering starts, the cartridge does
not say.

## The frame that went over 90 %

In the openMSX measurement, out of 1112 demo frames exactly **one** went above
90 % of the available time (70,080 cycles out of 71,591). It has not been pinned
down: it could be the screen change, which rebuilds the 192 characters, or a
normal peak with a lot of sprites in play.

## The measurements are from the demo

Everything measured —the cost of the name table dump, of the interrupt, the
writes to the VDP— comes from letting the **demo** run, and the demo plays on its
own without filling the screen with creatures. With ten of them and two shots in
flight the frame will cost more, and a real game with a joystick in hand has not
been measured.

## What happens when the world runs out

The route has two halves of nine screens and the table at 0x7B62 chains them with
two destinations each. On reaching the throne the map is turned over and the
other half begins; what happens after the final screen, and whether the
difficulty —which climbs to 0x20 and stops there— leaves the game playable, needs
playing to find out.
