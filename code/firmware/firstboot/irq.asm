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
; IRQ handling code. This needs to be in all banks in the 
; big ROM, so it's included in each bank main file with
; an appropriate section that's used in the link script.
;------------------------------------------------------------

; *******************************************************
; Timer tick IRQ handler; Driven by DUART timer
; *******************************************************
irq_handler:
        pha               ; Stack A
        phx               ; Stack X

        ldx TICKCNT       ; Get tick count
        dex               ; Decrement it
        bne .done         ; If non-zero, we're done

        ; If here, time to toggle green LED

        ldx #FLASHDELAY   ; Reset tick count

        lda TICKSTT       ; Get current LED state
        beq .turnon       ; If it's off, go turn it on

        ; If here, LED is on
        lda #$20          ; Set up to clear bit 6
        sta DUA_OPR_C     ; Send command
        lda #0            ; LED is now off
        sta TICKSTT       ; Store state
        bra .done

.turnon
        lda #$20          ; Set up to set bit 6
        sta DUA_OPR_S     ; Send command
        lda #1            ; LED is now on
        sta TICKSTT       ; Store state

.done
        lda DUA_STOPC     ; Send "stop timer" command (reset ISR[3])
        stx TICKCNT       ; Store X as the new tick count
        plx               ; Unstack X
        pla               ; Unstack A
        rti

