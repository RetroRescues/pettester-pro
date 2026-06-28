	; petromid2k.asm
	;
	; Standalone PET ROM identifier/checker for the One ROM menu system.
	; It computes CRC-16/CCITT over CPU-visible ROM ranges and compares the
	; result against a compact table generated from the zimmers.net PET ROM
	; archive. The diagnostic ROM replaces the EDIT ROM at $E000, so this
	; image cannot verify the machine's original EDIT ROM in place.

SET_POS	.macro y,x
	lda	#y
	ldx	#x
	jsr	SET_POS_RT
	.endm

SET_STR	.macro s
	lda	#<s
	sta	STRLL
	lda	#>s
	sta	STRHH
	.endm

EDITROM	.equ	$E000

vdu0	.equ	$8000
vdu1	.equ	$8100
vdu2	.equ	$8200
vdu3	.equ	$8300
vdu4	.equ	$8400
vdu5	.equ	$8500
vdu6	.equ	$8600
vdu7	.equ	$8700

crtca	.equ	$E880
crtcd	.equ	$E881
spc	.equ	$20

VDULL	.equ	$03
VDUHH	.equ	$04
STRLL	.equ	$05
STRHH	.equ	$06
ROMLL	.equ	$07
ROMHH	.equ	$08
PAGES	.equ	$09
CRCHI	.equ	$0A
CRCLO	.equ	$0B
TEMP	.equ	$0C
SCANHI	.equ	$0D
SCANPAGES .equ	$0E
SCANIDX	.equ	$0F
LINELL	.equ	$10
LINEHH	.equ	$11
YSAVE	.equ	$12
REFRESH	.equ	$13
ROWSTEP	.equ	$14
POSY	.equ	$15

	.org	EDITROM

	jmp	start

CRTC_INIT:
	.byte	49,40,41,15,32,3,25,29,0,9,0,0,16,0,0,0,0,0

start:
	sei
	cld
	ldx	#$FF
	txs
	ldx	#0
more_crtc:
	lda	CRTC_INIT,x
	stx	crtca
	sta	crtcd
	inx
	cpx	#$12
	bne	more_crtc
	jsr	DETECT_SCREEN

main_loop:
	jsr	CLEAR_SCREEN
	SET_POS 0,0
	SET_STR TITLE
	jsr	PRINTZ
	SET_POS 2,0
	SET_STR TABLE_TOP
	jsr	PRINTZ
	SET_POS 3,0
	SET_STR TABLE_HDR
	jsr	PRINTZ
	SET_POS 4,0
	SET_STR TABLE_SEP
	jsr	PRINTZ
	SET_POS 5,0
	jsr	LINE_HERE

	ldx	#0
scan_next:
	lda	SCAN_LIST,x
	beq	scan_done
	sta	SCANHI
	lda	SCAN_LIST+1,x
	sta	SCANPAGES
	lda	SCAN_LIST+2,x
	sta	STRLL
	lda	SCAN_LIST+3,x
	sta	STRHH
	stx	SCANIDX
	SET_STR ROW_START
	jsr	PRINTZ
	ldx	SCANIDX
	lda	SCAN_LIST+2,x
	sta	STRLL
	lda	SCAN_LIST+3,x
	sta	STRHH
	jsr	PRINTZ
	SET_STR COL_SEP
	jsr	PRINTZ
	jsr	COMPUTE_CRC
	lda	CRCHI
	jsr	OUTHEX
	lda	CRCLO
	jsr	OUTHEX
	SET_STR COL_SEP
	jsr	PRINTZ
	jsr	FIND_ROM_ROW
	SET_STR ROW_END
	jsr	PRINTZ
	jsr	NL
	ldx	SCANIDX
	inx
	inx
	inx
	inx
	bne	scan_next

scan_done:
	SET_STR TABLE_TOP
	jsr	PRINTZ
	SET_POS 11,0
	SET_STR NOTE
	jsr	PRINTZ
	SET_POS 12,0
	SET_STR NOTE2
	jsr	PRINTZ
	SET_POS 14,0
	SET_STR REFRESH_TXT
	jsr	PRINTZ
	jsr	COUNTDOWN_DELAY
	jmp	main_loop

COMPUTE_CRC:
	; CRC-16/CCITT, initial value $FFFF, polynomial $1021. This is slower
	; than PETTESTER's additive sum but avoids the collisions found in the
	; downloaded PET ROM corpus while still needing only two table bytes.
	lda	#$FF
	sta	CRCHI
	sta	CRCLO
	lda	#0
	sta	ROMLL
	lda	SCANHI
	sta	ROMHH
	lda	SCANPAGES
	sta	PAGES
crc_page:
	ldy	#0
crc_byte:
	lda	(ROMLL),y
	eor	CRCHI
	sta	CRCHI
	ldx	#8
crc_bit:
	asl	CRCLO
	rol	CRCHI
	bcc	crc_no_xor
	lda	CRCHI
	eor	#$10
	sta	CRCHI
	lda	CRCLO
	eor	#$21
	sta	CRCLO
crc_no_xor:
	dex
	bne	crc_bit
	iny
	bne	crc_byte
	inc	ROMHH
	dec	PAGES
	bne	crc_page
	rts

FIND_ROM_ROW:
	ldx	#0
find_loop:
	lda	ROM_TABLE,x
	beq	find_miss
	cmp	SCANHI
	bne	find_next
	lda	ROM_TABLE+1,x
	cmp	SCANPAGES
	bne	find_next
	lda	ROM_TABLE+2,x
	cmp	CRCHI
	bne	find_next
	lda	ROM_TABLE+3,x
	cmp	CRCLO
	bne	find_next
	SET_STR OK_ROW
	jsr	PRINTZ
	lda	ROM_TABLE+4,x
	sta	STRLL
	lda	ROM_TABLE+5,x
	sta	STRHH
	jmp	PRINTZ
find_next:
	txa
	clc
	adc	#6
	tax
	bne	find_loop
find_miss:
	SET_STR MISS_ROW
	jmp	PRINTZ

CLEAR_SCREEN:
	ldx	#0
	lda	#spc
clear_loop:
	sta	vdu0,x
	sta	vdu1,x
	sta	vdu2,x
	sta	vdu3,x
	sta	vdu4,x
	sta	vdu5,x
	sta	vdu6,x
	sta	vdu7,x
	inx
	bne	clear_loop
	rts

DETECT_SCREEN:
	lda	#40
	sta	ROWSTEP
	lda	#$55
	sta	vdu0+1
	lda	#$AA
	sta	vdu4+1
	lda	vdu0+1
	cmp	#$55
	bne	detect_done
	lda	vdu4+1
	cmp	#$AA
	bne	detect_done
	lda	#80
	sta	ROWSTEP
detect_done:
	lda	#spc
	sta	vdu0+1
	sta	vdu4+1
	rts

SET_POS_RT:
	sta	POSY
	stx	VDULL
	lda	#$80
	sta	VDUHH
	lda	POSY
	beq	set_pos_done
set_pos_loop:
	clc
	lda	VDULL
	adc	ROWSTEP
	sta	VDULL
	bcc	set_pos_no_carry
	inc	VDUHH
set_pos_no_carry:
	dec	POSY
	bne	set_pos_loop
set_pos_done:
	rts

PRINTZ:
	ldy	#0
printz_loop:
	lda	(STRLL),y
	beq	printz_done
	jsr	OUTCHAR
	iny
	bne	printz_loop
printz_done:
	rts

OUTCHAR:
	cmp	#$41
	bcc	outchar_store
	cmp	#$5B
	bcs	outchar_store
	and	#$1F
outchar_store:
	sty	YSAVE
	ldy	#0
	sta	(VDULL),y
	ldy	YSAVE
	inc	VDULL
	bne	outchar_done
	inc	VDUHH
outchar_done:
	rts

OUTSPACE:
	lda	#spc
	jmp	OUTCHAR

NL:
	clc
	lda	LINELL
	adc	ROWSTEP
	sta	LINELL
	lda	LINEHH
	adc	#0
	sta	LINEHH
	lda	LINELL
	sta	VDULL
	lda	LINEHH
	sta	VDUHH
nl_done:
	rts

LINE_HERE:
	lda	VDULL
	sta	LINELL
	lda	VDUHH
	sta	LINEHH
	rts

OUTHEX:
	sta	TEMP
	lsr
	lsr
	lsr
	lsr
	jsr	OUTNIB
	lda	TEMP
	and	#$0F
OUTNIB:
	cmp	#10
	bcc	outnib_digit
	clc
	adc	#6
outnib_digit:
	clc
	adc	#$30
	jmp	OUTCHAR

DELAY:
	lda	#40
delay_outer:
	ldx	#0
	ldy	#0
delay_inner:
	dex
	bne	delay_inner
	dey
	bne	delay_inner
	sec
	sbc	#1
	bne	delay_outer
	rts

COUNTDOWN_DELAY:
	lda	#9
	sta	REFRESH
countdown_loop:
	lda	REFRESH
	ora	#$30
	pha
	SET_POS 14,11
	pla
	ldy	#0
	sta	(VDULL),y
	jsr	DELAY
	dec	REFRESH
	bne	countdown_loop
	rts

SCAN_LIST:
	.byte	$B0,16,<LAB_B000,>LAB_B000
	.byte	$C0,16,<LAB_C000,>LAB_C000
	.byte	$D0,16,<LAB_D000,>LAB_D000
	.byte	$F0,16,<LAB_F000,>LAB_F000
	.byte	0

	; Table entry format: start high byte, pages, CRC high, CRC low, name ptr.
	; These are unique CPU-visible 2K/4K ROM images from the downloaded PET
	; firmware corpus, excluding EDIT ROMs because this diagnostic occupies E000.
ROM_TABLE:
	.byte	$B0,16,$B3,$4E,<N_WB,>N_WB
	.byte	$B0,16,$8B,$53,<N_B4B19,>N_B4B19
	.byte	$B0,16,$07,$E9,<N_B4B23,>N_B4B23
	.byte	$B0,16,$8E,$DB,<N_CCRB,>N_CCRB
	.byte	$B0,16,$04,$8A,<N_BEEB,>N_BEEB
	.byte	$B0,8,$BF,$75,<N_PAICSB,>N_PAICSB
	.byte	$B0,8,$AB,$8D,<N_B2EXT,>N_B2EXT
	.byte	$B0,8,$E5,$05,<N_TOOLB,>N_TOOLB
	.byte	$C0,16,$80,$A1,<N_WC,>N_WC
	.byte	$C0,16,$F8,$28,<N_B2C,>N_B2C
	.byte	$C0,16,$6D,$18,<N_B4C,>N_B4C
	.byte	$C0,8,$A0,$51,<N_R1C0,>N_R1C0
	.byte	$C0,8,$75,$6C,<N_R2C0,>N_R2C0
	.byte	$C0,8,$2E,$8E,<N_R3C0,>N_R3C0
	.byte	$C8,8,$9F,$FE,<N_R1C8,>N_R1C8
	.byte	$C8,8,$64,$56,<N_R3C8,>N_R3C8
	.byte	$D0,16,$58,$44,<N_WD,>N_WD
	.byte	$D0,16,$34,$8B,<N_B2D,>N_B2D
	.byte	$D0,16,$00,$CE,<N_B4D,>N_B4D
	.byte	$D0,8,$12,$51,<N_R1D0,>N_R1D0
	.byte	$D0,8,$22,$85,<N_R3D0,>N_R3D0
	.byte	$D8,8,$4C,$E5,<N_R1D8,>N_R1D8
	.byte	$D8,8,$95,$FC,<N_R3D8,>N_R3D8
	.byte	$F0,16,$DB,$14,<N_WF,>N_WF
	.byte	$F0,16,$E9,$3A,<N_CRANE,>N_CRANE
	.byte	$F0,16,$CA,$45,<N_PET80F,>N_PET80F
	.byte	$F0,16,$45,$94,<N_CCRF,>N_CCRF
	.byte	$F0,16,$47,$52,<N_K2,>N_K2
	.byte	$F0,16,$20,$2E,<N_K4,>N_K4
	.byte	$F0,8,$B1,$60,<N_R1F0,>N_R1F0
	.byte	$F0,8,$BE,$33,<N_R3F0,>N_R3F0
	.byte	$F8,8,$54,$C1,<N_R1F8,>N_R1F8
	.byte	$F8,8,$6A,$54,<N_R3F8,>N_R3F8
	.byte	0

TITLE:		.byte	scr("PET CPU ROM CRC16"),0
TABLE_TOP:	.byte	scr("+------+-------+-------+--------------+"),0
TABLE_HDR:	.byte	scr("| ROM  | CRC   | CHECK | MATCHES      |"),0
TABLE_SEP:	.byte	scr("+------+-------+-------+--------------+"),0
ROW_START:	.byte	scr("| "),0
COL_SEP:	.byte	scr(" | "),0
ROW_END:	.byte	scr(" |"),0
NOTE:		.byte	scr("E000 EDIT IS THIS TEST ROM"),0
NOTE2:		.byte	scr("CHAR ROM IS NOT CPU READABLE"),0
REFRESH_TXT:	.byte	scr("REFRESH IN 9"),0
OK_ROW:		.byte	scr("OK    | "),0
MISS_ROW:	.byte	scr("MISS  | UNKNOWN"),0
LAB_B000:	.byte	scr("B000"),0
LAB_C000:	.byte	scr("C000"),0
LAB_D000:	.byte	scr("D000"),0
LAB_F000:	.byte	scr("F000"),0

N_WB:		.byte	scr("WATERLOO B"),0
N_WC:		.byte	scr("WATERLOO C"),0
N_WD:		.byte	scr("WATERLOO D"),0
N_WF:		.byte	scr("WATERLOO F"),0
N_B4B19:	.byte	scr("BASIC4 B-19"),0
N_B4B23:	.byte	scr("BASIC4 B-23"),0
N_B4C:		.byte	scr("BASIC4 C"),0
N_B4D:		.byte	scr("BASIC4 D"),0
N_B2C:		.byte	scr("BASIC2 C"),0
N_B2D:		.byte	scr("BASIC2 D"),0
N_K2:		.byte	scr("KERNAL2"),0
N_K4:		.byte	scr("KERNAL4"),0
N_CCRB:		.byte	scr("CASHREG B"),0
N_CCRF:		.byte	scr("CASHREG F"),0
N_BEEB:		.byte	scr("BEE B000"),0
N_PAICSB:	.byte	scr("PAICS B"),0
N_B2EXT:	.byte	scr("BASIC2 EXT"),0
N_TOOLB:	.byte	scr("TOOLKIT B"),0
N_CRANE:	.byte	scr("CRANE F"),0
N_PET80F:	.byte	scr("PET80 F"),0
N_R1C0:		.byte	scr("ROM1 C0"),0
N_R1C8:		.byte	scr("ROM1 C8"),0
N_R1D0:		.byte	scr("ROM1 D0"),0
N_R1D8:		.byte	scr("ROM1 D8"),0
N_R1F0:		.byte	scr("ROM1 F0"),0
N_R1F8:		.byte	scr("ROM1 F8"),0
N_R2C0:		.byte	scr("ROM2 C0"),0
N_R3C0:		.byte	scr("ROM3 C0"),0
N_R3C8:		.byte	scr("ROM3 C8"),0
N_R3D0:		.byte	scr("ROM3 D0"),0
N_R3D8:		.byte	scr("ROM3 D8"),0
N_R3F0:		.byte	scr("ROM3 F0"),0
N_R3F8:		.byte	scr("ROM3 F8"),0

	.org	$E800
