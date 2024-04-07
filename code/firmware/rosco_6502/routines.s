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
; Common routines.
;
; These are pointed to by the routine table at the start
; of every bank, and must be included in each bank.
;
; The **don't** need to be at fixed addresses within the
; banks, since the routine table will point to them.
;------------------------------------------------------------

; call ROM0 function using thunk function (13 bytes overhead)
.macro          r0call  routine
.ident(.sprintf("_%s", .string(routine))):
                        ldy     BANK_SET
                        sty     THUNK_ROM0_MODBANK
                        ldy     #.ident(.sprintf("R_%s", .string(routine)))*3
                        sty     THUNK_ROM0_MODRTBL
                        jmp     THUNK_ROM0
.endmacro

; NOTE: To save size, UART A and B could be combined (with index)

; *******************************************************
; * Blocking output to DUART A. Character in A
; *******************************************************
_UART_A_SEND:
                        pha                     ; save character

@loop:                  lda     DUA_SRA         ; load UART A staus
                        and     #DUA_SR_TXRDY   ; check TXRDY bit
                        beq     @loop           ; loop if not ready (bit clear)

                        pla                     ; restore character
                        sta     DUA_TBA         ; send character to UART A
                        rts

; *******************************************************
; * Blocking output to DUART B. Character in A
; *******************************************************
_UART_B_SEND:
                        pha                     ; save character

@loop:                  lda     DUA_SRB         ; load UART B staus
                        and     #DUA_SR_TXRDY   ; check TXRDY bit
                        beq     @loop           ; loop if not ready (bit clear)

                        pla                     ; restore character
                        sta     DUA_TBB         ; send character to UART B
                        rts

; *******************************************************
; * Blocking input from DUART A. Character returned in A
; *******************************************************
_UART_A_RECV:
@loop:                  lda     DUA_SRA         ; load UART A status
                        ror                     ; check RXRDY bit 0 (shift into carry)
                        bcc     @loop           ; loop until a char is ready

                        lda     DUA_RBA         ; get UART A character
                        rts

; *******************************************************
; * Blocking input from DUART B. Character returned in A
; *******************************************************
_UART_B_RECV:
@loop:                  lda     DUA_SRB         ; load UART B status
                        ror                     ; check RXRDY bit 0 (shift into carry)
                        bcc     @loop           ; loop until a char is ready

                        lda     DUA_RBB         ; get UART B character
                        rts

; *******************************************************
; * Status for DUART A. if C=1 if Rx ready, A=0 if Tx not ready
; *******************************************************
_UART_A_STAT:
                        lda     DUA_SRA         ; load UART A status
                        ror                     ; check RXRDY bit 0 (C=RXRDY)
                        and     #DUA_SR_TXRDY>>1 ; isolate TXRDY bit (A=0 if TXRDY clear)
                        rts

; *******************************************************
; * Status for DUART B. if C=1 if Rx ready, A=0 if Tx not ready
; *******************************************************
_UART_B_STAT:
                        lda     DUA_SRB         ; load UART B status
                        ror                     ; check RXRDY bit 0 (C=RXRDY)
                        and     #DUA_SR_TXRDY>>1 ; isolate TXRDY bit (A=0 if TXRDY clear)
                        rts

; *******************************************************
; * Null-terminated string print
; *
; * Callable routine; A,X points to string (Low,High)
; * Trashes A, X
; *******************************************************
_PRINT:
                        phy
                        ldy     FW_ZP_TMPPTR
                        phy
                        ldy     FW_ZP_TMPPTR+1
                        phy
                        sta     FW_ZP_TMPPTR            ; ptr low
                        stx     FW_ZP_TMPPTR+1          ; ptr high
                        ldy     #$00                    ; Start at first character
@printloop:             lda     (FW_ZP_TMPPTR),Y        ; Get character into A
                        beq     @printdone              ; If it's zero, we're done..
                        jsr     PRINTCHAR               ; otherwise, print it
                        iny                             ; next character
                        bne     @printloop              ; and continue (unless Y wraps)
@printdone:             ply
                        sty     FW_ZP_TMPPTR+1
                        ply
                        sty     FW_ZP_TMPPTR+1
                        ply
                        rts

; *******************************************************
; * Null-terminated string print with EOL
; *
; * Callable routine; A,X points to string (Low,High)
; * Trashes A, X
; *******************************************************
_PRINTLN:
                        jsr     _PRINT
                        lda     #$0D
                        jsr     PRINTCHAR
                        lda     #$0A
                        jmp     PRINTCHAR

        .if CUR_ROMBANK<>0
; call ROM0 thunk for these routines (if not in ROM0)
                r0call  PRBYTE
                r0call  PRDEC32
                r0call  VT_CLRSCR
                r0call  VT_MOVEXY
        .else

; PRBYTE - Print A as two digit hex
; nothing trashed
_PRBYTE:                php
                        pha
                        jsr     @prhex2
                        pla
                        plp
                        rts
@prhex2:                pha                     ; save a for lsd.
                        lsr
                        lsr
                        lsr                     ; msd to lsd position.
                        lsr
                        jsr     @prhexdigit     ; output hex digit.
                        pla                     ; restore a.
@prhexdigit:            and     #$0f            ; mask lsd for hex print.
                        ora     #'0'            ; add "0".
                        cmp     #'9'+1          ; digit?
                        bcc     @echo           ; yes, output it.
                        adc     #$06            ; add offset for letter.
@echo:                  jmp     PRINTCHAR

; PRDEC32 - print unsigned 32 bit number in decimal (with optional width padding)
;           based on very clever code from TobyLobster/dp11 "ultra-compact version":
;           https://stardot.org.uk/forums/viewtopic.php?p=369724&sid=e71c30225371c64770ce43d15dea57f0#p369724
; DWORD_VAL - 32-bit number to print (will be destroyed)
; PRDEC_PAD - set to 0 for no leading padding or set to pad char (e.g., "0" or  " ")
; PRDEC_WIDTH - set padded width (will be exceeded if number doesn't fit)
;
_PRDEC32:
                        phy
                        phx
                        lda     #$0
                        tay
@calcloop:              sta     TEMPBUF16,y
                        iny
                        clv
                        lda     #0
                        ldx     #31
@loop:                  cmp     #5
                        bcc     @skip
                        sbc     #5+128
                        sec
@skip:                  rol     DWORD_VAL
                        rol     DWORD_VAL+1
                        rol     DWORD_VAL+2
                        rol     DWORD_VAL+3
                        rol
                        dex
                        bpl     @loop
                        bvs     @calcloop
                        sta     TEMPBUF16,y
                        tya
                        tax
                        lda     PRDEC_PAD
                        beq     @printloop2
@printloop0:            cpx     PRDEC_WIDTH
                        bge     @printloop2
                        jsr     PRINTCHAR
                        inx
                        bra     @printloop0
@printloop2:            lda     TEMPBUF16,y
                        ora     #'0'
                        jsr     PRINTCHAR
                        dey
                        bne     @printloop2
                        plx
                        ply
                        rts

; VT100 helpers
_VT_CLRSCR:
                        lda     #<VT100_CLRSCR
                        ldx     #>VT100_CLRSCR
                        jmp     _PRINT
_VT_MOVEXY:
                        phx
                        pha
                        lda     #<VT100_MOVEXY
                        ldx     #>VT100_MOVEXY
                        jsr     _PRINT
                        stz     PRDEC_PAD
                        stz     PRDEC_WIDTH
                        pla
                        jsr     @print_dec
                        lda     #';'
                        jsr     PRINTCHAR
                        pla
                        jsr     @print_dec
                        lda     #'H'
                        jmp     PRINTCHAR

@print_dec:             sta     DWORD_VAL0
                        stz     DWORD_VAL1
                        stz     DWORD_VAL2
                        stz     DWORD_VAL3
                        jsr     _PRDEC32
                        lda     #<TEMPBUF16
                        ldx     #<TEMPBUF16
                        jmp     _PRINT

_VT_SETCURSOR:
                        pha
                        lda     #<VT100_SETCURSOR
                        ldx     #>VT100_SETCURSOR
                        jsr     _PRINT
                        plx
                        lda     #'h'            ; show cursor
                        cpx     #0
                        bne     @cursorshow
                        lda     #'l'            ; hide cursor
@cursorshow:            jmp     PRINTCHAR

                .segment "RODATA0"
VT100_CLRSCR:           .byte   $1b,"[2J",0
VT100_MOVEXY:           .byte   $1b,"[",0
VT100_SETCURSOR:        .byte   $1b, "[?25",0 
                
        .endif