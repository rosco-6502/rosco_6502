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
.macro          ramvec vector, code
                .assert (vector-RAMVECT)=(*-RAMTABLE), error, .sprintf("%s not #%d", .string(vector), (vector-RAMVECT)/3)
                .if CUR_ROMBANK=0
                        .global  vector
                .endif
                .local  vecbeg
                vecbeg  =       *
                .if .PARAMCOUNT=2
                       	code
                        .res    3-(*-vecbeg)
		.else
			rts
			nop
			nop
		.endif
                .endmacro

                .segment "VECINIT"
RAMTABLE:
                        ramvec  PRINTCHAR,      {jmp _UART_A_SEND}
                        ramvec  INPUTCHAR,      {jmp _UART_A_RECV}
                        ramvec  CHECKINPUT,     {jmp _UART_A_STAT}
                        ramvec  CLRSCR,         {rts}
                        ramvec  MOVEXY,         {rts}
                        ramvec  SETCURSOR,      {rts}
			ramvec  USER_TICK,      {rts}
			ramvec  NMI_INTR,       {rti}

                .segment "THUNKINIT"
;
; RAM thunk to call ROM0 routine with another ROM bank banked
;
; THUNK_ROM0_ROMADRL     = low byte of ROMTABLE function
;
_THUNK_ROM0:
                        phy
                        ldy     BANK_SET
                        sty     THUNK_ROM0_BANKSAVE
                        stz     BANK_SET
                        ply
_THUNK_ROM0_ROMADRL      =       *+1
        .global _THUNK_ROM0_ROMADRL
                .assert (*+1-_THUNK_ROM0)=(THUNK_ROM0_ROMADRL-THUNK_ROM0), error, "THUNK_ROM0_ROMADRL mismatch"
                        jsr     ROMTABLE+$00    ; THUNK_ROM0_ROMADRL modified
                        php
                        phy
THUNK_ROM0_BANKSAVE     =       *+1
                        ldy     #$FF            ; THUNK_ROM0_BANKSAVE modified
                        sty     BANK_SET
                        ply
                        plp
                        rts

                        .res    3               ; pad
;
; RAM thunk to call routine with specific RAM/ROM banking
;
; THUNK_BANK_BANKSET    = BANK_SET value for routine
; THUNK_BANK_FUNCADDR   = address of routine (two bytes)
;
                .assert (*-_THUNK_ROM0)=(THUNK_BANK-THUNK_ROM0), error, "_THUNK_BANK mismatch"
_THUNK_BANK:
                        phy
                        ldy     BANK_SET
                        sty     THUNK_BANK_BANKSAVE
_THUNK_BANK_BANKSET      =       *+1
                .assert (*+1-_THUNK_ROM0)=(THUNK_BANK_BANKSET-THUNK_ROM0), error, "THUNK_BANK_BANKSET mismatch"
                        ldy     #$FF            ; THUNK_BANK_BANKSET modified
                        sty     BANK_SET
                        ply
_THUNK_BANK_FUNCADDR     =       *+1
                .assert (*+1-_THUNK_ROM0)=(THUNK_BANK_FUNCADDR-THUNK_ROM0), error, "THUNK_BANK_FUNCADDR mismatch"
                        jsr     $FFFF           ; THUNK_BANK_FUNCADDR modified (two bytes)
                        php
                        phy
THUNK_BANK_BANKSAVE     =       *+1
                        ldy     #$00            ; THUNK_BANK_BANKSAVE modified
                        sty     BANK_SET
                        ply
                        plp
                        rts

                        .res    3               ; pad

;
; RAM thunk to call routine with specific RAM/ROM banking (trashes Y and P)
;
; THUNK_BANKFAST_BANKSET    = BANK_SET value for routine
; THUNK_BANKFAST_FUNCADDR   = address of routine (two bytes)
;
                .assert (*-_THUNK_ROM0)=(THUNK_BANKFAST-THUNK_ROM0), error, "_THUNK_BANKFAST mismatch"
_THUNK_BANKFAST:
                        ldy     BANK_SET
                        phy
_THUNK_BANKFAST_BANKSET  =       *+1
                .assert (*+1-_THUNK_ROM0)=(THUNK_BANKFAST_BANKSET-THUNK_ROM0), error, "THUNK_BANKFAST_BANKSET mismatch"
                        ldy     #$FF            ; THUNK_BANKFAST_BANKSET modified
                        sty     BANK_SET
_THUNK_BANKFAST_FUNCADDR =       *+1
                .assert (*+1-_THUNK_ROM0)=(THUNK_BANKFAST_FUNCADDR-THUNK_ROM0), error, "THUNK_BANKFAST_FUNCADDR mismatch"
                        jsr     $FFFF           ; THUNK_BANKFAST_FUNCADDR modified (two bytes)
                        ply
                        sty     BANK_SET
                        rts

                        .res    3               ; pad
