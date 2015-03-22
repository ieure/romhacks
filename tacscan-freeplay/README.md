# Tac/Scan switchable freeplay with attract mode v1

## Installation

Burn the ROM image 1711a.cpu-u25 to a 2716 EPROM, and install it at
U25 on the CPU PCB.

## Enabling

The 4 coin / 1 credit DIP setting (all DIPs on the SW1 block set ON)
will now enable free play.

## Theory

The code at $0069 reads the coin switches to increment credits, which
is called from $0038. $0038 is patched to jump to normally unused
memory at $0790, where the patch has been added. Rather than read the
coin inputs, the patch:

 - Determines if a game is in progress. $CA20 is $00 if a game is
   being played, and $01 if the game is in attract. If the attract
   mode is not currently running, control is returned to $0069.
 - Reads the start buttons. The A register is loaded from I/O port
   $FC, which will cause $01 for a 1P start button actuation, or $02
   for a 2P start to be loaded into the accumulator. If no buttons
   were pressed, control is returned to the game.
 - Reads the DIP switches. If the DIPs are not set for 4 coin/1
   credit, control is once again returned to $0069. Otherwise, the
   credit counts at $C80B and $CB0F are loaded with the contents of
   the accumulator, which will be the correct number of credits for a
   1- or 2-player game.

Control is then passed to $0127, which is the game start screen,
normally called when there are credits on the machine. This code
notices that the start button is pressed, deducts the credits added by
the patch, and begins the game.

## Source

[The source code is freely available](patch).

Each file is prefixed with the location in memory where the patch is
to be applied.

## Issues/Enhancements

 - Inserting a coin will add credits even when in freeplay, which
   could prevent the attract mode from running. This is probably not a
   huge deal, but would be nice to fix.
 - It doesnt (yet) work on real hardware.

## Copyright

To the extent that this patch represents original work, I place it in
the public domain.
