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
; rosco_6502 hardware and firmware "bios" defines
;------------------------------------------------------------

; XR68C681P DUART registers
DUA_MR1A        =       $c000           ; R/W
DUA_MR2A        =       $c000           ; R/W
DUA_SRA         =       $c001           ; R
DUA_CSRA        =       $c001           ; W
DUA_MISR        =       $c002           ; R
DUA_CRA         =       $c002           ; W
DUA_RBA         =       $c003           ; R (aka RHRA)
DUA_TBA         =       $c003           ; W (aka THRA)
DUA_IPCR        =       $c004           ; R
DUA_ACR         =       $c004           ; W
DUA_ISR         =       $c005           ; R
DUA_IMR         =       $c005           ; W
DUA_CTU         =       $c006           ; R/W
DUA_CTL         =       $c007           ; R/W
DUA_MR1B        =       $c008           ; R/W
DUA_MR2B        =       $c008           ; R/W
DUA_SRB         =       $c009           ; R
DUA_CSRB        =       $c009           ; W
; reserved      =       $c00A           ; R
DUA_CRB         =       $c00A           ; W
DUA_RBB         =       $c00b           ; R (aka RHRB)
DUA_TBB         =       $c00b           ; W (aka THRB)
DUA_IVR         =       $c00c           ; R/W
DUA_IP          =       $c00d           ; R
DUA_OPCR        =       $c00d           ; W
DUA_STARTC      =       $c00e           ; R (start timer)
DUA_OPR_S       =       $c00e           ; W (set OPRn, OPn = LO)
DUA_OPR_LO      =       $c00e           ; W (set OPRn, OPn = LO)
DUA_STOPC       =       $c00f           ; R (stop timer)
DUA_OPR_C       =       $c00f           ; W (clear OPRn, OPn = HI)
DUA_OPR_HI      =       $c00f           ; W (clear OPRn, OPn = HI)

; DUART GPIO output usage constants
OP_RTSA         =       $01             ; OP output UART A RTS
OP_RTSB         =       $02             ; OP output UART B RTS
OP_SPI_CS       =       $04             ; OP output SPI CS 1
OP_LED_R        =       $08             ; OP output RED LED (active LO)
OP_SPI_SCK      =       $10             ; OP output SPI SCK
OP_LED_G        =       $20             ; OP output GREEN LED (active LO)
OP_SPI_COPI     =       $40             ; OP output SPI COPI
OP_SPI_CS2      =       $80             ; OP output SPI CS 2
; DUART GPIO input usage constants
IP_CTSA         =       $01             ; IP input UART A CTS
IP_CTSB         =       $02             ; IP input UART B CTS
IP_SPI_CIPO     =       $04             ; IP input SPI CIPO

; memory bank map constants
BANK_RAM_AD     =       $4000           ; $4000 - $BFFF 16 x 32KB RAM banks BANK_SET[3:0]
BANK_RAM_SZ     =       $8000           ; 32KB RAM bank size
BANK_ROM_AD     =       $E000           ; $E000 - $FFFF 8KB or 4 x 8KB ROM  BANK_SET[5:4]
BANK_ROM_SZ     =       $2000           ; 8K ROM bank size

; misc constants
BLINKCOUNT      =       50              ; interrupt count between LED toggles
INPUTLEN        =       240             ; 240 bytes in $0200 input buffer

RAM_BANKS       =       16              ; number of RAM banks ($4000-$8000)
BANK_RAM_B      =       0               ; shift for RAM bank bits in BANK_SET
BANK_RAM_M      =       $0F             ; mask for RAM bank bits in BANK_SET

ROM_BANKS       =       4               ; number of ROM banks ($E000-$FFFF)
BANK_ROM_B      =       4               ; shift for ROM bank bits in BANK_SET
BANK_ROM_M      =       $30             ; mask for ROM bank bits in BANK_SET

; *******************************************************
; * bios memory definitions
; *******************************************************

                dsect                   ; define symbols only

                org     $0000           ; zero page

; rosco_6502 65C02S ROM and RAM bank registers (read from underlying RAM)
BANK_SET        ds      1               ; R/W [5:4] ROM bank, [3:0] RAM bank
BANK_RSVD       ds      1               ; -/- reserved future banking register

; bios uses ZP $0002-$000F
FW_ZP_TMPPTR    ds      2               ; firmware ZP temp pointer
FW_ZP_IOBYTE    ds      1               ; firmware IO temp byte
FW_ZP_IOTEMP    ds      1               ; firmware IO temp byte
FW_ZP_IOPTR     ds      2               ; firmware IO buffer pointer
FW_ZP_IOLEN     ds      2               ; firmware IO buffer length
FW_ZP_BLOCKNUM  ds      4               ; firmware IO block/sector number
FW_ZP_rsvd      ds      2               ; reserved

                assert  *==$0010        ; user ZP should start at $0010
USER_ZP_START   ds      0

                org     $0200           ; input buffer page
INPUTBUF        ds      256             ; 256 byte input buffer (or user buffer)

                org     $0300           ; system global page

; bios I/O vectors, JMP to actual routine
COUT            ds      3               ; JMP to current char output (output char in A)
CIN             ds      3               ; JMP to current char input (C set when char returned in A)

USER_TICK       ds      3               ; 100 Hz user routine (JMP or RTS)
TICKCNT         ds      1               ; LED tick count (high bit is LED state)
TICK100HZ       ds      3               ; free incrementing 24-bit 100Hz counter (L/M/H)


                assert  *<=$0380         ; all firmware use should end before $0380

                dend


                ifnd    CUR_ROMBANK     ; if not building for ROM, include rtable symbols
                dsect
                org     BANK_ROM_AD

                include "rtable.asm"
                dend

                endif

