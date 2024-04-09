; vim: set et ts=8 sw=8
;------------------------------------------------------------
;                            ___ ___ ___ ___
;  ___ ___ ___ ___ ___      |  _| __|   |__ |
; |  _| . |_ -|  _| . |     | . |__ | | | __|
; |_| |___|___|___|___|_____|___|___|___|___|
;                     |_____|    Bringup Code
;------------------------------------------------------------
; Copyright (c)2022 Ross Bamford and contributors
; See top-level LICENSE.md for licence information.
;
; Common code that needs to be at the same address in all ROM
; banks, so it's included after romtable at start.
;------------------------------------------------------------

; ROM bank test/init, call with A=ROM bank ($00, $10, $20, $30), X=arg
; Y trashed, returns C=1 if bank was not present (small ROM), value in X
_ROMINITFUNC:
                        pha
                        ldy     BANK_SET
                        phy
                        sta     BANK_SET
                        cmp     #CUR_ROMBANK<<BANK_ROM_B
                        beq     @bankmatch
                        ldx     #CUR_ROMBANK<<BANK_ROM_B
                        sec
                        bra     @done
@bankmatch:             jsr     bank_init
                        clc
@done:                  ply
                        sty     BANK_SET
                        pla
                        rts

reset_handler:
                        stz     BANK_SET
        .if CUR_ROMBANK=0
                        jmp     system_reset            ; call bank 0 system_reset
        .else
                        jmp     *                       ; should never be executed
        .endif


; *******************************************************
; Timer tick IRQ handler; Driven by DUART timer
; *******************************************************
irq_handler:
                        phy                             ; push in order expected by EWozMon
                        phx
                        pha

                        tsx
                        lda     $104,x                  ; get the status register from the stack
                        and     #$10                    ; check "fake" B status bit (only in P pushed on stack)
                        bne     brk_handler             ; if B = 1, call BRK handler (EWozMon)

                        ldx     BLINKCNT                ; Get tick count
                        dex                             ; Decrement it
                        txa                             ; copy new count to A
                        asl                             ; shift out high bit
                        bne     @done                   ; if non-zero, we're done

                        ; If here, time to toggle green LED
                        lda     #OP_LED_G               ; Set up to bit 6 (LED G) to set/clear
                        bcc     @turnon                 ; if high bit was clear, turn on

@turnoff:               ldx     #BLINKCOUNT             ; Reset tick count
                        sta     DUA_OPR_C               ; Send command
                        bra     @done

@turnon:                ldx     #$80|BLINKCOUNT         ; Reset tick count OR'd with on flag
                        sta     DUA_OPR_S               ; Send command

@done:                  stx     BLINKCNT                ; Store X as the new tick count

                        inc     TICK100HZ
                        bne     @nohitick
                        inc     TICK100HZ+1
                        bne     @nohitick
                        inc     TICK100HZ+2

@nohitick:              lda     DUA_STOPC               ; Send "stop timer" command (reset ISR[3])

                        jsr     USER_TICK               ; call user timer vector

                        pla
                        plx
                        ply
nmi_handler:
                        rti

; called from IRQ, transfers to EWozMon (only in bank 0), X has S
brk_handler:
                        ldy     BANK_SET                ; Y is BANK_SET upon BRK
                        tya
                        and     #<(~BANK_ROM_M)         ; set ROM bank to 0
                        sta     BANK_SET                ; set bank
        .if CUR_ROMBANK=0
                        jmp     WOZHITBRK               ; call bank 0 EWozMon
        .else
                        jmp     *                       ; should never be executed
        .endif
