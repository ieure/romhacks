;;; Atari Space Duel
;;; Cocktail no-flip
;;; Ian Eure, 2022

    CPU 6502

    include symbols.s

    * = $82ea

    ;; Skip over the load/store at $82EC / $82EE to prevent screen
    ;; flip.
    jmp $82f1
