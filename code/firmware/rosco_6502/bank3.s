; vim: set et ts=8 sw=8
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
CUR_ROMBANK     =       3       ; assemble for ROM bank 3

; *******************************************************
; * include system defines
; *******************************************************
                .include "defines.inc"
                .include "firmware.inc"

; *******************************************************
; * Include routine table for this bank
; *******************************************************
                .segment "ROMCOMMON3"
                .include "romtable.s"

; *******************************************************
; * Include IRQ handling for this bank
; *******************************************************
                .segment "ROMCOMMON3"
                .include "common.s"

; *******************************************************
; * Include vectors for this bank
; *******************************************************
                .segment "VECTORS3"
                .include "vectors.s"

; Above this point, all addresses must match between banks

; *******************************************************
; * Bank specific code
; *******************************************************
                .segment "ROM3"

; *******************************************************
; * Bank init/test
; *******************************************************
bank_init:
                        lda     #<EBANK
                        ldx     #>EBANK
                        jsr     _PRINT
                        rts

; *******************************************************
; * include common routines
; *******************************************************
                .include "routines.s"

; *******************************************************
; * Readonly data
; *******************************************************
                .segment "RODATA3"

EBANK:                  .byte   $1B, "[0;37m    Bank    #3 ", $1B, "[1;32mpassed", $1B, "[0m (unused)", $D, $A, 0
