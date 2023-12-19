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
; Routine table - goes at the bottom of every bank.
;
; Actual implementations (which must also go in every bank)
; are in routines.asm...
;------------------------------------------------------------

routines:
R_PUTC      dw              putc
R_GETC      dw              0
R_PRINTSZ   dw              printsz
R_BANK      dw              bankswitch

