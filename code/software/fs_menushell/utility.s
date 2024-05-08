; vim: set et ts=8 sw=8
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
; Utility functions
;------------------------------------------------------------

		.code

; Some code adapted from:
; http://www.6502.org/source/general/memory_move.html
; - Thanks!

;
; copymem - copy (sptr) to (dptr) for A/X (L/H) bytes
;  in:   A/X (L/H), sptr, dptr
;  out:  -
;  uses: A, X, Y, sptr, dptr
;
copymem:		pha			; save size L
			ldy	#0		; zero index
			txa			; test size H
			beq	@copytail	; branch if < 256 bytes
@copypage:		lda	(sptr),y	; load source
			sta	(dptr),y	; store dest
			iny			; inc index
			bne	@copypage	; loop for 256 bytes
			inc	sptr+1		; next source page
			inc	dptr+1		; next dest page
			dex			; dec page copy count
			bne	@copypage	; copy pages while positive
@copytail:		plx			; get size L
			beq	@copydone	; branch if done
@copybytes:		lda	(sptr),y	; load source
			sta	(dptr),y	; store dest
			iny			; inc index
			dex			; dec count
			bne	@copybytes	; loop for remaining bytes
@copydone:		rts

;
; zeromem - fill (dptr) for Y/X (L/H) bytes with zero
; fillmem - fill (dptr) for Y/X (L/H) bytes with A
;  in:   A/X (L/H), dptr, Y (for fillmem)
;  out:  -
;  uses: A, X, Y, sptr, dptr
;
zeromem:		ldy	#0		; zero fill entry point
fillmem:		pha			; save size L
                        tya
			ldy	#0		; zero index
			cpx	#0		; test size H
			beq	@filltail	; branch if < 256 bytes
@fillpage:		sta	(dptr),y	; store dest
			iny			; inc index
			bne	@fillpage	; loop for 256 bytes
			inc	dptr+1		; next dest page
			dex			; dec page copy count
			bne	@fillpage	; copy pages while positive
@filltail:		plx			; get size L
			beq	@filldone	; branch if done
@fillbytes:		sta	(dptr),y	; store dest
			iny			; inc index
			dex			; dec count
			bne	@fillbytes	; loop for remaining bytes
@filldone:		rts

;
; strlen - return length of string (max 255 chars)
;  in:   A/X (L/H) or (cptr)
;  out:  Y (not including NUL)
;  uses: sptr
;
strlen:			sta	cptr
			stx	cptr+1
strlen_cptr:		ldy	#0
@strloop:		lda	(cptr),y
			beq	@strend
			iny
			bne	@strloop
			DBRK
@strend:		rts

;
; strcpy - copy string from (sptr) to (dptr) (max 255 chars)
;  in:   A/X (L/H) or sptr, dptr
;  out:  Y chars copied (not including NUL)
;  uses: sptr
;
strcpy:			sta	sptr
			stx	sptr+1
strcpy_sptr:		ldy	#0
@strloop:		lda	(sptr),y
			sta	(dptr),y
			beq	@strend
			iny
			bne	@strloop
			DBRK
@strend:		iny
			rts


;
; strcat - append string from (sptr) to end of (dptr) (max 255 chars)
;  in:   A/X (L/H) or sptr, dptr
;  out:  Y chars copied (not including NUL)
;  uses: sptr
;
strcat:			sta	sptr
			stx	sptr+1
strcat_sptr:		MOVW	dptr,cptr
			jsr	strlen
			ADDW	y,dptr
			ldy	#0
@strloop:		lda	(sptr),y
			sta	(dptr),y
			beq	@strend
			iny
			bne	@strloop
			DBRK
@strend:		iny
			rts

;
; strncmp - compare string cptr to sptr for length A chars
;  in:   A = length (>=1), cptr, sptr
;  out:  Z=1 and A=0 if strings match up to length (or cptr end)
;  uses: A, cptr, sptr, len
;
strncmp:		sta	slen		; store length in len
strncmp_len:		phy			; save Y
			ldy	#0		; start index at first char
@strloop:		lda	(cptr),y	; load cptr char
			cmp	(sptr),y	; is cptr char equal to sptr char?
			bne	@strnoteq	; branch if no match
			cmp	#0		; was the the end of both strings
			beq	@streq		; branch if yes, return match
			iny			; next char
			cpy	slen		; are we at length?
			bne	@strloop	; branch if not and keep matching
@streq:			ply			; restore Y
			lda	#$00		; match, return zero
			rts			; return (with Z=1)

@strnoteq:		ply			; restore Y
			lda	#$FF		; no match, return $FF
			rts			; return (with Z=0)

;
; tolower - convert uppercase ASCII to lowercase
;
tolower:		cmp	#'Z'+1
			blt	@nothigh
			rts

@nothigh:		cmp	#'A'
			bge	@notlow
			rts

@notlow:		ora	#$20
			rts


crlf:                   lda     #$D
                        jsr     COUT
                        lda     #$A
                        jmp     COUT
; ;
; ; print char in A with special handling
; ;
; putchar:	pha
; 		cmp	#' '		; is this a low ctrl char?
; 		bge	@notlowctrl	; branch if not
; 		cmp	#$0A		; is this LF?
; 		bne	@iscr		; branch if not
; 		lda	#prf_EOL_sent	; EOL flag bit
; 		trb	print_flags	; test if already printed EOL and clear
; 		beq	@preol		; branch if not printed and print EOL
; @eatchar:	bra	@exitprcr	; return and eat LF extra EOL from CR/LF

; @iscr:		cmp	#CR		; is this CR?
; 		bne	@istab		; branch if not
; 		lda	#prf_EOL_sent	; EOL flag bit
; 		tsb	print_flags	; set EOL printed flag?
; @preol:		stz	tabcol		; clear TAB column
; 		lda	#CR		; load CR
; 		jsr	CHROUT		; print CR
; 		bra	@exitprcr	; done

; @istab:		cmp	#CH::TAB	; is this TAB?
; 		bne	@printhex	; branch if not
; @prtab:		lda	#' '		; load space
; 		jsr	CHROUT		; print space
; 		inc	tabcol		; increment tab column
; 		lda	tabcol		; load tab column
; 		and	#%00000111	; are we at tab stop?
; 		bne	@prtab		; branch of not
; 		bra	@exitprcr	; done

; @notlowctrl:	cmp	#$80		; could it be high ctrl char?
; 		blt	@printable	; branch if not
; 		cmp	#$A0		; is it high ctrl char?
; 		bge	@printable	; branch if not
; @printhex:;	bit	print_flags	; test if printing hex ctrl chars (bit 6)
; ;		bvc	@prchr
; 		bra	@prchr
; 		pha			; save char
; 		lda	tabcol		; load tab column
; 		clc			; clear carry
; 		adc	#4		; add 4 chars "\xXX"
; 		sta	tabcol		; store tab column
; 		lda	#$5C		; load '\'
; 		jsr	CHROUT		; print
; 		lda	#'x'		; load 'x'
; 		jsr	CHROUT		; print
; 		pla			; get char
; 		jmp	prbyte		; print hex and return

; @printable:	inc	tabcol
; @prchr:		jsr	CHROUT
; @exitprcr:	pla
; 		rts

; delay:		jsr	delaytick
; 		dex
; 		bne	delay
; 		rts

; delaytick:	phx
; 		jsr	RDTIM
; 		sta	val
; @delayloop:	jsr	RDTIM
; 		cmp	val
; 		beq	@delayloop
; 		plx
; 		rts

; EOF
