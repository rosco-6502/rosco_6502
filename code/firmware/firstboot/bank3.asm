;------------------------------------------------------------
;                            ___ ___ ___ ___ 
;  ___ ___ ___ ___ ___      |  _| __|   |__ |
; |  _| . |_ -|  _| . |     | . |__ | | | __|
; |_| |___|___|___|___|_____|___|___|___|___|
;                     |_____|    Bringup Code
;------------------------------------------------------------
; Copyright (c)2022 Ross Bamford and contributors
; See top-level LICENSE.md for licence information.
;
; Main code for ROM bank 3
;------------------------------------------------------------

        section .bank3.text
        include "defines.asm"

start:
        sei
        cld
        jmp start         ; Just halt for now...
                          ; This will need to switch back to 
                          ; bank0, in case the board is reset
                          ; while this bank is selected...


; *******************************************************
; * Include IRQ handling for this bank
; *******************************************************
        section .bank3.irq
        include "irq.asm"


; *******************************************************
; * Include vectors for this bank
; *******************************************************
        section .bank3.vectors
        include "vectors.asm"
