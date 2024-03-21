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

SD_RESET_CYCLES         =       10
SD_IDLE_TIMEOUT         =       20
SD_START_TIMEOUT        =       200
SD_MAX_IDLE_RETRIES     =       5
SD_MAX_ACMD41_RETRIES   =       400
SD_CMD_WAIT_RETRIES     =       100
SD_WRITE_WAIT_RETRIES   =       2500
SD_CMD_RESP_RETRIES     =       4000

SD_R1_READY_STATE       =       $00
SD_R1_IDLE_STATE        =       $01
SD_R1_ILLEGAL_COMMAND   =       $04
SD_WRITE_RESPONSE_OK    =       $05
SD_BLOCK_START          =       $FE

SD_IOFLG_FORCECMD       =       1<<7

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


; *******************************************************
; * SPI routines
; *******************************************************
                section .text

                global  sd_init
sd_init:
                trace   'I'
                stz     FW_ZP_IOFLAGS
                stz     FW_ZP_IOSTAT

                lda     #SD_MAX_IDLE_RETRIES
                sta     sd_retry_count
.chk_idle       jsr     sd_reset
                jsr     sd_send_idle
                bcc     .got_idle
                dec     sd_retry_count
                bne     .chk_idle
                trace   '!'
.got_idle
                trace   'i'
                rts

; de-assert CS and send $FFs to reset card
sd_reset:
                trace   'R'
                lda     #OP_SPI_CS      ; CS = HI (de-assert)
                sta     DUA_OPR_HI

                lda     #SD_RESET_CYCLES
                sta     FW_ZP_IOBYTE
.resetloop      lda     #$FF
                jsr     spi_send_byte
                dec     FW_ZP_IOBYTE
                bne     .resetloop
                trace   'r'
                rts

; send sd idle command
sd_send_idle:
                trace   'D'
                ldx     #SD_IDLE_TIMEOUT
.loop           lda     #<sd_cmd0_bytes
                ldx     #>sd_cmd0_bytes
                jsr     sd_send_sd_cmd          ; cmd 0, arg 0, force
                trace   'd'
                rts

; send sd command
sd_send_sd_cmd:
                sta     FW_ZP_IOPTR
                stx     FW_ZP_IOPTR+1
                lda     #6
                sta     FW_ZP_IOLEN
                stz     FW_ZP_IOLEN+1
                trace   'S'
                tracev  (FW_ZP_IOPTR)
sd_send_sd_cmd2:
                lda     #OP_SPI_CS                      ; CS = LO (assert)
                sta     DUA_OPR_LO

                jsr     spi_send_buffer
                jsr     sd_wait_result
                bcs     .sd_send_err
                tracea

                ldx     #OP_SPI_CS|OP_SPI_COPI          ; CS+COPI = HI (de-assert)
                stx     DUA_OPR_HI
                clc
.sd_send_err
                trace   's'
                rts

; wait for non-$FF result
sd_wait_result:
                trace   'W'
                lda     #<(-SD_CMD_RESP_RETRIES)        ; negate so we can inc
                sta     sd_timeout_ctr
                lda     #>(-SD_CMD_RESP_RETRIES)
                sta     sd_timeout_ctr+1

.sd_wait_loop   jsr     spi_read_byte
                cmp     #$ff
                bne     .sd_wait_good
                inc     sd_timeout_ctr
                bne     .sd_wait_loop
                inc     sd_timeout_ctr+1
                bne     .sd_wait_loop
                trace   '!'
                sec
                bra     .sd_wait_exit
.sd_wait_good
                clc
.sd_wait_exit   trace   'w'
                rts

; *******************************************************
; * Initialized data
; *******************************************************
                section  .rodata

sd_cmd0_bytes   db      $40,$00,$00,$00,$00,$95
sd_cmd8_bytes   db      $48,$00,$00,$00,$00,$87
sd_cmd55_bytes  db      $77,$00,$00,$00,$00,$01
sd_cmd41_bytes  db      $69,$00,$00,$00,$00,$01

; *******************************************************
; * Uninitialized data
; *******************************************************
                section  .bss

SD_TYPE_V1      =       1
SD_TYPE_V2      =       2
SD_TYPE_SDHC    =       3
SD_TYPE_UNKN    =       $ff

SD_STAT_INIT    =       1<<7
SD_STAT_PARTIAL =       1<<6

sd_card_stat    ds      1               ; bit 7 = initialized, bit 6 = can do partial read
sd_card_type    ds      1               ; sd card type SD_TYPE_*
sd_blk_start    ds      4               ; sd card current block start
sd_blk_offset   ds      2               ; sd card current block offset
sd_timeout_ctr  ds      2

sd_retry_count  ds      1

sd_cmd_number   ds      1
sd_cmd_arg      ds      4

