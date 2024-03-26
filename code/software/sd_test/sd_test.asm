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

ZP_COUNT        =       USER_ZP_START

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

; *******************************************************
; * Entry point for RAM code
; *******************************************************
        section .text

        global  _start

_start:
                PRINT   RUNMSG

                ; PRINT   SDSTAT
                ; jsr     sd_check_status
                ; php
                ; jsr     res_msg
                ; plp
;                bcc     .skip_init

                PRINT   SDINIT
                jsr     sd_init
                jsr     res_msg

.skip_init:     lda     #$E3
                ldx     #$00
.clr_block:     sta     $1000,x
                sta     $1100,x
                dex
                bne     .clr_block

        if 0

                lda     #<$1000
                sta     FW_ZP_TMPPTR
                lda     #>$1000
                sta     FW_ZP_TMPPTR+1

                lda     #$10
                sta     ZP_COUNT
                lda     #$00
                sta     ZP_COUNT+1

                jsr     examine
; 00 20 00 00
                lda     #$00
                sta     FW_ZP_BLOCKNUM
                lda     #$10
                sta     FW_ZP_BLOCKNUM+1
                lda     #$00
                sta     FW_ZP_BLOCKNUM+2
                lda     #$00
                sta     FW_ZP_BLOCKNUM+3

                lda     #<$1000
                sta     FW_ZP_IOPTR
                lda     #>$1000
                sta     FW_ZP_IOPTR+1

                PRINT   SDREAD
                jsr     sd_read_block
                jsr     res_msg

                lda     #<$1000
                sta     FW_ZP_TMPPTR
                lda     #>$1000
                sta     FW_ZP_TMPPTR+1

                lda     #$10
                sta     ZP_COUNT
                lda     #$00
                sta     ZP_COUNT+1

                jsr     examine

                PRINT   SDSTAT
                jsr     sd_check_status
                jsr     res_msg

                lda     #<$1000
                sta     FW_ZP_IOPTR
                lda     #>$1000
                sta     FW_ZP_IOPTR+1

                lda     #"X"
                sta     $1000
                lda     #"a"
                sta     $1001
                lda     #"r"
                sta     $1002
                lda     #"k"
                sta     $1003
                inc     $1004

                ; PRINT   SDWRITE
                ; jsr     sd_write_block
                ; jsr     res_msg

;                PRINT   SDSTAT
;                jsr     sd_check_status
;                jsr     res_msg

                lda     #<$1000
                sta     FW_ZP_IOPTR
                lda     #>$1000
                sta     FW_ZP_IOPTR+1

                PRINT   SDREAD
                jsr     sd_read_block
                jsr     res_msg

                PRINT   SDSTAT
                jsr     sd_check_status
                jsr     res_msg

                lda     #<$1000
                sta     FW_ZP_TMPPTR
                lda     #>$1000
                sta     FW_ZP_TMPPTR+1

                lda     #$10
                sta     ZP_COUNT
                lda     #$00
                sta     ZP_COUNT+1

                jsr     examine

                PRINT   SDSTAT
                jsr     sd_check_status
                jsr     res_msg

        endif

                lda     #0
                tax
.clrit          sta     $1000,x
                sta     $1100,x
                sta     $0400,X
                sta     $0500,x
                inx
                bne     .clrit

                PRINT   FAT32INIT
                jsr     fat32_init
                jsr     res_msg

;                lda     fat32_errorstage
;                jsr     outbyte

                PRINT   FAT32OPENROOT
                jsr     fat32_openroot
                jsr     res_msg

                lda     #'"'
                jsr     COUT
                PRINT   subdirname
                lda     #'"'
                jsr     COUT
                lda     #$0D
                jsr     COUT
                lda     #$0A
                jsr     COUT

                PRINT   FAT32FINDDIRENT
                ; Find subdirectory by name
                ldx     #<subdirname
                ldy     #>subdirname
                jsr     fat32_finddirent
                jsr     res_msg

                ; open dir
                PRINT   FAT32OPENDIRENT
                jsr     fat32_opendirent
                jsr     res_msg

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

                lda     #'"'
                jsr     COUT
                PRINT   filename
                lda     #'"'
                jsr     COUT
                lda     #$0D
                jsr     COUT
                lda     #$0A
                jsr     COUT

                PRINT   FAT32FINDDIRENT
                ; Find file by name
                ldx     #<filename
                ldy     #>filename
                jsr     fat32_finddirent
                jsr     res_msg

                ; open file
                PRINT   FAT32OPENDIRENT
                jsr     fat32_opendirent
                jsr     res_msg

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

                lda     #<$1000
                sta     fat32_address
                lda     #>$1000
                sta     fat32_address+1

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

file2:

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
                ; Find subdirectory by name
                ldx     #<subdirname2
                ldy     #>subdirname2
                jsr     fat32_finddirent
                jsr     res_msg

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
                ; Find file by name
                ldx     #<filename2
                ldy     #>filename2
                jsr     fat32_finddirent
                jsr     res_msg

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

                print   FAT32FILEREAD

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

                jmp     .byebye
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
                PRINTR   ERRMSG
ok_msg:         PRINTR   OKMSG

                global  outbyte
outbyte:        pha                     ; save a for lsd.
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
                bpl     examine
                rts

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
NAMEMSG         asciiz  "NAME: ",$22
LENMSG          asciiz  "LENGTH: "
EOFMSG          asciiz  $D, $A, "<EOF>",$D, $A

EXITMSG         ascii   $D, $A, "Exit."
EOLMSG          asciiz  $D, $A

subdirname      asciiz  "FOLDER     "
filename        asciiz  "FILE       "
subdirname2     asciiz  "ANOTHER_SUB"
filename2       asciiz  "VECTORS ASM"

; *******************************************************
; * Uninitialized data
; *******************************************************
                section  .bss
benchcount      ds      2
tempBinary      ds      2
decimalResult   ds      5
dummy           ds      1
