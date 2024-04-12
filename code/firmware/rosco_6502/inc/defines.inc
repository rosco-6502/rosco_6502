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
; NOTE: Made for most 6502 assemblers (mostly "=", ca65 and vasm tested)
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

BANK_RAM_ADDR           =       $4000                   ; $4000-$BFFF 16 x 32KB RAM banks BANK_SET[3:0]
BANK_RAM_SIZE           =       $8000                   ; 32KB RAM bank size
BANK_ROM_ADDR           =       $E000                   ; $E000-$FFFF 8KB or 4 x 8KB ROM  BANK_SET[5:4]
BANK_ROM_SIZE           =       $2000                   ; 8K ROM bank size

RAM_BANKS               =       16                      ; number of RAM banks ($4000-$BFFF)
BANK_RAM_B              =       0                       ; shift for RAM bank bits in BANK_SET
BANK_RAM_M              =       $0F                     ; mask for RAM bank bits in BANK_SET

ROM_BANKS               =       4                       ; number of ROM banks in 32K ROM ($E000-$FFFF)
BANK_ROM_B              =       4                       ; shift for ROM bank bits in BANK_SET
BANK_ROM_M              =       $30                     ; mask for ROM bank bits in BANK_SET

; *******************************************************
; * rosco_6502 I/O addresses
; *******************************************************

; rosco_6502 65C02S ROM and RAM bank registers (read from underlying RAM)
BANK_SET                =       $00                     ; R/W [5:4] ROM bank, [3:0] RAM bank
BANK_RSVD               =       $01                     ; -/- reserved future banking register

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
OP_RTSB                 =       $02                     ; OP output UART B RTS
OP_RTSA                 =       $01                     ; OP output UART A RTS
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
; * BIOS firmware memory definitions (API)
; *******************************************************

; BIOS firmware zero-page addresses                     ; 16 bytes firmware general zero-page
FW_ZP_START             =       $02

FW_ZP_TMPPTR            =       FW_ZP_START             ; 2 bytes firmware ZP temp ptr/word
FW_ZP_TMPPTR_L          =       FW_ZP_TMPPTR
FW_ZP_TMPPTR_H          =       FW_ZP_TMPPTR+1
FW_ZP_TEMPWORD          =       FW_ZP_TMPPTR+2          ; 2 bytes firmware ZP temp word/ptr
FW_ZP_TEMPWORD_L        =       FW_ZP_TEMPWORD
FW_ZP_TEMPWORD_H        =       FW_ZP_TEMPWORD+1
FW_ZP_TEMP_1            =       FW_ZP_TEMPWORD+2        ; 1 byte temp (set before use, clobbered)
FW_ZP_TEMP_2            =       FW_ZP_TEMP_1+1          ; 1 byte temp (set before use, clobbered)
FW_ZP_TEMP_3            =       FW_ZP_TEMP_2+1          ; 1 byte temp (used by I/O)
FW_ZP_BANKTEMP          =       FW_ZP_TEMP_3+1          ; 1 byte temp used when switching BANK_SET
FW_ZP_IOPTR             =       FW_ZP_BANKTEMP+1        ; 2 bytes firmware IO buffer pointer
FW_ZP_IOPTR_L           =       FW_ZP_IOPTR
FW_ZP_IOPTR_H           =       FW_ZP_IOPTR+1
FW_ZP_BLOCKNUM          =       FW_ZP_IOPTR+2           ; 4 bytes ($c-$f) 32-bit IO block number
FW_ZP_BLOCKNUM0         =       FW_ZP_BLOCKNUM          ; LSB [ 7: 0]
FW_ZP_BLOCKNUM1         =       FW_ZP_BLOCKNUM+1        ;     [15: 8]
FW_ZP_BLOCKNUM2         =       FW_ZP_BLOCKNUM+2        ;     [23:16]
FW_ZP_BLOCKNUM3         =       FW_ZP_BLOCKNUM+3        ; MSB [31:24]

FS_ZP_START             =       $10                     ; 32 bytes filesystem zero-page (when used)
MON_ZP_START            =       $30                     ; 16 bytes monitor zero-page (only used while in use)
USER_ZP_START           =       $40                     ; 192 bytes zero-page unused by firmware

; BIOS firmware low-RAM addresses
FW_RAM_START            =       $0200                   ; 256 bytes reserved for firmware

TICK100HZ               =       FW_RAM_START            ; 3 bytes $0200-$0202 free incrementing 24-bit 100Hz counter (L/M/H)
TICK100HZ_L             =       TICK100HZ
TICK100HZ_M             =       TICK100HZ+1
TICK100HZ_H             =       TICK100HZ+2
BLINKCNT                =       TICK100HZ+3             ; 1 byte LED heartbeat tick count (high bit is current LED state)
CPUMHZ                  =       BLINKCNT+1              ; CPU MHz from boot test
DWORD_VAL               =       CPUMHZ+1                ; 4 byte 32-bit value
DWORD_VAL0              =       DWORD_VAL
DWORD_VAL1              =       DWORD_VAL+1
DWORD_VAL2              =       DWORD_VAL+2
DWORD_VAL3              =       DWORD_VAL+3
PR_WIDTH                =       DWORD_VAL+4             ; 1 byte minimum PRDEC_U32 width
PR_PAD                  =       PR_WIDTH+1              ; 1 byte PRDEC_U32 leading pad character (or 0 for no padding)
FW_RSVD_B               =       PR_PAD+1
FW_RSVD_C               =       FW_RSVD_B+1
FW_RSVD_D               =       FW_RSVD_C+1
FW_RSVD_E               =       FW_RSVD_D+1
FW_RSVD_F               =       FW_RSVD_E+1
TEMPBUF16               =       FW_RSVD_F+1             ; 16 byte temp buffer (PRDEC_U32)

; BIOS firmware RAM jump-table
RAMTABLE                =       $0220                   ; BIOS RAM vectors, 3 bytes per routine

; BIOS low-RAM vector index numbers with JMP at RAMVECTBL+(3*index) per routine (up to 32)
PRINTCHAR               =        0*3+RAMTABLE           ; console output
INPUTCHAR               =        1*3+RAMTABLE           ; console input, waits for character, returns A=char
CHECKINPUT              =        2*3+RAMTABLE           ; console check input, returns C=1 if char ready
INPUTLINE               =        3*3+RAMTABLE           ; console line input, A/X (l/h) buffer, Y=max len
CLRSCR                  =        4*3+RAMTABLE           ; current user output screen (default UART assumes VT100)
MOVEXY                  =        5*3+RAMTABLE           ; move current output screen cursor A=V, X=H (default UART assumes VT100)
SETCURSOR               =        6*3+RAMTABLE           ; hide/show output screen cursor (default UART assumes VT100)
USER_TICK               =        7*3+RAMTABLE           ; called every ~100Hz timer tick
NMI_INTR                =        8*3+RAMTABLE           ; NMI interrupt RAM vector address
CD_CTRL                 =        9*3+RAMTABLE           ; char device control/init
CD_SENDCHAR             =       10*3+RAMTABLE           ; char device output, A=char
CD_RECVCHAR             =       11*3+RAMTABLE           ; char device wait for input
CD_CHECKCHAR            =       12*3+RAMTABLE           ; char device check input
BD_CTRL                 =       13*3+RAMTABLE           ; block device control/init (default SD card)
BD_STATUS               =       14*3+RAMTABLE           ; block device status (default SD card)
BD_READ                 =       15*3+RAMTABLE           ; block device read block (default SD card)
BD_WRITE                =       16*3+RAMTABLE           ; block device write block (default SD card)
FS_CTRL                 =       17*3+RAMTABLE           ; filesystem control/init
FS_OPEN                 =       18*3+RAMTABLE           ; filesystem open file or directory
FS_READ                 =       19*3+RAMTABLE           ; filesystem read from file (or directory)
FS_READDIRENT           =       20*3+RAMTABLE           ; filesystem read next directory entry from directory
FS_SEEK                 =       21*3+RAMTABLE           ; TODO: filesystem seek in file (or directory)
FS_WRITE                =       22*3+RAMTABLE           ; TODO: filesystem write to file (or directory)
FS_CLOSE                =       23*3+RAMTABLE           ; TODO: filesystem close file or directory

; BIOS low-RAM bank switching "thunks" (code copied at boot)
THUNK_ROM0              =       $0280                   ; call ROM0 routine (Y=bank, FW_ZP_BANKTEMP=Y)
;THUNK_BANK              =       $0298                   ; TODO: call RAM/ROM routine with BANK_SET
;THUNK_BANKFAST          =       $02B4                   ; TODO: faster call RAM/ROM routine with Y=BANK_SET (trashes Y)

; common 6502 aliases
COUT                    =       PRINTCHAR
RDKEY                   =       INPUTCHAR
GETKEY                  =       INPUTCHAR
PRBYTE                  =       PRHEX_U8

; BIOS firmware low-RAM buffers
INPUTBUF                =       $0300                   ; 256 byte line input buffer (or scratch use)
INPUTBUF_SIZE           =       $0100
FILESYSBUF              =       $0400                   ; 512 byte sector buffer (filesystem)
FILESYSBUF_SIZE         =       $0200
FILENAMEBUF             =       $0600                   ; 256 byte file name buffer (filesystem)
FILENAMEBUF_SIZE        =       $0100
SCRATCHBUF              =       $0700                   ; 256 byte scratch buffer (also used copying between banks)
SCRATCHBUF_SIZE         =       $0100

; *******************************************************
; * firmware BIOS routine and vector numbers
; *******************************************************
; BIOS firmware ROM jump-table
ROMTABLE                =       BANK_ROM_ADDR           ; BIOS ROM functions, 3 bytes per routine

; BIOS ROM routine index numbers with JMP at ROMVECTBL+(3*index) per routine
ROMINITFUNC             =        0*3+ROMTABLE           ; ROM bank specific init
UART_A_CTRL             =        1*3+ROMTABLE           ; TODO: UART A control/init
UART_A_SEND             =        2*3+ROMTABLE           ; blocking output to UART A, A=char (A X Y preserved)
UART_A_RECV             =        3*3+ROMTABLE           ; blocking input from UART A, A=char (X Y preserved)
UART_A_STAT             =        4*3+ROMTABLE           ; status from UART A, returns C=1 if Rx ready, A=$01 if Tx full
UART_B_CTRL             =        5*3+ROMTABLE           ; TODO: UART B control/init
UART_B_SEND             =        6*3+ROMTABLE           ; blocking output to UART B, A=char (A X Y preserved)
UART_B_RECV             =        7*3+ROMTABLE           ; blocking input from UART B, A=char (X Y preserved)
UART_B_STAT             =        8*3+ROMTABLE           ; status from UART B, returns C=1 if Rx ready, A=$01 if Tx full
PRINT                   =        9*3+ROMTABLE           ; print string to PRINTCHAR, A/X (l/h)=string ending with 0
PRINTLN                 =       10*3+ROMTABLE           ; print string to PRINTCHAR with EOL, A/X (l/h)=string ending with 0
READLINE                =       11*3+ROMTABLE           ; input line from INPUTCHAR, A/X (l/h)=string, Y=max len, returns Y=len
PRHEX_U8                =       12*3+ROMTABLE           ; print A as 2 digit hex number
PRDEC_U32               =       13*3+ROMTABLE           ; print DWORD_VAL as 32-bit unsigned decimal (PR_WIDTH=width, PR_PAD=pad)
VT_CLRSCR               =       14*3+ROMTABLE           ; print to PRINTCHAR VT100 clear screen code
VT_MOVEXY               =       15*3+ROMTABLE           ; print to PRINTCHAR VT100 move cursor to X, Y position (1 based, 0=unchanged)
VT_SETCURSOR            =       16*3+ROMTABLE           ; print to PRINTCHAR VT100 cursor to 0=hidden, non-zero visible
SD_CTRL                 =       17*3+RAMTABLE           ; FIXME: block device control/init (default SD card)
SD_STATUS               =       18*3+RAMTABLE           ; FIXME: block device status (default SD card)
SD_READ                 =       19*3+RAMTABLE           ; FIXME: block device read block (default SD card)
SD_WRITE                =       20*3+RAMTABLE           ; FIXME: block device write block (default SD card)
FAT_CTRL                =       21*3+RAMTABLE           ; FIXME: filesystem control/init
FAT_OPEN                =       22*3+RAMTABLE           ; FIXME: filesystem open file or directory
FAT_READ                =       23*3+RAMTABLE           ; FIXME: filesystem read from file (or directory)
FAT_READDIRENT          =       24*3+RAMTABLE           ; FIXME: filesystem read next directory entry from directory
FAT_SEEK                =       25*3+RAMTABLE           ; TODO: filesystem seek in file (or directory)
FAT_WRITE               =       26*3+RAMTABLE           ; TODO: filesystem write to file (or directory)
FAT_CLOSE               =       27*3+RAMTABLE           ; TODO: filesystem close file or directory
