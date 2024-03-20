;------------------------------------------------------------
;                            ___ ___ ___ ___ 
;  ___ ___ ___ ___ ___      |  _| __|   |__ |
; |  _| . |_ -|  _| . |     | . |__ | | | __|
; |_| |___|___|___|___|_____|___|___|___|___|
;                     |_____|    Bringup Code
;------------------------------------------------------------
; Copyright (c)2022-2024 Ross Bamford and contributors
; See top-level LICENSE.md for licence information.
;
; Main code for ROM bank 1
;------------------------------------------------------------
CUR_ROMBANK     =       1       ; assemble for ROM bank 1

; *******************************************************
; * include system defines
; *******************************************************
                include "defines.asm"

; *******************************************************
; * Include routine table for this bank
; *******************************************************
                section .bank1.rtable
                include "rtable.asm"

; *******************************************************
; * Include IRQ handling for this bank
; *******************************************************
                section .bank1.irq
                include "irq.asm"

; *******************************************************
; * Include vectors for this bank
; *******************************************************
                section .bank1.vectors
                include "vectors.asm"

; Above this point, all addresses must match between banks

; *******************************************************
; * Bank specific code
; *******************************************************
                section .bank1.text

; *******************************************************
; * Bank init/test
; *******************************************************
bank_init:
                and     #BANK_ROM_M     ; mask ROM bits
                cmp     #CUR_ROMBANK<<BANK_ROM_B
                beq     .goodbank
                sec
                rts
.goodbank       lda     #<EBANK
                ldx     #>EBANK
                jsr     PRINT_SZ        ; Print message
                clc
                rts

; *******************************************************
; * include common routines
; *******************************************************
                include "routines.asm"

; *******************************************************
; * Readonly data
; *******************************************************
                section .bank1.rodata

EBANK           db      $1B, "[0;37m    Bank   #1 ", $1B, "[1;32mpassed", $1B, "[0m (unused)", $D, $A, 0
