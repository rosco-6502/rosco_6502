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

ZP_COUNT        =       USER_ZP_START

        if      1
PRINT           macro   msg
                lda     #<\msg
                ldx     #>\msg
                jsr     PRINT_SZ
                endm

PRINTR          macro   msg
                lda     #<\msg
                ldx     #>\msg
                jmp     PRINT_SZ
                endm
        else
PRINT           macro   msg
                endm
PRINTR          macro   msg
                rts
                endm
        endif

; *******************************************************
; * Entry point for RAM code
; *******************************************************
        section .text

        global  _start

_start:
                PRINT   RUNMSG
.byebye:
                PRINTR   EXITMSG

                global  outbyte
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
                section  .rodata

RUNMSG          asciiz  "Message Test Running.", $D, $A

                incbin  "/Users/kenj/Dev/Rosco_Dev/rosco_6502/code/firmware/firstboot/wozmon.asm"

EXITMSG         ascii   $D, $A, "Exit."
EOLMSG          asciiz  $D, $A
