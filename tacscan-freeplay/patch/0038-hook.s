;; Sega Tac/Scan
;; Free play hack
;; 2015 Ian Eure <ian.eure@gmail.com>

include 'symbols.s'

org hook
        jp freeplay             ; Patch in freeplay code
