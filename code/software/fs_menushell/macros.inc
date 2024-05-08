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
; Filesystem menu and shell
;------------------------------------------------------------

                .macpack generic
                .macpack longbranch

.macro                  jra     dest
                .if     .def(dest) .and ((*+2)-(dest) <= 127)
                        bra     dest
                .else
                        jmp     dest
                .endif
.endmacro

; load AX (L/H)
.macro                  LDAX    arg
                .if (.match (.left (1, {arg}), #))
                        lda     #<(.right (.tcount ({arg})-1, {arg}))
                        ldx     #>(.right (.tcount ({arg})-1, {arg}))
                .else
                        lda     arg
                        ldx     1+(arg)
                .endif
.endmacro

; store YX (L/H) dest
.macro                  STAX    arg
                        sty     arg
                        stx     1+(arg)
.endmacro

; debug break or stop (for emulator)
.macro                  DBRK
        	.if     DEBUG
                	stp
        	.else
                	brk
        	.endif
.endmacro

; increment word
.macro INCW             addr
        	.local  @skiphi
                	inc     addr
                	bne     @skiphi
                	inc     1+(addr)
@skiphi:
.endmacro
;       ADDW    A,dptr
;       ADDW    Y,dptr
;       ADDW    X,dptr
;       ADDW    #0,dptr
;       ADDW    #1,dptr
;       ADDW    #$0034,dptr
;       ADDW    #$1200,dptr
;       ADDW    #$1234,dptr
;       ADDW    sptr,dptr

.macro ADDW             arg,dest
                .local  @skiphi
                .if (.match (.left (1, {arg}), A)) .or (.match (.left (1, {arg}), a))           ; add A
                        clc
                        adc     dest
                        sta     dest
                        bcc     @skiphi
                        inc     1+(dest)
                .elseif (.match (.left (1, {arg}), X)) .or (.match (.left (1, {arg}), x))       ; add X
                        txa
                        clc
                        adc     dest
                        sta     dest
                        bcc     @skiphi
                        inc     1+(dest)
                .elseif (.match (.left (1, {arg}), Y)) .or (.match (.left (1, {arg}), y))       ; add Y
                        tya
                        clc
                        adc     dest
                        sta     dest
                        bcc     @skiphi
                        inc     1+(dest)
                .elseif (.match (.left (1, {arg}), #))
                  ; ADDW #$XXXX,mem
                  .if .const((.right (.tcount ({arg})-1, {arg}))) .and (.right (.tcount ({arg})-1, {arg}))=0            ; ADDW #0
                        .out    "NOTE: macro ADDW #0 has no effect"
                  .elseif .const((.right (.tcount ({arg})-1, {arg}))) .and (.right (.tcount ({arg})-1, {arg}))=1        ; ADDW #1
                        inc     dest
                        bne     @skiphi
                        inc     1+(dest)
                  .else
                    .if .const((.right (.tcount ({arg})-1, {arg}))) .and .lobyte((.right (.tcount ({arg})-1, {arg})))<>0 ; ADDW #$??xx
                        lda     dest
                        clc
                        adc     #<((.right (.tcount ({arg})-1, {arg})))
                        sta     dest
                    .endif
                      ; hibyte
                    .if .const((.right (.tcount ({arg})-1, {arg}))) .and .hibyte((.right (.tcount ({arg})-1, {arg})))=0         ; ADDW #$00??
                        bcc     @skiphi
                        inc     1+(dest)
                    .else                                                                                                       ; ADDW #$xx??
                        lda     1+(dest)
                        adc     #>((.right (.tcount ({arg})-1, {arg})))
                        sta     1+(dest)
                    .endif
                  .endif
                .else
                  ; ADDW mem,mem
                        lda     dest
                        clc
                        adc     arg
                        sta     dest
                        lda     1+(dest)
                        adc     1+(arg)
                        sta     1+(dest)
                .endif
@skiphi:
.endmacro

;
; MOVW - move word arg to dest
;        arg can be immediate value/addr or zp/abs address (use #sym for immediate)
;
; Uses A, unless #0
;
; examples:
;       MOVW    #buffer,ptr
;       MOVW    #$1234,sym
;       MOVW    sym1,sym2
;
.macro MOVW arg,dest
                .if (.match (.left (1, {arg}), #))
                ; #arg immediate
                .if .const((.right (.tcount ({arg})-1, {arg}))) .and .lobyte((.right (.tcount ({arg})-1, {arg})))=0
                        stz dest
                .else
                        lda #<((.right (.tcount ({arg})-1, {arg})))
                        sta dest
                .endif
                .if .const((.right (.tcount ({arg})-1, {arg}))) .and .hibyte((.right (.tcount ({arg})-1, {arg})))=0
                        stz 1+(dest)
                .else
                        .if (.not .const((.right (.tcount ({arg})-1, {arg})))) .or (>((.right (.tcount ({arg})-1, {arg}))))<>(<((.right (.tcount ({arg})-1, {arg}))))
                                lda #>((.right (.tcount ({arg})-1, {arg})))
                        .endif
                        sta 1+(dest)
                .endif
                .else
                ; arg address
                        lda arg
                        sta dest
                        lda 1+(arg)
                        sta 1+(dest)
                .endif
.endmacro

.macro                  PRPTR msg
                        lda     #<msg
                        ldx     #>msg
                        jsr     PRINT
.endmacro

.macro                  PRMSG   mesg
                .local  @maddr
                        lda     #<@maddr
                        ldx     #>@maddr
                        jsr     PRINT
                .pushseg
                .rodata
@maddr:                 .asciiz mesg
                .popseg
.endmacro
