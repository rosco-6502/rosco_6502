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

; *******************************************************
; * Include routine table for this bank
; *******************************************************
        section .bank0.rtable
        include "rtable.asm"


; *******************************************************
; * RESET vector entry for this bank
; *******************************************************
        section .bank0.text
        include "defines.asm"

start:
        sei
        cld
        ldx #$ff
        txs

        ; Init DUART A
        lda #$a0          ; Enable extended TX rates
        sta DUA_CRA
        lda #$80          ; Enable extended RX rates
        sta DUA_CRA
        lda #$80          ; Select bit rate set 2
        sta DUA_ACR
        lda #$88          ; Select 115k2
        sta DUA_CSRA
        lda #$10          ; Select MR1A
        sta DUA_CRA
        lda #$13          ; No RTS, RxRDY, Char, No Parity, 8 bits
        sta DUA_MR1A
        lda #$07          ; Normal, No TX CTX/RTS, 1 stop bit
        sta DUA_MR2A
        lda #$05          ; Enable TX/RX port A
        sta DUA_CRA

;        ; Init DUART B
        lda #$a0          ; Enable extended TX rates
        sta DUA_CRB
        lda #$80          ; Enable extended RX rates
        sta DUA_CRB
        lda #$80          ; Select bit rate set 2
        sta DUA_ACR
        lda #$88          ; Select 115k2
        sta DUA_CSRB
        lda #$10          ; Select MR1B
        sta DUA_CRB
        lda #$13          ; No RTS, RxRDY, Char, No Parity, 8 bits
        sta DUA_MR1B
        lda #$07          ; Normal, No TX CTX/RTS, 1 stop bit
        sta DUA_MR2B
        lda #$05          ; Enable TX/RX port B
        sta DUA_CRB

        ; Set up timer tick
        lda #$F0          ; Enable timer XCLK/16
        sta DUA_ACR

        ; Timer will run at ~100Hz: 3686400 / 16 / (1152 * 2) = 100
        lda #$04          ; Counter MSB = 0x04
        sta DUA_CTU
        lda #$80          ; Counter LSB = 0x80
        sta DUA_CTL
        lda DUA_STARTC    ; Issue START COUNTER
        lda #$08          ; Unmask counter interrupt
        sta DUA_IMR

        lda #FLASHDELAY   ; Initial tick count is 100
        sta TICKCNT
        lda #0            ; Initial state is 0 (LED off)
        sta TICKSTT
        cli               ; Enable interrupts
 
        ; Do the banner
        jsr printbanner

        ; Do RAM bank checks
        jsr bankcheck

        ; Cycle ROM banks - this will end up switching back
        ; to this bank, and will jump in to bankenter0, continuing
        ; the boot process...
        lda #<EBANK
        ldx #>EBANK
        jsr printsz       ; Print message

        lda #$10          ; Switch to bank 1
        jmp bankswitch



; *******************************************************
; * Banner print
; *******************************************************
printbanner:
        ldy #$00          ; Start at first character

.loop
        ldx SZ_BANNER0,Y  ; Get character into x
        beq .done         ; If it's zero, we're done..
        jsr putc          ; otherwise, print it
        iny               ; next character
        bra .loop         ; and continue

.done
        rts


; *******************************************************
; * Basic test of the memory bank hardware
; *******************************************************
bankcheck:
        ldx #$00          ; Start at bank 0
.writeloop
        stx BANK_SET      ; Set bank register
        stx BANK_RAM_AD   ; Store bank num to start of bank...
        stx BANK_RAM_AD+BANK_RAM_SZ-1 ; ... and to end also
        inx               ; Next bank...
        cpx #$10          ; ... unless we're out of banks
        beq .read         ; (go to read if so)
        bra .writeloop    ; else loop for next bank.

.read
        ldx #$00          ; Start back at bank 0
.readloop
        stx BANK_SET      ; Set bank register
        cpx BANK_RAM_AD   ; Is first byte of bank the bank num?
        bne .failed       ; ... failed if not :-(
        cpx BANK_RAM_AD+BANK_RAM_SZ-1 ; Is last byte of bank the bank num?
        bne .failed       ; ... also failed if not :-(
        inx               ; Next bank...
        cpx #$10          ; ... unless we're out of banks
        beq .passed       ; (if so, we passed :-) )
        bra .readloop     ; else loop for next bank.

; If we reach this, the check passed!
.passed
        ldy #$00          ; Start at first character of message

.passloop
        ldx BCPASSED,Y    ; Get character at Y into X
        beq .done         ; If it's zero, we're done
        jsr putc          ; otherwise, print it
        iny               ; next character
        bra .passloop     ; and continue...

; If we get here, the check failed :-(
.failed
        ldy #$00          ; Start at first character of message
.failloop
        ldx BCFAILED,Y    ; Get character at Y into X
        beq .done         ; If it's zero, we're done
        jsr putc          ; otherwise, print it
        iny               ; next character
        bra .failloop     ; and continue...

; We're done.
.done
        rts


; *******************************************************
; * include common routines
; *******************************************************
        section .bank0.routines
        include "routines.asm"


; *******************************************************
; * Include bank switch code for this bank
; *******************************************************
        section .bank0.bank
        include "bank.asm"

bankenter0:
        lda #<PBANK
        ldx #>PBANK
        jsr printsz
        jmp WOZMON

          
; *******************************************************
; * Include IRQ handling for this bank
; *******************************************************
        section .bank0.irq
        include "irq.asm"


; *******************************************************
; * Include wozmon for this bank
; *******************************************************
        section .bank0.wozmon
        include "wozmon.asm"

; *******************************************************
; * Include vectors for this bank
; *******************************************************
        section .bank0.vectors
        include "vectors.asm"

; *******************************************************
; * Readonly data
; *******************************************************
        section .bank0.rodata
SZ_BANNER0      db      $D, $A, $1B, "[1;33m"
SZ_BANNER1      db      "                           ___ ___ ___ ___ ", $D
SZ_BANNER2      db      " ___ ___ ___ ___ ___      |  _| __|   |__ |", $D
SZ_BANNER3      db      "|  _| . |_ -|  _| . |     | . |__ | | | __|", $D
SZ_BANNER4      db      "|_| |___|___|___|___|_____|___|___|___|___|", $D 
SZ_BANNER5      db      "                    |_____|", $1B, "[1;37m System ", $1B, "[1;30m0.01.DEV", $1B, "[0m", $D, $D, 0
BCFAILED        db      $1B, "[0;37mRAM Bankcheck ", $1B, "[1;31mfailed", $1B, "[0m", $D, 0
BCPASSED        db      $1B, "[0;37mRAM Bankcheck ", $1B, "[1;32mpassed", $1B, "[0m", $D, 0
EBANK           db      $1B, "[0;37mROM Bank   #0 ", $1B, "[1;32mpassed", $1B, "[0m", $D, 0
PBANK           db      $1B, "[0;37mMemory checks ", $1B, "[1;32mpassed", $1B, "[0m", $D, 0

