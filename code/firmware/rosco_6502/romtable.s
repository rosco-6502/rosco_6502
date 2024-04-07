; vim: set et ts=8 sw=8
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

; R_<routine>   = rtable.inc routine table index
; <routine>     = address of routine JMP in ROM table
; _<routine>    = default destination address (if dest not specified)
;
; romvec <routine>[,<destaddr>]
.macro          romvec routine, destaddr
                .assert .ident(.sprintf("R_%s", .string(routine)))=((*-ROMTABLE)/3), error, .sprintf("R_%d", ((*-ROMTABLE)/3))
                .if CUR_ROMBANK=0
                        .global  routine
                .endif
                .if .PARAMCOUNT=2
routine:                jmp     destaddr
                .else
routine:                jmp     .ident(.sprintf("_%s", .string(routine)))
                .endif
                .endmacro

.macro          stub routine
                .assert .ident(.sprintf("R_%s", .string(routine)))=((*-ROMTABLE)/3), error, .sprintf("R_%d", ((*-ROMTABLE)/3))
routine:                sec
                        rts
                        nop
                .endmacro

ROMTABLE:
                        romvec  UART_A_SEND
                        romvec  UART_A_RECV
                        romvec  UART_A_STAT
                        stub    UART_A_CTRL
                        romvec  UART_B_SEND
                        romvec  UART_B_RECV
                        romvec  UART_B_STAT
                        stub    UART_B_CTRL
                        romvec  PRINT       
                        romvec  PRINTLN     
                        stub    READLINE    
                        romvec  PRBYTE      
                        romvec  PRDEC32     
                        romvec  VT_CLRSCR   
                        romvec  VT_MOVEXY   
                        romvec  VT_SETCURSOR
                        stub    ROMBANKFUNC 
