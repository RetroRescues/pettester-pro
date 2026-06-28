	; petieee2k.asm
	;
	; Standalone IEEE-488/GPIB diagnostic ROM for Commodore PET/CBM machines.
	; This is intended for use as a separate One ROM menu target, not as part
	; of the already-full PETTESTER image.
	;
	; The test is based on the Commodore BASIC listing and the compact
	; PETTESTER V6 implementation. It drives the PET-side IEEE outputs, reads
	; the matching inputs, and reports each line clearly.

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

pia1	.equ	$E810
pia2	.equ	$E820
via	.equ	$E840
crtca	.equ	$E880
crtcd	.equ	$E881

spc	.equ	$20

VDULL	.equ	$03
VDUHH	.equ	$04
STRLL	.equ	$05
STRHH	.equ	$06
TEMP	.equ	$07
DATAMASK .equ	$08
CTRLMASK .equ	$09
ADDRLL	.equ	$0A
ADDRHH	.equ	$0B
VALUE0	.equ	$0C
VALUE1	.equ	$0D
RUNLO	.equ	$0E
RUNHI	.equ	$0F
IDX	.equ	$10
LINELL	.equ	$11
LINEHH	.equ	$12
YSAVE	.equ	$13
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

	lda	#0
	sta	RUNLO
	sta	RUNHI
	jsr	CLEAR_SCREEN
	SET_POS 0,0
	SET_STR TITLE
	jsr	PRINTZ
	SET_POS 3,0
	SET_STR TESTING_TXT
	jsr	PRINTZ
	jsr	RUN_IEEE
	jsr	DELAY

main_loop:
	jsr	CLEAR_SCREEN
	SET_POS 0,0
	SET_STR TITLE
	jsr	PRINTZ
	SET_POS 1,0
	SET_STR LEGEND
	jsr	PRINTZ

	jsr	RUN_IEEE
	jsr	SHOW_RESULTS
	jsr	DELAY
	jmp	main_loop

RUN_IEEE:
	; Data bus test. PIA #2 port B writes DIO1-DIO8; PIA #2 port A
	; reads them back through the IEEE bus input path. A bit left set
	; in DATAMASK means that DIO line failed either low or high.
	lda	#0
	sta	pia2+2
	lda	pia2
	sta	TEMP
	lda	#$FF
	sta	pia2+2
	lda	pia2
	eor	#$FF
	ora	TEMP
	sta	DATAMASK

	; VIA DDRB must only drive PB1/PB2. PB0/PB6/PB7 are read inputs for
	; NDAC/NRFD/DAV, so making all of port B outputs causes false failures.
	lda	#$06
	sta	via+2
	lda	#0
	sta	CTRLMASK
	lda	#$E8
	sta	ADDRHH
	ldy	#0
	ldx	#0

ctrl_loop:
	; Table order is EOI, NRFD, DAV, NDAC. Each entry writes two output
	; states and verifies the corresponding masked input in both states.
	lda	IEEE_W,x
	sta	ADDRLL
	lda	IEEE_V0,x
	sta	(ADDRLL),y
	lda	IEEE_R,x
	sta	ADDRLL
	lda	(ADDRLL),y
	and	IEEE_M,x
	sta	VALUE0

	lda	IEEE_W,x
	sta	ADDRLL
	lda	IEEE_V1,x
	sta	(ADDRLL),y
	lda	IEEE_R,x
	sta	ADDRLL
	lda	(ADDRLL),y
	and	IEEE_M,x
	sta	VALUE1

	lda	VALUE0
	cmp	IEEE_E0,x
	bne	ctrl_bad
	lda	VALUE1
	cmp	IEEE_E1,x
	beq	ctrl_next
ctrl_bad:
	lda	CTRLMASK
	ora	CTRL_BIT,x
	sta	CTRLMASK
ctrl_next:
	inx
	cpx	#4
	bne	ctrl_loop

	; ATN is latched on PIA #2 CA1. Reading port A clears the latch, then
	; VIA PB2 is pulsed high-low-high. CRA bit 7 should then be set.
	lda	pia2
	lda	#4
	sta	via
	lda	#0
	sta	via
	lda	#4
	sta	via
	lda	pia2+1
	and	#$80
	bne	atn_ok
	lda	CTRLMASK
	ora	#$01
	sta	CTRLMASK
atn_ok:
	lda	#$FF
	sta	via
	rts

SHOW_RESULTS:
	SET_POS 3,0
	jsr	LINE_HERE
	SET_STR DATA_HDR
	jsr	PRINTZ
	lda	DATAMASK
	jsr	OUTHEX

	ldx	#0
data_line:
	stx	IDX
	jsr	NL
	SET_STR DIO_TXT
	jsr	PRINTZ
	ldx	IDX
	txa
	clc
	adc	#$31
	jsr	OUTCHAR
	jsr	OUTSPACE
	ldx	IDX
	lda	DATAMASK
	and	BITVAL,x
	jsr	PRINT_STATUS
	ldx	IDX
	inx
	cpx	#8
	bne	data_line

	jsr	NL
	jsr	NL
	SET_STR CTRL_HDR
	jsr	PRINTZ
	lda	CTRLMASK
	jsr	OUTHEX

	ldx	#0
ctrl_line:
	stx	IDX
	jsr	NL
	lda	CTRL_NAME_LO,x
	sta	STRLL
	lda	CTRL_NAME_HI,x
	sta	STRHH
	jsr	PRINTZ
	jsr	OUTSPACE
	ldx	IDX
	lda	CTRLMASK
	and	CTRL_SHOW_BIT,x
	jsr	PRINT_STATUS
	ldx	IDX
	inx
	cpx	#5
	bne	ctrl_line

	jsr	NL
	jsr	NL
	lda	DATAMASK
	ora	CTRLMASK
	bne	show_bad
	SET_STR ALL_OK
	jsr	PRINTZ
	inc	RUNLO
	bne	show_run
	inc	RUNHI
	bne	show_run
show_bad:
	SET_STR HAS_FAIL
	jsr	PRINTZ
show_run:
	jsr	NL
	SET_STR RUN_TXT
	jsr	PRINTZ
	lda	RUNHI
	jsr	OUTHEX
	lda	RUNLO
	jsr	OUTHEX
	rts

PRINT_STATUS:
	cmp	#0
	bne	print_bad
	SET_STR OK_TXT
	jmp	PRINTZ
print_bad:
	SET_STR BAD_TXT
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
	lda	#20
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

IEEE_W:		.byte	$11,$40,$23,$21
IEEE_R:		.byte	$10,$40,$40,$40
IEEE_V0:	.byte	52,255,52,52
IEEE_V1:	.byte	60,253,60,60
IEEE_M:		.byte	64,64,128,1
IEEE_E0:	.byte	0,64,0,0
IEEE_E1:	.byte	64,0,128,1
CTRL_BIT:	.byte	$02,$04,$08,$10

BITVAL:		.byte	$01,$02,$04,$08,$10,$20,$40,$80
CTRL_SHOW_BIT:	.byte	$10,$08,$04,$02,$01

CTRL_NAME_LO:	.byte	<NDAC_TXT,<DAV_TXT,<NRFD_TXT,<EOI_TXT,<ATN_TXT
CTRL_NAME_HI:	.byte	>NDAC_TXT,>DAV_TXT,>NRFD_TXT,>EOI_TXT,>ATN_TXT

TITLE:		.byte	scr("IEEE-488 TEST"),0
TESTING_TXT:	.byte	scr("TESTING....."),0
LEGEND:		.byte	scr("BAD MEANS PET CANNOT DRIVE/READ LINE"),0
DATA_HDR:	.byte	scr("DATA MASK "),0
CTRL_HDR:	.byte	scr("CTRL MASK "),0
DIO_TXT:	.byte	scr("DIO"),0
NDAC_TXT:	.byte	scr("NDAC"),0
DAV_TXT:	.byte	scr("DAV "),0
NRFD_TXT:	.byte	scr("NRFD"),0
EOI_TXT:	.byte	scr("EOI "),0
ATN_TXT:	.byte	scr("ATN "),0
OK_TXT:		.byte	scr("OK"),0
BAD_TXT:	.byte	scr("BAD"),0
ALL_OK:		.byte	scr("ALL IEEE LINES OK"),0
HAS_FAIL:	.byte	scr("IEEE FAULT PRESENT"),0
RUN_TXT:	.byte	scr("GOOD PASSES "),0

	.org	$E800
