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
; Common routines.
;
; These are pointed to by the routine table at the bottom
; of every bank, and must be included in each bank.
;
; The **don't** need to be at fixed addresses within the
; banks, since the routine table will point to them.
;------------------------------------------------------------

; NOTE: To save size, UART A and B could be combined (with index)

; *******************************************************
; * Blocking output to DUART A. Character in A
; *******************************************************
_uart_a_out:
                        pha                     ; save character

.loop                   lda     DUA_SRA         ; load UART A staus
                        and     #4              ; check TXRDY bit
                        beq     .loop           ; loop if not ready (bit clear)

                        pla                     ; restore character
                        sta     DUA_TBA         ; send character to UART B

                        rts

; *******************************************************
; * Blocking output to DUART B. Character in A
; *******************************************************
_uart_b_out:
                        pha                     ; save character

.loop                   lda     DUA_SRB         ; load UART A staus
                        and     #4              ; check TXRDY bit
                        beq     .loop           ; loop if not ready (bit clear)

                        pla                     ; restore character
                        sta     DUA_TBB         ; send character to UART B

                        rts

; *******************************************************
; * Non-blocking getc for DUART A. if C=1 then character in A
; *******************************************************
_uart_a_in:
                        lda     DUA_SRA         ; load UART B status
                        ror                     ; check RXRDY bit (shift into carry)
                        bcc     .done           ; return with C clear if not ready

                        lda     DUA_RBA         ; get UART A character

.done                   rts

; *******************************************************
; * Non-blocking getc for DUART A. if C=1 then character in A
; *******************************************************
_uart_b_in:
                        lda     DUA_SRB         ; load UART B status
                        ror                     ; check RXRDY bit (shift into carry)
                        bcc     .done           ; return with C clear if not ready

                        lda     DUA_RBB         ; get UART B character

.done                   rts

; *******************************************************
; * Null-terminated string print
; *
; * Callable routine; A,X points to string (Low,High)
; * Trashes A, X
; *******************************************************
_printsz:
                        phy
                        ldy     FW_ZP_TMPPTR
                        phy
                        ldy     FW_ZP_TMPPTR+1
                        phy
                        sta     FW_ZP_TMPPTR       ; ptr low
                        stx     FW_ZP_TMPPTR+1     ; ptr high
                        ldy     #$00            ; Start at first character
.printloop:             lda     (FW_ZP_TMPPTR),Y   ; Get character into A
                        beq     .printdone      ; If it's zero, we're done..
                        jsr     COUT            ; otherwise, print it
                        iny                     ; next character
                        bne     .printloop      ; and continue (unless Y wraps)
.printdone:             ply
                        sty     FW_ZP_TMPPTR+1
                        ply
                        sty     FW_ZP_TMPPTR+1
                        ply
                        rts

