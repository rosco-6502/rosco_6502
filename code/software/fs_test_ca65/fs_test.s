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
; Filesystem ROM call test
;------------------------------------------------------------

                .include "defines.inc"

ZP_COUNT        =       USER_ZP_START

        .if      1
.macro          PRINT   msg
                lda     #<msg
                ldx     #>msg
                jsr     PRINT
.endmacro

.macro          PRINTR  msg
                lda     #<msg
                ldx     #>msg
                jmp     PRINT
.endmacro
        .else
.macro          PRINT   msg
.endmacro
.macro          PRINTR  msg
                rts
.endmacro
        .endif

; *******************************************************
; * Entry point for RAM code
; *******************************************************
        .code
        .global  _start
_start:
                PRINT   RUNMSG

                PRINT   SDINIT
                jsr     sd_init                 ; init SD card
                bcc     @sdcardok
                PRINT   NOSDMSG
                bcs     bail
@sdcardok:
                PRINT   FAT32INIT
                jsr     fat32_init              ; init FAT32
                jsr     res_msg
                bcs     @byebye
@fatinitgood:
                lda     #<testpath
                ldx     #>testpath
                jsr     PRINT
                lda     #<testpath
                ldx     #>testpath
                jsr     fat32_openpath          ; open filepath in A/X
                bcs     @byebye
                jsr     showdir

                PRINT   FAT32OPENPATH
                PRINT   testfile                ; show test filename
                lda     #$0D
                jsr     COUT
                lda     #$0A
                jsr     COUT

                lda     #<testfile
                ldx     #>testfile
                jsr     fat32_openpath          ; open filepath in A/X
                bcs     @byebye

                lda     fat32_bytesremaining+3  ; show opened file size
                jsr     outbyte
                lda     fat32_bytesremaining+2
                jsr     outbyte
                lda     fat32_bytesremaining+1
                jsr     outbyte
                lda     fat32_bytesremaining+0
                jsr     outbyte

                lda     fat32_bytesremaining+3
                sta     print_dec_value+3
                lda     fat32_bytesremaining+2
                sta     print_dec_value+2
                lda     fat32_bytesremaining+1
                sta     print_dec_value+1
                lda     fat32_bytesremaining+0
                sta     print_dec_value+0

                lda     #10
                sta     print_dec_width
                lda     #' '
                sta     print_dec_pad
                jsr     print_dec

                lda     #$D
                jsr     COUT
                lda     #$A
                jsr     COUT

                PRINT   BENCHMSG

                lda     #<$4000
                sta     fat32_address
                lda     #>$4000
                sta     fat32_address+1

                jsr     fat32_file_read         ; at $C000 ptr back to $4000 and inc bank (stops after bank 15)
                jsr     res_msg

                bra     @byebye

@byebye:
                PRINT   EXITMSG
                rts

res_msg:        bcc     ok_msg
                PRINT   ERRMSG
                lda     fat32_errorcode
                jsr     outbyte
bail:           PRINT   EOLMSG
                sec
                rts
ok_msg:         PRINT   OKMSG
                clc
                rts

;
; print ASCII file to terminal (dirent already open)
;
showfile:
                PRINT   DISPFILE

@printloop:     jsr     FAT_READ
                bcs     @eof
                cmp     #$0A
                bne     @notlf
                LDA     #$0d
                jsr     COUT
                lda     #$0A
@notlf:         jsr     COUT
                bra     @printloop
@eof:           PRINT   EOFMSG
                rts

;
; show disk directory (open root or dirent first)
;
showdir:        jsr     FAT_READDIRENT
                bcc     @noerror

                PRINT   ERRMSG;
                bra     @donedir

@noerror:       cmp     #$ff
                beq     @donedir

                bit     #$06            ; skip hidden/system
                bne     showdir

                pha
                jsr     outbyte
                pla

                bit     #$08
                beq     @notvol
                PRINT   VOLMSG
                bra     @prsize
@notvol:        bit     #$10
                beq     @notdir
                PRINT   DIRMSG
                bra     @prsize
@notdir:        PRINT   FILEMSG

@prsize:
        .if 0    ; hex size
                ldy     #$1c+3
                lda     (FW_ZP_IOPTR),y
                jsr     outbyte
                ldy     #$1c+2
                lda     (FW_ZP_IOPTR),y
                jsr     outbyte
                ldy     #$1c+1
                lda     (FW_ZP_IOPTR),y
                jsr     outbyte
                ldy     #$1c+0
                lda     (FW_ZP_IOPTR),y
                jsr     outbyte
        .else    ; decimal size
                ldy     #$1c+3
                lda     (FW_ZP_IOPTR),y
                sta     print_dec_value+3
                dey
                lda     (FW_ZP_IOPTR),y
                sta     print_dec_value+2
                dey
                lda     (FW_ZP_IOPTR),y
                sta     print_dec_value+1
                dey
                lda     (FW_ZP_IOPTR),y
                sta     print_dec_value+0

                lda     #10
                sta     print_dec_width
                lda     #' '
                sta     print_dec_pad
                jsr     print_dec
        .endif
@prname:
                lda     #' '
                jsr     COUT
        .if 0    ; also show SFN
                lda     #'"'
                jsr     COUT
                ldy     #0
@showname:      lda     (FW_ZP_IOPTR),y
                jsr     COUT
                iny
                cpy     #8
                bne     @showname
                lda     #'.'
                jsr     COUT
@showname2:     lda     (FW_ZP_IOPTR),y
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
                lda     #$0D
                jsr     COUT
                lda     #$0A
                jsr     COUT

                bra     showdir

@donedir:        rts

; hex dump with ASCII
; ptr = FW_ZP_TMPPTR, bytes ZP_COUNT

EXAMWIDTH       =       16
examine:
                lda     FW_ZP_TMPPTR+1
                jsr     outbyte
                lda     FW_ZP_TMPPTR
                jsr     outbyte
                lda     #':'
                jsr     COUT
                lda     #' '
                jsr     COUT
                ldy     #0
@examhex:       lda     (FW_ZP_TMPPTR),y
                jsr     outbyte
                lda     #' '
                jsr     COUT
                iny
                cpy     #EXAMWIDTH
                bne     @examhex
                ldy     #0
@examascii:     lda     (FW_ZP_TMPPTR),y        ;output characters
                cmp     #' '
                bcc     @exambad
                cmp     #$80
                bcc     @examok
@exambad:       lda     #'@'
@examok:        jsr     COUT
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
                lda     ZP_COUNT
                sec
                sbc     #EXAMWIDTH
                sta     ZP_COUNT
                lda     ZP_COUNT+1
                sbc     #0
                sta     ZP_COUNT+1
                ora     ZP_COUNT
                bne     examine
                rts

; *******************************************************
; * Initialized data
; *******************************************************
	.rodata

RUNMSG:                 .asciiz "SD Test running.\r\n"
OKMSG:                  .asciiz " OK\r\n"
NOSDMSG:                .asciiz "No SD card detected.\r\n"
ERRMSG:                 .asciiz " FAT32 ERROR="
SDINIT:                 .asciiz "sd_init:"
FAT32INIT:              .asciiz "fat32_init:"
FAT32OPENPATH:          .asciiz "fat32_openpath:"
FAT32FILEREAD:          .asciiz "fat32_file_read:"
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
