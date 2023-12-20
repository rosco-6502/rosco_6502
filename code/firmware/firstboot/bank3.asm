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

; *******************************************************
; * Include routine table for this bank
; *******************************************************
        section .bank3.rtable
        include "rtable.asm"


; *******************************************************
; * RESET vector entry for this bank
; *******************************************************
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
; * include common routines
; *******************************************************
        section .bank3.routines
        include "routines.asm"


; *******************************************************
; * Include bank switch code for this bank
; *******************************************************
        section .bank3.bank
        include "bank.asm"

bankenter3:
        lda #<EBANK
        ldx #>EBANK
        jsr printsz
        lda #$00          ; Switch to bank 0!
        jmp bankswitch


; *******************************************************
; * Include IRQ handling for this bank
; *******************************************************
        section .bank3.irq
        include "irq.asm"


; *******************************************************
; * Include wozmon for this bank
; *******************************************************
        section .bank3.wozmon
        include "wozmon.asm"


; *******************************************************
; * Include vectors for this bank
; *******************************************************
        section .bank3.vectors
        include "vectors.asm"


; *******************************************************
; * Readonly data
; *******************************************************
        section .bank3.rodata

EBANK           db      $1B, "[0;37m    Bank   #3 ", $1B, "[1;32mpassed", $1B, "[0m", $D, 0

