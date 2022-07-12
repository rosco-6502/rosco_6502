
        section .data
        ORG 0

        section .text
        ORG $e000

DUA_MR1A    = $c000
DUA_MR2A    = $c000
DUA_SRA     = $c001
DUA_CSRA    = $c001
DUA_CRA     = $c002 
DUA_TBA     = $c003
DUA_ACR     = $c004
DUA_OPR_S   = $c00e
DUA_OPR_C   = $c00f

start:
        sei
        cld
        lda #$ff
        txs

        ; Init DUART
        lda #$a0          ; Enable extended TX rates
        sta DUA_CRA
        lda #$80          ; Enable extended RX rates
        sta DUA_CRA
        lda #$80          ; Select bit rate set 2
        sta DUA_ACR
        lda #$88          ; Select 115k2
        sta DUA_CSRA
        lda #$13          ; No RTS, RxRDY, Char, No Parity, 8 bits
        sta DUA_MR1A
        lda #$07          ; Normal, No TX CTX/RTS, 1 stop bit
        sta DUA_MR2A
        lda #$05          ; Enable TX/RX port A
        sta DUA_CRA

        ; Do the banner
        jsr printbanner

        ; Go to flash lop
.flash:
        lda #$08
        sta DUA_OPR_S
    
        ldy #$FF          ; (2 cycles)
        ldx #$FF          ; (2 cycles)
.delay:  
        dex               ; (2 cycles)
        bne .delay        ; (3 cycles in loop, 2 cycles at end)
        dey               ; (2 cycles)
        bne .delay        ; (3 cycles in loop, 2 cycles at end)

        lda #$08
        sta DUA_OPR_C

        ldy #$FF          ; (2 cycles)
        ldx #$FF          ; (2 cycles)
.delay2:
        dex               ; (2 cycles)
        bne .delay2       ; (3 cycles in loop, 2 cycles at end)
        dey               ; (2 cycles)
        bne .delay2       ; (3 cycles in loop, 2 cycles at end)

        bra .flash

printbanner:
        ldy #$00

.loop
        ldx SZ_BANNER0,Y
        beq .done
        jsr putc
        iny
        bra .loop

.done
        rts
        
; blocking putc to DUART. Character in X.
putc:
        lda DUA_SRA
        and #4
        beq putc
        stx DUA_TBA       ; Send character
        rts
      
SZ_BANNER0      db      $D, $A, $1B, "[1;33m"
SZ_BANNER1      db      "                           ___ ___ ___ ___ ", $D, $A
SZ_BANNER2      db      " ___ ___ ___ ___ ___      |  _| __|   |__ |", $D, $A
SZ_BANNER3      db      "|  _| . |_ -|  _| . |     | . |__ | | | __|", $D, $A
SZ_BANNER4      db      "|_| |___|___|___|___|_____|___|___|___|___|", $D, $A
SZ_BANNER5      db      "                    |_____|", $1B, "[1;37mBringup ", $1B, "[1;30m0.01.DEV", $1B, "[0m", $D, $A, 0

        ORG $fffc

RESET           dw      start
IRQ             dw      $00E0

