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
; Routine table, routines callable from all ROM banks
;
;------------------------------------------------------------

; NOTE: It is expected this code is in all ROM banks at same address!

reset_handler:
                stz     BANK_SET        ; set bank 0
        ifnd    CUR_ROMBANK
                ds      3
        else
        if      CUR_ROMBANK==0
                jmp     system_reset    ; call bank 0 system_reset
        else
                jmp     reset_handler   ; should never be executed
        endif
        endif

UART_A_OUT:     jmp     _uart_a_out     ; output character in A
UART_A_IN:      jmp     _uart_a_in      ; C set when character returned in A
UART_B_OUT:     jmp     _uart_b_out     ; output character in A
UART_B_IN:      jmp     _uart_b_in      ; C set when character returned in A
PRINT_SZ:       jmp     _printsz        ; print NUL terminated string in A/X (l/h)

; ROM bank test/init, call with A=ROM bank ($00, $10, $20, $30)
; X, Y trashed, returns C=1 if bank not set (small ROM)
init_rom_bank:
                pha
                ldx     BANK_SET
                phx
                sta     BANK_SET
                jsr     bank_init       ; A has ROM bank to init
                plx
                stx     BANK_SET
                pla
                rts

; called from IRQ, transfers to EWozMon (only in bank 0), X has S
HITBRK:
                ldy     BANK_SET        ; A BANK_SET upon BRK
                tya
                and     #~BANK_ROM_M    ; set ROM bank to 0
                sta     BANK_SET        ; set bank
        ifnd    CUR_ROMBANK
                ds      3
        else
        if      CUR_ROMBANK==0
                jmp     WOZHITBRK       ; call bank 0 EWozMon
        else
                jmp     reset_handler   ; should never be executed
        endif
        endif
