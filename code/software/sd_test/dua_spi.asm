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

; send byte in A via SPI
;
; ~16.5 cycles per bit (138 to 146 cycles per byte)
spi_send_byte:
                ldx     #OP_SPI_SCK     ;  2    SCK GPIO bit
                ldy     #OP_SPI_COPI    ;  2    CPIO GPIO bit

.bit7           stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit7c          ;  2/3  
                sty     DUA_OPR_S       ;  4    COPI HI
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit6c          ;  2/3  
.bit6s          sty     DUA_OPR_S       ;  4    COPI HI
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit5c          ;  2/3  
.bit5s          sty     DUA_OPR_S       ;  4    COPI HI
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit4c          ;  2/3  
.bit4s          sty     DUA_OPR_S       ;  4    COPI HI
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit3c          ;  2/3  
.bit3s          sty     DUA_OPR_S       ;  4    COPI HI
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit2c          ;  2/3  
.bit2s          sty     DUA_OPR_S       ;  4    COPI HI
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit1c          ;  2/3  
.bit1s          sty     DUA_OPR_S       ;  4    COPI HI
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcc     .bit0c          ;  2/3  
.bit0s          sty     DUA_OPR_S       ;  4    COPI HI
                stx     DUA_OPR_S       ;  4    SCK HI

                rts                     ;  6    done
.bit7c
                sty     DUA_OPR_C       ;  4    COPI LO
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit6s          ;  2/3  
.bit6c          sty     DUA_OPR_C       ;  4    COPI LO
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit5s          ;  2/3  
.bit5c          sty     DUA_OPR_C       ;  4    COPI LO
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit4s          ;  2/3  
.bit4c          sty     DUA_OPR_C       ;  4    COPI LO
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit3s          ;  2/3  
.bit3c          sty     DUA_OPR_C       ;  4    COPI LO
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit2s          ;  2/3  
.bit2c          sty     DUA_OPR_C       ;  4    COPI LO
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit1s          ;  2/3  
.bit1c          sty     DUA_OPR_C       ;  4    COPI LO
                stx     DUA_OPR_S       ;  4    SCK HI

                stx     DUA_OPR_C       ;  4    SCK LO
                asl                     ;  2    shift MSB to carry
                bcs     .bit0s          ;  2/3  
.bit0c          sty     DUA_OPR_C       ;  4    COPI LO
                stx     DUA_OPR_S       ;  4    SCK HI

                rts                     ;  6    done

spi_read_byte:
                ldx     #OP_SPI_SCK     ;  2    SCK GPIO bit

        rept    8
                stx     DUA_OPR_C       ;  4    SCK LO
                lda     DUA_IP          ;  4    read IP byte
                and     #IP_SPI_CIPO    ;  2    isolate CIPO bit
                stx     DUA_OPR_S       ;  4    SCK HI
                cmp     #IP_SPI_CIPO    ;  2    set carry if CIPO set
                ror     FW_ZP_IOBYTE    ;  5    rotate carry into msb
        endr
                rts                     ;  6    done
