; vim: set et ts=8 sw=8
;------------------------------------------------------------
;                            ___ ___ ___ ___
;  ___ ___ ___ ___ ___      |  _| __|   |__ |
; |  _| . |_ -|  _| . |     | . |__ | | | __|
; |_| |___|___|___|___|_____|___|___|___|___|
;                     |_____|    Bringup Code
;------------------------------------------------------------
;
; Copyright (c)2022-2024 Ross Bamford and contributors
; See top-level LICENSE.md for licence information.
;
; Main code for ROM bank 0 (system bank)
;------------------------------------------------------------

CUR_ROMBANK     =       0       ; assemble for ROM bank 0

; *******************************************************
; * include system defines
; *******************************************************
                .include "defines.inc"
                .include "firmware.inc"

; *******************************************************
; * Include routine table for this bank
; *******************************************************
                .segment "ROMCOMMON0"
                .include "romtable.s"

; *******************************************************
; * Include IRQ handling for this bank
; *******************************************************
                .segment "ROMCOMMON0"
                .include "common.s"

; *******************************************************
; * Include vectors for this bank
; *******************************************************
                .segment "VECTORS0"
                .include "vectors.s"

; Above this point, all addresses must match between banks
; *******************************************************
; * Bank specific code
; *******************************************************
                .segment "ROM0"

; *******************************************************
; * System reset
; *******************************************************
;
; called on system RESET
;
                .import __FW_VARSTART__
                .import __FW_VARSIZE__
                .import __VECINIT_LOAD__
                .import __VECINIT_RUN__
                .import __VECINIT_SIZE__
                .import __THUNKINIT_LOAD__
                .import __THUNKINIT_RUN__
                .import __THUNKINIT_SIZE__

;                .export system_reset
system_reset:
                        sei
                        cld
                        ldx     #$ff
                        txs

                        ; Init DUART A
                        lda     #$a0                    ; Enable extended TX rates
                        sta     DUA_CRA
                        lda     #$80                    ; Enable extended RX rates
                        sta     DUA_CRA
                        lda     #$80                    ; Select bit rate set 2
                        sta     DUA_ACR
                        lda     #$88                    ; Select 115k2
                        sta     DUA_CSRA
                        lda     #$10                    ; Select MR1A
                        sta     DUA_CRA
                        lda     #$13                    ; No RTS, RxRDY, Char, No Parity, 8 bits
                        sta     DUA_MR1A
                        lda     #$07                    ; Normal, No TX CTX/RTS, 1 stop bit
                        sta     DUA_MR2A
                        lda     #$05                    ; Enable TX/RX port A
                        sta     DUA_CRA

                        ; Init DUART B
                        lda     #$a0                    ; Enable extended TX rates
                        sta     DUA_CRB
                        lda     #$80                    ; Enable extended RX rates
                        sta     DUA_CRB
                        lda     #$80                    ; Select bit rate set 2
                        sta     DUA_ACR
                        lda     #$88                    ; Select 115k2
                        sta     DUA_CSRB
                        lda     #$10                    ; Select MR1B
                        sta     DUA_CRB
                        lda     #$13                    ; No RTS, RxRDY, Char, No Parity, 8 bits
                        sta     DUA_MR1B
                        lda     #$07                    ; Normal, No TX CTX/RTS, 1 stop bit
                        sta     DUA_MR2B
                        lda     #$05                    ; Enable TX/RX port B
                        sta     DUA_CRB

                        stz     DUA_OPCR                ; set OP to normal outputs

                        lda     #OP_LED_R|OP_LED_G
                        sta     DUA_OPR_S               ; flash red LED

                        ; Set up timer tick
                        lda     #$F0                    ; Enable timer XCLK/16
                        sta     DUA_ACR

                        ; Timer will run at ~100Hz: 3686400 / 16 / (1152 * 2) = 100
                        lda     #$04                    ; Counter MSB = 0x04
                        sta     DUA_CTU
                        lda     #$80                    ; Counter LSB = 0x80
                        sta     DUA_CTL
                        lda     DUA_STARTC              ; Issue START COUNTER
                        lda     #$08                    ; Unmask counter interrupt
                        sta     DUA_IMR

                        ; setup low RAM vectors and thunks

                        ldx     #$00
@clearvar:              stz     __FW_VARSTART__,x
                        inx
                        bne     @clearvar

;                        ldx     #0
@vecinit:               lda     __VECINIT_LOAD__,x
                        sta     __VECINIT_RUN__,x
                        inx
                        cpx     #<__VECINIT_SIZE__
                        bne     @vecinit

                        ldx     #0
@thunkinit:             lda     __THUNKINIT_LOAD__,x
                        sta     __THUNKINIT_RUN__,x
                        inx
                        cpx     #<__THUNKINIT_SIZE__
                        bne     @thunkinit

                        lda     #$80|BLINKCOUNT         ; set initial tick count
                        sta     BLINKCNT

                        cli                             ; Enable interrupts

                        ; Do the banner
                        lda     #<SZ_BANNER0
                        ldx     #>SZ_BANNER0
                        jsr     _PRINT

                        ; print system info
                        lda     #<SYSINFO0
                        ldx     #>SYSINFO0
                        jsr     _PRINT

                        stz     FW_ZP_TMPPTR
                        stz     FW_ZP_TMPPTR+1
                        ldx     TICK100HZ
@tickwait:              cpx     TICK100HZ
                        beq     @tickwait
                        ldx     TICK100HZ
                        ; 10ms calibrated loop where result is $MMxx where $MM is approx@ MHz
@timeloop:              jsr     an_rts                  ; 12
                        lda     FW_ZP_TMPPTR            ; 3
                        clc                             ; 2
                        adc     #1                      ; 2
                        sta     FW_ZP_TMPPTR            ; 3
                        lda     FW_ZP_TMPPTR+1          ; 3
                        adc     #0                      ; 2
                        sta     FW_ZP_TMPPTR+1          ; 3
                        cpx     TICK100HZ               ; 4
                        beq     @timeloop               ; 3 = 37 per iteration

                        stz     PR_PAD
                        stz     PR_PAD
                        lda     FW_ZP_TMPPTR+1
                        sta     CPUMHZ
                        sta     DWORD_VAL0
                        ; stz     DWORD_VAL1
                        ; stz     DWORD_VAL2
                        ; stz     DWORD_VAL3
                        jsr     _PRDEC_U32

                        lda     #<TEMPBUF16
                        ldx     #>TEMPBUF16
                        jsr     _PRINT

                        lda     #<SYSINFO1
                        ldx     #>SYSINFO1
                        jsr     _PRINT

                        lda     #OP_LED_R
                        sta     DUA_OPR_C               ; red LED off

                        ; check if 8KB or 32KB (8KBx4 banks) of ROM
                        lda     #$80|(3<<BANK_ROM_B)
                        ldx     #0
                        jsr     ROMINITFUNC             ; expected to fail on r4
                        lda     #'1'
                        cpx     #3<<BANK_ROM_B          ; was ROM 3 mapped?
                        bne     @smallrom
                        lda     #'4'
@smallrom:              jsr     PRINTCHAR

                        lda     #<SYSINFO2
                        ldx     #>SYSINFO2
                        jsr     _PRINT

                        ; Do RAM banks check
                        jsr     bank_check

                        ; do ROM bank init
                        lda     #0<<BANK_ROM_B
@romloop:               ldx     #0                      ; X passed to bank_init (0 = init)
                        jsr     ROMINITFUNC             ; A = bank << ROM_BANK_B
                        clc
                        adc     #1<<BANK_ROM_B
                        cmp     #ROM_BANKS<<BANK_ROM_B
                        bne     @romloop

                        ; tests passed
                        lda     #<PBANK
                        ldx     #>PBANK
                        jsr     _PRINT
 
                .if     1
                        lda     #<SDCHECKMSG
                        ldx     #>SDCHECKMSG
                        jsr     _PRINT
                        jsr     BD_CTRL                 ; init SD card
                        bcc     @sdcardok
@sdfail:                lda     #<NOTFOUNDMSG
                        ldx     #>NOTFOUNDMSG
                        jsr     _PRINT
                        bra     @monitor
@sdcardok:
                        lda     #<OKMSG
                        ldx     #>OKMSG
                        jsr     _PRINT
                        lda     #<SDBOOTMSG
                        ldx     #>SDBOOTMSG
                        jsr     _PRINT
                        jsr     FS_CTRL                 ; init FAT32
                        bcs     @sdfail

                        lda     #<BOOTFILENAME
                        ldx     #>BOOTFILENAME
                        jsr     FS_OPEN                 ; open filepath in A/X
                        bcs     @sdfail

                        lda     #<OKMSG
                        ldx     #>OKMSG
                        jsr     _PRINT

                        lda     #<LOADINGMSG
                        ldx     #>LOADINGMSG
                        jsr     _PRINT

                        lda     FS_ZP_BYTESLEFT+3
                        sta     DWORD_VAL+3
                        lda     FS_ZP_BYTESLEFT+2
                        sta     DWORD_VAL+2
                        lda     FS_ZP_BYTESLEFT+1
                        sta     DWORD_VAL+1
                        lda     FS_ZP_BYTESLEFT+0
                        sta     DWORD_VAL+0

                        lda     #0
                        sta     PR_WIDTH
                        sta     PR_PAD
                        jsr     _PRDEC_U32

                        lda     #<BYTESMSG
                        ldx     #>BYTESMSG
                        jsr     _PRINT

                        lda     #<$0800
                        sta     FS_ZP_ADDRPTR
                        lda     #>$0800
                        sta     FS_ZP_ADDRPTR+1

                        jsr     FS_READFILE             ; at $C000 ptr back to $4000 and inc bank (stops after bank 15)
                        bcc     @bootok

                        lda     #<FAILEDMSG
                        ldx     #>FAILEDMSG
                        jsr     _PRINT
                        bra     @monitor
@bootok:
                        lda     #<OKMSG
                        ldx     #>OKMSG
                        jsr     _PRINT

                        lda     #<STARTINGMSG
                        ldx     #>STARTINGMSG
                        jsr     _PRINT

                        jsr     clearuart
                        jsr     $0800

                .endif

@monitor:               ; start in EWozMon
                        jmp     WOZMON

                        ; rts


                        ; clear junk chars
clearuart:
                        ldx     #0
@uartloop:
                        lda     DUA_SRA
                        nop
                        nop
                        lda     DUA_RBA
                        nop
                        nop
                        lda     DUA_SRA
                        nop
                        nop
                        lda     DUA_RBA
                        dex
                        bne     @uartloop
                        rts


; *******************************************************
; * Bank init/test
; *******************************************************
bank_init:
                        lda     #<EBANK
                        ldx     #>EBANK
                        jsr     _PRINT                ; Print message
an_rts:                 rts

; *******************************************************
; * non-destructive basic test of RAM memory banks
; *******************************************************
                .export bank_check
bank_check:
                        ldx     #RAM_BANKS-1            ; Start at banks-1
@writeloop:
                        stx     BANK_SET                ; Set bank register
                        lda     BANK_RAM_ADDR             ; get RAM value
                        sta     INPUTBUF,x              ; preserve RAM value
                        stx     BANK_RAM_ADDR             ; Store bank num to start of bank
                        lda     BANK_RAM_ADDR+BANK_RAM_SIZE-1 ; get RAM value
                        sta     INPUTBUF+RAM_BANKS,x    ; preserve RAM value
                        stx     BANK_RAM_ADDR+BANK_RAM_SIZE-1 ; store to end of bank
                        dex                             ; Next bank...
                        bpl    @writeloop               ; loop if >= 0
@read:
                        ldx     #RAM_BANKS-1            ; Start at banks-1
@readloop:
                        stx     BANK_SET                ; Set bank register
                        cpx     BANK_RAM_ADDR             ; Is first byte of bank the bank num?
                        bne     @failed                 ; ... failed if not :-(
                        lda     INPUTBUF,x              ; get old RAM value
                        sta     BANK_RAM_ADDR             ; restore RAM value
                        cpx     BANK_RAM_ADDR+BANK_RAM_SIZE-1 ; Is last byte of bank the bank num?
                        bne     @failed                 ; ... also failed if not :-(
                        lda     INPUTBUF+RAM_BANKS,x    ; get old RAM value
                        sta     BANK_RAM_ADDR+BANK_RAM_SIZE-1 ; restore RAM value
                        dex                             ; Next bank...
                        bpl     @readloop               ; loop if >= 0

; If we reach this, the check passed!
@passed:
                        lda     #<BCPASSED
                        ldx     #>BCPASSED
                        jmp     _PRINT
                        ; rts

; If we get here, the check failed :-(
@failed:
                        lda     #<BCFAILED
                        ldx     #>BCFAILED
                        jmp     _PRINT
                        ; rts

; *******************************************************
; * SD card routines
; *******************************************************
                .include "duart_spi.s"
                .include "sd_card.s"

; *******************************************************
; * filesystem routines
; *******************************************************
                .include "fat32_readonly.s"

; *******************************************************
; * Include wozmon
; *******************************************************
                .include "wozmon.s"

; *******************************************************
; * include common routines
; *******************************************************
                .include "routines.s"

; *******************************************************
; * RAM data to be copied to low-RAM
; *******************************************************
                .include "ramtable.s"

; *******************************************************
; * Readonly data
; *******************************************************
                .segment "RODATA0"

SZ_BANNER0:             .byte   $D, $A, $1B, "[1;33m"
SZ_BANNER1:             .byte   "                           ___ ___ ___ ___ ", $D, $A
SZ_BANNER2:             .byte   " ___ ___ ___ ___ ___      |  _| __|   |__ |", $D, $A
SZ_BANNER3:             .byte   "|  _| . |_ -|  _| . |     | . |__ | | | __|", $D, $A
SZ_BANNER4:             .byte   "|_| |___|___|___|___|_____|___|___|___|___|", $D, $A
SZ_BANNER5:             .byte   "                    |_____|", $1B, "[1;37m System ", $1B, "[1;30m0.03.DEV", $1B, "[0m", $D, $A, $D, $A, 0
SYSINFO0:               .byte   "W65C02S CPU @ ", 0
SYSINFO1:               .byte   "MHz with 16KB+16x32KB RAM and ", 0
SYSINFO2:               .byte   "x8KB ROM", $D, $A, 0
BCFAILED:               .byte   $1B, "[0;37mRAM Banks 0-15 ", $1B, "[1;31mfailed", $1B, "[0m", $D, $A, 0
BCPASSED:               .byte   $1B, "[0;37mRAM Banks 0-15 ", $1B, "[1;32mpassed", $1B, "[0m", $D, $A, 0
EBANK:                  .byte   $1B, "[0;37mROM 8K Bank #0 ", $1B, "[1;32mpassed", $1B, "[0m (BIOS+Monitor)", $D, $A, 0
PBANK:                  .byte   $1B, "[0;37mMemory checks: ", $1B, "[1;32mpassed", $1B, "[0m", $D, $A, 0
SDCHECKMSG:             .byte   "Checking for SDHC media...", 0
SDBOOTMSG:              .byte   "Checking for \"/ROSC0DE_6502.BIN\"...", 0
LOADINGMSG:             .byte   "Loading ", 0
BYTESMSG:               .byte   " bytes to $0800...", 0
OKMSG:                  .byte   "OK", $D, $A, 0
FAILEDMSG:              .byte   "Failed", $D, $A, 0
NOTFOUNDMSG:            .byte   "Not found", $D, $A, 0
STARTINGMSG:            .byte   "Starting...", $D, $A, $D, $A, 0
BOOTFILENAME:           .byte   "/ROSC0DE_6502.BIN", 0          ; up to ~512KB starting at $0800 (will increment RAM bank)
