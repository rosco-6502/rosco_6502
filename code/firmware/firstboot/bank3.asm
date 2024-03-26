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
; Main code for ROM bank 3
;------------------------------------------------------------
CUR_ROMBANK             =       3       ; assemble for ROM bank 3

; *******************************************************
; * include system defines
; *******************************************************
                section .bank3.text
                include "defines.asm"

; *******************************************************
; * Include routine table for this bank
; *******************************************************
                section .bank3.rtable
                include "rtable.asm"

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

; Above this point, all addresses must match between banks

; *******************************************************
; * Bank specific code
; *******************************************************
                section .bank3.text

; *******************************************************
; * Bank init/test
; *******************************************************
bank_init:
                        lda     #<EBANK
                        ldx     #>EBANK
                        jsr     PRINT_SZ
                        rts

; *******************************************************
; * include common routines
; *******************************************************
                include "routines.asm"

; *******************************************************
; * Readonly data
; *******************************************************
                section .bank3.rodata

EBANK                   db      $1B, "[0;37m    Bank   #3 ", $1B, "[1;32mpassed", $1B, "[0m (unused)", $D, $A, 0
