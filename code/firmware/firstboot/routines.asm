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


; *******************************************************
; * Blocking putc to DUART. Character in X
; *******************************************************
putc:
        lda DUA_SRA       ; Check TXRDY bit
        and #4
        beq putc          ; Loop if not ready (bit clear)
        stx DUA_TBA       ; else, send character
        rts
        

; *******************************************************
; * Null-terminated string print
; *
; * Callable routine; A,X points to string (Low,High)
; * Trashes everything
; *******************************************************
printsz:
        sta $4            ; Low part of pointer to $4
        stx $5            ; High part of pointer to $5
        ldy #$00          ; Start at first character

.loop
        lda ($4),Y        ; Get character into x
        beq .done         ; If it's zero, we're done..
        tax
        jsr putc          ; otherwise, print it
        iny               ; next character
        bra .loop         ; and continue

.done
        rts

