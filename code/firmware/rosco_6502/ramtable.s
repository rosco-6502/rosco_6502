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
                .assert (vector-RAMTABLE)=(*-_RAMTABLE), warning, .sprintf("%s not #%d", .string(vector), (vector-RAMTABLE)/3)
                .if CUR_ROMBANK=0
;                        .export  vector
                .endif
                .local  vecbeg
                vecbeg  =       *
                       	code
                .res    3-(*-vecbeg),$60
                .endmacro

                .segment "VECINIT"
_RAMTABLE:
                        ; unknown ROM bank mapped, so use _ROMTABLE for ROM functions
                        ramvec  PRINTCHAR,      { jmp   UART_A_SEND     }
                        ramvec  INPUTCHAR,      { jmp   UART_A_RECV     }
                        ramvec  CHECKINPUT,     { jmp   UART_A_STAT     }
                        ramvec  INPUTLINE,      { jmp   READLINE        }
                        ramvec  CLRSCR,         { jmp   CLRSCR          }
                        ramvec  MOVEXY,         { jmp   MOVEXY          }
                        ramvec  SETCURSOR,      { jmp   SETCURSOR       }
			ramvec  USER_TICK,      { rts }
			ramvec  NMI_INTR,       { rti } ; NOTE: Uses RTI not RTS
			ramvec  CD_CTRL,        { rts } ; TODO
			ramvec  CD_SENDCHAR,    { jmp   UART_B_SEND     }
			ramvec  CD_RECVCHAR,    { jmp   UART_B_RECV     }
			ramvec  CD_CHECKCHAR,   { jmp   UART_B_STAT     }
			ramvec  BD_CTRL,        { jmp   SD_CTRL         }
			ramvec  BD_READ,        { jmp   SD_READ         }
			ramvec  BD_WRITE,       { jmp   SD_WRITE        }
			ramvec  FS_CTRL,        { jmp   FAT_CTRL        }
			ramvec  FS_OPEN,        { jmp   FAT_OPEN        }
			ramvec  FS_READ,        { jmp   FAT_READ        }
			ramvec  FS_READDIRENT,  { jmp   FAT_READDIRENT  }
			ramvec  FS_SEEK,        { jmp   FAT_SEEK        }
			ramvec  FS_WRITE,       { jmp   FAT_WRITE       }
			ramvec  FS_CLOSE,       { jmp   FAT_CLOSE       }

; *******************************************************
; * Low-RAM thunk code (copied to RAM by system_reset)
; *******************************************************
                .segment "THUNKINIT"
;
; RAM thunk to call ROM0 routine from another ROM bank
; A X Y C passed in, A X Y C returned
;         sty     FW_ZP_BANKTEMP        ; Y to pass in
;         ldy     #<ROM_routine         ; low byte of _ROMTABLE addr
;         jmp     THUNK_ROM0
;
                .export _THUNK_ROM0
_THUNK_ROM0:
                        sty     @jsrmod+1
                        ldy     BANK_SET
                        phy
                        stz     BANK_SET
                        ldy     FW_ZP_BANKTEMP
@jsrmod:                jsr     _ROMTABLE               ; only low modified!
                        sty     FW_ZP_BANKTEMP
                        ply
                        sty     BANK_SET
                        ldy     FW_ZP_BANKTEMP
                        rts                             ; return to ROMTABLE caller

_BOOTSIG:               .byte   $55,$AA,$42             ; warm boot signature
; ;
; ; RAM thunk to call routine with specific RAM/ROM banking (~69 cycles overhead vs JSR)
; ;
; ;       pha                             ; 3 A to pass in
; ;       phx                             ; 3 X to pass in
; ;       sty     FW_ZP_BANKTEMP          ; 3 Y to pass in
; ;       lda     #<function              ; 2 routine L
; ;       ldx     #>function              ; 2 routine H
; ;       ldy     #bank                   ; 2 routine bank
; ;       jsr     THUNK_BANK              ; 6 jump to thunk
; ;
;                 .assert (*-_THUNK_ROM0)=(THUNK_BANK-THUNK_ROM0), warning, "_THUNK_BANK mismatch"
;                 .export _THUNK_BANK
; _THUNK_BANK:
;                         sta     @jsrmod+1               ; 4
;                         stx     @jsrmod+2               ; 4
;                         lda     BANK_SET                ; 3
;                         sty     BANK_SET                ; 3
;                         tay                             ; 2
;                         plx                             ; 4
;                         pla                             ; 4
;                         phy                             ; 3
;                         ldy     FW_ZP_BANKTEMP          ; 3
; @jsrmod:                jsr     $FFFF                   ; -
;                         sty     FW_ZP_BANKTEMP          ; 3
;                         ply                             ; 3
;                         sty     BANK_SET                ; 3
;                         ldy     FW_ZP_BANKTEMP          ; 3
;                         rts                             ; 6

;                         .res    3

; ;
; ; RAM thunk to call routine with specific RAM/ROM banking (trashes Y)
; ;
; ;       pha                             ; A to pass in
; ;       phx                             ; X to pass in
; ;       lda     #<function              ; routine L
; ;       ldx     #>function              ; routine H
; ;       ldy     #bank                   ; routine bank
; ;       jmp     _THUNK_BANKFAST         ; jump to thunk
; ;
;                 .assert (*-_THUNK_ROM0)=(THUNK_BANKFAST-THUNK_ROM0), warning, "_THUNK_BANKFAST mismatch"
;                 .export _THUNK_BANKFAST
; _THUNK_BANKFAST:
;                         sta     @jsrmod+1
;                         stx     @jsrmod+2
;                         lda     BANK_SET
;                         sty     BANK_SET
;                         tay
;                         plx
;                         pla
;                         phy
; @jsrmod:                jsr     $FFFF
;                         ply
;                         sty     BANK_SET
;                         rts
