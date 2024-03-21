;------------------------------------------------------------
;                            ___ ___ ___ ___
;  ___ ___ ___ ___ ___      |  _| __|   |__ |
; |  _| . |_ -|  _| . |     | . |__ | | | __|
; |_| |___|___|___|___|_____|___|___|___|___|
;                     |_____|    Bringup Code
;------------------------------------------------------------
; Copyright (c)2022-2023 Ross Bamford and contributors
; See top-level LICENSE.md for licence information.
;
; Initial bringup and basic testing code for the board.
;------------------------------------------------------------

        include "defines.asm"

; *******************************************************
; * Entry point for RAM code
; *******************************************************
        section .text

_start:
                lda     #<TESTMSG
                ldx     #>TESTMSG
                jsr     PRINT_SZ

                lda     #$12
                jsr     outbyte
                lda     #$34
                jsr     outbyte
                brk
                rts

outbyte:        pha                     ; save a for lsd.
                lsr
                lsr
                lsr                     ; msd to lsd position.
                lsr
                jsr     .prhex          ; output hex digit.
                pla                     ; restore a.
.prhex:         and     #$0f            ; mask lsd for hex print.
                ora     #'0'            ; add "0".
                cmp     #$3a            ; digit?
                bcc     .echo           ; yes, output it.
                adc     #$06            ; add offset for letter.
.echo:          jmp     COUT

; *******************************************************
; * Initialized data
; *******************************************************
                section  .data

TESTMSG         asciiz  "RAM test okay.", $D, $A

; *******************************************************
; * Uninitialized data
; *******************************************************
                section  .bss

                ds      32
