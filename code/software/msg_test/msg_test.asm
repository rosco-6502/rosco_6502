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

                include "defines.inc"

ZP_COUNT        =       USER_ZP_START

        if      1
PRINT           macro   msg
                lda     #<\msg
                ldx     #>\msg
                jsr     PRINT
                endm

PRINTR          macro   msg
                lda     #<\msg
                ldx     #>\msg
                jmp     PRINT
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

		PRINT	ENTERMSG

		ldx	#0
.clr:		stz	INPUTBUF,x
		inx
		bne	.clr


; .echo:		JSR	INPUTCHAR
; 		JSR	PRINTCHAR
; 		bra	.echo

		lda	#<INPUTBUF
		ldx	#>INPUTBUF
		ldy	#10
;		jsr	readlinz
		jsr	READLINE
		tya
		jsr	outbyte

		PRINT	OUTMSG

		lda	#<INPUTBUF
		ldx	#>INPUTBUF
		jsr	PRINT

byebye:
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

ENTERMSG        asciiz  "Enter message :"

OUTMSG       	asciiz  $D, $A, "Entered :"

EXITMSG         ascii   $D, $A, "Exit."
EOLMSG          asciiz  $D, $A
