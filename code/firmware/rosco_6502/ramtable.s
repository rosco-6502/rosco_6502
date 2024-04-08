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
THUNK_ROM0:
                        ldy     BANK_SET
                        sty     THUNK_ROM0_BANKSAVE
                        stz     BANK_SET
THUNK_ROM0_MODRTBL      =       *+1                       
                        jsr     ROMTABLE+$00    ; THUNK_ROM0_MODRTBL modified
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
; THUNK_BANK_FUNCADDR   = address of routine
;
THUNK_BANK:
                        phy
                        ldy     BANK_SET
                        sty     THUNK_BANK_BANKSAVE
THUNK_BANK_BANKSET      =       *+1                       
                        ldy     #$FF            ; THUNK_BANK_BANKSET modified
                        sty     BANK_SET
                        ply
THUNK_BANK_FUNCADDR     =       *+1                       
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
; THUNK_BANKFAST_FUNCADDR   = address of routine
;
THUNK_BANKFAST:
                        ldy     BANK_SET
                        phy
THUNK_BANKFAST_BANKSET  =       *+1                       
                        ldy     #$FF            ; THUNK_BANKFAST_BANKSET modified
                        sty     BANK_SET
THUNK_BANKFAST_FUNCADDR =       *+1                       
                        jsr     $FFFF           ; THUNK_BANKFAST_FUNCADDR modified (two bytes)
                        ply
                        sty     BANK_SET
                        rts

                        .res    3               ; pad
