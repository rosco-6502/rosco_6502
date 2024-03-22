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
SD_IDLE_TIMEOUT         =       20
SD_START_TIMEOUT        =       200
SD_MAX_IDLE_RETRIES     =       5
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
                sta     sd_init_retries
                stz     sd_cmd_retries
                
.chk_idle       jsr     sd_reset
.cmd0_idle:     lda     #<sd_cmd0_bytes
                ldx     #>sd_cmd0_bytes
                jsr     sd_send_sd_cmd          ; send idle cmd
                cmp     #SD_R1_IDLE_STATE
                beq     .cmd8_if
.retry_init:    dec     sd_init_retries
                bne     .chk_idle
                bra     .err_return
.cmd8_if:       lda     #<sd_cmd8_bytes
                ldx     #>sd_cmd8_bytes
                jsr     sd_send_sd_cmd          ; send idle cmd
                cmp     #SD_R1_IDLE_STATE
                bne     .retry_init
                ldy     #4
.eatresponse:   jsr     spi_read_byte
                tracea
                dey
                bne     .eatresponse
.cmd55_app_cmd: lda     #<sd_cmd55_bytes
                ldx     #>sd_cmd55_bytes
                jsr     sd_send_sd_cmd          ; send idle cmd
                cmp     #SD_R1_IDLE_STATE
                bne     .retry_init
.cmd41_op_cond: lda     #<sd_cmd41_bytes
                ldx     #>sd_cmd41_bytes
                jsr     sd_send_sd_cmd          ; send idle cmd
                cmp     #SD_R1_READY_STATE
                beq     .card_ready
                cmp     #SD_R1_IDLE_STATE
                bne     .retry_init
                inc     sd_cmd_retries
                beq     .err_return
                trace   '.'
                lda     #1
                jsr     delay_10ms            ; give card small delay and retry cmd55
                bra     .cmd55_app_cmd
.card_ready:    trace   '*'
                clc
.done:          trace   'i'
                rts
.err_return:    sec
                trace   '!'
                bra     .done

; 
sd_read_sector:


; de-assert CS and send $FFs to reset card
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

; send sd idle command
sd_send_idle:
                trace   'D'
                trace   'd'
                rts

; send sd command
sd_send_sd_cmd:
                sta     FW_ZP_IOPTR
                stx     FW_ZP_IOPTR+1
                trace   'S'
                tracev  (FW_ZP_IOPTR)

                lda     #OP_SPI_CS                      ; CS = LO (assert)
                sta     DUA_OPR_LO

                ldx     #6
                jsr     spi_write_bytes
                jsr     sd_wait_result
                bcs     .sd_send_err

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

.sd_wait_loop:  jsr     spi_read_byte
                cmp     #$ff
                bne     .sd_wait_good
                inc     sd_timeout_ctr
                bne     .sd_wait_loop
                inc     sd_timeout_ctr+1
                bne     .sd_wait_loop
                trace   '!'
                sec
                bra     .sd_wait_exit
.sd_wait_good:  tracea
                clc
.sd_wait_exit:  trace   'w'
                rts

; delay for A * ~4.4usec (uses DUART internal timer tick)
                global  delay_usec
delay_usec:
                phy
.delayouter:    ldy     DUA_CTL
.delayloop:     cpy     DUA_CTL
                beq     .delayloop
                dec
                bne     .delayouter
                ply
                rts

; delay for A * ~10ms (uses DUART interrupt)
                global  delay_usec
delay_10ms:
                phy
.delayouter:    ldy     TICK100HZ
.delayloop:     cpy     TICK100HZ
                beq     .delayloop
                dec
                bne     .delayouter
                ply
                rts


; ; delay for A * ~2.6usec (adjusted vs CPU speed by delay_init)
;                 global  delay_usec
; delay_usec:
;                 phx
;                 phy
;                 tay
; .delayouter:    ldx     delay_value
;                 lda     delay_value+1
; .delayloop:     cpx     #$01                    ; 2
;                 dex                             ; 2
;                 sbc     #0                      ; 2
;                 bit     $1337                   ; 4 (timing dummy)
;                 bcs     .delayloop              ; 3
;                 dey
;                 bne     .delayouter
;                 ply
;                 plx
;                 rts

; ; init delay_value
; delay_init:
;                 lda     #0
;                 tax
;                 ldy     TICK100HZ
; .waittick:      cpy     TICK100HZ
;                 beq     .waittick
;                 iny
; .calloop:       cpx     #$ff                    ; 2
;                 inx                             ; 2
;                 adc     #0                      ; 2
;                 cpy     TICK100HZ               ; 4
;                 beq     .calloop                ; 3 = 25 per loop
;                 sta     delay_value+1
;                 txa
;                 clc
;                 adc     #8
;                 bcc     .nohiinc
;                 inc     delay_value+1
; .nohiinc:       ldx     #4
; .div16          lsr     delay_value+1
;                 ror     
;                 dex
;                 bne     .div16
;                 sta     delay_value+0
;                 rts

; *******************************************************
; * Initialized data
; *******************************************************
                section  .rodata

sd_cmd0_bytes   db      $40,$00,$00,$00,$00,$95
sd_cmd8_bytes   db      $48,$00,$00,$01,$aa,$87
sd_cmd55_bytes  db      $77,$00,$00,$00,$00,$01
sd_cmd41_bytes  db      $69,$40,$00,$00,$00,$01

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

sd_init_retries  ds      1
sd_cmd_retries   ds      1

sd_cmd_number   ds      1
sd_cmd_arg      ds      4

delay_value     ds      2               ; ~0.625ms delay loop count-up
