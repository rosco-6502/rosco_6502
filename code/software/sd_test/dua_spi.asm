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

; *******************************************************
; * SPI routines
; *******************************************************
                section .text

; send buffer at addr FW_ZP_IOPTR, len FW_ZP_IOLEN via SPI
; A, X, Y trashed
;
                global  spi_send_buffer
spi_send_buffer:
                ldx     #OP_SPI_SCK     ;  2    SCK GPIO bit
                ldy     #OP_SPI_COPI    ;  2    CPIO GPIO bit
.loop           lda     FW_ZP_IOLEN
                bne     .nolenhi
                lda     FW_ZP_IOLEN+1
                beq     .done
                dec     FW_ZP_IOLEN+1
.nolenhi        dec     FW_ZP_IOLEN
                lda     (FW_ZP_IOPTR)
                inc     FW_ZP_IOPTR
                bne     .nobufhi
                inc     FW_ZP_IOPTR+1
.nobufhi        jsr     spi_send_byte2
                bra     .loop
.done           rts

; send byte in A via SPI
; A, X, Y trashed
;
; ~16.5 cycles per bit (138 to 146 cycles per byte)
                global  spi_send_byte
spi_send_byte:
                ldx     #OP_SPI_SCK     ;  2    SCK GPIO bit
                ldy     #OP_SPI_COPI    ;  2    CPIO GPIO bit

spi_send_byte2: ; if X and Y already loaded

.bit7           stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit7c          ;  2/3  
                sty     DUA_OPR_HI      ;  4    COPI HI
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit6c          ;  2/3  
.bit6s          sty     DUA_OPR_HI      ;  4    COPI HI
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit5c          ;  2/3  
.bit5s          sty     DUA_OPR_HI      ;  4    COPI HI
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit4c          ;  2/3  
.bit4s          sty     DUA_OPR_HI      ;  4    COPI HI
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit3c          ;  2/3  
.bit3s          sty     DUA_OPR_HI      ;  4    COPI HI
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit2c          ;  2/3  
.bit2s          sty     DUA_OPR_HI      ;  4    COPI HI
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit1c          ;  2/3  
.bit1s          sty     DUA_OPR_HI      ;  4    COPI HI
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit0c          ;  2/3  
.bit0s          sty     DUA_OPR_HI      ;  4    COPI HI
                stx     DUA_OPR_HI      ;  4    SCK HI

                rts                     ;  6    done
.bit7c
                sty     DUA_OPR_LO      ;  4    COPI LO
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit6s          ;  2/3  
.bit6c          sty     DUA_OPR_LO      ;  4    COPI LO
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit5s          ;  2/3  
.bit5c          sty     DUA_OPR_LO      ;  4    COPI LO
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit4s          ;  2/3  
.bit4c          sty     DUA_OPR_LO      ;  4    COPI LO
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit3s          ;  2/3  
.bit3c          sty     DUA_OPR_LO      ;  4    COPI LO
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit2s          ;  2/3  
.bit2c          sty     DUA_OPR_LO      ;  4    COPI LO
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit1s          ;  2/3  
.bit1c          sty     DUA_OPR_LO      ;  4    COPI LO
                stx     DUA_OPR_HI      ;  4    SCK HI

                stx     DUA_OPR_LO      ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit0s          ;  2/3  
.bit0c          sty     DUA_OPR_LO      ;  4    COPI LO
                stx     DUA_OPR_HI      ;  4    SCK HI

anrts:          rts                     ;  6    done

; read buffer at addr FW_ZP_IOPTR, len FW_ZP_IOLEN via SPI
; A, X, Y trashed
;
                global  spi_read_buffer
spi_read_buffer:
                ldy     #0
                ldx     #OP_SPI_SCK     ;  2    SCK GPIO bit
.loop           jsr     spi_read_byte2
                sta     (FW_ZP_IOPTR),y
                iny
                bne     .nobufhi
                inc     FW_ZP_IOPTR+1
.nobufhi        lda     FW_ZP_IOLEN
                bne     .nolenhi
                lda     FW_ZP_IOLEN+1
                beq     anrts
                dec     FW_ZP_IOLEN+1
.nolenhi        dec     FW_ZP_IOLEN
                bra     .loop

; read byte via SPI to FW_ZP_IOBYTE
; A, X trashed
;
; ~21 cycles per bit (179 cycles per byte)
                global  spi_read_byte,spi_read_byte2 
spi_read_byte:
                ldx     #OP_SPI_SCK     ;  2    SCK GPIO bit
spi_read_byte2: ; if X already loaded
        rept    8
                stx     DUA_OPR_LO      ;  4    SCK LO
                lda     DUA_IP          ;  4    read IP byte
                and     #IP_SPI_CIPO    ;  2    isolate CIPO bit
                stx     DUA_OPR_HI      ;  4    SCK HI
                cmp     #IP_SPI_CIPO    ;  2    set carry if CIPO set
                rol     FW_ZP_IOBYTE    ;  5    rotate carry into lsb
        endr
                lda     FW_ZP_IOBYTE    ;  3    get result in A
                rts                     ;  6    done