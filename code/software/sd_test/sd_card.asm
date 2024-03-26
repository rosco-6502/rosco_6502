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
; Huge shout-out to the following for helpful reference material:
; George Foot           https://github.com/gfoot/sdcard6502
; Electronic Lives Mfg. http://elm-chan.org/docs/mmc/mmc_e.html
; Dr. Roc's Blog        https://www.asinine.nz/2023-01-29/SD_Card-part1/
;------------------------------------------------------------

                include "defines.asm"

TRACE                   =       1       ; 1 for invasive debug trace prints

                if TRACE
trace                   macro   char
                        php
                        pha
                        lda     #\char
                        jsr     COUT
                        pla
                        plp
                        endm
tracea                  macro
                        php
                        pha
                        jsr     outbyte
                        pla
                        plp
                        endm
tracev                  macro   var
                        php
                        pha
                        lda     \var
                        jsr     outbyte
                        pla
                        plp
                        endm
                else
trace                   macro   char
                        endm
tracea                  macro
                        endm
tracev                  macro   var
                        endm
                endif

; *******************************************************
; * SD card constants
; *******************************************************

SD_RESET_CYCLES         =       10                      ; reset retry count
SD_IDLE_RETRIES         =       5                       ; SD card idle retry count
SD_CMD_RESP_RETRIES     =       1024                    ; number of retries after SD command
SD_WAIT_TIMEOUT         =       4096                    ; SD card wait done timeout (check iterations)

SD_R1_READY_STATE       =       $00
SD_R1_IDLE_STATE        =       $01
SD_WRITE_RESPONSE_OK    =       $05
SD_BLOCK_START          =       $FE
SD_READY                =       $FF

; optional run-time features

CRCCHECKYANK            =       1                       ; read CRC and if $FFFF check for card yank

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
                        jsr     sd_check_status         ; check if already initialized
                        bcs     .doinit                 ; only init if status failed
                        rts                             ; return (already initialized)
.doinit                 ldx     #OP_SPI_CS|OP_SPI_COPI  ; CS = HI (de-assert)
                        stx     DUA_OPR_HI
                        trace   '~'
                        lda     #SD_RESET_CYCLES
                        sta     FW_ZP_IOTEMP
.resetloop              lda     #$FF
                        jsr     spi_write_byte
                        dec     FW_ZP_IOTEMP
                        bne     .resetloop
                        lda     #SD_IDLE_RETRIES
                        sta     sd_idle_retry
                        jsr     sd_assert
.chk_idle               lda     #<sd_40_cmd0_go_idle
                        ldx     #>sd_40_cmd0_go_idle
                        jsr     sd_send_sd_cmd          ; send cmd0
                        cmp     #SD_R1_IDLE_STATE
                        beq     .cmd8_if
.retry_init             dec     sd_idle_retry
                        bne     .chk_idle
                        jmp     sd_deassert_fail
.cmd8_if                lda     #<sd_48_cmd8_if_cond
                        ldx     #>sd_48_cmd8_if_cond
                        jsr     sd_send_sd_cmd          ; send cmd8
                        cmp     #SD_R1_IDLE_STATE
                        bne     .retry_init
                        trace   ':'
                        jsr     spi_read_byte
                        tracea
                        jsr     spi_read_byte
                        tracea
                        jsr     spi_read_byte
                        tracea
                        jsr     spi_read_byte
                        tracea
                        stz     sd_init_timeout
.cmd55_app_cmd          lda     #<sd_77_cmd55_app_cmd
                        ldx     #>sd_77_cmd55_app_cmd
                        jsr     sd_send_sd_cmd          ; send cmd 55
                        cmp     #SD_R1_IDLE_STATE
                        bne     .retry_init
.cmd41_op_cond          lda     #<sd_69_acmd41_op_cond
                        ldx     #>sd_69_acmd41_op_cond
                        jsr     sd_send_sd_cmd          ; send cmd 41
                        cmp     #SD_R1_READY_STATE
                        beq     .cmd58_ocr
                        cmp     #SD_R1_IDLE_STATE
                        bne     .retry_init
                        inc     sd_init_timeout
                        bne     .delay
                        jmp     sd_deassert_fail
.delay                  trace   '.'
                        lda     #14                     ; ~2.5 ms @ 10 Mhz
                        ldx     #0
.delayloop              dex
                        bne     .delayloop
                        dec
                        bne     .delayloop
                        bra     .cmd55_app_cmd
.cmd58_ocr              lda     #<sd_7A_cmd58_read_ocr
                        ldx     #>sd_7A_cmd58_read_ocr
                        jsr     sd_send_sd_cmd
                        cmp     #SD_R1_READY_STATE
                        bne     sd_deassert_fail
                        trace   ':'
                        jsr     spi_read_byte
                        tracea
                        sta     sd_sdhc_flag            ; save, bit 6 = SDHC flag
                if TRACE
                        and     #$40
                        cmp     #$40
                        lda     #"+"
                        bcs     .has_sdhc
                        lda     #"-"
.has_sdhc               jsr     COUT
                endif
                        jsr     spi_read_byte
                        tracea
                        jsr     spi_read_byte
                        tracea
                        jsr     spi_read_byte
                        tracea
.cmd16_blklen           lda     #<sd_50_cmd16_blocklen
                        ldx     #>sd_50_cmd16_blocklen
                        jsr     sd_send_sd_cmd
                        cmp     #SD_R1_READY_STATE
                        beq     sd_deassert_good

sd_assert               ldx     #OP_SPI_CS              ; CS = LO (assert)
                        stx     DUA_OPR_LO
                        trace   '['
;;                        jsr     spi_read_byte
                        jsr     sd_wait_ready
                        rts

sd_deassert_fail        sec
                        trace   '!'
                        bra     sd_deassert

; sd_check_status - check if SD card is present, initialized and ready
; trashes A, X, Y
; returns C set if SD not present, initialized or other error
                global  sd_check_status
sd_check_status:
                        trace   'S'
                        jsr     sd_assert
                        lda     #<sd_4D_cmd13_status
                        ldx     #>sd_4D_cmd13_status
                        jsr     sd_send_sd_cmd
                        tax                             ; test result
                        bne     sd_deassert_fail
                        jsr     spi_read_byte
                        tracea
                        ; tax                             ; test result
                        bne     sd_deassert_fail
sd_deassert_good        clc
                        trace   '^'
sd_deassert             ldx     #OP_SPI_CS|OP_SPI_COPI ; CS,COPI = HI (de-assert)
                        stx     DUA_OPR_HI
                        trace   ']'
                        rts

; sd_read_block - read 512 byte block
; 32-bit block number in FW_ZP_BLOCKNUM, block ptr FW_ZP_IOPTR
; trashes A, X, Y
; returns C set on error
                global  sd_read_block
sd_read_block:
                        trace   'R'
                        lda     #$40|17                 ; cmd17 $51=READ_SINGLE_BLOCK
                        jsr     sd_send_blockcmd

                        jsr     sd_wait_result
                        cmp     #SD_R1_READY_STATE
                        bne     sd_deassert_fail

                        jsr     sd_wait_result
                        cmp     #SD_BLOCK_START
                        bne     sd_deassert_fail

                        trace   '#'
                        jsr     spi_read_page
                        inc     FW_ZP_IOPTR+1
                        jsr     spi_read_page
                        dec     FW_ZP_IOPTR+1

                if CRCCHECKYANK                         ; read CRC to check for yank
                        trace   '-'
                        jsr     spi_read_byte
                        sta     FW_ZP_IOTEMP
                        tracea
                        jsr     spi_read_byte
                        tracea

; if CRC $FFFF, double check if card yanked
                        cmp     #$FF
                        bne     .not_FFFF_crc
                        cmp     FW_ZP_IOTEMP
                        bne     .not_FFFF_crc

; issue BLKSIZE to check if card responding
                        lda     #<sd_50_cmd16_blocklen
                        ldx     #>sd_50_cmd16_blocklen
                        jsr     sd_send_sd_cmd
                        cmp     #SD_R1_READY_STATE
                        beq     .not_FFFF_crc
                        jmp     sd_deassert_fail
.not_FFFF_crc
                endif
                        jmp     sd_deassert_good

; sd_write_block - write 512 byte block
; 32-bit block number in FW_ZP_BLOCKNUM, block ptr FW_ZP_IOPTR
; trashes A, X, Y
; returns C set on error
                global  sd_write_block
sd_write_block:
                        trace   'W'
                        lda     #$40|24                 ; cmd24 $88=WRITE_BLOCK
                        jsr     sd_send_blockcmd        ; send command and blocknum

                        jsr     sd_wait_result          ; check response ready
                        cmp     #SD_R1_READY_STATE
                        bne     .sd_write_fail

                        lda     #$FF                    ; write dummy byte (delay)
                        jsr     spi_write_byte

                        lda     #SD_BLOCK_START         ; write data token
                        jsr     spi_write_byte

                        trace   '#'
                        jsr     spi_write_page          ; write 512 byte block
                        inc     FW_ZP_IOPTR+1
                        jsr     spi_write_page
                        dec     FW_ZP_IOPTR+1

                        trace   '+'
                        lda     #$FF                    ; write dummy CRC16 $FFFF
                        tracea
                        jsr     spi_write_byte
                        lda     #$FF
                        tracea
                        jsr     spi_write_byte

                        jsr     sd_wait_result          ; check data response accepted
                        and     #$1F
                        cmp     #SD_WRITE_RESPONSE_OK
                        bne     .sd_write_fail

                        jsr     sd_wait_ready           ; wait for write to be done
                        bcs     .sd_write_fail
                        jmp     sd_deassert_good

.sd_write_fail          jmp     sd_deassert_fail


; sd_send_blocknum - send 32 bit blocknum/bytenum and dummy crc byte
; A = block cmd byte, 32-bit blocknum at FW_ZP_BLOCKNUM
; trashes A, X, Y
sd_send_blockcmd:
                        sta     FW_ZP_IOTEMP
                        jsr     sd_assert
                        trace   '>'
                        lda     FW_ZP_IOTEMP
                        tracea
                        jsr     spi_write_byte
                        trace   '@'
                        bit     sd_sdhc_flag            ; check SDHC flag bit 6
                        bvc     .not_sdhc               ; branch if need to calc bytenum
                        lda     FW_ZP_BLOCKNUM+3        ; send big endian blocknum[31:24]
                        tracea
                        jsr     spi_write_byte
                        lda     FW_ZP_BLOCKNUM+2        ; send big endian blocknum[23:16]
                        tracea
                        jsr     spi_write_byte
                        lda     FW_ZP_BLOCKNUM+1        ; send big endian blocknum[15:8]
                        tracea
                        jsr     spi_write_byte
                        lda     FW_ZP_BLOCKNUM+0        ; send big endian blocknum[7:0]
                        tracea
                        jsr     spi_write_byte
.dummycrc7              lda     #$FF                    ; send ignored CRC7
                        tracea
                        jmp     spi_write_byte
                        ; rts
.not_sdhc               lda     FW_ZP_BLOCKNUM+0        ; calc bytenum = blocknum << 9
                        asl
                        sta     FW_ZP_TMPPTR
                        lda     FW_ZP_BLOCKNUM+1
                        rol
                        sta     FW_ZP_TMPPTR+1
                        lda     FW_ZP_BLOCKNUM+2
                        rol                             ; send big endian bytenum[31:24]
                        tracea
                        jsr     spi_write_byte
                        lda     FW_ZP_TMPPTR+1          ; send big endian bytenum[31:24]
                        tracea
                        jsr     spi_write_byte
                        lda     FW_ZP_TMPPTR            ; send big endian bytenum[31:24]
                        tracea
                        jsr     spi_write_byte
                        lda     #0                      ; send big endian bytenum[7:0] (always zero)
                        tracea
                        jsr     spi_write_byte
                        bra     .dummycrc7

; SD send command
; 6 byte command at FW_ZP_IOPTR
; trashes A, X, Y
; returns C set if timeout
sd_send_sd_cmd:
                        sta     FW_ZP_IOPTR
                        stx     FW_ZP_IOPTR+1
                        trace   '>'
                if TRACE
                        ldy     #0
.cmd_trace_loop         lda     (FW_ZP_IOPTR),y
                        jsr     outbyte
                        iny
                        cpy     #6
                        bne     .cmd_trace_loop
                endif
                        ldx     #6
                        jsr     spi_write_bytes
                ; FALLS THROUGH!
                        ; jmp     sd_wait_result        ; C=1 on timeout
                        ; rts

; sd_wait_result
; wait until result not equal to SD_READY
; trashes A, X, Y
; returns C set if timeout
sd_wait_result:
                        trace   '='
                        stz     sd_timeout_ctr
                        lda     #>SD_CMD_RESP_RETRIES
                        sta     sd_timeout_ctr+1
.sd_wait_loop           jsr     spi_read_byte
                        cmp     #SD_READY
                        bne     .sd_ready
                        inc     sd_timeout_ctr
                        bne     .sd_wait_loop
                        dec     sd_timeout_ctr+1
                        bne     .sd_wait_loop
                        sec                     
                        trace   '!'
                        rts
.sd_ready               ; clc                           ; always clear from cmp #$FF
                        tracea
.sd_wait_exit:          rts

; sd_wait_ready
; wait until result equal to SD_READY
; trashes A, X, Y
; returns C set if timeout
sd_wait_ready:
                        trace   '|'
                        stz     sd_timeout_ctr
                        lda     #>SD_WAIT_TIMEOUT
                        sta     sd_timeout_ctr+1
.sd_wait_loop           jsr     spi_read_byte
                        cmp     #SD_READY
                        beq     .sd_done
                        inc     sd_timeout_ctr
                        bne     .sd_wait_loop
                        dec     sd_timeout_ctr+1
                        bne     .sd_wait_loop
                        sec
                        trace   '!'
                        rts
.sd_done                clc                   ; always clear from cmp #$FF
.sd_wait_exit           rts

; *******************************************************
; * Initialized data
; *******************************************************
                section  .rodata

sd_40_cmd0_go_idle      db      $40| 0,$00,$00,$00,$00,$95      ; $40=GO_IDLE_STATE
sd_48_cmd8_if_cond      db      $40| 8,$00,$00,$01,$aa,$87      ; $48=SEND_IF_COND
sd_77_cmd55_app_cmd     db      $40|55,$00,$00,$00,$00,$FF      ; $77=APP_CMD
sd_69_acmd41_op_cond    db      $40|41,$40,$00,$00,$00,$FF      ; $69=SD_SEND_OP_COND
sd_7A_cmd58_read_ocr    db      $40|58,$40,$00,$00,$00,$FF      ; $7A=READ_OCR
sd_50_cmd16_blocklen    db      $40|16,$00,$00,$02,$00,$FF      ; $50=SET_BLOCKLEN
sd_4D_cmd13_status      db      $40|13,$00,$00,$00,$00,$FF      ; $4D=SEND_STATUS

; *******************************************************
; * Uninitialized data
; *******************************************************
                section  .bss

sd_sdhc_flag            ds      1       ; bit 6 SDHC
sd_init_timeout         ds      1
sd_idle_retry           ds      1
sd_timeout_ctr          ds      2
