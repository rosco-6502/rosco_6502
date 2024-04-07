; vim: set et ts=8 sw=8
;------------------------------------------------------------
;                            ___ ___ ___ ___
;  ___ ___ ___ ___ ___      |  _| __|   |__ |
; |  _| . |_ -|  _| . |     | . |__ | | | __|
; |_| |___|___|___|___|_____|___|___|___|___|
;                     |_____|   BIOS Firmware
;------------------------------------------------------------
; Copyright (c)2022-2024 Ross Bamford, Xark and contributors
; See top-level LICENSE.md for licence information.
;
; rosco_6502 hardware and firmware BIOS defines
;------------------------------------------------------------
;
; rosco_6502 r4 Memory Map:
;
; |Memory Range | Bytes | Usage
; +-------------+-------+------------------------------------------------
; | $0000-$0001 |    2  | BANK_SET and BANK_RSVD [TBD] banking registers
; | $0002-$000F |   14  | Firmware zero-page (arguments, variables)
; | $0010-$002F |   32  | Filesystem zero-page
; | $0030-$003F |   16  | Temp zero-page (used by EWozmon)
; | $0040-$00FF |  192  | User zero-page
; +-------------+-------+------------------------------------------------
; | $0100-$01FF |  256  | 65C02S CPU stack
; +-------------+-------+------------------------------------------------
; | $0200-$021F |   32  | Firmware variables
; | $0220-$027F |   96  | RAM firmware vectors (see rtable.inc)
; | $0280-$02FF |  128  | Firmware "thunk" routines
; +-------------+-------+------------------------------------------------
; | $0300-$03FF |  256  | Line input buffer (otherwise available)
; +-------------+-------+------------------------------------------------
; | $0400-$04FF |  256  | Scratch bank copy buffer (otherwise available)
; +-------------+-------+------------------------------------------------
; | $0500-$06FF |  512  | Filesystem sector buffer (during use)
; | $0700-$07FF |  256  | Filesystem LFN storage buffer (during use)
; +-------------+-------+------------------------------------------------
; | $0800-$3FFF |  14KB | User low-RAM (application program start)
; +-------------+-------+------------------------------------------------
; | $4000-$BFFF | 512KB | User banked high-RAM (16x32KB banks 0-15)
; +-------------+-------+------------------------------------------------
; | $C000-$C00F |   16  | XR68C681 DUART I/O registers
; | $C010-$DFFF |  ~8KB | Reserved I/O space
; +-------------+-------+------------------------------------------------
; | $E000-$FFFF |  8KB+ | Firmware banked ROM (1x8KB or 4x8KB [32KB ROM])
; +-------------+-------+------------------------------------------------
;
; memory bank map constants

BANK_RAM_ADDR           =       $4000           ; $4000-$BFFF 16 x 32KB RAM banks BANK_SET[3:0]
BANK_RAM_SIZE           =       $8000           ; 32KB RAM bank size
BANK_ROM_ADDR           =       $E000           ; $E000-$FFFF 8KB or 4 x 8KB ROM  BANK_SET[5:4]
BANK_ROM_SIZE           =       $2000           ; 8K ROM bank size

RAM_BANKS               =       16              ; number of RAM banks ($4000-$BFFF)
BANK_RAM_B              =       0               ; shift for RAM bank bits in BANK_SET
BANK_RAM_M              =       $0F             ; mask for RAM bank bits in BANK_SET

ROM_BANKS               =       4               ; number of ROM banks in 32K ROM ($E000-$FFFF)
BANK_ROM_B              =       4               ; shift for ROM bank bits in BANK_SET
BANK_ROM_M              =       $30             ; mask for ROM bank bits in BANK_SET

; *******************************************************
; * rosco_6502 I/O addresses
; *******************************************************

; rosco_6502 65C02S ROM and RAM bank registers (read from underlying RAM)
BANK_SET                =       $00             ; R/W [5:4] ROM bank, [3:0] RAM bank
BANK_RSVD               =       $01             ; -/- reserved future banking register

; XR68C681 DUART registers
DUART_BASE              =       $C000
DUA_MR1A                =       DUART_BASE+$0           ; R/W   A mode reg
DUA_MR2A                =       DUART_BASE+$0           ; R/W   A mode reg
DUA_SRA                 =       DUART_BASE+$1           ; R     A status reg
DUA_CSRA                =       DUART_BASE+$1           ; W     A clock select reg
DUA_MISR                =       DUART_BASE+$2           ; R     A masked intr. status
DUA_CRA                 =       DUART_BASE+$2           ; W     A command reg
DUA_RBA                 =       DUART_BASE+$3           ; R     A Rx holding reg (aka RHRA)
DUA_TBA                 =       DUART_BASE+$3           ; W     A Tx holding reg (aka THRA)
DUA_IPCR                =       DUART_BASE+$4           ; R     input port change reg
DUA_ACR                 =       DUART_BASE+$4           ; W     aux. control reg
DUA_ISR                 =       DUART_BASE+$5           ; R     intr. status reg
DUA_IMR                 =       DUART_BASE+$5           ; W     intr. mask reg
DUA_CTU                 =       DUART_BASE+$6           ; R/W   counter/timer upper reg
DUA_CTL                 =       DUART_BASE+$7           ; R/W   counter/timer lower reg
DUA_MR1B                =       DUART_BASE+$8           ; R/W   B mode reg        
DUA_MR2B                =       DUART_BASE+$8           ; R/W   B mode reg
DUA_SRB                 =       DUART_BASE+$9           ; R     B status reg
DUA_CSRB                =       DUART_BASE+$9           ; W     B clock select reg
; reserved              =       DUART_BASE+$A           ; R     (reserved)
DUA_CRB                 =       DUART_BASE+$A           ; W     B command reg
DUA_RBB                 =       DUART_BASE+$B           ; R     B Rx holding reg (aka RHRB)
DUA_TBB                 =       DUART_BASE+$B           ; W     B Tx holding reg (aka THRB)
DUA_IVR                 =       DUART_BASE+$C           ; R/W   intr. vector reg
DUA_IP                  =       DUART_BASE+$D           ; R     input port reg
DUA_OPCR                =       DUART_BASE+$D           ; W     output port reg
DUA_STARTC              =       DUART_BASE+$E           ; R     start counter/timer
DUA_OPR_S               =       DUART_BASE+$E           ; W     set output OPRn bits (OPn pin=LO)
DUA_OPR_LO              =       DUART_BASE+$E           ; W     set output OPRn pins LO (set OPRn bits)
DUA_STOPC               =       DUART_BASE+$F           ; R     stop counter/timer reg
DUA_OPR_C               =       DUART_BASE+$F           ; W     clear output OPRn bits (OPn pin=HI)
DUA_OPR_HI              =       DUART_BASE+$F           ; W     set output OPRn pins HI (clears OPRn bits)

; DUART SRA/SRB status register bits
DUA_SR_RXRDY            =       $01                     ; receiver ready
DUA_SR_FFULL            =       $02                     ; FIFO full
DUA_SR_TXRDY            =       $04                     ; transmitter ready
DUA_SR_TXEMT            =       $08                     ; transmitter empty
DUA_SR_OVERR            =       $10                     ; overrun error
DUA_SR_PAERR            =       $20                     ; parity error
DUA_SR_FRERR            =       $40                     ; framing error
DUA_SR_BREAK            =       $80                     ; received break

; DUART OP output bit usage constants
OP_RTSA                 =       $01                     ; OP output UART A RTS
OP_RTSB                 =       $02                     ; OP output UART B RTS
OP_SPI_CS               =       $04                     ; OP output SPI CS 1
OP_LED_R                =       $08                     ; OP output RED LED (active LO)
OP_SPI_SCK              =       $10                     ; OP output SPI SCK
OP_LED_G                =       $20                     ; OP output GREEN LED (active LO)
OP_SPI_COPI             =       $40                     ; OP output SPI COPI
OP_SPI_CS2              =       $80                     ; OP output SPI CS 2
; DUART IP input bit usage constants
IP_CTSA                 =       $01                     ; IP input UART A CTS
IP_CTSB                 =       $02                     ; IP input UART B CTS
IP_SPI_CIPO             =       $04                     ; IP input SPI CIPO

; *******************************************************
; * bios memory definitions
; *******************************************************

; BIOS firmware zero-page addresses                     ; 16 bytes firmware general zero-page
FW_ZP_START             =       $02

FW_ZP_TMPPTR            =       FW_ZP_START             ; 2 bytes firmware ZP temp pointer
FW_ZP_TMPPTR_L          =       FW_ZP_TMPPTR
FW_ZP_TMPPTR_H          =       FW_ZP_TMPPTR+1
FW_ZP_BANKTEMP          =       FW_ZP_START+$02         ; 1 byte temp used when setting BANK_SET
FW_ZP_BANKSAVE          =       FW_ZP_START+$03         ; 1 byte firmware thunk previous BANK_SET
FW_ZP_IOTEMP            =       FW_ZP_START+$04         ; 1 byte firmware IO temp
FW_ZP_IOPTR             =       FW_ZP_START+$05         ; 2 bytes firmware IO buffer pointer
FW_ZP_IOPTR_L           =       FW_ZP_IOPTR
FW_ZP_IOPTR_H           =       FW_ZP_IOPTR+1
FW_ZP_IOBYTE            =       FW_ZP_START+$07         ; 1 byte firmware IO read byte
FW_ZP_IOLEN             =       FW_ZP_START+$08         ; 2 bytes firmware IO buffer length
FW_ZP_IOLEN_L           =       FW_ZP_IOLEN
FW_ZP_IOLEN_H           =       FW_ZP_IOLEN+1
FW_ZP_BLOCKNUM          =       FW_ZP_START+$0A         ; 4 bytes ($c-$f) 32-bit IO block number
FW_ZP_BLOCKNUM0         =       FW_ZP_BLOCKNUM          ; LSB [ 7: 0]
FW_ZP_BLOCKNUM1         =       FW_ZP_BLOCKNUM+1        ;     [15: 8]
FW_ZP_BLOCKNUM2         =       FW_ZP_BLOCKNUM+2        ;     [23:16]
FW_ZP_BLOCKNUM3         =       FW_ZP_BLOCKNUM+3        ; MSB [31:24]

FS_ZP_START             =       $10                     ; 32 bytes filesystem zero-page (when used)
MON_ZP_START            =       $30                     ; 16 bytes monitor zero-page (only used while in use)
USER_ZP_START           =       $40                     ; 192 bytes zero-page unused by firmware

; BIOS firmware low-RAM addresses
TICK100HZ               =       $0200                   ; 3 bytes $0200-$0202 free incrementing 24-bit 100Hz counter (L/M/H)
TICK100HZ_L             =       TICK100HZ
TICK100HZ_M             =       TICK100HZ+1
TICK100HZ_H             =       TICK100HZ+2
BLINKCNT                =       $0203                   ; 1 byte LED heartbeat tick count (high bit is current LED state)
DWORD_VAL               =       $0204                   ; 4 byte 32-bit value
DWORD_VAL0              =       DWORD_VAL
DWORD_VAL1              =       DWORD_VAL+1
DWORD_VAL2              =       DWORD_VAL+2
DWORD_VAL3              =       DWORD_VAL+3
PRDEC_WIDTH             =       $0208                   ; 1 byte minimum PRDEC32 width
PRDEC_PAD               =       $0209                   ; 1 byte PRDEC32 leading pad character (or 0 for no padding)
;                       =       $020A
;                       =       $020B
;                       =       $020C
;                       =       $020D
;                       =       $020E
;                       =       $020F
TEMPBUF16               =       $0210                   ; 16 byte temp formatting buffer (PRDEC32)


; BIOS firmware RAM jump-table
RAMVECTBL               =       $0220                   ; BIOS RAM vectors, 3 bytes per routine

; BIOS firmware low-RAM buffers
INPUTBUF                =       $0300                   ; 256 byte line input/scratch buffer
INPUTBUF_SIZE           =       $0100
SCRATCHBUF              =       $0400                   ; 256 byte scratch buffer (used for copying between banks)
SCRATCHBUF_SIZE         =       $0100
FILESYSBUF              =       $0500                   ; 512 byte sector buffer
FILESYSBUF_SIZE         =       $0200
FILENAMEBUF             =       $0700                   ; 256 byte file name buffer (for LFN support)
FILENAMEBUF_SIZE        =       $0100

; BIOS firmware ROM jump-table
ROMVECTBL               =       BANK_ROM_ADDR           ; BIOS ROM vectors, 3 bytes per routine

; *******************************************************
; * firmware BIOS routine and vector numbers
; *******************************************************

; BIOS ROM routine index numbers with JMP at ROMVECTBL+(3*index) per routine
R_UART_A_SEND           =       0               ; blocking output to UART A, A=char (A X Y preserved)
R_UART_A_RECV           =       1               ; blocking input from UART A, A=char (X Y preserved)
R_UART_A_STAT           =       2               ; status from UART A, returns C=1 if Rx ready, A=$01 if Tx full
R_UART_A_CTRL           =       3               ; TODO: UART A control/init
R_UART_B_SEND           =       4               ; blocking output to UART B, A=char (A X Y preserved)
R_UART_B_RECV           =       5               ; blocking input from UART B, A=char (X Y preserved)
R_UART_B_STAT           =       6               ; status from UART B, returns C=1 if Rx ready, A=$01 if Tx full
R_UART_B_CTRL           =       7               ; TODO: UART B control/init
R_PRINT                 =       8               ; print string to V_PRINTCHAR, A/X (l/h)=string ending with 0
R_PRINTLN               =       9               ; print string to V_PRINTCHAR with EOL, A/X (l/h)=string ending with 0
R_READLINE              =       10              ; input line from V_INPUTCHAR, A/X (l/h)=string, Y=max len, returns Y=len
R_PRBYTE                =       11              ; print A as 2 digit hex number
R_PRDEC32               =       12              ; print DWORD_VAL as 32-bit unsigned decimal (PRDEC_WIDTH=width, PRDEC_PAD=pad)
R_VT_CLRSCR             =       13              ; print to V_PRINTCHAR VT100 clear screen code
R_VT_MOVEXY             =       14              ; print to V_PRINTCHAR VT100 move cursor to X, Y position (1 based, 0=unchanged)
R_VT_SETCURSOR          =       15              ; print to V_PRINTCHAR VT100 cursor to 0=hidden, non-zero visible
R_ROMBANKFUNC           =       16              ; call generic ROM bank (A/X (l/h)=function addr, Y=bank)

; BIOS low-RAM vector index numbers with JMP at RAMVECTBL+(3*index) per routine (up to 32)
V_PRINTCHAR             =       0               ; console output
V_INPUTCHAR             =       1               ; console input, waits for character, returns A=char
V_CHECKINPUT            =       2               ; console check input, returns C=1 if char ready
V_CLRSCR                =       3               ; current user output screen (default UART assumes VT100)
V_MOVEXY                =       4               ; move current output screen cursor A=V, X=H (default UART assumes VT100)
V_SETCURSOR             =       5               ; hide/show output screen cursor (default UART assumes VT100)
V_USER_TICK             =       6              ; called every ~100Hz timer tick (1st slot)
V_CD_CTRL               =       7              ; char device control/init, A=char, X=device (0=UART A, 1=UART B)
V_CD_SENDCHAR           =       8              ; char device output, A=char
V_CD_RECVCHAR           =       9              ; char device wait for input
V_CD_CHECKCHAR          =       10              ; char device check input
V_BD_CTRL               =       11              ; block device control/init (default SD card)
V_BD_STATUS             =       12              ; block device status (default SD card)
V_BD_READ               =       13              ; block device read block (default SD card)
V_BD_WRITE              =       14              ; block device write block (default SD card)
V_FS_CTRL               =       15              ; filesystem control/init
V_FS_OPEN               =       16              ; filesystem open file or directory
V_FS_READ               =       17              ; filesystem read from file (or directory)
V_FS_READDIRENT         =       18              ; filesystem read next directory entry from directory
V_FS_SEEK               =       19              ; TODO: filesystem seek in file (or directory)
V_FS_WRITE              =       20              ; TODO: filesystem write to file (or directory)
V_FS_CLOSE              =       21              ; TODO: filesystem close file or directory
                                                ; vectors 21-31 available

; V_IRQIVEC		=	6		; IRQ interrupt vector (1st slot)
; V_IRQVEC_2		=	7		; IRQ interrupt vector (2nd slot)
; V_IRQVEC_3		=	8		; IRQ interrupt vector (3rd slot)
; V_NMIVEC		=	9		; NMI interrupt vector (1st slot)
; V_NMIVEC_2		=	10		; NMI interrupt vector (2nd slot)
; V_NMIVEC_3		=	11		; NMI interrupt vector (3rd slot)
