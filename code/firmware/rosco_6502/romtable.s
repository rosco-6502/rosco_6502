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
; Routine table, BIOS entry points callable from all ROM banks
;------------------------------------------------------------

; R_<routine>   = rtable.inc routine table index
; <routine>     = address of routine JMP in ROM table
; _<routine>    = default destination address (if dest not specified)
;
; romvec <routine>[,<destaddr>]
.macro          romvec routine, destaddr
                .assert (routine-ROMTABLE)=(*-_ROMTABLE), error, .sprintf("%s not #%d", .string(routine), (routine-ROMTABLE)/3)
                .if CUR_ROMBANK=0
;                        .export  routine
                .endif
                .if .PARAMCOUNT=2
                        jmp     destaddr
                .else
                        jmp     .ident(.sprintf("_%s", .string(routine)))
                .endif
                .endmacro

                .assert (_ROMTABLE=ROMTABLE),error,"ROMTABLE mismatch"
_ROMTABLE:
                        romvec  ROMINITFUNC
                        romvec  UART_A_CTRL,_STUB
                        romvec  UART_A_SEND
                        romvec  UART_A_RECV
                        romvec  UART_A_STAT
                        romvec  UART_B_CTRL,_STUB
                        romvec  UART_B_SEND
                        romvec  UART_B_RECV
                        romvec  UART_B_STAT
                        romvec  PRINT
                        romvec  PRINTLN
                        romvec  READLINE
                        romvec  PRHEX_U8
                        romvec  PRDEC_U32
                        romvec  VT_CLRSCR
                        romvec  VT_MOVEXY
                        romvec  VT_SETCURSOR
                        romvec  SD_CTRL,_STUB
                        romvec  SD_READ,_STUB
                        romvec  SD_WRITE,_STUB
                        romvec  FAT_CTRL,_STUB
                        romvec  FAT_OPEN,_STUB
                        romvec  FAT_READDIRENT,_STUB
                        romvec  FAT_READ,_STUB
                        romvec  FAT_SEEK,_STUB
                        romvec  FAT_WRITE,_STUB
                        romvec  FAT_CLOSE,_STUB
