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

SD_RESET_CYCLES         =       20
SD_IDLE_TIMEOUT         =       20
SD_START_TIMEOUT        =       200
SD_MAX_IDLE_RETRIES     =       5
SD_CMD_WAIT_RETRIES     =       100
SD_WRITE_WAIT_RETRIES   =       2500
SD_CMD_RESP_RETRIES     =       $1000

SD_R1_READY_STATE       =       $00
SD_R1_IDLE_STATE        =       $01
SD_R1_ILLEGAL_COMMAND   =       $04
SD_WRITE_RESPONSE_OK    =       $05
SD_BLOCK_START          =       $FE

SD_IOFLG_FORCECMD       =       1<<7

                if      1
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
                stz     FW_ZP_IOFLAGS
                stz     FW_ZP_IOSTAT

                lda     #SD_MAX_IDLE_RETRIES
                sta     sd_init_retries
                stz     sd_cmd_retries
                
.chk_idle       jsr     sd_reset
                ldx     #OP_SPI_CS      ; CS = LO (assert)
                stx     DUA_OPR_LO
                lda     #<sd_cmd0_bytes
                ldx     #>sd_cmd0_bytes
                jsr     sd_send_sd_cmd          ; send cmd0
                cmp     #SD_R1_IDLE_STATE
                beq     .cmd8_if
.retry_init:    dec     sd_init_retries
                bne     .chk_idle
                bra     .card_error
.cmd8_if:       lda     #<sd_cmd8_bytes
                ldx     #>sd_cmd8_bytes
                jsr     sd_send_sd_cmd          ; send cmd8
                cmp     #SD_R1_IDLE_STATE
                bne     .retry_init
                trace   '='
                ldy     #4
.eatresponse:   jsr     spi_read_byte
                tracea
                dey
                bne     .eatresponse
.cmd55_app_cmd: lda     #<sd_cmd55_bytes
                ldx     #>sd_cmd55_bytes
                jsr     sd_send_sd_cmd          ; send cmd 55
                cmp     #SD_R1_IDLE_STATE
                bne     .retry_init
.cmd41_op_cond: lda     #<sd_cmd41_bytes
                ldx     #>sd_cmd41_bytes
                jsr     sd_send_sd_cmd          ; send cmd 41
                cmp     #SD_R1_READY_STATE
                beq     .card_ready
                cmp     #SD_R1_IDLE_STATE
                bne     .retry_init
                inc     sd_cmd_retries
                beq     .card_error
                trace   '.'
                lda     #14                     ; ~2.5 ms @ 10 Mhz
                ldx     #0
.delay:         dex
                bne     .delay
                dec
                bne     .delay
                bra     .cmd55_app_cmd
.card_error:    sec
                trace   '!'
                bra     .done
.card_ready:    trace   '^'
                clc
.done:          ldx     #OP_SPI_CS|OP_SPI_COPI ; CS,COPI = HI (de-assert)
                stx     DUA_OPR_HI
                trace   'i'
                rts

; 
sd_read_sector:
                rts

; de-assert CS and send $FFs to reset card
; trashes A, X, Y
sd_reset:
                trace   'R'
                lda     #OP_SPI_CS|OP_SPI_COPI  ; CS = HI (de-assert)
                sta     DUA_OPR_HI

                lda     #SD_RESET_CYCLES
                sta     FW_ZP_IOBYTE
.resetloop      lda     #$FF
                jsr     spi_write_byte
                dec     FW_ZP_IOBYTE
                bne     .resetloop
                trace   'r'
                rts

; send sd command
; 6 byte command at FW_ZP_IOPTR
; trashes A, X, Y
; returns C set if timeout
sd_send_sd_cmd:
                sta     FW_ZP_IOPTR
                stx     FW_ZP_IOPTR+1
                trace   'S'
                trace   '>'
                tracev  (FW_ZP_IOPTR)

                ldx     #6
                jsr     spi_write_bytes
                jsr     sd_wait_result                  ; C=1 on timeout

.sd_send_err
                trace   's'
                rts

; sd_wait_result
; wait for non-$FF result
; trashes A, X, Y
; returns C set if timeout
sd_wait_result:
                trace   'W'
                stz     sd_timeout_ctr
                lda     #>SD_CMD_RESP_RETRIES
                sta     sd_timeout_ctr+1

.sd_wait_loop:  jsr     spi_read_byte
                cmp     #$ff
                bne     .sd_wait_good
                inc     sd_timeout_ctr
                bne     .sd_wait_loop
                dec     sd_timeout_ctr+1
                bne     .sd_wait_loop
                trace   '!'
                sec
                bra     .sd_wait_exit
.sd_wait_good:  trace   '='
                tracea
                clc
.sd_wait_exit:  trace   'w'
                rts

; *******************************************************
; * Initialized data
; *******************************************************
                section  .rodata

sd_cmd0_bytes   db      $40|0,$00,$00,$00,$00,$95       ; 40
sd_cmd8_bytes   db      $40|8,$00,$00,$01,$aa,$87       ; 48
sd_cmd55_bytes  db      $40|55,$00,$00,$00,$00,$01      ; 77
sd_cmd41_bytes  db      $40|41,$40,$00,$00,$00,$01      ; 69

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

sd_init_retries ds      1
sd_cmd_retries  ds      1

sd_cmd_number   ds      1
sd_cmd_arg      ds      4
