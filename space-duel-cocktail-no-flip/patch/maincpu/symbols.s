;;; Atari Space Duel
;;; Free play with attract
;;; Ian Eure, 2022

cab_opt    equ $0907           ; Cabinet & Option input
flip_out    equ $0c00          ; Invert, LED, EAROM, coin lockout, coin counter output

load_cab_opt    equ $690C      ; Load cab_opt
