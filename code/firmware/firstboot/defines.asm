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

; 65C02S ROM and RAM bank register (write-only, mirrored in BANKS)
BANK_SET        = $00           ; R/W [5:4] ROM bank, [3:0] RAM bank

; XR68C681P DUART registers
DUA_MR1A        = $c000         ; R/W
DUA_MR2A        = $c000         ; R/W
DUA_SRA         = $c001         ; R
DUA_CSRA        = $c001         ; W
DUA_MISR        = $c002         ; R
DUA_CRA         = $c002         ; W
DUA_RBA         = $c003         ; R (aka RHRA)
DUA_TBA         = $c003         ; W (aka THRA)
DUA_IPCR        = $c004         ; R
DUA_ACR         = $c004         ; W
DUA_ISR         = $c005         ; R
DUA_IMR         = $c005         ; W
DUA_CTU         = $c006         ; R/W
DUA_CTL         = $c007         ; R/W
DUA_MR1B        = $c008         ; R/W
DUA_MR2B        = $c008         ; R/W
DUA_SRB         = $c009         ; R
DUA_CSRB        = $c009         ; W
; reserved      = $c00A         ; R
DUA_CRB         = $c00A         ; W
DUA_RBB         = $c00b         ; R (aka RHRB)
DUA_TBB         = $c00b         ; W (aka THRB)
DUA_IVR         = $c00c         ; R/W
DUA_IP          = $c00d         ; R
DUA_OPCR        = $c00d         ; W
DUA_STARTC      = $c00e         ; R (start timer)
DUA_OPR_S       = $c00e         ; W (set GPIO OPn)
DUA_STOPC       = $c00f         ; R (stop timer)
DUA_OPR_C       = $c00f         ; W (clear GPIO OPn)

; DUART GPIO output usage
OP_RTSA         = $01           ; GPIO output UART A RTS
OP_RTSB         = $02           ; GPIO output UART B RTS
OP_SPI_CS       = $04           ; GPIO output SPI CS 1
OP_LED_R        = $08           ; GPIO output RED LED
OP_SPI_CLK      = $10           ; GPIO output SPI CLK
OP_LED_G        = $20           ; GPIO output GREEN LED
OP_SPI_MOSI     = $40           ; GPIO output SPI MOSI
OP_SPI_CS2      = $80           ; GPIO output SPI CS 2
; DUART GPIO input usage
IP_CTSA         = $01           ; GPIO input UART A CTS
IP_CTSB         = $02           ; GPIO input UART B CTS
IP_SPI_MISO     = $04           ; GPIO input SPI MISO

; memory bank map
BANK_RAM_AD     = $4000         ; $4000 - $BFFF 16 x 32KB RAM banks BANK_SET[3:0]
BANK_RAM_SZ     = $8000         ; 32KB RAM bank size
BANK_ROM_AD     = $E000         ; $E000 - $FFFF 8KB or 4 x 8KB ROM  BANK_SET[5:4]
BANK_ROM_SZ     = $2000         ; 8K ROM bank size

; bios system globals $02F0-$02FF
USERTICK        = $02F0          ; 100 Hz user routine (or RTS)
TICKCNT         = $02FE          ; LED tick count (high bit is LED state)
TICK100HZ       = $02FF          ; incrementing 100Hz counter


; misc
BLINKCOUNT      = 50            ; Delay (interrupts) between LED toggles
