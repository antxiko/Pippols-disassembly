# The code

Nine thousand bytes of Z80, with 152 routines somebody calls by name and a frame
Konami reused across its cartridges of those years: the interrupt as the program,
a dispatcher that jumps through tables and a three-channel sound player.

## The interrupt is the program

INIT (0x404A) sets up the VDP, loads the fixed characters, writes `jp 0x4010`
into the BIOS's H.KEYI hook and drops into a two-byte `jr $` at 0x4074. From then
on the main loop does absolutely nothing: **everything** —sound, controls, the
player, the creatures, the objects and the scroll— happens inside the interrupt,
one step per frame.

The first thing the interrupt does is read the VDP status, which is what lowers
the request, and the last thing is read it again in case another arrived
meanwhile. In between there is a lock (0xE005): if the previous step has not
finished, the new one just gives the sound a step and leaves. That way the music
does not break when a frame overruns, which happens here often: the whole
interrupt averages 73 % of the frame.

## The dispatcher

```
	call DESPACHA
	defw target_0, target_1, ...
```

`DESPACHA` (0x4043) is six instructions: `add a,a` because the index is in
words, `pop hl` to pick up the return address —which is exactly where the table
begins—, read word number A from there and `jp (hl)`. You go in with a `call` and
you never come back.

There is a second, cheaper dispatcher for things indexed by type: a `push bc /
ret` with the table **two bytes below** its base, so the index can start at 1
instead of 0. The three creature tables (0x6861, 0x6894, 0x68B4) and the
per-frame routine table (0x6B58) all work that way.

## The eight states

0xE000 says what the program is doing, and 0xE001 is a substate that each state
eats away with `djnz`:

| state | what it does |
|---|---|
| 0 | the KONAMI logo rising three rows every two frames |
| 1 | the title on screen, with its countdown |
| 2 | the menu: PUSH SPACE KEY blinking |
| 3 | starts the demo |
| 4 | starts the stage: clear, paint the panel and build it |
| 5 | **playing**: one step of the game per frame |
| 6 | end of game, with sound 0x98 |
| 7 | GAME OVER and back to the title |

States 0, 1 and 2 push the return address 0x4184 before dispatching, which is a
trick for the three of them to share the menu handling without repeating it: on
return, that stretch reads the controls and starts the game if space was pressed.

## One step of the game

`PASO_DE_PARTIDA` (0x5087) is what runs on every frame while you play, in this
order: the sprite table, the controls, the player, the creatures, the shots
—yours and theirs—, the objects, the scroll and the collisions. At the end,
`ELIGE_MUSICA` (0x5168) looks at what the player is up to and asks for the music
that fits; since the highest number wins in each channel, it can ask every frame
without cutting off whatever is already playing.

## The sound

Three 14-byte channels at 0xE010, and a table of **40 sounds** at 0x4AD8 pointing
at **36 tracks**. The sound number also says how many channels it wants: below 7,
only channel C, which is the effects one; from 7 to 14, two; from 15 up, all
three. And if a channel is already playing something with a higher number, the
new one does not take its place.

A track is a run of bytes: the high nibble is the note and the low one the
length, `0x2n` changes the length of whatever follows, 0xFF silences the channel
and 0xFE is end-or-jump —with a loop count, which is how repeats are done. The
notes come from fifteen PSG periods (0x4AC9), one octave and three notes over,
each one the previous times 0.944, which is the semitone; reading three bytes
earlier drops three semitones at once, and that is what bit 6 of a channel does.

## The background and the map

Here is what sets this cartridge apart, and it has its own page: **[The pixel
scroll](THE-PIXEL-SCROLL.html)**. In short: the background characters are in
VRAM eight times over, each copy a pixel lower, and scrolling the screen means
adding 24 to the character number and writing the whole name table again, 24 rows
by 22 columns, on every frame.

The road is not stored as screens but on four floors:

```
position in pixels
  --> stretch (0..12) and row within the stretch (0..23)
        --> plan (0x53A2): 10 plans x 13 stretches
              --> stretch (0x5424): 19 stretches x 6 pieces
                    --> piece (0xE500): 44 pieces of 24 rows
```

A stage is thirteen stretches of 24 rows, that is 2496 pixels, and each stretch
is six pieces of four columns laid side by side. The 44 pieces are built in RAM
by gluing groups of three rows from a dictionary of 25, with the index list at
0x550B: **328 bytes for the game's whole map**.

## The player and the creatures

The player's state (0xE120) comes straight from the controls through a
sixteen-entry table (0x5D32), and everything hangs off it: the animation, the
sprite that gets loaded and which way the shot goes. Before moving, the character
ahead is checked with four probes (0x5B6A), and the comparison is made against
`0x40 + 24 × phase` because background characters change number with the scroll
offset.

The creatures are ten 16-byte slots with 8.8 fixed-point velocity, and twelve
routines, one per type. The chase engine (0x6B72) does not turn on a sixpence: it
**eases** the current velocity towards the one that would reach the target, and
that is why they trace those curves instead of heading straight for the player.
