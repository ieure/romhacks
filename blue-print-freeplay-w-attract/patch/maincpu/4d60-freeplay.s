;; Midway Blue Print
;; Free play with attract hack v2
;; Ian Eure, 2014-2015

include 'symbols.s'

org patch                       ; Unused ROM space
        LD A, (mode)            ; Are we in game?
        CP ingame
        JR Z, end               ; Yes, bail

        LD A, (dips)            ; Read DIP
        AND $08                 ; freeplay enabled?
        JP Z, coincheck         ; No, call the coin input code

freeplay:
        LD A, (p1)
        AND $02                 ; P1 start being pressed?
        JP NZ, start
        LD A, (p2)
        AND $02                 ; P2 start being pressed?
        JP NZ, start

end:
        RET

