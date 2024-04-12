; vim: set et ts=8 sw=8
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

                .include "defines.inc"

ZP_COUNT        =       USER_ZP_START

        .if      1
.macro          PRINT   msg
                lda     #<msg
                ldx     #>msg
                jsr     PRINT
.endmacro

.macro          PRINTR  msg
                lda     #<msg
                ldx     #>msg
                jmp     PRINT
.endmacro
        .else
.macro          PRINT   msg
.endmacro
.macro          PRINTR  msg
                rts
.endmacro
        .endif

; *******************************************************
; * Entry point for RAM code
; *******************************************************
        .segment "CODE"

        .global  _start
_start:
                PRINT   RUNMSG

                PRINT   ENTERMSG

                ldx     #0
@clr:           stz     INPUTBUF,x
                inx
                bne     @clr


; @echo:        JSR     INPUTCHAR
;               JSR     PRINTCHAR
;               bra     @echo

                lda     #<INPUTBUF
                ldx     #>INPUTBUF
                ldy     #10
;               jsr     readlinz
                jsr     READLINE
                tya
                jsr     PRBYTE

                PRINT   OUTMSG

                lda     #<INPUTBUF
                ldx     #>INPUTBUF
                jsr     PRINT

byebye:
                PRINTR   EXITMSG

; *******************************************************
; * Initialized data
; *******************************************************
        .segment "RODATA"

RUNMSG:         .byte   "Message Test Running.", $D, $A, 0

ENTERMSG:       .byte   "Enter message :", 0

OUTMSG:         .byte   $D, $A, "Entered :", 0

EXITMSG:        .byte   $D, $A, "Exit."
EOLMSG:         .byte   $D, $A, 0
