;; Sega Tac/Scan
;; Free play hack
;; 2015 Ian Eure <ian.eure@gmail.com>

scancoin:       equ $69         ; Scan for coin input
start:          equ $0127       ; Game start
hook:           equ $0038       ; patch in freeplay code
freeplay:       equ $0790       ; Unused Rom space

firstdip:       equ $F8
lastdip:        equ $FC
enread:         equ $F8
startbtn:       equ $FC

credit1:        equ $C80B
credit2:        equ $CB0F

gamestate:      equ $CA20
