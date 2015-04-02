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

## Easter Eggs

You never know what you’ll find kicking around in a game’s ROMs. In
the case of Tac/Scan, it seems that whatever created the master ROM
images padded the ends with the contents of its memory, which included
some fragments assembly source code.

### 1709a.prom-u20

#### Fragment 1

```assembly
	JP NZ,DIN20
	LD H,E			;C=CHOICE,L=ADDR
```

#### Fragment 2

I’m not sure what this is doing, but perhaps "DIN" means "Data In." I
assembled this code with a placeholder for the `DIN50` value, but
didn’t find it anywhere in the Tac/Scan ROMs.

```assembly
DIN40:
	LD A,H
	OR A
	JP NZ,DIN50

	;SPACE FOURTH COLUMN
	LD H,4
	LD A,' '
```

#### Fragment 3

Just a label.

```assembly
DGDATA:
```

#### Fragment 4

I also wasn’t able to find this anywhere in the ROMs.

```assembly
	OR A
	JP NZ,DGDATA
	LD A,E
	CP 5
	JP NC,DGDATA
	LD 
```

#### Fragment 5

```
;IN
```

### 1710a.prom-u21

This code seems to control audio. In the first fragment, "USB" refers
to "Universal Sound Board," the audio hardware in Tac/Scan.

#### Fragment 1

```assembly
P BC
	RET


;OUTPUT BYTE IN 'L' TO USB
DEBUGOUT:
	CALL 
```

#### Fragment 2

```assembly
	RET


MD0:
	DB ' Select function; R
```

#### Fragment 3

```
ength (1..255,x
```

#### Fragment 4

```
EYPRESS  -  '
```

#### Fragment 5

```assembly
CHAN10
CHAN1:
	CP 6
	JP C,CHAN10
	LD A,0
C
```

#### Fragment 6

```
MPLITUDE UP  -  '|'
```

#### Fragment 7

```assembly
:
	LD C,-1

AMPL10:
	LD B,TRANSMOC
	CALL OUTPUTD
	RET C
	CALL GETCHAN
	LD A,(IX+AMPLP)
	ADD A,C
	LD (IX+AMPLP),A
	CALL AMPLO
	JP NOTETOUT


;****OCTAVE UP  -  '>'
OCTU:
	LD C,1
	JP OCT

;****OCTAVE DOWN  -  '<'
OCTD:
	LD C,-1
OCT:
	LD B,TRANSMOC
	CALL OUTPUTD
	RET C
	CALL GETCHAN
OCT3:
	LD A,(IX+OCTP)
	ADD A,C
	JP M,OCT2
	CP 10
	JP C,OCT1
	SUB 10
OCT1:
	LD (IX+OCTP),A
	JP OC
```

#### Fragment 8

```assembly
D C,-1
NO
```

## Copyright

To the extent that this patch represents original work, I place it in
the public domain.
