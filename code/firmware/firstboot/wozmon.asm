;  The WOZ Monitor for the Apple 1
;  Written by Steve Wozniak in 1976

;  Modified for rosco_6502 / VASM by 
;  Ross Bamford forty-seven years later.

; Tweaked by Xark with enhancements from ewozmon6850.asm:
; https://gist.github.com/robinharris/b529a24f39bcbd53f1e21775e24d0b9e

; Page 0 Variables

REGA            =       $20
REGX            =       $21
REGY            =       $22
REGP            =       $23
BANKSAV         =       $30

XAML            =       $24             ;  Last "opened" location Low
XAMH            =       $25             ;  Last "opened" location High
STL             =       $26             ;  Store address Low
STH             =       $27             ;  Store address High
L               =       $28             ;  Hex value parsing Low
H               =       $29             ;  Hex value parsing High
YSAV            =       $2A             ;  Used to see if hex value is given
MODE            =       $2B             ;  $00=XAM, $7F=STOR, $AE=BLOCK XAM
MSGL            =       $2C
MSGH            =       $2D
COUNTER         =       $2E
CRC             =       $2F
CRCCHECK        =       $30

; Other Variables

IN              =       $0200           ;  Input buffer to $027F

;-------------------------------------------------------------------------
;  Constants
;-------------------------------------------------------------------------

PROMPT          EQU     $5C            ; Prompt character
BS              EQU     $08            ; Backspace key, arrow left key
DEL             EQU     $7F            ; DEL
CR              EQU     $0D            ; Carriage Return
LF              EQU     $0A            ; Carriage Return
ESC             EQU     $1B            ; ESC key

WOZMON:
                LDA     BANK_SET
                STA     BANKSAV
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
                CLD                     ; Clear decimal arithmetic mode.
                CLI
                LDA     #<MONMSG
                STA     MSGL
                LDA     #>MONMSG
                STA     MSGH
                JSR     SHWMSG         ; Show Welcome
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
                LDX     #$FF
                TXS
                JSR     CRLF
                LDA     #$1B           
; Program falls through to the GETLINE routine to save some program bytes

;-------------------------------------------------------------------------
; The GETLINE process
;-------------------------------------------------------------------------

NOTCR:          CMP     #BS             ; Backspace?
                BEQ     BACKSPACE       ; Yes.
                CMP     #ESC            ; ESC?
                BEQ     ESCAPE          ; Yes.
                INY                     ; Advance text index.
                BPL     NEXTCHAR        ; Auto ESC if > 127.
ESCAPE:         JSR     CRLF
                LDA     #'\'            ; "\".
                JSR     ECHO            ; Output it.
GETLINE:        JSR     CRLF
                LDY     #$01            ; Initialize text index.
BACKSPACE:      DEY                     ; Back up text index.
                BMI     GETLINE         ; Beyond start of line, reinitialize.
                LDA     #' '
                JSR     ECHO
                LDA     #BS
                JSR     ECHO
NEXTCHAR:       LDA     DUA_SRA         ; Key ready?
                AND     #$01            ; (Bit 1 of DUART SRA set?)
                BEQ     NEXTCHAR        ; Loop until ready.
                LDA     DUA_TBA         ; Load character.
                CMP     #DEL            ; DEL?
                BNE     NOTDEL          ; branch if not
                LDA     #BS             ; convert DEL to BS 
NOTDEL:         CMP     #$60            ;*Is it Lower case
                BMI     CONVERT         ;*Nope, just convert it
                AND     #$5F            ;*If lower case, convert to Upper case
CONVERT:        STA     IN,Y            ; Add to text buffer.
                JSR     ECHO            ; Display character.
                CMP     #CR             ; CR?
                BNE     NOTCR           ; No.
                LDY     #$FF            ; Reset text index.
                LDA     #$00            ; For XAM mode.
                TAX                     ; 0->X.
SETBLOCK:       ASL                     ; Leaves $B8 if setting BLOCK XAM mode.
SETSTOR:        ASL                     ; Leaves $7B if setting STOR mode.
                STA     MODE            ; $00=XAM, $74=STOR, $B8=BLOCK XAM.
BLSKIP:         INY                     ; Advance text index.
NEXTITEM:       LDA     IN,Y            ; Get character.
                CMP     #CR             ; CR?
                BEQ     GETLINE         ; Yes, done this line.
                CMP     #'.'            ; "."?
                BCC     BLSKIP          ; Skip delimiter.
                BEQ     SETBLOCK        ; Set BLOCK XAM mode.
                CMP     #':'            ; ":"?
                BEQ     SETSTOR         ; Yes. Set STOR mode.
                CMP     #'R'            ; "R"?
                BEQ     RUN             ; Yes. Run user program.
                CMP     #'L'            ;* "L"?
                BEQ     LOADINT         ;* Yes, Load Intel Code
                STX     L               ; $00->L.
                STX     H               ;  and H.
                STY     YSAV            ; Save Y for comparison.
NEXTHEX:        LDA     IN,Y            ; Get character for hex test.
                EOR     #$30            ; Map digits to $0-9.
                CMP     #$0A            ; Digit?
                BCC     DIG             ; Yes.
                ADC     #$88            ; Map letter "A"-"F" to $FA-FF.
                CMP     #$FA            ; Hex letter?
                BCC     NOTHEX          ; No, character not hex.
DIG:            ASL
                ASL                     ; Hex digit to MSD of A.
                ASL
                ASL
                LDX     #$04            ; Shift count.
HEXSHIFT:       ASL                     ; Hex digit left, MSB to carry.
                ROL     L               ; Rotate into LSD.
                ROL     H               ; Rotate into MSD’s.
                DEX                     ; Done 4 shifts?
                BNE     HEXSHIFT        ; No, loop.
                INY                     ; Advance text index.
                BNE     NEXTHEX         ; Always taken. Check next character for hex.
NOTHEX:         CPY     YSAV            ; Check if L, H empty (no hex digits).
                BNE     NOESCAPE        ; Branch out of range, had to improvise...
                JMP     ESCAPE          ; Yes, generate ESC sequence

RUN:            JSR     CRLF
                JSR     ACTRUN          ; JSR to the Address we want to run
                JMP     SOFTRESET       ; When returned for the program, reset EWOZ
ACTRUN:         LDA     REGP
                PHP
                LDA     REGA
                LDX     REGX
                LDY     REGY
                PLP
                JMP     (XAML)          ; Run at current XAM index

LOADINT:        JSR     LOADINTEL       ; Load the Intel code
                JMP     SOFTRESET       ; When returned from the program, reset EWOZ

NOESCAPE:       BIT     MODE            ; Test MODE byte.
                BVC     NOTSTOR         ; B6=0 STOR, 1 for XAM and BLOCK XAM
                LDA     L               ; LSD’s of hex data.
                STA     (STL,X)         ; Store at current ‘store index’.
                INC     STL             ; Increment store index.
                BNE     NEXTITEM        ; Get next item. (no carry).
                INC     STH             ; Add carry to ‘store index’ high order.
TONEXTITEM:     JMP     NEXTITEM        ; Get next command item.
NOTSTOR:        BMI     XAMNEXT         ; B7=0 for XAM, 1 for BLOCK XAM.
                LDX     #$02            ; Byte count.
SETADR:         LDA     L-1,X           ; Copy hex data to
                STA     STL-1,X         ;  ‘store index’.
                STA     XAML-1,X        ; And to ‘XAM index’.
                DEX                     ; Next of 2 bytes.
                BNE     SETADR          ; Loop unless X=0.
NXTPRNT:        BNE     PRDATA          ; NE means no address to print.

                JSR     CRLF            ; CR.
                LDA     XAMH            ; ‘Examine index’ high-order byte.
                JSR     PRBYTE          ; Output it in hex format.
                LDA     XAML            ; Low-order ‘examine index’ byte.
                JSR     PRBYTE          ; Output it in hex format.
                LDA     #':'            ; ":".
                JSR     ECHO            ; Output it.
PRDATA:         LDA     #$20            ; Blank.
                JSR     ECHO            ; Output it.
                LDA     (XAML,X)        ; Get data byte at ‘examine index’.
                JSR     PRBYTE          ; Output it in hex format.
XAMNEXT:        STX     MODE            ; 0->MODE (XAM mode).
                LDA     XAML    
                CMP     L               ; Compare ‘examine index’ to hex data.
                LDA     XAMH    
                SBC     H       
                BCS     TONEXTITEM      ; Not less, so no more data to output.
                INC     XAML    
                BNE     MOD8CHK         ; Increment ‘examine index’.
                INC     XAMH    
MOD8CHK:        LDA     XAML            ; Check low-order ‘examine index’ byte
                AND     #$07            ;  For MOD 8=0
                BPL     NXTPRNT         ; Always taken.
PRBYTE:         PHA                     ; Save A for LSD.
                LSR             
                LSR             
                LSR                     ; MSD to LSD position.
                LSR             
                JSR     PRHEX           ; Output hex digit.
                PLA                     ; Restore A.
PRHEX:          AND     #$0F            ; Mask LSD for hex print.
                ORA     #'0'            ; Add "0".
                CMP     #$3A            ; Digit?
                BCC     ECHO            ; Yes, output it.
                ADC     #$06            ; Add offset for letter.
ECHO:
                PHA
ECHOLOOP:
                LDA     DUA_SRA         ; Check TXRDY bit
                AND     #$04    
                BEQ     ECHOLOOP        ; Loop if not ready (bit clear)
                PLA             
                STA     DUA_TBA         ; else, send character
                RTS                     ; Return.

SHWMSG:         LDY     #$0
SHWMSG1:        LDA     (MSGL),Y
                BEQ     .DONE
                JSR     ECHO
                INY 
                BNE     SHWMSG1
.DONE           RTS 

CRLF:           LDA     #CR
                JSR     ECHO
                LDA     #LF
                JMP     ECHO

WOZHITBRK:
                STY     BANKSAV         ; save BANK_SET at BRK time
                CLI
                CLD
                LDA     #<BRKMSG
                STA     MSGL
                LDA     #>BRKMSG
                STA     MSGH
                JSR     SHWMSG
                LDA     $106,X
                STA     MSGH
                LDA     $105,X
                SEC
                SBC     #2
                STA     MSGL
                LDA     MSGH
                SBC     #0
                JSR     PRBYTE
                LDA     MSGL
                JSR     PRBYTE
                LDA     #'B'
                JSR     PRREGNAME
                LDA     BANKSAV
                JSR     PRBYTE
                LDA     #'S'
                JSR     PRREGNAME
                TXA
                CLC
                ADC     #6              ; A X Y P RL RH
                JSR     PRBYTE
                JMP     BRKCONT

PRREGNAME:      PHA
                LDA     #' '
                JSR     ECHO
                PLA
                JSR     ECHO
                LDA     #'='
                JMP     ECHO

;-------------------------------------------------------------------------
; Load an program in Intel Hex Format.
;-------------------------------------------------------------------------

LOADINTEL:      LDA     #CR
                JSR     ECHO           
                LDA     #<TRBEGMSG
                STA     MSGL
                LDA     #>TRBEGMSG
                STA     MSGH
                JSR     SHWMSG          ; Show Start Transfer           
                LDY     #$00
                STY     CRCCHECK        ; If CRCCHECK=0, all is good
INTELLINE:      JSR     GETCHAR         ; Get char
                STA     IN,Y            ; Store it
                INY                     ; Next
                CMP     #ESC            ; Escape ?
                BEQ     INTELDONE       ; Yes, abort
                CMP     #LF             ; Did we find a new line ?
                BNE     INTELLINE       ; Nope, continue to scan line
                LDY     #$FF            ; Find (:)
FINDCOL:        INY     
                LDA     IN,Y    
                CMP     #':'            ; Is it Colon ?
                BNE     FINDCOL         ; Nope, try next
                INY                     ; Skip colon
                LDX     #$00            ; Zero in X
                STX     CRC             ; Zero Check sum
                JSR     GETHEX          ; Get Number of bytes
                STA     COUNTER         ; Number of bytes in Counter
                CLC                     ; Clear carry
                ADC     CRC             ; Add CRC
                STA     CRC             ; Store it
                JSR     GETHEX          ; Get Hi byte
                STA     STH             ; Store it
                CLC                     ; Clear carry
                ADC     CRC             ; Add CRC
                STA     CRC             ; Store it
                JSR     GETHEX          ; Get Lo byte
                STA     STL             ; Store it
                CLC                     ; Clear carry
                ADC     CRC             ; Add CRC
                STA     CRC             ; Store it
                LDA     #'.'            ; Load "."
                JSR     ECHO            ; Print it to indicate activity
NODOT:          JSR     GETHEX          ; Get Control byte
                CMP     #$01            ; Is it a Termination record ?
                BEQ     INTELDONE       ; Yes, we are done
                CLC                     ; Clear carry
                ADC     CRC             ; Add CRC
                STA     CRC             ; Store it
INTELSTORE:     JSR     GETHEX          ; Get Data Byte
                STA     (STL,X)         ; Store it
                CLC                     ; Clear carry
                ADC     CRC             ; Add CRC
                STA     CRC             ; Store it
                INC     STL             ; Next Address
                BNE     TESTCOUNT       ; Test to see if Hi byte needs INC
                INC     STH             ; If so, INC it
TESTCOUNT:      DEC     COUNTER         ; Count down
                BNE     INTELSTORE      ; Next byte
                JSR     GETHEX          ; Get Checksum
                LDY     #$00            ; Zero Y
                CLC                     ; Clear carry
                ADC     CRC             ; Add CRC
                BEQ     INTELLINE       ; Checksum OK
                LDA     #$01            ; Flag CRC error
                STA     CRCCHECK        ; Store it
                JMP     INTELLINE       ; Process next line

INTELDONE:      LDA     CRCCHECK        ; Test if everything is OK
                BEQ     OKMESS          ; Show OK message
                LDA     #<TRBADMSG      ; Load Error Message
                STA     MSGL
                LDA     #>TRBADMSG
                STA     MSGH
                JSR     SHWMSG          ; Show Error
                RTS

OKMESS:
                LDA     #<TROKMSG      ; Load OK Message
                STA     MSGL
                LDA     #>TROKMSG
                STA     MSGH
                JSR     SHWMSG          ; Show Done
                RTS

GETHEX:         LDA     IN,Y            ; Get first char
                EOR     #$30
                CMP     #$0A
                BCC     DONEFIRST
                ADC     #$08
DONEFIRST:      ASL
                ASL
                ASL
                ASL
                STA     L
                INY
                LDA     IN,Y            ; Get next char
                EOR     #$30
                CMP     #$0A
                BCC     DONESECOND
                ADC     #$08
DONESECOND:     AND     #$0F
                ORA     L
                INY
                RTS

;-------------------------------------------------------------------------

GETCHAR:        LDA     DUA_SRA         ; Key ready?
                ROR                     ; (Bit 0 of DUART SRA to C)
                BCC     GETCHAR         ; Loop until ready.
                LDA     DUA_TBA         ; Load character. 
                RTS

;-------------------------------------------------------------------------

MONMSG          asciiz   $0D, $0A, "rosco_6502 EWozMon:"
BRKMSG          asciiz  $0D,$0A,$07, "BRK @"
TRBEGMSG        asciiz  "Start Intel hex code import:",$0D,$0A
TROKMSG         asciiz  $0D,$0A,"Intel hex imported OK.",$0D,$0A
TRBADMSG        asciiz  $0D,$0A,$07,"Intel hex imported with checksum error.",$0D,$0A
