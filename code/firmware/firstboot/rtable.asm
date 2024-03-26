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
; Routine table, bios entry points callable from all ROM banks
;------------------------------------------------------------

UART_A_OUT:     	jmp     _uart_a_out     	; output character in A
UART_A_IN:      	jmp     _uart_a_in      	; C set when character returned in A
UART_B_OUT:     	jmp     _uart_b_out     	; output character in A
UART_B_IN:      	jmp     _uart_b_in      	; C set when character returned in A
PRINT_SZ:       	jmp     _printsz        	; print NUL terminated string in A/X (l/h)
