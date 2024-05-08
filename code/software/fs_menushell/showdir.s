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
; Show FAT directory
;------------------------------------------------------------

;
; show disk directory (open root or dirent first)
;
showdir:
                        jsr     FS_OPEN                 ; open filepath in A/X
                        jcs     @errout
        
@dirent:                jsr     FAT_READDIRENT
                        bcc     @noerror

@errout:                jsr     perrmsg
                        jra     @donedir

@noerror:               cmp     #$ff
                        jeq     @donedir

                        bit     #$06            ; skip hidden/system
                        bne     @dirent

                        bit     #$08
                        beq     @notvol

                        PRMSG   "VOLUME:"
                        jra     @prname
;                        jsr     PRHEX_U8

@notvol:                bit     #$10
                        beq     @notdir
                        PRPTR DIRMSG
                        bra     @prsize
@notdir:                PRPTR FILEMSG

@prsize:
                        ldy     #$1c+3
                        lda     (FW_ZP_IOPTR),y
                        sta     DWORD_VAL+3
                        dey
                        lda     (FW_ZP_IOPTR),y
                        sta     DWORD_VAL+2
                        dey
                        lda     (FW_ZP_IOPTR),y
                        sta     DWORD_VAL+1
                        dey
                        lda     (FW_ZP_IOPTR),y
                        sta     DWORD_VAL+0

                        lda     #10
                        sta     PR_WIDTH
                        lda     #' '
                        sta     PR_PAD
                        jsr     PRDEC_U32
@prname:
        .if 0            ; also show SFN
                        lda     #' '
                        jsr     COUT
                        lda     #'"'
                        jsr     COUT
                        ldy     #0
@showname:              lda     (FW_ZP_IOPTR),y
                        jsr     COUT
                        iny
                        cpy     #8
                        bne     @showname
                        lda     #'.'
                        jsr     COUT
@showname2:             lda     (FW_ZP_IOPTR),y
                        jsr     COUT
                        iny
                        cpy     #11
                        bne     @showname2
                        lda     #'"'
                        jsr     COUT
        .endif
                        lda     #' '
                        jsr     COUT

                        lda     FILENAMEBUF
                        beq     @notlfn

                        lda     #$22
                        jsr     COUT

                        lda     #<FILENAMEBUF
                        ldx     #>FILENAMEBUF
                        jsr     PRINT
                        lda     #$22
                        jsr     COUT
@notlfn:
                        jsr     crlf
                        jra     @dirent

@donedir:               rts

perrmsg:
                        PRMSG   "\r\nError: "
                        jsr     printerr
                        jmp     crlf

printerr:
                        ldx     FS_ZP_ERRORCODE
                        lda     @erroff,x
                        clc
                        adc     #<@e
                        ldx     #>@e
                        bcc     @noecarry
                        inx
@noecarry:              jmp     PRINT

                .pushseg
                .rodata
@erroff:                .byte   @e-@e,@e1-@e,@e2-@e,@e3-@e,@e4-@e,@e5-@e,@e6-@e,@e7-@e,@e8-@e,@e9-@e,@e10-@e,@e11-@e
                .assert *-@erroff=FSERR_NUM_ERRORS,warning,"FSERR_NUM_ERRORS mismatch"
@e:                     .asciiz  "none"
@e1:                    .asciiz  "MBR"
@e2:                    .asciiz  "PARTITION"
@e3:                    .asciiz  "BADBPB"
@e4:                    .asciiz  "BADROOT"
@e5:                    .asciiz  "BADTOTALSEC"
@e6:                    .asciiz  "BADSECSIZE"
@e7:                    .asciiz  "MEDIAERR"
@e8:                    .asciiz  "BADPATH"
@e9:                    .asciiz  "NOTFOUND"
@e10:                   .asciiz  "EOF"
@e11:                   .asciiz  "TRUNCATED"
                .popseg