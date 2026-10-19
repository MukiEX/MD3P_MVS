# MD3P_MVS: Neo Geo Paddle Editions

Taito F3-style "Sensor" spinner support for three Neo Geo (MVS/AES) puzzle games, as
patches to the original `.neo` files.

| Game | Set | NGH | Output |
|---|---|---|---|
| Magical Drop III | `magdrop3` | 233 | `magdrop3_paddle.neo` (+ `_nomagnet` variant) |
| Pop 'n Bounce | `popbounc` | 237 | `popbounc_paddle.neo` |
| Puzzle Bobble 2 | `pbobbl2n` | 248 | `pbobbl2n_paddle.neo` |

## How the spinner is read

The spinner sits on the joystick's LEFT/RIGHT lines as a quadrature encoder,
like the F3's JP3 sensor input:

- LEFT = phase A, RIGHT = phase B
- A leading B (`00 → 10 → 11 → 01`) = +1 = clockwise = right/down
- a sample where both phases changed is ignored

The Neo Geo has no counter for this, so each patch points the LSPC raster timer
(IRQ2) at a decoder that samples both ports every 4 lines (about 3.9 kHz).

A port becomes a spinner the first time LEFT and RIGHT read pressed together,
which a lever can't do. Until then the game is unchanged and the timer stays off.
UP, DOWN and the buttons always come from the joystick.

Targets: MiSTer NeoGeo core, NeoSD and real MVS/AES. On MiSTer, use a mouse or
spinner mapped to LEFT/RIGHT quadrature, for example the PaddleNeoGeo core
build in Taito F3 mode with F3 Step Clock set to Port Read.

## What each patch does

**Magical Drop III**
- A virtual paddle drives the clown: 4 counts per column, with an edge buffer
  and re-centring.
- The clown and aim line glide between columns, and the target column pulses.
- Menus, character select and name entry step Puchi Carat-style.
- MOUSE SPEED (x0.25 / x0.5 / x1) is added to the AES option menu.
- The hidden characters are unlocked.
- Same-colour slowdown ("magnet") is on by default; the `_nomagnet` build
  turns it off.

[`games/magdrop3/CHANGES.txt`](games/magdrop3/CHANGES.txt) has the full
breakdown, including every patch site and the tuning block.

**Pop 'n Bounce**
- The spinner count replaces the analog dial that the game's own PADDLE mode
  reads, in play and in menus.
- A launches the ball.
- PADDLE mode is forced on once a spinner is seen.
- Tuning block at CPU `$E9000`.

**Puzzle Bobble 2**
- The knob turns the launcher directly: one aim step per count, angle −60…+60.
  UP still re-centres the launcher.
- The crank tick plays as with the lever, at most once per 4 frames so it
  never holds up the game's other sounds.
- Game select, the puzzle route map and difficulty select step one item per
  16 counts.
- Both ports work in versus.
- There was no free space, so the P ROM grows from 1 MB to 2 MB. The patch
  code runs from CPU `$200000`, and its tuning block is at `$200004`.

## Building

You need `vasmm68k_mot` (Motorola syntax), Python 3 and `make`. Put your own
original `.neo` files in `roms/`:

```
roms/magdrop3.neo
roms/popbounc.neo
roms/pbobbl2n.neo
```

then:

```
make          # .neo builds, IPS patches, and build/sensor_paddle_patcher.html
make check    # compare with the CRC32s of the builds tested on MiSTer
```

- Each `build.py` checks the original bytes at every patch site and refuses a
  ROM that doesn't match.
- `make check` compares whole-file CRCs, so a `.neo` from a different packer
  (different header) can show DIFF even when the patched program ROM is
  correct. The browser patcher checks the program ROM only.
- IPS files are made only for the same-size patches. Puzzle Bobble 2's file
  grows, so use the `.neo` or the patcher for it.

## Browser patcher

`build/sensor_paddle_patcher.html` is one self-contained page:
- Drop in an original `.neo` and it recognises the game, applies the patch,
  checks the result against the tested build, and saves the Paddle Edition.
- It has the magnet / no-magnet choice for Magical Drop III.
- It contains only the changed bytes, no ROM data.

## Layout

```
games/<set>/       patch source (.asm) and build.py for each game
tools/             mkips.py, mkpatcher.py, check.py
patcher/           HTML template for the browser patcher
test/harness/      headless Geolith harness used for testing (see test/README.md)
test/<set>/        the test scripts used during development
```
