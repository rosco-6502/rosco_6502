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

                ; rosco_6502 firmware definitions
                .include "defines.inc"

                .list   off
                .include "macros.inc"
                .list   on

DEBUG           =       1

                .import __BSS_RUN__
                .import __BSS_SIZE__

                .zeropage
sptr:                   .res    2
dptr:                   .res    2
cptr:                   .res    2
slen:                   .res    1
wordcount:              .res    2

; *******************************************************
; * Entry point for RAM code
; *******************************************************
                .code
                .global  _start
_start:
                        PRMSG   "rosco_6502: SD Card Menu - (c) 2024 Xark, MIT License\r\n"

                        MOVW    #__BSS_RUN__,dptr
                        LDAX    #__BSS_SIZE__
                        jsr     zeromem

                        jsr     BD_CTRL                 ; init SD card
                        bcc     @sdcardok
                        PRMSG   "No SDHC card detected.\r\n"
                        jcs     @byebye
@sdcardok:
                        jsr     FS_CTRL                 ; init FAT32
                        bcc     @promtloop

                        PRMSG   "No FAT32 partition found, error: "
                        jsr     printerr
                        jsr     crlf
                        jcs     @byebye
@promtloop:
                        PRMSG   "\r\n>"

                        LDAX    #INPUTBUF
                        LDY     #$FF
                        jsr     INPUTLINE

                        PRMSG   "Entered:"

                        LDAX    #INPUTBUF
                        jsr     PRINT
                        jsr     crlf

                        LDAX    #INPUTBUF
                        jsr     showdir

                .if 0

                        PRPTR FAT32OPENPATH
                        PRPTR testfile                ; show test filename
                        lda     #$0D
                        jsr     COUT
                        lda     #$0A
                        jsr     COUT

                        lda     #<testfile
                        ldx     #>testfile
                        jsr     FS_OPEN                 ; open filepath in A/X
                        bcs     @byebye

                        lda     FS_ZP_BYTESLEFT+3       ; show opened file size
                        jsr     PRHEX_U8
                        lda     FS_ZP_BYTESLEFT+2
                        jsr     PRHEX_U8
                        lda     FS_ZP_BYTESLEFT+1
                        jsr     PRHEX_U8
                        lda     FS_ZP_BYTESLEFT+0
                        jsr     PRHEX_U8

                        lda     FS_ZP_BYTESLEFT+3
                        sta     DWORD_VAL+3
                        lda     FS_ZP_BYTESLEFT+2
                        sta     DWORD_VAL+2
                        lda     FS_ZP_BYTESLEFT+1
                        sta     DWORD_VAL+1
                        lda     FS_ZP_BYTESLEFT+0
                        sta     DWORD_VAL+0

                        lda     #10
                        sta     PR_WIDTH
                        lda     #' '
                        sta     PR_PAD
                        jsr     PRDEC_U32

                        lda     #$D
                        jsr     COUT
                        lda     #$A
                        jsr     COUT
        .endif

        .if 0
                        PRPTR BENCHMSG

                        lda     #<$4000
                        sta     FS_ZP_ADDRPTR
                        lda     #>$4000
                        sta     FS_ZP_ADDRPTR+1

                        jsr     FS_READFILE             ; at $C000 ptr back to $4000 and inc bank (stops after bank 15)
                        jsr     res_msg

        .endif

                        bra     @byebye

@byebye:
                        PRPTR EXITMSG
                        rts

res_msg:                bcc     ok_msg
                        PRPTR ERRMSG
                        lda     FS_ZP_ERRORCODE
                        jsr     PRHEX_U8
bail:                   PRPTR EOLMSG
                        sec
                        rts
ok_msg:                 PRPTR OKMSG
                        clc
                        rts

;
; print ASCII file to terminal (dirent already open)
;
showfile:
                        PRPTR DISPFILE

@printloop:             jsr     FAT_READ
                        bcs     @eof
                        cmp     #$0A
                        bne     @notlf
                        LDA     #$0d
                        jsr     COUT
                        lda     #$0A
@notlf:                 jsr     COUT
                        bra     @printloop
@eof:                   PRPTR EOFMSG
                        rts

; hex dump with ASCII
; ptr = FW_ZP_TMPPTR, bytes wordcount

EXAMWIDTH               =       16
examine:
                        lda     FW_ZP_TMPPTR+1
                        jsr     PRHEX_U8
                        lda     FW_ZP_TMPPTR
                        jsr     PRHEX_U8
                        lda     #':'
                        jsr     COUT
                        lda     #' '
                        jsr     COUT
                        ldy     #0
@examhex:               lda     (FW_ZP_TMPPTR),y
                        jsr     PRHEX_U8
                        lda     #' '
                        jsr     COUT
                        iny
                        cpy     #EXAMWIDTH
                        bne     @examhex
                        ldy     #0
@examascii:             lda     (FW_ZP_TMPPTR),y        ;output characters
                        cmp     #' '
                        bcc     @exambad
                        cmp     #$80
                        bcc     @examok
@exambad:               lda     #'@'
@examok:                jsr     COUT
                        iny
                        cpy     #EXAMWIDTH
                        bne     @examascii
                        lda     #$0D
                        jsr     COUT
                        lda     #$0A
                        jsr     COUT
                        lda     FW_ZP_TMPPTR
                        clc
                        adc     #EXAMWIDTH
                        sta     FW_ZP_TMPPTR
                        lda     FW_ZP_TMPPTR+1
                        adc     #0
                        sta     FW_ZP_TMPPTR+1
                        lda     wordcount
                        sec
                        sbc     #EXAMWIDTH
                        sta     wordcount
                        lda     wordcount+1
                        sbc     #0
                        sta     wordcount+1
                        ora     wordcount
                        bne     examine
                        rts

                .include "showdir.s"
                .include "utility.s"

; *******************************************************
; * Initialized data
; *******************************************************
	                .rodata

OKMSG:                  .asciiz " OK\r\n"
NOSDMSG:                .asciiz "No SD card detected.\r\n"
ERRMSG:                 .asciiz " FAT32 ERROR="
DISPFILE:               .asciiz "Display text file:\r\n\r\n"
NAMEMSG:                .asciiz "NAME: \""
LENMSG:                 .asciiz "LENGTH: "
EOFMSG:                 .asciiz "<EOF>\r\n"
VOLMSG:                 .asciiz " [VOL] "
DIRMSG:                 .asciiz " <DIR> "
FILEMSG:                .asciiz "       "

EXITMSG:                .byte   "\r\nExit."
EOLMSG:                 .asciiz "\r\n"

BENCHMSG:       	.asciiz	"Reading 512KB into high-RAM banks...\r\n"

; test file path
testpath:               .asciiz "/"
testfile:               .asciiz "/Some Folder/Deep Folder/data512k.bin"

                        .bss
cur_dir:                .res    256
