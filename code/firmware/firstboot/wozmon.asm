; The WOZ Monitor for the Apple 1
; Written by Steve Wozniak in 1976

; Modified for rosco_6502 / VASM by
; Ross Bamford forty-seven years later.
; Tweaked by Xark with enhancements from ewozmon6850.asm:
; https://gist.github.com/robinharris/b529a24f39bcbd53f1e21775e24d0b9e

; Page 0 Variables
REGA                    =       $20                     ; A reg value (R or BRK)
REGX                    =       $21                     ; X reg value (R or BRK)
REGY                    =       $22                     ; Y reg value (R or BRK)
REGP                    =       $23                     ; P reg value (R or BRK)

XAML                    =       $24                     ; Last "opened" location Low
XAMH                    =       $25                     ; Last "opened" location High
STL                     =       $26                     ; Store address Low
STH                     =       $27                     ; Store address High
L                       =       $28                     ; Hex value parsing Low
H                       =       $29                     ; Hex value parsing High
YSAV                    =       $2A                     ; Used to see if hex value is given
MODE                    =       $2B                     ; $00=XAM, $7F=STOR, $AE=BLOCK XAM
COUNTER                 =       $2C                     ; Intel hex bytes per line counter
CRC                     =       $2D                     ; Intel hex CRC value
CRCCHECK                =       $2E                     ; CRC fail flag, also used for current BRK bank
BYTESL                  =       $2F                     ; Intel hex byte count low
BYTESH                  =       $30                     ; Intel hex byte count high

; Other Variables

IN                      =       INPUTBUF                ;  Input buffer to $0200

;-------------------------------------------------------------------------
;  Constants
;-------------------------------------------------------------------------

PROMPT                  =       $5C                     ; Prompt character
BS                      =       $08                     ; Backspace key, arrow left key
DEL                     =       $7F                     ; DEL
CR                      =       $0D                     ; Carriage Return
LF                      =       $0A                     ; Line Feed
ESC                     =       $1B                     ; ESC key

WOZMON:
                        LDA     #$00
                        TAX
                        TAY
                        CLC
                        CLV
SOFTRESET:
                        PHP
                        PHY
                        PHX
                        PHA
                        CLD                             ; Clear decimal arithmetic mode.
                        CLI
                        LDA     #<MONMSG
                        LDY     #>MONMSG
                        JSR     SHWMSG                  ; Show Welcome
BRKCONT:
                        LDA     #'A'
                        JSR     PRREGNAME
                        PLA
                        STA     REGA
                        JSR     PRBYTE
                        LDA     #'X'
                        JSR     PRREGNAME
                        PLA
                        STA     REGX
                        JSR     PRBYTE
                        LDA     #'Y'
                        JSR     PRREGNAME
                        PLA
                        STA     REGY
                        JSR     PRBYTE
                        LDA     #'P'
                        JSR     PRREGNAME
                        PLA
                        STA     REGP
                        JSR     PRBYTE
                        LDA     #' '
                        JSR     ECHO
                        LDA     REGP
                        LDY     #7
FLAGLOOP:               ASL
                        PHA
                        LDA     FLAGNAMES,Y
                        BCS     FLAGPRINT
                        ORA     #$20                    ; convert to lowercase
FLAGPRINT:              JSR     COUT
                        PLA
                        DEY
                        BPL     FLAGLOOP
                        BRA     GETLINE

;-------------------------------------------------------------------------
; The GETLINE process
;-------------------------------------------------------------------------

NOTCR:                  CMP     #BS                     ; Backspace?
                        BEQ     BACKSPACE               ; Yes.
                        INY                             ; Advance text index.
                        BPL     NEXTCHAR                ; Auto ESC if > 127.
ESCAPE:                 LDA     #'?'                    ; "?".
                        JSR     ECHO                    ; Output it.
GETLINE:                JSR     CRLF
                        JSR     CRLF
                        LDA     #'\'                    ; "\".
                        JSR     ECHO                    ; Output it.
                        LDY     #$01                    ; Initialize text index.
BACKSPACE:              DEY                             ; Back up text index.
                        BMI     GETLINE                 ; Beyond start of line, reinitialize.
                        LDA     #' '
                        JSR     ECHO
                        LDA     #BS
                        JSR     ECHO
NEXTCHAR:               JSR     CIN                     ; Key ready?
                        BCC     NEXTCHAR
                        CMP     #ESC                    ; ESC?
                        BEQ     ESCAPE                  ; Yes.
                        CMP     #DEL                    ; DEL?
                        BNE     NOTDEL                  ; branch if not
                        LDA     #BS                     ; convert DEL to BS
NOTDEL:                 CMP     #$60                    ;*Is it Lower case
                        BMI     CONVERT                 ;*Nope, just convert it
                        AND     #$5F                    ;*If lower case, convert to Upper case
CONVERT:                STA     IN,Y                    ; Add to text buffer.
                        CMP     #CR                     ; CR?
                        BEQ     ISCR                    ; branch yes
                        JSR     ECHO                    ; else echo
                        BRA     NOTCR
ISCR:                   LDY     #$FF                    ; Reset text index.
                        LDA     #$00                    ; For XAM mode.
SETBLOCK:               ASL                             ; Leaves $B8 if setting BLOCK XAM mode.
SETSTOR:                ASL                             ; Leaves $7B if setting STOR mode.
                        STA     MODE                    ; $00=XAM, $74=STOR, $B8=BLOCK XAM.
BLSKIP:                 INY                             ; Advance text index.
NEXTITEM:               LDA     IN,Y                    ; Get character.
                        CMP     #CR                     ; CR?
                        BEQ     GETLINE                 ; Yes, done this line.
                        CMP     #'.'                    ; "."?
                        BCC     BLSKIP                  ; Skip delimiter.
                        BEQ     SETBLOCK                ; Set BLOCK XAM mode.
                        CMP     #':'                    ; ":"?
                        BEQ     SETSTOR                 ; Yes. Set STOR mode.
                        CMP     #'R'                    ; "R"?
                        BEQ     RUN                     ; Yes. Run user program.
                        CMP     #'L'                    ;* "L"?
                        BEQ     LOADINT                 ;* Yes, Load Intel Code
                        STZ     L                       ; $00->L.
                        STZ     H                       ;  and H.
                        STY     YSAV                    ; Save Y for comparison.
NEXTHEX:                LDA     IN,Y                    ; Get character for hex test.
                        EOR     #$30                    ; Map digits to $0-9.
                        CMP     #$0A                    ; Digit?
                        BCC     DIG                     ; Yes.
                        ADC     #$88                    ; Map letter "A"-"F" to $FA-FF.
                        CMP     #$FA                    ; Hex letter?
                        BCC     NOTHEX                  ; No, character not hex.
DIG:                    ASL
                        ASL                             ; Hex digit to MSD of A.
                        ASL
                        ASL
                        LDX     #$04                    ; Shift count.
HEXSHIFT:               ASL                             ; Hex digit left, MSB to carry.
                        ROL     L                       ; Rotate into LSD.
                        ROL     H                       ; Rotate into MSD’s.
                        DEX                             ; Done 4 shifts?
                        BNE     HEXSHIFT                ; No, loop.
                        INY                             ; Advance text index.
                        BNE     NEXTHEX                 ; Always taken. Check next character for hex.
NOTHEX:                 CPY     YSAV                    ; Check if L, H empty (no hex digits).
                        BNE     NOESCAPE                ; Branch out of range, had to improvise...
;                        JSR     CRLF
                        JMP     ESCAPE                  ; Yes, generate ESC sequence

RUN:                    JSR     CRLF
                        JSR     ACTRUN                  ; JSR to the Address we want to run
                        JMP     SOFTRESET               ; When returned for the program, reset EWOZ
ACTRUN:                 LDA     REGP
                        PHP
                        LDA     REGA
                        LDX     REGX
                        LDY     REGY
                        PLP
                        JMP     (XAML)                  ; Run at current XAM index

LOADINT:                JSR     LOADINTEL               ; Load the Intel code
                        JMP     GETLINE                 ; When returned from the program, reset EWOZ

NOESCAPE:               BIT     MODE                    ; Test MODE byte.
                        BVC     NOTSTOR                 ; B6=0 STOR, 1 for XAM and BLOCK XAM
                        LDA     L                       ; LSD’s of hex data.
                        STA     (STL)                   ; Store at current ‘store index’.
                        INC     STL                     ; Increment store index.
                        BNE     NEXTITEM                ; Get next item. (no carry).
                        INC     STH                     ; Add carry to ‘store index’ high order.
TONEXTITEM:             JMP     NEXTITEM                ; Get next command item.
NOTSTOR:                BMI     XAMNEXT                 ; B7=0 for XAM, 1 for BLOCK XAM.
                        LDX     #$02                    ; Byte count.
SETADR:                 LDA     L-1,X                   ; Copy hex data to
                        STA     STL-1,X                 ;  ‘store index’.
                        STA     XAML-1,X                ; And to ‘XAM index’.
                        DEX                             ; Next of 2 bytes.
                        BNE     SETADR                  ; Loop unless X=0.
NXTPRNT:                BNE     PRDATA                  ; NE means no address to print.

                        JSR     CRLF                    ; CR.
                        LDA     XAMH                    ; ‘Examine index’ high-order byte.
                        JSR     PRBYTE                  ; Output it in hex format.
                        LDA     XAML                    ; Low-order ‘examine index’ byte.
                        JSR     PRBYTE                  ; Output it in hex format.
                        LDA     #':'                    ; ":".
                        JSR     ECHO                    ; Output it.
PRDATA:                 LDA     #$20                    ; Blank.
                        JSR     ECHO                    ; Output it.
                        LDA     (XAML)                  ; Get data byte at ‘examine index’.
                        JSR     PRBYTE                  ; Output it in hex format.
XAMNEXT:                STZ     MODE                    ; 0->MODE (XAM mode).
                        LDA     XAML
                        CMP     L                       ; Compare ‘examine index’ to hex data.
                        LDA     XAMH
                        SBC     H
                        BCS     TONEXTITEM              ; Not less, so no more data to output.
                        INC     XAML
                        BNE     MOD8CHK                 ; Increment ‘examine index’.
                        INC     XAMH
MOD8CHK:                LDA     XAML                    ; Check low-order ‘examine index’ byte
                        AND     #$07                    ;  For MOD 8=0
                        BPL     NXTPRNT                 ; Always taken.
PRBYTE:                 PHA                             ; Save A for LSD.
                        LSR
                        LSR
                        LSR                             ; MSD to LSD position.
                        LSR
                        JSR     PRHEX                   ; Output hex digit.
                        PLA                             ; Restore A.
PRHEX:                  AND     #$0F                    ; Mask LSD for hex print.
                        ORA     #'0'                    ; Add "0".
                        CMP     #$3A                    ; Digit?
                        BCC     ECHO                    ; Yes, output it.
                        ADC     #$06                    ; Add offset for letter.
ECHO:
                        JSR     COUT
                        CMP     #CR                     ; was CR printed?
                        BNE     NOADDLF                 ; branch if not
                        LDA     #LF                     ; print LF
                        JMP     COUT
NOADDLF:                RTS

; X has S, Y bas BANK_SET
WOZHITBRK:
                        STY     CRCCHECK                ; save BANK_SET at BRK time
                        CLI
                        CLD
                        LDA     #<BRKMSG
                        LDY     #>BRKMSG
                        JSR     SHWMSG
                        LDA     $105,X                  ; return address L
                        SEC
                        SBC     #2
                        STA     STL
                        LDA     $106,X                  ; return address H
                        BCS     NOBRKDECHI
                        DEC
NOBRKDECHI:             JSR     PRBYTE
                        LDA     STL
                        JSR     PRBYTE
                        LDA     #'B'
                        JSR     PRREGNAME
                        LDA     CRCCHECK                ; saved BANK
                        JSR     PRBYTE
                        LDA     #'S'
                        JSR     PRREGNAME
                        TXA
                        CLC
                        ADC     #6                      ; skip A X Y P RL RH to point at BRK
                        JSR     PRBYTE
                        JMP     BRKCONT

PRREGNAME:              PHA
                        LDA     #' '
                        JSR     ECHO
                        PLA
                        JSR     ECHO
                        LDA     #'='
                        JMP     ECHO

;-------------------------------------------------------------------------
; Load an program in Intel Hex Format.
;-------------------------------------------------------------------------

INTELABORT:
                        INC     CRCCHECK
                        JMP     INTELDONE
INTELIGNORE:
                        LDA     #1
                        STA     CRCCHECK
                        JMP     INTELLINE
; entry
LOADINTEL:
                        LDA     #<TRBEGMSG
                        LDY     #>TRBEGMSG
                        JSR     SHWMSG                  ; Show Start Transfer
                        LDY     #$00
                        STY     CRCCHECK                ; If CRCCHECK=0, all is good
                        STZ     BYTESL
                        STZ     BYTESH
                        STZ     XAML
                        STZ     XAMH
INTELLINE:              JSR     CIN                     ; Get char
                        BCC     INTELLINE
                        STA     IN,Y                    ; Store it
                        CMP     #ESC                    ; Escape ?
                        BEQ     INTELABORT              ; Yes, abort
                        INY                             ; Next
                        BEQ     INTELABORT              ; line too long
                        CMP     #LF                     ; Did we find a new line ?
                        BNE     INTELLINE               ; Nope, continue to scan line
                        LDY     #$00                    ; Find (:)
FINDCOL:                LDA     IN,Y                    ; get char from line
                        INY                             ; increment Y
                        BEQ     INTELIGNORE             ; no colon, abort
                        CMP     #':'                    ; Is it Colon ?
                        BNE     FINDCOL                 ; Nope, try next
                        STZ     CRC                     ; Zero Check sum
                        JSR     GETHEX                  ; Get Number of bytes
                        STA     COUNTER                 ; Number of bytes in Counter
                        CLC                             ; Clear carry
                        ADC     CRC                     ; Add CRC
                        STA     CRC                     ; Store it
                        JSR     GETHEX                  ; Get Hi byte
                        STA     STH                     ; Store it
                        CLC                             ; Clear carry
                        ADC     CRC                     ; Add CRC
                        STA     CRC                     ; Store it
                        JSR     GETHEX                  ; Get Lo byte
                        STA     STL                     ; Store it
                        CLC                             ; Clear carry
                        ADC     CRC                     ; Add CRC
                        STA     CRC                     ; Store it
                        LDA     XAML
                        ORA     XAMH
                        BNE     NODOT
                        LDA     STL
                        STA     XAML
                        LDA     STH
                        STA     XAMH
NODOT:                  JSR     GETHEX                  ; Get Control byte
                        CMP     #$01                    ; Is it a Termination record ?
                        BEQ     INTELDONE               ; Yes, we are done
                        CLC                             ; Clear carry
                        ADC     CRC                     ; Add CRC
                        STA     CRC                     ; Store it
INTELSTORE:             JSR     GETHEX                  ; Get Data Byte
                        STA     (STL)                   ; Store it
                        INC     BYTESL                  ; increment byte count
                        BNE     NOBYTESHI               ; low wrapped?
                        INC     BYTESH                  ; increment high byte count
NOBYTESHI               CLC                             ; Clear carry
                        ADC     CRC                     ; Add CRC
                        STA     CRC                     ; Store it
                        INC     STL                     ; Next Address
                        BNE     TESTCOUNT               ; Test to see if Hi byte needs INC
                        INC     STH                     ; If so, INC it
TESTCOUNT:              DEC     COUNTER                 ; Count down
                        BNE     INTELSTORE              ; Next byte
                        JSR     GETHEX                  ; Get Checksum
                        LDY     #$00                    ; Zero Y
                        CLC                             ; Clear carry
                        ADC     CRC                     ; Add CRC
                        BNE     BADCRC                  ; Checksum not OK
                        LDA     #'.'                    ; Load "."
                        JSR     ECHO                    ; Print it to indicate activity
                        JMP     INTELLINE               ; Checksum OK
BADCRC:                 LDA     #'X'                    ; Flag CRC error
                        STA     CRCCHECK                ; Store it
                        JSR     ECHO                    ; Print it to indicate activity
                        JMP     INTELLINE               ; Process next line
INTELDONE:
                        LDA     #<TRDONMSG              ; Load Done Message
                        LDY     #>TRDONMSG
                        JSR     SHWMSG                  ; Show Done

                        LDA     CRCCHECK                ; Test if everything is OK
                        BEQ     OKMESS                  ; Show OK message
                        LDA     #<TRBADMSG              ; Load Error Message
                        LDY     #>TRBADMSG
                        JMP     SHWMSG                  ; Show Error
OKMESS:
                        LDA     #<TROKMSG               ; Load OK Message
                        LDY     #>TROKMSG
                        JSR     SHWMSG                  ; Show Done
                        LDA     XAMH
                        JSR     PRBYTE
                        LDA     XAML
                        JSR     PRBYTE
                        LDA     #<TROKMSG2              ; Load OK Message
                        LDY     #>TROKMSG2
                        JSR     SHWMSG
                        LDA     BYTESH
                        JSR     PRBYTE
                        LDA     BYTESL
                        JMP     PRBYTE

GETHEX:                 LDA     IN,Y                    ; Get first char
                        EOR     #$30
                        CMP     #$0A
                        BCC     DONEFIRST
                        ADC     #$08
DONEFIRST:              ASL
                        ASL
                        ASL
                        ASL
                        STA     L
                        INY
                        LDA     IN,Y                    ; Get next char
                        EOR     #$30
                        CMP     #$0A
                        BCC     DONESECOND
                        ADC     #$08
DONESECOND:             AND     #$0F
                        ORA     L
                        INY
                        RTS

CRLF:                   LDA     #CR
                        JMP     ECHO

; show NUL terminated string in A/Y (l/h) using ECHO (which does CR to CR/LF)
SHWMSG:
                        STA     L
                        STY     H
                        LDY     #$0
SHWMSG1:                LDA     (L),Y
                        BEQ     .DONE
                        JSR     ECHO
                        INY
                        BNE     SHWMSG1
.DONE                   RTS

;-------------------------------------------------------------------------
FLAGNAMES               ascii   "CZIDB1VN"
MONMSG                  asciiz  $0D, "rosco_6502 EWozMon:"
BRKMSG                  asciiz  $0D, $0D, $07, "BRK @"
TRBEGMSG                asciiz  $0D, "Start Intel hex file import:", $0D
TRDONMSG                asciiz  $0D, "Done, hex import"
TROKMSG                 asciiz  "ed OK.", $0D, "Start:"
TROKMSG2                asciiz  " Bytes:"
TRBADMSG                asciiz  " had checksum ERRORs!", $07, $0D
