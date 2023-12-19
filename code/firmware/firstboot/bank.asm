;------------------------------------------------------------
;                            ___ ___ ___ ___ 
;  ___ ___ ___ ___ ___      |  _| __|   |__ |
; |  _| . |_ -|  _| . |     | . |__ | | | __|
; |_| |___|___|___|___|_____|___|___|___|___|
;                     |_____|    Bringup Code
;------------------------------------------------------------
; Copyright (c)2023 Ross Bamford and contributors
; See top-level LICENSE.md for licence information.
;
; Bank switch.
;------------------------------------------------------------


; Expects to be followed immediately by bank enter code 
; in each bank!
;
; Target bank byte in A
bankswitch:
        sta BANKS         ; Store new bank in memory 
        sta $DFFF         ; Set (write-only) bank register

        ; ... will continue to bank-specific entry code

