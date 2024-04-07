; vim: set et ts=8 sw=8
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
;------------------------------------------------------------

; R_<routine>   = rtable.inc routine table index
; <routine>     = address of routine JMP in ROM table
; _<routine>    = default destination address (if dest not specified)
;
; ramvec <routine>[,<destaddr>]
.macro          ramvec vector, destaddr
                .assert .ident(.sprintf("V_%s", .string(vector)))=((*-RAMTABLE)/3), error, .sprintf("%s not at %d", .string(vector), ((*-RAMTABLE)/3))
                .if CUR_ROMBANK=0
                        .global  vector
                .endif
vector:
                .if .PARAMCOUNT=2
                       	jmp	destaddr
		.else
			rts
			nop
			nop
		.endif
                .endmacro

RAMTABLE:
                        ramvec  PRINTCHAR,_UART_A_SEND
                        ramvec  INPUTCHAR,_UART_A_RECV
                        ramvec  CHECKINPUT,_UART_A_STAT
                        ramvec  CLRSCR   
                        ramvec  MOVEXY   
                        ramvec  SETCURSOR
			ramvec  USER_TICK
;
; RAM thunk to call ROM0 from another ROM bank
;
THUNK_ROM0:
                        stz     BANK_SET
THUNK_ROM0_MODRTBL      :=      *+1                       
                        jsr     ROMTABLE+$00
                        php
THUNK_ROM0_MODBANK      :=      *+1                       
                        ldy     #$00
                        sty     BANK_SET
                        plp
                        rts
