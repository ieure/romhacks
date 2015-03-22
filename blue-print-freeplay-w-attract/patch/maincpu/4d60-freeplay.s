;; Midway Blue Print
;; Free play with attract hack
;; Ian Eure, 2014

include 'symbols.s'

org patch                       ; Unused ROM space

  ld a, (dips)                  ; Read DIP
  and $08                       ; freeplay enabled?
  jp z,coincheck                ; No, call the coin input code

freeplay:
  ld a, (p1)
  and $02                       ; P1 start being pressed?
  jp nz, start
  ld a, (p2)
  and $02                       ; P2 start being pressed?
  jp nz, start
  ret

