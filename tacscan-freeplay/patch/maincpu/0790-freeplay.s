;; Sega Tac/Scan
;; Free play hack
;; 2015 Ian Eure <ian.eure@gmail.com>

include 'symbols.s'

org freeplay
        PUSH AF

;;; Game already playing?
        LD A, (gamestate)
        BIT 0, A
        JR Z, end

;;; Start pressed?
        LD A, $FF
        OUT (enread), A         ; You have to write $FF here
        IN A, (startbtn)        ; Before reading the start button
        AND $03
        JR Z, end               ; Neither button pressed

;; Check dips
        PUSH BC
        LD B, A                 ; Save switch state
        LD C, firstdip          ; DIPs SW2:4/8
loop:   IN A, (C)               ; Read DIPs
        CPL
        AND $03                 ; Both enabled?
        JR Z, endloop           ; No, skip to end
        INC C                   ; Next port
        LD A, C
        CP lastdip              ; Done checking ports?
        JR NZ, loop

        ;; Add credits & start
        LD A, B                 ; Restore switch state
        XOR $03                 ; Were *both* buttons pressed?!
        JP NZ, cont             ; No
        LD A, B                 ; XOR changes A, reload
        DEC A                   ; Cap two credits.
cont:
        LD BC, credit1          ; LD ($C80B), A doesnt work, why?
        LD (BC), A
        LD BC, credit2
        LD (BC), A
        POP BC
        POP AF
        JP start

endloop:
        POP BC
end:    POP AF
        JP scancoin
