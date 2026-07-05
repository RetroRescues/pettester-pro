	; diagclipedit2k.asm
	;
	; Proof-of-life EDIT-ROM wrapper for the Commodore Diagnostic Clip ROM.
	;
	; The original diagnostic clip boots from $F000, performs early checks,
	; copies its main diagnostic body to $0200, asks the user to remove the CPU
	; clip, then runs from RAM. This wrapper is for the One ROM menu path: it
	; starts at the EDIT ROM entry point, copies the already-extracted RAM body
	; to $0200, then jumps to it.
	;
	; This first wrapper intentionally does not initialise the CRTC. The body
	; plus copy loader almost fills the 2K EDIT ROM slot. It is intended to be
	; launched from the menu after the menu has already set up the display.

EDITROM	.equ	$E000

SRCLO	.equ	$00
SRCHI	.equ	$01
DSTLO	.equ	$02
DSTHI	.equ	$03
CNTLO	.equ	$04
CNTHI	.equ	$05

	.org	EDITROM

	lda	#<DIAG_BODY
	sta	SRCLO
	lda	#>DIAG_BODY
	sta	SRCHI
	lda	#0
	sta	DSTLO
	lda	#2
	sta	DSTHI
	lda	#$AE		; Copy $07AE bytes, matching the diagnostic clip loader.
	sta	CNTLO
	lda	#7
	sta	CNTHI
	ldy	#0

COPY_BODY:
	lda	(SRCLO),y
	sta	(DSTLO),y
	inc	SRCLO
	bne	SRC_OK
	inc	SRCHI
SRC_OK:
	inc	DSTLO
	bne	DST_OK
	inc	DSTHI
DST_OK:
	dec	CNTLO
	bne	COPY_BODY
	dec	CNTHI
	bpl	COPY_BODY

	jmp	$0200

DIAG_BODY:
	.incbin	"src/diagclip_body_u2u3.bin"

	.org	$E800
