# Arcade ROM hacks

This is a small collection of ROM hacks I’ve created for classic
arcade video games.

 - [Blue Print: Freeplay with attract](blue-print-freeplay-w-attract/README.md)
 - [Tac/Scan: Switchable freeplay with attract](tacscan-freeplay/README.md)

# Hack Assembler

Hack Assembler (ha) is a tool for patching arcade ROMs
programmatically, from source code.  This allows patches to be written
in assembler, and preseves the source, which allows for greater
understanding and quick development.

To use all the features of ha, you will need MAME.

## Features

 - Maintain patches as assembler source, rather than binary patches.
 - Assembles the patch and patches the ROM in one step.
 - Discovers the ROM files to patch, based on filename - fully
   automatic.
 - Dev mode assembles, patches, and runs the patched ROM in MAME, all
   in one command.

## Supported CPUs

- 6502 or Z80 via [crasm](https://github.com/colinbourassa/crasm).  This is the recommended assembler.
- 6502, via [asm6](https://github.com/parasyte/asm6).
- Z80, via [z80asm](https://www.nongnu.org/z80asm/).


## Setup

You need to have MAME somewhere on your machine, and set the
`MAME_DIR` environment variable to wherever it’s installed.  This
assumes that ROMs live in `$MAME_DIR/roms`, and that the MAME
executable is named `mame64`.  You can set the MAME binary with
`$MAME_BIN` or the `--mame-bin` option.  The ROM location can’t
currently be changed.  At some point it ought to parse MAME’s
configuration.

## Layout

Patches must have a specific layout.  `ha init <romname>` will create
it for you.

```
+ <root>
 \
  + game.xml   - This is the MAME XML info dump for the game.
  + ha.ini     - Optional configuration for ha.
  + roms
  |\
  | + original - Original ROMs for the game being patched.
  | + patched  - Patched ROMs. ha will create these.
  |
  + patch      - Patch source directory
   \
    + maincpu  - Patches for the CPU region.
    |\
    | + 0000-desc.s  - This patch applies at 0x0000
    | + 4000-other.s - This patch applies at 0x4000
    + soundcpu - You can patch ROMs in other regions, too.
```

Based on the region and prefix in the source file name, ha will
determine the correct ROM to patch using `game.xml`.

## Configuration

When assembling patches, ha will choose an appropriate assembler for the game’s CPU.  If you want to use a specific assembler, it can be specified in `ha.ini`.  One assembler per game cpu may be specified.

Example:

```
[assemblers]
maincpu = AssembleCRASM
```

## Commands

`ha init pacmanf`

Creates a template for patches to the `pacmanf` MAME ROM.  The
`game.xml` file will be written, original ROMs extracted, and
directories created for each region.  Any valid MAME ROM name may be
provided.

`ha asm`

Assemble the patch.  See "Supported CPUs."

`ha patch`

Patch ROMs.  This doesn’t assemble; you must have assembled already.

`ha ap`

Assemble & patch.

`ha dev`

Assemble, patch, and run the patched ROM in MAME.

`ha orig`

Run the original ROM in MAME.
