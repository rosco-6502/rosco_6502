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
                phy
                phx
                pha

                tsx
                lda     $104,x	                ; get the status register from the stack
                and     #$10			; Isolate B status bit
                beq     .checktick  		; If B = 1, BRK detected
        
                jmp     HITBRK                  ; wozmon

.checktick
                ldx     TICKCNT                 ; Get tick count
                dex                             ; Decrement it
                txa                             ; copy new count to A
                asl                             ; shift out high bit
                bne     .done                   ; if non-zero, we're done

                ; If here, time to toggle green LED

                lda     #OP_LED_G               ; Set up to bit 6 (LED G) to set/clear
                bcc     .turnon                 ; if high bit was clear, turn on

                ; If here, LED is on
                ldx     #BLINKCOUNT             ; Reset tick count
                sta     DUA_OPR_C               ; Send command
                bra     .done
.turnon:
                ldx     #$80|BLINKCOUNT         ; Reset tick count OR'd with on flag
                sta     DUA_OPR_S               ; Send command
.done:
                stx     TICKCNT                 ; Store X as the new tick count
                inc     TICK100HZ
                jsr     USERTICK
                lda     DUA_STOPC               ; Send "stop timer" command (reset ISR[3])

                pla
                plx
                ply

                rti
