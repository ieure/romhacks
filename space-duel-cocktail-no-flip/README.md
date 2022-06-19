# Space Duel Cocktail No-Flip

This ROM hack patches Space Duel to disable video flipping in cocktail mode.

## Rationale

The Vector-Labs Space Duel multigame kits advertise themselves as being designed for both upright and cocktail Space Duel cabinets.  In truth, they aren’t designed for cocktail machines, which means they don’t work as they should in those cabinets.

Space Duel cocktail machines mount the monitor upside-down relative to the upright.  This allows the monitor to be adjusted from the Player 1 side, where the test mode switch is.  Since the monitor is upside-down, the game enables the Invert X & Y feature of the AVG so it displays right-side-up for the first player.  It also draws the Player 2 lives and score on the bottom of the screen, upside-down, so they’re in the same (relative) position for Player 2 as Player 1’s lives and score.

Since the multigame kit lets you play Gravitar and Black Widow — games which never got a cocktail release, and don’t invert their video — owners of SD cocktails must rotate their monitors, which strains the video cable, renders it non-adjustable (since the service door opens onto a metal panel), and when playing Space Duel, Player 2’s scores are illegible.  And this is the *best* option.  If you leave the monitor in its original orientation, Gravitar and Black Widow play upside-down.

This ROM hack opens the door to another approach:

1. Pull the 6100’s yoke connector, and swap the two X wires and two Y wires.  This causes the monitor to display the image upside-down, which cancels out the upside-downness of the inverted monitor.  Now Gravitar and Black Widow display right, but *Space Duel*, in cocktail mode, doesn’t.
2. Install this ROM hack on the Space Duel board.  This hack 

## Installation

Program 136006-103.m1 and 136006-105.j1 onto 2532 EPROMs, and replace the ROMs at M1 and J1 with the new ones.

## Theory of Operation

The harness of the cocktail Space Duel has a jumper between pins P and R; the upright doesn’t.  This is mapped to the high bit of $0907.  When the game detects this bit set to 1, it writes to the video flip output at $0c00 to invert the video.

This happens in three places: one for the game mode, one for service mode, and one for self-test.  The patch either NOPs the code or turns conditional branches into unconditional jumps, whatever’s appropriate for the code being patched.
