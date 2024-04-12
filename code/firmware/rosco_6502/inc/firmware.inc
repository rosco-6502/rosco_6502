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
; rosco_6502 hardware and firmware BIOS defines
;------------------------------------------------------------

                .list   off
                .macpack generic
                .macpack longbranch

.macro          jra     Target
                .if     .def(Target) .and ((*+2)-(Target) <= 127)
                bra     Target
                .else
                jmp     Target
                .endif
.endmacro
                .list   on

; call ROM0 function using thunk function (13 bytes overhead)
.macro          r0call  routine
.ident(.sprintf("_%s", .string(routine))):
                        sty     FW_ZP_BANKTEMP
                        ldy     #<routine
                .assert (>routine)=(>_ROMTABLE),error,"routine must be in first page"
                        jmp     THUNK_ROM0
.endmacro

; misc constants
BLINKCOUNT              =       50              ; interrupt count between LED toggles
