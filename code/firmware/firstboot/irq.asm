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
                phy                             ; push in order expected by EWozMon
                phx
                pha

                tsx
                lda     $104,x	                ; get the status register from the stack
                and     #$10			; check "fake" B status bit (only in P pushed on stack)
                beq     .checktick  		; if B = 1, BRK detected
        
                jmp     HITBRK                  ; call EWozMon for BRK

.checktick      ldx     TICKCNT                 ; Get tick count
                dex                             ; Decrement it
                txa                             ; copy new count to A
                asl                             ; shift out high bit
                bne     .done                   ; if non-zero, we're done

                ; If here, time to toggle green LED
                lda     #OP_LED_G               ; Set up to bit 6 (LED G) to set/clear
                bcc     .turnon                 ; if high bit was clear, turn on

.turnoff        ldx     #BLINKCOUNT             ; Reset tick count
                sta     DUA_OPR_C               ; Send command
                bra     .done

.turnon         ldx     #$80|BLINKCOUNT         ; Reset tick count OR'd with on flag
                sta     DUA_OPR_S               ; Send command

.done           stx     TICKCNT                 ; Store X as the new tick count

                inc     TICK100HZ
                bne     .nohitick
                inc     TICK100HZ+1
                bne     .nohitick
                inc     TICK100HZ+2

.nohitick       lda     DUA_STOPC               ; Send "stop timer" command (reset ISR[3])

                jsr     USER_TICK               ; call user timer vector

                pla
                plx
                ply
nmi_handler:                                    ; use RTI as NOP NMI handler
                rti
