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

                include "defines.asm"

        if      1
PRINT           macro   msg
                lda     #<\msg
                ldx     #>\msg
                jsr     PRINT_SZ
                endm

PRINTR          macro   msg
                lda     #<\msg
                ldx     #>\msg
                jmp     PRINT_SZ
                endm
        else
PRINT           macro   msg
                endm
PRINTR          macro   msg
                rts
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
                jsr     sd_init
                jsr     res_msg
                bcc     .sdinitgood
                rts
.sdinitgood

                PRINT   FAT32INIT
                jsr     fat32_init
                jsr     res_msg
                bcc     .fatinitgood
                lda     fat32_errorstage
                jsr     outbyte
                rts
.fatinitgood


                PRINT   FAT32OPENROOT
                jsr     fat32_openroot
                jsr     res_msg

                jsr     showdir

                PRINT   FAT32OPENROOT
                jsr     fat32_openroot
                jsr     res_msg

                PRINT   FAT32FINDDIRENT
                lda     #'"'
                jsr     COUT
                PRINT   subdirname
                lda     #'"'
                jsr     COUT
                ; Find subdirectory by name
                ldx     #<subdirname
                ldy     #>subdirname
                jsr     fat32_finddirent
                php
                jsr     res_msg
                plp
                bcs     .fnf

                ; open dir
                PRINT   FAT32OPENDIRENT
                jsr     fat32_opendirent
                jsr     res_msg

                jsr     showdir

                PRINT   FAT32OPENROOT
                jsr     fat32_openroot
                jsr     res_msg

                PRINT   FAT32FINDDIRENT
                lda     #'"'
                jsr     COUT
                PRINT   subdirname
                lda     #'"'
                jsr     COUT
                ; Find subdirectory by name
                ldx     #<subdirname
                ldy     #>subdirname
                jsr     fat32_finddirent
                php
                jsr     res_msg
                plp
                bcs     .fnf

                PRINT   FAT32OPENDIRENT
                jsr     fat32_opendirent
                jsr     res_msg


                PRINT   FAT32FINDDIRENT
                lda     #'"'
                jsr     COUT
                PRINT   filename
                lda     #'"'
                jsr     COUT

                ; Find file by name
                ldx     #<filename
                ldy     #>filename
                jsr     fat32_finddirent
                php
                jsr     res_msg
                plp
                bcs     .fnf

                ; open file
                PRINT   FAT32OPENDIRENT
                jsr     fat32_opendirent
                jsr     res_msg


;                 PRINT   FAT32FILEREAD
;                 jsr     fat32_file_read
;                 jsr     res_msg

;                 lda     #<$1000
;                 sta     FW_ZP_TMPPTR
;                 lda     #>$1000
;                 sta     FW_ZP_TMPPTR+1

;                 lda     #$10
;                 sta     ZP_COUNT
;                 lda     #$00
;                 sta     ZP_COUNT+1

;                 jsr     examine

;                 ldy     #0
; .printloop      lda     $1000,y
;                 beq     .doneprint
;                 cmp     #$0A
;                 bne     .notlf
;                 LDA     #$0d
;                 jsr     COUT
;                 lda     #$0A
; .notlf          jsr     COUT
;                 iny
;                 bra     .printloop
; .doneprint

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

.eof
                PRINT   EOFMSG
.fnf
file2:

                bra     .byebye

                PRINT   FAT32OPENROOT
                jsr     fat32_openroot
                jsr     res_msg

                PRINT   NAMEMSG
                PRINT   subdirname2
                lda     #'"'
                jsr     COUT
                lda     #$0D
                jsr     COUT
                lda     #$0A
                jsr     COUT

                PRINT   FAT32FINDDIRENT
                lda     #'"'
                jsr     COUT
                PRINT   subdirname2
                lda     #'"'
                jsr     COUT
                ; Find subdirectory by name
                ldx     #<subdirname2
                ldy     #>subdirname2
                jsr     fat32_finddirent
                php
                jsr     res_msg
                plp
                bcs     .fnf2

                ; open dir
                PRINT   FAT32OPENDIRENT
                jsr     fat32_opendirent
                jsr     res_msg

                PRINT   LENMSG
                lda     fat32_bytesremaining+3
                jsr     outbyte
                lda     fat32_bytesremaining+2
                jsr     outbyte
                lda     fat32_bytesremaining+1
                jsr     outbyte
                lda     fat32_bytesremaining+0
                jsr     outbyte
                lda     #$0D
                jsr     COUT
                lda     #$0A
                jsr     COUT

                PRINT   NAMEMSG
                PRINT   filename2
                lda     #'"'
                jsr     COUT
                lda     #$0D
                jsr     COUT
                lda     #$0A
                jsr     COUT

                PRINT   FAT32FINDDIRENT
                lda     #'"'
                jsr     COUT
                PRINT   filename2
                lda     #'"'
                jsr     COUT
                ; Find file by name
                ldx     #<filename2
                ldy     #>filename2
                jsr     fat32_finddirent
                php
                jsr     res_msg
                plp
                bcs     .fnf2

                ; open file
                PRINT   FAT32OPENDIRENT
                jsr     fat32_opendirent
                jsr     res_msg

                PRINT   LENMSG
                lda     fat32_bytesremaining+3
                jsr     outbyte
                lda     fat32_bytesremaining+2
                jsr     outbyte
                lda     fat32_bytesremaining+1
                jsr     outbyte
                lda     fat32_bytesremaining+0
                jsr     outbyte
                lda     #$0D
                jsr     COUT
                lda     #$0A
                jsr     COUT

                lda     fat32_bytesremaining+0
                sta     ZP_COUNT
                lda     fat32_bytesremaining+1
                sta     ZP_COUNT+1

                PRINT   FAT32FILEREAD

                lda     #<$8000
                sta     fat32_address
                lda     #>$8000
                sta     fat32_address+1

                jsr     fat32_file_read
                jsr     res_msg

                lda     #<$8000
                sta     FW_ZP_TMPPTR
                lda     #>$8000
                sta     FW_ZP_TMPPTR+1

                jsr     examine

.fnf2           jmp     .byebye
; ***

;                 lda     #<128
;                 sta     benchcount
;                 lda     #>128
;                 sta     benchcount+1

;                 lda     #<12345
;                 sta     tempBinary
;                 lda     #>12345
;                 sta     tempBinary+1
;                 jsr     BinaryToDecimal
;                 lda     decimalResult+4
;                 ora     #"0"
;                 jsr     COUT
;                 lda     decimalResult+3
;                 ora     #"0"
;                 jsr     COUT
;                 lda     decimalResult+2
;                 ora     #"0"
;                 jsr     COUT
;                 lda     decimalResult+1
;                 ora     #"0"
;                 jsr     COUT
;                 lda     decimalResult+0
;                 ora     #"0"
;                 jsr     COUT

;                 sei
;                 stz     TICK100HZ
;                 stz     TICK100HZ+1
;                 stz     TICK100HZ+2
;                 cli
; .loop:

;                 ; lda     TICK100HZ
;                 ; jsr     outbyte
;                 ; lda     #" "
;                 ; jsr     COUT

;                 lda     #<$1000
;                 sta     FW_ZP_IOPTR
;                 lda     #>$1000
;                 sta     FW_ZP_IOPTR+1

; ;                PRINT   SDREAD
;                 jsr     sd_read_block
;                 php
; ;                jsr     res_msg

;                 inc     FW_ZP_BLOCKNUM
;                 bne     .secincdone
;                 inc     FW_ZP_BLOCKNUM+1
;                 bcc     .secincdone
;                 inc     FW_ZP_BLOCKNUM+2
;                 bne     .secincdone
;                 inc     FW_ZP_BLOCKNUM+3
; .secincdone
;                 plp
;                 bcs     .done
;                 jsr     CIN
;                 bcs     .done

;                 lda     benchcount
;                 bne     .declo
;                 lda     benchcount+1
;                 beq     .done
;                 dec     benchcount+1
; .declo          dec     benchcount
;                 jmp     .loop

; .done:
;                 sei

;                 PRINT   BENCHRES
;                 lda     TICK100HZ+2
;                 jsr     outbyte
;                 lda     TICK100HZ+1
;                 jsr     outbyte
;                 lda     TICK100HZ+0
;                 jsr     outbyte
;                 cli

.byebye:
                PRINTR   EXITMSG

res_msg:        bcc     ok_msg
                PRINT   ERRMSG
                sec
                rts
ok_msg:         PRINT   OKMSG
                clc
                rts


showdir         jsr     fat32_readdirent
                bcs     .donedir

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
        if 0
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
        else
                ldy     #$1c+3
                lda     (FW_ZP_IOPTR),y
                sta     print_dec_value+3
                ldy     #$1c+2
                lda     (FW_ZP_IOPTR),y
                sta     print_dec_value+2
                ldy     #$1c+1
                lda     (FW_ZP_IOPTR),y
                sta     print_dec_value+1
                ldy     #$1c+0
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

                lda     #" "
                jsr     COUT

                lda     fat32_lfnbuffer
                beq     .notlfn

                lda     #$22
                jsr     COUT

                lda     #<fat32_lfnbuffer
                ldx     #>fat32_lfnbuffer
                jsr     PRINT_SZ
                lda     #$22
                jsr     COUT
.notlfn
                lda     #$0D
                jsr     COUT
                lda     #$0A
                jsr     COUT

                ; lda     #<fat32_lfnbuffer
                ; sta     FW_ZP_TMPPTR
                ; lda     #>fat32_lfnbuffer
                ; sta     FW_ZP_TMPPTR+1

                ; lda     #$00
                ; sta     ZP_COUNT
                ; lda     #$01
                ; sta     ZP_COUNT+1

                ; jsr     examine

                bra     showdir

.donedir        rts

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

; from https://taywee.github.io/NerdyNights/nerdynights/numbers.html
BinaryToDecimal:
                lda     #$00
                sta     decimalResult+0
                sta     decimalResult+1
                sta     decimalResult+2
                sta     decimalResult+3
                sta     decimalResult+4
                ldx     #$10
BitLoop:
                asl     tempBinary+0
                rol     tempBinary+1
                ldy     decimalResult+0
                lda     BinTable, y
                rol     a
                sta     decimalResult+0
                ldy     decimalResult+1
                lda     BinTable, y
                rol     a
                sta     decimalResult+1
                ldy     decimalResult+2
                lda     BinTable, y
                rol     a
                sta     decimalResult+2
                ldy     decimalResult+3
                lda     BinTable, y
                rol     a
                sta     decimalResult+3
                rol     decimalResult+4
                dex
                bne     BitLoop
an_rts:                rts
BinTable:
                db      $00, $01, $02, $03, $04, $80, $81, $82, $83, $84

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

EXAMWIDTH       =       16
        global  examine
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

RUNMSG          asciiz  "SD Test running.", $D, $A
OKMSG           asciiz  " OK", $D, $A
ERRMSG          asciiz  " ERROR!", $D, $A
BENCHRES        asciiz  "64KB (128 sectors) 100Hz ticks: "
SDSTAT          asciiz  "sd_status:"
SDINIT          asciiz  "sd_init:"
SDREAD          asciiz  "sd_read_block:"
SDWRITE         asciiz  "sd_write_block:"
FAT32INIT       asciiz  "fat32_init:"
FAT32OPENROOT   asciiz  "fat32_openroot:"
FAT32FINDDIRENT asciiz  "fat32_finddirent:"
FAT32OPENDIRENT asciiz  "fat32_opendirent:"
FAT32FILEREAD   asciiz  "fat32_file_read:"
DISPFILE        asciiz  "Display text file:", $D,$A,$D,$A
NAMEMSG         asciiz  "NAME: ",$22
LENMSG          asciiz  "LENGTH: "
EOFMSG          asciiz  "<EOF>",$D, $A
VOLMSG          asciiz  " [VOL] "
DIRMSG          asciiz  " <DIR> "
FILEMSG         asciiz  "       "

EXITMSG         ascii   $D, $A, "Exit."
EOLMSG          asciiz  $D, $A

;subdirname      asciiz  "ADAFR~53   "
subdirname      asciiz  "Adafruit_ILI9341"
filename        asciiz  "library.properties"
subdirname2     asciiz  "ANOTHER_SUB"
filename2       asciiz  "VECTORS ASM"

print_dec_pad   db      0
print_dec_width db      8

; *******************************************************
; * Uninitialized data
; *******************************************************
                section  .bss
benchcount      ds      2
tempBinary      ds      2
decimalResult   ds      5
dummy           ds      1
print_dec_temp        ds      10
