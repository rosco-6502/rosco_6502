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

; *******************************************************
; * low-level SPI routines using XR68C681 DUART IP/OP
; *******************************************************
                section .text

; write 256 bytes to SPI from buffer at FW_ZP_IOPTR
; A, X, Y trashed
;
                global  spi_write_page
spi_write_page:
                        ldx     #OP_SPI_SCK             ;  2    load X for spi_write_byte2
                        stz     FW_ZP_IOLEN             ;  3
.pageloop               ldy     FW_ZP_IOLEN             ;  3
                        lda     (FW_ZP_IOPTR),y         ;  5
                        jsr     spi_write_byte2         ; ~140
                        inc     FW_ZP_IOLEN             ;  5
                        bne     .pageloop               ; 2/3
                        rts                             ;  6

; spi_write_bytes - send X 256 bytes from FW_ZP_IOPTR via SPI
; A, X, Y trashed
;
                global  spi_write_bytes
spi_write_bytes:
                        stx     FW_ZP_IOLEN+1           ;  3
                        stz     FW_ZP_IOLEN             ;  3
                        ldx     #OP_SPI_SCK             ;  2    load X for spi_write_byte2
.byteloop               ldy     FW_ZP_IOLEN             ;  2
                        lda     (FW_ZP_IOPTR),y         ;  5
                        jsr     spi_write_byte2         ; ~140
                        inc     FW_ZP_IOLEN             ;  5
                        dec     FW_ZP_IOLEN+1           ;  5
                        bne     .byteloop               ; 2/3
                        rts                             ;  6

; spi_write_byte - send byte in A via SPI
; A, X, Y trashed
;
; ~16.5 cycles per bit (138 to 146 cycles per byte)
                global  spi_write_byte
spi_write_byte:
                        ldx     #OP_SPI_SCK             ;  2    SCK GPIO bit

spi_write_byte2:         ; if X already loaded
                        ldy     #OP_SPI_COPI            ;  2    CPIO GPIO bit

                        stx     DUA_OPR_LO              ;  4    SCK LO
                        asl                             ;  2    shift MSB to carry
                        bcc     .bit7c                  ; 2/3
.bit7s:                 sty     DUA_OPR_HI              ;  4    COPI HI
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcc     .bit6c                  ; 2/3
.bit6s:                 sty     DUA_OPR_HI              ;  4    COPI HI
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcc     .bit5c                  ; 2/3
.bit5s:                 sty     DUA_OPR_HI              ;  4    COPI HI
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcc     .bit4c                  ; 2/3
.bit4s:                 sty     DUA_OPR_HI              ;  4    COPI HI
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcc     .bit3c                  ; 2/3
.bit3s:                 sty     DUA_OPR_HI              ;  4    COPI HI
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcc     .bit2c                  ; 2/3
.bit2s:                 sty     DUA_OPR_HI              ;  4    COPI HI
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcc     .bit1c                  ; 2/3
.bit1s:                 sty     DUA_OPR_HI              ;  4    COPI HI
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcc     .bit0c                  ; 2/3
.bit0s:                 sty     DUA_OPR_HI              ;  4    COPI HI
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        rts                             ;  6    done
.bit7c:
                        sty     DUA_OPR_LO              ;  4    COPI LO
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcs     .bit6s                  ; 2/3
.bit6c:                 sty     DUA_OPR_LO              ;  4    COPI LO
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcs     .bit5s                  ; 2/3
.bit5c:                 sty     DUA_OPR_LO              ;  4    COPI LO
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcs     .bit4s                  ; 2/3
.bit4c:                 sty     DUA_OPR_LO              ;  4    COPI LO
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcs     .bit3s                  ; 2/3
.bit3c:                 sty     DUA_OPR_LO              ;  4    COPI LO
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcs     .bit2s                  ; 2/3
.bit2c:                 sty     DUA_OPR_LO              ;  4    COPI LO
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcs     .bit1s                  ; 2/3
.bit1c:                 sty     DUA_OPR_LO              ;  4    COPI LO
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        asl                             ;  2    shift MSB to carry
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        bcs     .bit0s                  ; 2/3
.bit0c:                 sty     DUA_OPR_LO              ;  4    COPI LO
                        stx     DUA_OPR_HI              ;  4    SCK HI

                        rts                             ;  6    done

; read 256 bytes from SPI into buffer at FW_ZP_IOPTR
; A, X, Y trashed
;
                global  spi_read_page
spi_read_page:
                        ldx     #OP_SPI_SCK             ;  2    load SCK for spi_read_byte2
                        ldy     #0                      ;  2
.pageloop:              jsr     spi_read_byte2          ; 177
                        sta     (FW_ZP_IOPTR),y         ;  5
                        iny                             ;  2
                        bne     .pageloop               ; 2/3
                        rts                             ;  6

; spi_read_byte - read byte via SPI into A
; A, X trashed
;
; ~21 cycles per bit + 11  (179 cycles per byte)
                global  spi_read_byte
spi_read_byte:
                        ldx     #OP_SPI_SCK     ;  2    SCK GPIO bit
spi_read_byte2:         ; if X already loaded
                rept    8
                        stx     DUA_OPR_LO              ;  4    SCK LO
                        lda     #IP_SPI_CIPO            ;  2    CIPO bit mask
                        and     DUA_IP                  ;  4    AND with IP byte
                        stx     DUA_OPR_HI              ;  4    SCK HI
                        cmp     #IP_SPI_CIPO            ;  2    set carry if CIPO set
                        rol     FW_ZP_IOBYTE            ;  5    rotate carry into lsb
                endr    
                        lda     FW_ZP_IOBYTE            ;  3    get result in A
                        rts                             ;  6    done
