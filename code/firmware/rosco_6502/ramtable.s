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
                .assert (vector-RAMVECT)=(*-RAMTABLE), warning, .sprintf("%s not #%d", .string(vector), (vector-RAMVECT)/3)
                .if CUR_ROMBANK=0
;                        .export  vector
                .endif
                .local  vecbeg
                vecbeg  =       *
                       	code
                .res    3-(*-vecbeg),$60
                .endmacro

                .segment "VECINIT"
RAMTABLE:
                        ; unknown ROM bank mapped, so use ROMTABLE for ROM functions
                        ramvec  PRINTCHAR,      {jmp UART_A_SEND}
                        ramvec  INPUTCHAR,      {jmp UART_A_RECV}
                        ramvec  CHECKINPUT,     {jmp UART_A_STAT}
                        ramvec  CLRSCR,         {rts}
                        ramvec  MOVEXY,         {rts}
                        ramvec  SETCURSOR,      {rts}
			ramvec  USER_TICK,      {rts}
			ramvec  NMI_INTR,       {rti}

                .segment "THUNKINIT"
;
; RAM thunk to call ROM0 routine from another ROM bank
; A X Y C passed in, A X Y C returned
;         sty     FW_ZP_BANKTEMP        ; Y to pass in
;         ldy     #<ROM_routine         ; low byte of ROMTABLE addr
;         jmp     THUNK_ROM0
;
                .export _THUNK_ROM0
_THUNK_ROM0:
                        sty     @jsrmod+1
                        ldy     BANK_SET
                        phy
                        stz     BANK_SET
                        ldy     FW_ZP_BANKTEMP
@jsrmod:                jsr     ROMTABLE            ; only low modified!
                        sty     FW_ZP_BANKTEMP
                        ply
                        sty     BANK_SET
                        ldy     FW_ZP_BANKTEMP
                        rts

                        .res    3
;
; RAM thunk to call routine with specific RAM/ROM banking
;
;       pha                             ; A to pass in
;       phx                             ; X to pass in
;       sty     FW_ZP_BANKTEMP          ; Y to pass in
;       lda     #<function              ; routine L
;       ldx     #>function              ; routine H
;       ldy     #bank                   ; routine bank
;       jmp     THUNK_BANK
;
                .assert (*-_THUNK_ROM0)=(THUNK_BANK-THUNK_ROM0), warning, "_THUNK_BANK mismatch"
                .export _THUNK_BANK
_THUNK_BANK:
                        sta     @jsrmod+1
                        stx     @jsrmod+2
                        lda     BANK_SET
                        pha
                        sty     BANK_SET
                        ldy     FW_ZP_BANKTEMP
@jsrmod:                jsr     $FFFF
                        sty     FW_ZP_BANKTEMP
                        ply
                        sty     BANK_SET
                        ldy     FW_ZP_BANKTEMP
                        rts
;
; RAM thunk to call routine with specific RAM/ROM banking (trashes Y)
;
; pha
; phx
; lda     #<function
; ldx     #>function
; ldy     #bank
; jmp     THUNK_BANK
;
                .assert (*-_THUNK_ROM0)=(THUNK_BANKFAST-THUNK_ROM0), warning, "_THUNK_BANKFAST mismatch"
                .export _THUNK_BANKFAST
_THUNK_BANKFAST:
                        sta     @jsrmod+1
                        stx     @jsrmod+2
                        lda     BANK_SET
                        pha
                        sty     BANK_SET
@jsrmod:                jsr     $FFFF
                        ply
                        sty     BANK_SET
                        rts
