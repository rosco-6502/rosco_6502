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
; Huge shout-out to George Foot, this is largely based on:
; https://github.com/gfoot/sdcard6502
;
;------------------------------------------------------------

                include "defines.asm"

SD_RESET_CYCLES         =       10
SD_IDLE_RETRIES         =       5
SD_CMD_RESP_RETRIES     =       $1000
SD_WRITE_WAIT_RETRIES   =       $1000

SD_R1_READY_STATE       =       $00
SD_R1_IDLE_STATE        =       $01
SD_R1_ILLEGAL_COMMAND   =       $04
SD_WRITE_RESPONSE_OK    =       $05
SD_BLOCK_START          =       $FE
SD_NOT_READY            =       $FF

SD_IOFLG_FORCECMD       =       1<<7

TRACE           =       1

                if      TRACE
trace           macro   char
                php
                pha
                lda     #\char
                jsr     COUT
                pla
                plp
                endm
tracea          macro
                php
                pha
                jsr     outbyte
                pla
                plp
                endm
tracev          macro   var
                php
                pha
                lda     \var
                jsr     outbyte
                pla
                plp
                endm

                else

trace           macro   char
                endm
tracea          macro
                endm
tracev          macro   var
                endm
                endif

; *******************************************************
; * SD card routines
; *******************************************************
                section .text

; sd_init - initialize SD card
; trashes A, X, Y
; returns C set if init failed
                global  sd_init
sd_init:
                trace   'I'
                lda     #OP_SPI_CS|OP_SPI_COPI  ; CS = HI (de-assert)
                sta     DUA_OPR_HI
                trace   '~'
                lda     #SD_RESET_CYCLES
                sta     FW_ZP_IOTEMP
.resetloop      lda     #$FF
                jsr     spi_write_byte
                dec     FW_ZP_IOTEMP
                bne     .resetloop
                lda     #SD_IDLE_RETRIES
                sta     sd_idle_retry
                ldx     #OP_SPI_CS              ; CS = LO (assert)
                trace   '['
                stx     DUA_OPR_LO
.chk_idle:
                lda     #<sd_cmd0_bytes
                ldx     #>sd_cmd0_bytes
                jsr     sd_send_sd_cmd          ; send cmd0
                cmp     #SD_R1_IDLE_STATE
                beq     .cmd8_if
.retry_init:    dec     sd_idle_retry
                bne     .chk_idle
                jmp     .card_error
.cmd8_if:       lda     #<sd_cmd8_bytes
                ldx     #>sd_cmd8_bytes
                jsr     sd_send_sd_cmd          ; send cmd8
                cmp     #SD_R1_IDLE_STATE
                bne     .retry_init
                trace   '='
                jsr     spi_read_byte
                tracea
                jsr     spi_read_byte
                tracea
                jsr     spi_read_byte
                tracea
                jsr     spi_read_byte
                tracea
                stz     sd_init_timeout
.cmd55_app_cmd: lda     #<sd_cmd55_bytes
                ldx     #>sd_cmd55_bytes
                jsr     sd_send_sd_cmd          ; send cmd 55
                cmp     #SD_R1_IDLE_STATE
                bne     .retry_init
.cmd41_op_cond: lda     #<sd_cmd41_bytes
                ldx     #>sd_cmd41_bytes
                jsr     sd_send_sd_cmd          ; send cmd 41
                cmp     #SD_R1_READY_STATE
                beq     .cmd58_ocr
                cmp     #SD_R1_IDLE_STATE
                bne     .retry_init
                inc     sd_init_timeout
                beq     .card_error
                trace   '.'
                lda     #14                     ; ~2.5 ms @ 10 Mhz
                ldx     #0
.delay:         dex
                bne     .delay
                dec
                bne     .delay
                bra     .cmd55_app_cmd
.cmd58_ocr:     lda     #<sd_cmd58_bytes
                ldx     #>sd_cmd58_bytes
                jsr     sd_send_sd_cmd
                cmp     #SD_R1_READY_STATE
                bne     .card_error
                trace   '='
                jsr     spi_read_byte
                tracea
                sta     sd_sdhc_flag            ; save, bit 6 = SDHC flag
        if      TRACE
                and     #$40
                beq     .nosdhc
                trace   '+'
                bra     .ocrchk
.nosdhc:        trace   '-'
.ocrchk:
        endif
                jsr     spi_read_byte
                tracea
                jsr     spi_read_byte
                tracea
                jsr     spi_read_byte
                tracea
.cmd16_blklen:  lda     #<sd_cmd16_bytes
                ldx     #>sd_cmd16_bytes
                jsr     sd_send_sd_cmd
                cmp     #SD_R1_READY_STATE
                beq     .card_ready
.card_error:    sec
                trace   '!'
                bra     .done
.card_ready:    clc
                trace   '^'
.done:          ldx     #OP_SPI_CS|OP_SPI_COPI ; CS,COPI = HI (de-assert)
                stx     DUA_OPR_HI
                trace   ']'
                rts

; sd_read_block - read 512 byte block
; 32-bit block number in FW_ZP_BLOCKNUM to FW_ZP_IOPTR
; trashes A, X, Y
; returns C set on error
                global  sd_read_block
sd_read_block:
                trace   'R'
                ldx     #OP_SPI_CS              ; CS = LO (assert)
                stx     DUA_OPR_LO
                trace   '['
                trace   '>'
                lda     #$40|17                 ; cmd17 $51=READ_SINGLE_BLOCK
                tracea
                jsr     spi_write_byte
                trace   '@'
                jsr     sd_send_blocknum

                jsr     sd_wait_result
                cmp     #SD_R1_READY_STATE
                bne     .sd_read_fail

                jsr     sd_wait_result
                cmp     #SD_BLOCK_START
                beq     .sd_read_data

.sd_read_fail:  sec
                trace   '!'
                bra     .sd_read_done

.sd_read_data:  jsr     spi_read_page
                inc     FW_ZP_IOPTR+1
                jsr     spi_read_page
                dec     FW_ZP_IOPTR+1

        if 0    ; CRC
                trace   '='
                jsr     spi_read_byte
                sta     FW_ZP_IOTEMP
                tracea
                jsr     spi_read_byte
                tracea

; if CRC $FFFF, double check if card yanked
                cmp     #$FF
                bne     .notFFFFcrc
                cmp     FW_ZP_IOTEMP
                bne     .notFFFFcrc

; issue BLKSIZE to check if card responding
                lda     #<sd_cmd16_bytes
                ldx     #>sd_cmd16_bytes
                jsr     sd_send_sd_cmd
                cmp     #SD_R1_READY_STATE
                bne     .sd_read_fail 
.notFFFFcrc:
        endif

                clc
                trace   '^'
.sd_read_done:  ldx     #OP_SPI_CS|OP_SPI_COPI ; CS,COPI = HI (de-assert)
                stx     DUA_OPR_HI
                trace   ']'
                rts

; sd_write_block - write 512 byte block
; 32-bit block number in FW_ZP_BLOCKNUM to FW_ZP_IOPTR
; trashes A, X, Y
; returns C set on error
                global  sd_write_block
sd_write_block:
                trace   'W'
                ldx     #OP_SPI_CS              ; CS = LO (assert)
                stx     DUA_OPR_LO
                trace   '['
                trace   '>'
                lda     #$40|24                 ; cmd24 $51=WRITE_BLOCK
                tracea
                jsr     spi_write_byte
                trace   '@'
                jsr     sd_send_blocknum

                jsr     sd_wait_result
                cmp     #SD_R1_READY_STATE
                bne     .sd_write_fail

                lda     #$FF                    ; dummy byte
                jsr     spi_write_byte

                lda     #SD_BLOCK_START
                jsr     spi_write_byte

                jsr     spi_write_page
                inc     FW_ZP_IOPTR+1
                jsr     spi_write_page
                dec     FW_ZP_IOPTR+1

        if 1    ; CRC
                lda     #$FF
                tracea
                jsr     spi_write_byte
                lda     #$FF
                tracea
                jsr     spi_write_byte
        endif

                jsr     sd_wait_result
                and     #$1F
                cmp     #SD_WRITE_RESPONSE_OK
                bne     .sd_write_fail

                jsr     sd_wait_done

                clc
                trace   '^'
.sd_write_done: ldx     #OP_SPI_CS|OP_SPI_COPI ; CS,COPI = HI (de-assert)
                stx     DUA_OPR_HI
                trace   ']'
                rts
.sd_write_fail: sec
                trace   '!'
                bra     .sd_write_done

; sd_send_blocknum - spi write 32 bit blocknum or bytenum and dummy crc byte
; 32-bit blocknum at FW_ZP_BLOCKNUM
; trashes A, X, Y
sd_send_blocknum:
                bit     sd_sdhc_flag
                bvc     .not_sdhc
                lda     FW_ZP_BLOCKNUM+3
                tracea
                jsr     spi_write_byte          ; send big endian blocknum[31:24]
                lda     FW_ZP_BLOCKNUM+2
                tracea
                jsr     spi_write_byte          ; send big endian blocknum[23:16]
                lda     FW_ZP_BLOCKNUM+1
                tracea
                jsr     spi_write_byte          ; send big endian blocknum[15:8]
                lda     FW_ZP_BLOCKNUM+0
                tracea
                jsr     spi_write_byte          ; send big endian blocknum[7:0]
.dummycrc7:     lda     #$FF                    ; ignored CRC (and end bit)
;                tracea
                jmp     spi_write_byte
                ; rts
.not_sdhc:      lda     FW_ZP_BLOCKNUM+0        ; bytenum = blocknum << 9
                asl
                sta     FW_ZP_TMPPTR            
                lda     FW_ZP_BLOCKNUM+1
                rol
                sta     FW_ZP_TMPPTR+1
                lda     FW_ZP_BLOCKNUM+2
                rol
                tracea
                jsr     spi_write_byte          ; send big endian bytenum[31:24]
                lda     FW_ZP_TMPPTR+1
                tracea
                jsr     spi_write_byte          ; send big endian bytenum[31:24]
                lda     FW_ZP_TMPPTR
                tracea
                jsr     spi_write_byte          ; send big endian bytenum[31:24]
                lda     #0                      ; [7:0] always zero
                tracea
                jsr     spi_write_byte          ; send big endian bytenum[7:0]
                bra     .dummycrc7

; SD send command
; 6 byte command at FW_ZP_IOPTR
; trashes A, X, Y
; returns C set if timeout
sd_send_sd_cmd:
                sta     FW_ZP_IOPTR
                stx     FW_ZP_IOPTR+1
                trace   '>'
        if      TRACE
                ldy     #0
.loop           lda     (FW_ZP_IOPTR),y
                jsr     outbyte
                iny
                cpy     #6
                bne     .loop
        endif
                ldx     #6
                jsr     spi_write_bytes
        ; FALLS THROUGH
                ; jmp     sd_wait_result                  ; C=1 on timeout
                ; rts

; sd_wait_result
; wait for non-$FF result
; trashes A, X, Y
; returns C set if timeout
sd_wait_result:
                trace   '|'
                stz     sd_timeout_ctr
                lda     #>SD_CMD_RESP_RETRIES
                sta     sd_timeout_ctr+1
.sd_wait_loop:  jsr     spi_read_byte
                cmp     #SD_NOT_READY
                bne     .sd_ready
                inc     sd_timeout_ctr
                bne     .sd_wait_loop
                dec     sd_timeout_ctr+1
                bne     .sd_wait_loop
                sec                     ; always set from cmp #$FF
                trace   '!'
                rts
.sd_ready: ;      clc                   ; always clear from cmp #$FF
                tracea
.sd_wait_exit:  rts

; sd_wait_result
; wait for non-$FF result
; trashes A, X, Y
; returns C set if timeout
sd_wait_done:
                trace   '|'
                stz     sd_timeout_ctr
                lda     #>SD_CMD_RESP_RETRIES
                sta     sd_timeout_ctr+1
.sd_wait_loop:  jsr     spi_read_byte
                cmp     #$FF
                beq     .sd_ready
                inc     sd_timeout_ctr
                bne     .sd_wait_loop
                dec     sd_timeout_ctr+1
                bne     .sd_wait_loop
                sec                     ; always set from cmp #$FF
                trace   '!'
                rts
.sd_ready: ;      clc                   ; always clear from cmp #$FF
                tracea
.sd_wait_exit:  rts


; *******************************************************
; * Initialized data
; *******************************************************
                section  .rodata

sd_cmd0_bytes   db      $40| 0,$00,$00,$00,$00,$95      ; $40=GO_IDLE_STATE
sd_cmd8_bytes   db      $40| 8,$00,$00,$01,$aa,$87      ; $48=SEND_IF_COND
sd_cmd55_bytes  db      $40|55,$00,$00,$00,$00,$FF      ; $77=app command
sd_cmd41_bytes  db      $40|41,$40,$00,$00,$00,$FF      ; $69=APP_SEND_OP_COND
sd_cmd58_bytes  db      $40|58,$40,$00,$00,$00,$FF      ; $7A=APP_CMD
sd_cmd16_bytes  db      $40|16,$00,$00,$02,$00,$FF      ; $50=SET_BLOCKLEN

; *******************************************************
; * Uninitialized data
; *******************************************************
                section  .bss

sd_sdhc_flag    ds      1       ; bit 6 SDHC
sd_init_timeout ds      1
sd_idle_retry   ds      1
sd_timeout_ctr  ds      2
