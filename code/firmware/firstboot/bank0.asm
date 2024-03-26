;------------------------------------------------------------
;                            ___ ___ ___ ___
;  ___ ___ ___ ___ ___      |  _| __|   |__ |
; |  _| . |_ -|  _| . |     | . |__ | | | __|
; |_| |___|___|___|___|_____|___|___|___|___|
;                     |_____|    Bringup Code
;------------------------------------------------------------
; Copyright (c)2022-2024 Ross Bamford and contributors
; See top-level LICENSE.md for licence information.
;
; Main code for ROM bank 0 (system bank)
;------------------------------------------------------------
CUR_ROMBANK             =       0       ; assemble for ROM bank 0

; *******************************************************
; * include system defines
; *******************************************************
                include "defines.asm"

; *******************************************************
; * Include routine table for this bank
; *******************************************************
                section .bank0.rtable
                include "rtable.asm"

; *******************************************************
; * Include IRQ handling for this bank
; *******************************************************
                section .bank0.irq
                include "irq.asm"

; *******************************************************
; * Include vectors for this bank
; *******************************************************
                section .bank0.vectors
                include "vectors.asm"

; Above this point, all addresses must match between banks

; *******************************************************
; * Bank specific code
; *******************************************************
                section .bank0.text

; *******************************************************
; * Bank init/test
; *******************************************************
bank_init:
                        lda     #<EBANK
                        ldx     #>EBANK
                        jsr     PRINT_SZ                ; Print message
an_rts:                 rts

;
; called on system RESET
;
system_reset:
                        sei
                        cld
                        ldx     #$ff
                        txs
                        stz     BANK_SET

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

                        ; set bios I/O vectors
                        lda     #$4C                    ; JMP opcode
                        sta     COUT
                        sta     CIN
                        lda     #<UART_A_OUT
                        sta     COUT+1
                        lda     #>UART_A_OUT
                        sta     COUT+2
                        lda     #<UART_A_IN
                        sta     CIN+1
                        lda     #>UART_A_IN
                        sta     CIN+2

                        ; set bios time variables
                        lda     #$60                    ; RTS opcode
                        sta     USER_TICK
                        stz     USER_TICK+1
                        stz     USER_TICK+2
                        lda     #BLINKCOUNT             ; set initial tick count
                        sta     TICKCNT
                        stz     TICK100HZ               ; clear timer
                        stz     TICK100HZ+1
                        stz     TICK100HZ+2

                        cli                             ; Enable interrupts

                        ; Do the banner
                        lda     #<SZ_BANNER0
                        ldx     #>SZ_BANNER0
                        jsr     PRINT_SZ

                        ; print system info
                        lda     #<SYSINFO0
                        ldx     #>SYSINFO0
                        jsr     PRINT_SZ

                        stz     FW_ZP_TMPPTR
                        stz     FW_ZP_TMPPTR+1
                        ldx     TICK100HZ
.tickwait               cpx     TICK100HZ
                        beq     .tickwait
                        ldx     TICK100HZ
                        ; 10ms calibrated loop where result is $MMxx where $MM is approx. MHz
.timeloop               jsr     an_rts                  ; 12
                        lda     FW_ZP_TMPPTR            ; 3
                        clc                             ; 2
                        adc     #1                      ; 2
                        sta     FW_ZP_TMPPTR            ; 3
                        lda     FW_ZP_TMPPTR+1          ; 3
                        adc     #0                      ; 2
                        sta     FW_ZP_TMPPTR+1          ; 3
                        cpx     TICK100HZ               ; 4
                        beq     .timeloop               ; 3 = 37 per iteration

                        ldx     #'0'
                        lda     FW_ZP_TMPPTR+1
.tencnt                 cmp     #10
                        bcc     .tensdone
                        inx
                        sbc     #10
                        bne     .tencnt
.tensdone               pha
                        txa
                        cmp     #'0'
                        beq     .notens
                        jsr     COUT
.notens                 pla
                        ora     #'0'
                        jsr     COUT

                        lda     #<SYSINFO1
                        ldx     #>SYSINFO1
                        jsr     PRINT_SZ

                        ; check if 8KB or 32KB (8KBx4 banks) of ROM
                        lda     #$80|(3<<BANK_ROM_B)
                        tay
                        jsr     init_rom_bank
                        lda     #'1'
                        bcc     .smallrom
                        cpy     #3<<BANK_ROM_B
                        bne     .smallrom
                        lda     #'4'
.smallrom               jsr     COUT

                        lda     #<SYSINFO2
                        ldx     #>SYSINFO2
                        jsr     PRINT_SZ

                        ; Do RAM banks check
                        jsr     bankcheck

                        ; do ROM bank init
                        lda     #0<<BANK_ROM_B
.romloop                jsr     init_rom_bank           ; X = bank << ROM_BANK_B
                        clc
                        adc     #1<<BANK_ROM_B
                        cmp     #ROM_BANKS<<BANK_ROM_B
                        blt     .romloop

                        ; tests passed
                        lda     #<PBANK
                        ldx     #>PBANK
                        jsr     PRINT_SZ

                        ; start in EWozMon
                        jmp     WOZMON

; *******************************************************
; * non-destructive basic test of RAM memory banks
; *******************************************************
bankcheck:
                        ldx     #RAM_BANKS-1            ; Start at banks-1
.writeloop
                        stx     BANK_SET                ; Set bank register
                        lda     BANK_RAM_AD             ; get RAM value
                        sta     INPUTBUF,x              ; preserve RAM value
                        stx     BANK_RAM_AD             ; Store bank num to start of bank
                        lda     BANK_RAM_AD+BANK_RAM_SZ-1 ; get RAM value
                        sta     INPUTBUF+RAM_BANKS,x    ; preserve RAM value
                        stx     BANK_RAM_AD+BANK_RAM_SZ-1 ; store to end of bank
                        dex                             ; Next bank...
                        bpl    .writeloop               ; loop if >= 0
.read
                        ldx     #RAM_BANKS-1            ; Start at banks-1
.readloop
                        stx     BANK_SET                ; Set bank register
                        cpx     BANK_RAM_AD             ; Is first byte of bank the bank num?
                        bne     .failed                 ; ... failed if not :-(
                        lda     INPUTBUF,x              ; get old RAM value
                        sta     BANK_RAM_AD             ; restore RAM value
                        cpx     BANK_RAM_AD+BANK_RAM_SZ-1 ; Is last byte of bank the bank num?
                        bne     .failed                 ; ... also failed if not :-(
                        lda     INPUTBUF+RAM_BANKS,x    ; get old RAM value
                        sta     BANK_RAM_AD+BANK_RAM_SZ-1 ; restore RAM value
                        dex                             ; Next bank...
                        bpl     .readloop               ; loop if >= 0

; If we reach this, the check passed!
.passed
                        lda     #<BCPASSED
                        ldx     #>BCPASSED
                        jmp     PRINT_SZ
                        ; rts

; If we get here, the check failed :-(
.failed
                        lda     #<BCFAILED
                        ldx     #>BCFAILED
                        jmp     PRINT_SZ
                        ; rts

; *******************************************************
; * Include wozmon
; *******************************************************
                include "wozmon.asm"

; *******************************************************
; * include common routines
; *******************************************************
                include "routines.asm"

; *******************************************************
; * Readonly data
; *******************************************************
                section .bank0.rodata

SZ_BANNER0              db      $D, $A, $1B, "[1;33m"
SZ_BANNER1              db      "                           ___ ___ ___ ___ ", $D, $A
SZ_BANNER2              db      " ___ ___ ___ ___ ___      |  _| __|   |__ |", $D, $A
SZ_BANNER3              db      "|  _| . |_ -|  _| . |     | . |__ | | | __|", $D, $A
SZ_BANNER4              db      "|_| |___|___|___|___|_____|___|___|___|___|", $D, $A
SZ_BANNER5              db      "                    |_____|", $1B, "[1;37m System ", $1B, "[1;30m0.02.DEV", $1B, "[0m", $D, $A, $D, $A, 0
SYSINFO0                db      "W65C02S CPU @ ", 0
SYSINFO1                db      "MHz with 16KB+16x32KB RAM and ", 0
SYSINFO2                db      "x8KB ROM", $D, $A, 0
BCFAILED                db      $1B, "[0;37mRAM Bankcheck ", $1B, "[1;31mfailed", $1B, "[0m", $D, $A, 0
BCPASSED                db      $1B, "[0;37mRAM Bankcheck ", $1B, "[1;32mpassed", $1B, "[0m", $D, $A, 0
EBANK                   db      $1B, "[0;37mROM Bank   #0 ", $1B, "[1;32mpassed", $1B, "[0m (BIOS+Monitor)", $D, $A, 0
PBANK                   db      $1B, "[0;37mMemory checks ", $1B, "[1;32mpassed", $1B, "[0m", $D, $A, 0
