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

                PRINT   SDINIT
                jsr     sd_init
                jsr     res_msg

                lda     #$E3
                ldx     #$00
clr_block:      sta     $1000,x
                sta     $1100,x
                dex
                bne     clr_block

                ; lda     #<$1000
                ; sta     FW_ZP_PTR
                ; lda     #>$1000
                ; sta     FW_ZP_PTR+1

                ; lda     #$00
                ; sta     FW_ZP_COUNT
                ; lda     #$02
                ; sta     FW_ZP_COUNT+1

                ; jsr     examine
; 00 20 00 00
                lda     #$00
                sta     FW_ZP_BLOCKNUM
                lda     #$00
                sta     FW_ZP_BLOCKNUM+1
                lda     #$00
                sta     FW_ZP_BLOCKNUM+2
                lda     #$00
                sta     FW_ZP_BLOCKNUM+3
.loop:
                lda     #<$1000
                sta     FW_ZP_IOPTR
                lda     #>$1000
                sta     FW_ZP_IOPTR+1

                PRINT   SDREAD
                jsr     sd_read_block
                php
                jsr     res_msg

                inc     FW_ZP_BLOCKNUM
                bne     .secincdone
                inc     FW_ZP_BLOCKNUM+1
                bcc     .secincdone
                inc     FW_ZP_BLOCKNUM+2
                bne     .secincdone
                inc     FW_ZP_BLOCKNUM+3
.secincdone
                plp
                bcs     .done
                jsr     CIN
                bcc     .loop

.done:
                PRINTR   EXITMSG

res_msg:        bcc     ok_msg
                PRINTR   ERRMSG
ok_msg:         PRINTR   OKMSG

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

EXAMWIDTH       =       16

examine:
                
                lda     FW_ZP_PTR+1
                jsr     outbyte
                lda     FW_ZP_PTR
                jsr     outbyte
                lda     #':'
                jsr     COUT
                lda     #' '
                jsr     COUT
                ldy     #0
.examhex:       lda     (FW_ZP_PTR),y
                jsr     outbyte
                lda     #' '
                jsr     COUT
                iny
                cpy     #EXAMWIDTH
                bne     .examhex
                ldy     #0
.examascii:     lda     (FW_ZP_PTR),y	;output characters
                cmp     #' '
                bcc     .exambad
                cmp     #$80
                bcc     .examok
.exambad:       lda     #'.'
.examok:        jsr     COUT
                iny
                cpy     #EXAMWIDTH
                bne     .examascii
                lda     #$0D
                jsr     COUT
                lda     #$0A
                jsr     COUT
                lda     FW_ZP_PTR
                clc
                adc     #EXAMWIDTH
                sta     FW_ZP_PTR
                lda     FW_ZP_PTR+1
                adc     #0
                sta     FW_ZP_PTR+1
                lda     FW_ZP_COUNT
                sec
                sbc     #EXAMWIDTH
                sta     FW_ZP_COUNT
                lda     FW_ZP_COUNT+1
                sbc     #0
                sta     FW_ZP_COUNT+1
                ora     FW_ZP_COUNT
                bne     examine
                rts

; *******************************************************
; * Initialized data
; *******************************************************
                section  .rodata

RUNMSG          asciiz  "SD Test running.", $D, $A
OKMSG           asciiz  " OK", $D, $A
ERRMSG          asciiz  " ERROR!", $D, $A
SDINIT          asciiz  "sd_init:"
SDREAD          asciiz  "sd_read_block:"
EXITMSG         ascii   $D, $A, "Exit."
EOLMSG          asciiz  $D, $A

; *******************************************************
; * Uninitialized data
; *******************************************************
                section  .bss
