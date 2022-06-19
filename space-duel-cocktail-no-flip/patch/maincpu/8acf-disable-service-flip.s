;;; Atari Space Duel
;;; Cocktail no-flip
;;; Ian Eure, 2022

    CPU 6502

    include symbols.s

    * = $8acf

    ;; The original code here is BVC $8AD3, which branches over the
    ;; LDA #$C0 at $6911, which sets the two high bits of A before
    ;; it's written to $0C00 at $8AD3.
    ;; NOPping out the branch means the high bits are always set, and
    ;; the screen won't flip.
    nop
    nop
