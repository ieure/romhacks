;;; Atari Space Duel
;;; Cocktail no-flip
;;; Ian Eure, 2022

    CPU 6502

    include symbols.s

    * = $690c

    ;; The code needs to be rearranged slightly to fix the ROM
    ;; checksum.

    ;; Original code:
    ;;
    ;; 690c: ldx $0907    ; ae 07 09
    ;; 690f: bmi $6913    ; 30 02
    ;; 6911: ora #$c0     ; 09 c0
    ;; 9613: ldx $30      ; a6 30
    ;;
    ;; The ora at $6911 sets the bits of A to put the video into
    ;; non-inverted mode.  $690c loads the DIP switch settings, and
    ;; skips over that, to $6913 if the high bit is set.
    ;;
    ;; Since the value of $0907 (cab_opt) is only used for this test,
    ;; replacing that read with a jmp frees two bytes to fix the
    ;; checksum.

    jmp $6911                   ; 4c 11 69
    nop
    ;; This byte will get overwritten to make the ROM pass selftest.
    nop
