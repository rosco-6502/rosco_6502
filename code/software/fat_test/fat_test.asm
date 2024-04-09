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
; Initial bringup and basic testing code for the board.
;------------------------------------------------------------

                include "defines.inc"

        if      1
PRINT           macro   msg
                lda     #<\msg
                ldx     #>\msg
                jsr     PRINT
                endm

        else
PRINT           macro   msg
                endm
        endif

                global ZP_COUNT

        dsect
                org     USER_ZP_START
ZP_COUNT        ds      2
print_dec_value ds      4
        dend


; *******************************************************
; * Entry point for RAM code
; *******************************************************
        section .text

        global  _start

_start:
                PRINT   RUNMSG

                PRINT   SDINIT
                jsr     sd_init                 ; init SD card
                bcc     .sdcardok
                PRINT   NOSDMSG
                bcs     bail
.sdcardok
                PRINT   FAT32INIT
                jsr     fat32_init              ; init FAT32
                jsr     res_msg
                bcs     .byebye
.fatinitgood
                lda     #<testpath
                ldx     #>testpath
                jsr     PRINT
                lda     #<testpath
                ldx     #>testpath
                jsr     fat32_openpath          ; open filepath in A/X
                bcs     .byebye
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
                bcs     .byebye

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
                lda     #" "
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

                bra     .byebye

.byebye:
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
showfile
                PRINT   DISPFILE

.printloop      jsr     fat32_file_readbyte
                bcs     .eof
                cmp     #$0A
                bne     .notlf
                LDA     #$0d
                jsr     COUT
                lda     #$0A
.notlf          jsr     COUT
                bra     .printloop
.eof            PRINT   EOFMSG
                rts

;
; show disk directory (open root or dirent first)
;
showdir         jsr     fat32_readdirent
                bcc     .noerror

                PRINT   ERRMSG;
                bra     .donedir

.noerror        cmp     #$ff
                beq     .donedir

                bit     #$06            ; skip hidden/system
                bne     showdir

                pha
                jsr     outbyte
                pla

                bit     #$08
                beq     .notvol
                PRINT   VOLMSG
                bra     .prsize
.notvol         bit     #$10
                beq     .notdir
                PRINT   DIRMSG
                bra     .prsize
.notdir         PRINT   FILEMSG

.prsize
        if 0    ; hex size
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
        else    ; decimal size
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
                lda     #" "
                sta     print_dec_pad
                jsr     print_dec
        endif
.prname
                lda     #" "
                jsr     COUT
        if 0    ; also show SFN
                lda     #'"'
                jsr     COUT
                ldy     #0
.showname       lda     (FW_ZP_IOPTR),y
                jsr     COUT
                iny
                cpy     #8
                bne     .showname
                lda     #"."
                jsr     COUT
.showname2      lda     (FW_ZP_IOPTR),y
                jsr     COUT
                iny
                cpy     #11
                bne     .showname2
                lda     #'"'
                jsr     COUT
        endif
                lda     #" "
                jsr     COUT

                lda     fat32_lfnbuffer
                beq     .notlfn

                lda     #$22
                jsr     COUT

                lda     #<fat32_lfnbuffer
                ldx     #>fat32_lfnbuffer
                jsr     PRINT
                lda     #$22
                jsr     COUT
.notlfn
                lda     #$0D
                jsr     COUT
                lda     #$0A
                jsr     COUT

                bra     showdir

.donedir        rts

; outbyte - print byte in A in hex
;

                global  outbyte
outbyte:        php
                pha
                jsr     outbyte2
                pla
                plp
                rts
outbyte2:       pha                     ; save a for lsd.
                lsr
                lsr
                lsr                     ; msd to lsd position.
                lsr
                jsr     .prhex          ; output hex digit.
                pla                     ; restore a.
.prhex:         and     #$0f            ; mask lsd for hex print.
                ora     #'0'            ; add "0".
                cmp     #$3a            ; digit?
                bcc     .echo           ; yes, output it.
                adc     #$06            ; add offset for letter.
.echo:          jmp     COUT

; print_dec - print 32 bit number in decimal (with optional width padding)
;             based on very clever code from https://stardot.org.uk/forums/viewtopic.php?p=369724&sid=e71c30225371c64770ce43d15dea57f0#p369724
; print_dec_value - 32-bit number to print (will be destroyed)
; print_dec_pad - set to 0 for no leading padding or set to pad char (e.g., "0" or  " ")
; print_dec_width - set padded width (will be exceeded if number doesn't fit)
;
                global  print_dec
print_dec:
                lda     #$0
                tay
.calcloop       sta     print_dec_temp,y
                iny
                clv
                lda     #0
                ldx     #31
.loop           cmp     #5
                bcc     .skip
                sbc     #5+128
                sec
.skip           rol     print_dec_value
                rol     print_dec_value+1
                rol     print_dec_value+2
                rol     print_dec_value+3
                rol
                dex
                bpl     .loop
                bvs     .calcloop
                sta     print_dec_temp,y
                tya
                tax
                lda     print_dec_pad
                beq     .printloop2
.printloop0     cpx     print_dec_width
                bge     .printloop2
                jsr     COUT
                inx
                bra     .printloop0
.printloop2     lda     print_dec_temp,y
                eor     #"0"
                jsr     COUT
                dey
                bne    .printloop2
                rts

; hex dump with ASCII
; ptr = FW_ZP_TMPPTR, bytes ZP_COUNT
        global  examine
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
.examhex:       lda     (FW_ZP_TMPPTR),y
                jsr     outbyte
                lda     #' '
                jsr     COUT
                iny
                cpy     #EXAMWIDTH
                bne     .examhex
                ldy     #0
.examascii:     lda     (FW_ZP_TMPPTR),y        ;output characters
                cmp     #' '
                bcc     .exambad
                cmp     #$80
                bcc     .examok
.exambad:       lda     #'.'
.examok:        jsr     COUT
                iny
                cpy     #EXAMWIDTH
                bne     .examascii
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
far             rts

; *******************************************************
; * Initialized data
; *******************************************************
                section  .rodata

RUNMSG                  asciiz  "SD Test running.", $D, $A
OKMSG                   asciiz  " OK", $D, $A
NOSDMSG                 asciiz  "No SD card detected.", $D, $A
ERRMSG                  asciiz  " FAT32 ERROR="
SDINIT                  asciiz  "sd_init:"
FAT32INIT               asciiz  "fat32_init:"
FAT32OPENPATH           asciiz  "fat32_openpath:"
FAT32FILEREAD           asciiz  "fat32_file_read:"
DISPFILE                asciiz  "Display text file:", $D,$A,$D,$A
NAMEMSG                 asciiz  "NAME: ",$22
LENMSG                  asciiz  "LENGTH: "
EOFMSG                  asciiz  "<EOF>",$D, $A
VOLMSG                  asciiz  " [VOL] "
DIRMSG                  asciiz  " <DIR> "
FILEMSG                 asciiz  "       "

EXITMSG                 ascii   $D, $A, "Exit."
EOLMSG                  asciiz  $D, $A

BENCHMSG		asciiz	"Reading 512KB into high-RAM banks...",$D,$A

; test file path
testpath                asciiz  "/"
testfile                asciiz  "/Some Folder/Deep Folder/data512k.bin"

print_dec_pad           db      0
print_dec_width         db      8

; *******************************************************
; * Uninitialized data
; *******************************************************
                section  .bss
benchcount              ds      2
tempBinary              ds      2
decimalResult           ds      5
dummy                   ds      1
print_dec_temp        ds      10
