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
; Initial bringup and basic testing code for the board.
;------------------------------------------------------------

DUA_MR1A    = $c000
DUA_MR2A    = $c000
DUA_SRA     = $c001
DUA_CSRA    = $c001
DUA_CRA     = $c002 
DUA_TBA     = $c003
DUA_ACR     = $c004
DUA_IMR     = $c005
DUA_CTUR    = $c006
DUA_CTLR    = $c007
DUA_OPR_S   = $c00e
DUA_STARTC  = $c00e
DUA_OPR_C   = $c00f
DUA_STOPC   = $c00f

TICKCNT     = $0          ; Stash tick count at bottom of RAM for now...
TICKSTT     = $1          ; Tick state at 0x1 for now..
