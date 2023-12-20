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
; Main code for ROM bank 1
;------------------------------------------------------------

; *******************************************************
; * Include routine table for this bank
; *******************************************************
        section .bank1.rtable
        include "rtable.asm"


; *******************************************************
; * RESET vector entry for this bank
; *******************************************************
        section .bank1.text
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
        section .bank1.routines
        include "routines.asm"


; *******************************************************
; * Include bank switch code for this bank
; *******************************************************
        section .bank1.bank
        include "bank.asm"

bankenter1:
        lda #<EBANK
        ldx #>EBANK
        jsr printsz
        lda #$20          ; Switch to bank 2!
        jmp bankswitch

          
; *******************************************************
; * Include IRQ handling for this bank
; *******************************************************
        section .bank1.irq
        include "irq.asm"


; *******************************************************
; * Include wozmon for this bank
; *******************************************************
        section .bank1.wozmon
        include "wozmon.asm"


; *******************************************************
; * Include vectors for this bank
; *******************************************************
        section .bank1.vectors
        include "vectors.asm"


; *******************************************************
; * Readonly data
; *******************************************************
        section .bank1.rodata

EBANK           db      $1B, "[0;37m    Bank   #1 ", $1B, "[1;32mpassed", $1B, "[0m", $D, 0
