	; petmenu2k.asm
	;
	; 2K PET EDIT ROM menu/boot shim for One ROM RBCP.
	; Derived from the RetroRescues V6 pettester.asm startup path, but kept
	; separate so the original PETTESTER sources and binaries are not changed.
	;
	; Expected One ROM flash layout:
	;   slot 0: this menu ROM
	;   slot 1: normal EDIT ROM
	;   slot 2: PETTESTER V6 ROM
	;   slot 3: IEEE test ROM
	;   slot 4: ROM ID / CRC ROM
	;   slot 5: Diagnostic Clip wrapper ROM
	;
	; The ROM runs the early PETTESTER guard checks that matter before a menu:
	; video RAM and page 0/1 RAM. If those pass, it shows a fixed five-choice
	; menu. Any key selects the next target; waiting boots the selection.

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
RAMBOOT	.equ	$0200

via	.equ	$E840
crtca	.equ	$E880
crtcd	.equ	$E881
pia1	.equ	$E810

vdu0	.equ	$8000
vdu1	.equ	$8100
vdu2	.equ	$8200
vdu3	.equ	$8300
vdu4	.equ	$8400
vdu5	.equ	$8500
vdu6	.equ	$8600
vdu7	.equ	$8700

mem0	.equ	$0000
mem1	.equ	$0100

spc	.equ	$20
dot	.equ	$2E
gud1	.equ	$07
bad1	.equ	$02
right	.equ	$3E

VDULL	.equ	$03
VDUHH	.equ	$04
STRLL	.equ	$05
STRHH	.equ	$06
CNTDOWN	.equ	$08
SCREENK	.equ	$15
BOOTSEL	.equ	$16
RAM_PHASE	.equ	$19
RBCP_MODE	.equ	$1A
SLOT1ID	.equ	$1B
SLOT2ID	.equ	$1C
RBCP_NVBYTE	.equ	$1D
ROWSTEP	.equ	$1E
POSY	.equ	$1F
MENU1LINE	.equ	$20
MENU2LINE	.equ	$48
MENU1NAME	.equ	MENU1LINE+8
MENU2NAME	.equ	MENU2LINE+8

	.org	EDITROM

	jmp	BOOT_BEEP

CRTC_INIT:
	.byte	49,40,41,15,32,3,25,29,0,9,0,0,16,0,0,0,0,0

BOOT_BEEP:
	lda	#$10
	sta	via+$0B
	sta	via+$0A
	ldx	#0
BOOT_BEEPa:
	stx	via+$08
	stx	via+$09
BOOT_BEEPb:
	dey
	bne	BOOT_BEEPb
	dex
	bne	BOOT_BEEPa
	stx	via+$0B

start:
	sei
	cld
	ldx	#$FF
	txs
	lda	#40
	sta	ROWSTEP
	ldx	#0
more_crtc:
	lda	CRTC_INIT,x
	stx	crtca
	sta	crtcd
	inx
	cpx	#$12
	bne	more_crtc

	jsr	INIT_KEYBOARD
	jsr	SCAN_ANY_KEY
	bcs	START_NORMAL
	lda	#0
	sta	RBCP_MODE
	jmp	RUN_RAMBOOT
NV_READ_DONE:
	lda	RBCP_NVBYTE
	cmp	#1
	bne	START_NORMAL
	lda	#1
	sta	BOOTSEL
	lda	#2
	sta	RBCP_MODE
	jmp	BOOT_SELECTED_WITH_MODE
START_NORMAL:
	jmp	WARMUP_BOOT

TEST_VDU:
	ldx	#0
more_vduW:
	txa
	sta	vdu0,x
	sta	vdu1,x
	sta	vdu2,x
	sta	vdu3,x
	sta	vdu4,x
	sta	vdu5,x
	sta	vdu6,x
	sta	vdu7,x
	inx
	bne	more_vduW

	ldx	#0
more_vduR:
	txa
	cmp	vdu0,x
	bne	TEST_VDU
	cmp	vdu1,x
	bne	TEST_VDU
	cmp	vdu2,x
	bne	TEST_VDU
	cmp	vdu3,x
	bne	TEST_VDU
	inx
	bne	more_vduR

	jsr	LONG_DELAY
	jsr	CLEAR_SCREEN

TEST_00FF:
	ldx	#0
add2mem:
	txa
	sta	mem0,x
	sta	mem1,x
	inx
	bne	add2mem

	cld
	ldx	#0
memread0Fa:
	lda	#dot
	sta	vdu1,x
	txa
	ldy	#gud1
	cmp	mem0,x
	beq	memread0Fb
	ldy	#bad1
	sed
	lda	mem0,x
	sta	vdu1,x
memread0Fb:
	tya
	sta	vdu0,x
	inx
	bne	memread0Fa

	ldx	#0
memread0Fc:
	lda	#dot
	sta	vdu3,x
	txa
	ldy	#gud1
	cmp	mem1,x
	beq	memread0Fd
	ldy	#bad1
	sed
	lda	mem1,x
	sta	vdu3,x
memread0Fd:
	tya
	sta	vdu2,x
	inx
	bne	memread0Fc

	jsr	LONG_DELAY

	lda	#$99
	clc
	adc	#1
	bcc	OK_00FF
	jmp	TEST_00FF

OK_00FF:
	cld
	ldx	#$FF
	txs
	jsr	DETECT_SCREEN
	jmp	QUERY_DONE

QUERY_DONE:
	jsr	INIT_KEYBOARD
	lda	#2
	sta	BOOTSEL
	lda	#30
	sta	CNTDOWN

MENU_REDRAW:
	jsr	DRAW_MENU

MENU_LOOP:
	jsr	UPDATE_MENU_COUNT
	jsr	MENU_DELAY_KEY
	bcc	MENU_WAIT
	jsr	SCAN_ENTER
	bcs	MENU_BOOT_NOW
	lda	BOOTSEL
	clc
	adc	#1
	cmp	#6
	bcc	MENU_SELECT_OK
	lda	#1
MENU_SELECT_OK:
	sta	BOOTSEL
	lda	#30
	sta	CNTDOWN
	jsr	DRAW_MENU
	jsr	WAIT_NO_KEY

MENU_WAIT:
	dec	CNTDOWN
	bne	MENU_LOOP
MENU_BOOT_NOW:
	jmp	BOOT_SELECTED

INIT_KEYBOARD:
	lda	#$0F
	sta	pia1+0
	lda	#$04
	sta	pia1+1
	lda	#$00
	sta	pia1+2
	lda	#$04
	sta	pia1+3
	rts

SCAN_ANY_KEY:
	lda	#0
	sta	pia1+0
	ldx	#10
SCAN_ROW:
	ldy	#0
SCAN_SETTLE:
	dey
	bne	SCAN_SETTLE
	lda	pia1+2
	eor	#$FF
	bne	SCAN_HIT
	inc	pia1+0
	dex
	bne	SCAN_ROW
	clc
	rts
SCAN_HIT:
	sec
	rts

SCAN_ENTER:
	; PET keyboard layouts differ: keep both known RETURN matrix positions.
	lda	#3
	jsr	SCAN_KEY_ROW
	and	#$10		; business / 80-column RETURN
	bne	SCAN_ENTER_YES
	lda	#6
	jsr	SCAN_KEY_ROW
	and	#$20		; normal 40-column graphics RETURN
	beq	SCAN_ENTER_NO
SCAN_ENTER_YES:
	sec
	rts
SCAN_ENTER_NO:
	clc
	rts

SCAN_KEY_ROW:
	sta	pia1+0
	ldy	#0
SCAN_ENTER_SETTLE:
	dey
	bne	SCAN_ENTER_SETTLE
	lda	pia1+2
	eor	#$FF
	rts

WAIT_NO_KEY:
	jsr	SCAN_ANY_KEY
	bcs	WAIT_NO_KEY
	rts

DETECT_SCREEN:
	lda	#40
	sta	ROWSTEP
	lda	#$55
	sta	vdu0+1
	lda	#$AA
	sta	vdu4+1
	lda	#1
	sta	SCREENK
	lda	vdu0+1
	cmp	#$55
	bne	DETECT_DONE
	lda	vdu4+1
	cmp	#$AA
	bne	DETECT_DONE
	lda	#80
	sta	ROWSTEP
	lda	#2
	sta	SCREENK
DETECT_DONE:
	lda	#spc
	sta	vdu0+1
	sta	vdu4+1
	rts

CLEAR_SCREEN:
	ldx	#0
	lda	#spc
CLEAR_SCREENa:
	sta	vdu0,x
	sta	vdu1,x
	sta	vdu2,x
	sta	vdu3,x
	sta	vdu4,x
	sta	vdu5,x
	sta	vdu6,x
	sta	vdu7,x
	inx
	bne	CLEAR_SCREENa
	rts

SET_POS_RT:
	sta	POSY
	stx	VDULL
	lda	#$80
	sta	VDUHH
	lda	POSY
	beq	SET_POS_DONE
SET_POS_LOOP:
	clc
	lda	VDULL
	adc	ROWSTEP
	sta	VDULL
	bcc	SET_POS_NO_CARRY
	inc	VDUHH
SET_POS_NO_CARRY:
	dec	POSY
	bne	SET_POS_LOOP
SET_POS_DONE:
	rts

DRAW_MENU:
	jsr	CLEAR_SCREEN

	SET_POS 1,7
	SET_STR MSG_TITLE
	jsr	PRINTZ

	SET_POS 2,7
	SET_STR MSG_BRAND
	jsr	PRINTZ

	SET_POS 3,10
	SET_STR MSG_VERSION
	jsr	PRINTZ

	SET_POS 5,2
	SET_STR MSG_TESTS
	jsr	PRINTZ

	SET_POS 6,5
	SET_STR MSG_MODE_40
	lda	SCREENK
	cmp	#2
	bne	DRAW_MODE
	SET_STR MSG_MODE_80
DRAW_MODE:
	jsr	PRINTZ

	SET_POS 8,7
	SET_STR MSG_MENU1_DEFAULT
	jsr	PRINTZ

	SET_POS 10,7
	SET_STR MSG_MENU2_DEFAULT
	jsr	PRINTZ

	SET_POS 12,7
	SET_STR MSG_MENU3_DEFAULT
	jsr	PRINTZ

	SET_POS 14,7
	SET_STR MSG_MENU4_DEFAULT
	jsr	PRINTZ

	SET_POS 16,7
	SET_STR MSG_MENU5_DEFAULT
	jsr	PRINTZ

	SET_POS 18,2
	SET_STR MSG_HINT1
	jsr	PRINTZ
	SET_POS 19,2
	SET_STR MSG_HINT2
	jsr	PRINTZ
	SET_POS 21,2
	SET_STR MSG_COUNT
	jsr	PRINTZ
	jsr	UPDATE_MENU_COUNT

	lda	BOOTSEL
	asl
	clc
	adc	#6
	tax
	lda	#right
DRAW_SEL_MARK:
	pha
	txa
	ldx	#5
	jsr	SET_POS_RT
	pla
	ldy	#0
	sta	(VDULL),y
	rts

UPDATE_MENU_COUNT:
	lda	CNTDOWN
	ldx	#0
UPDATE_COUNT_TENS:
	cmp	#10
	bcc	UPDATE_COUNT_DIGITS
	sec
	sbc	#10
	inx
	bne	UPDATE_COUNT_TENS
UPDATE_COUNT_DIGITS:
	pha
	txa
	sta	$17
	SET_POS 20,15
	lda	$17
	ora	#$30
	ldy	#0
	sta	(VDULL),y
	iny
	pla
	ora	#$30
	sta	(VDULL),y
	rts

PRINTZ:
	ldy	#0
PRINTZa:
	lda	(STRLL),y
	beq	PRINTZb
	sta	(VDULL),y
	iny
	bne	PRINTZa
PRINTZb:
	rts

LONG_DELAY:
	ldx	#0
	ldy	#0
LONG_DELAYa:
	lda	mem0,x
	inx
	bne	LONG_DELAYa
	iny
	bne	LONG_DELAYa
	rts

MENU_DELAY:
	lda	#4
MENU_DELAYa:
	pha
	jsr	SHORT_DELAY
	pla
	sec
	sbc	#1
	bne	MENU_DELAYa
	rts

MENU_DELAY_KEY:
	lda	#32
	sta	$17
MENU_DELAY_KEY_LOOP:
	jsr	TINY_DELAY
	jsr	SCAN_ANY_KEY
	bcs	MENU_DELAY_KEY_HIT
	dec	$17
	bne	MENU_DELAY_KEY_LOOP
	clc
	rts
MENU_DELAY_KEY_HIT:
	sec
	rts

TINY_DELAY:
	ldx	#$20
TINY_DELAY_X:
	ldy	#0
TINY_DELAY_Y:
	dey
	bne	TINY_DELAY_Y
	dex
	bne	TINY_DELAY_X
	rts

SHORT_DELAY:
	ldx	#0
SHORT_DELAYa:
	ldy	#0
SHORT_DELAYb:
	dey
	bne	SHORT_DELAYb
	dex
	bne	SHORT_DELAYa
	rts

BOOT_SELECTED:
	lda	#1
	sta	RBCP_MODE
BOOT_SELECTED_WITH_MODE:
	sei
	jsr	CLEAR_SCREEN
	SET_POS 12,6
	SET_STR MSG_BOOTING
	jsr	PRINTZ

RUN_RAMBOOT:
	ldy	#0
	lda	#<RAM_BOOT_SRC
	sta	STRLL
	lda	#>RAM_BOOT_SRC
	sta	STRHH
	lda	#<RAMBOOT
	sta	VDULL
	lda	#>RAMBOOT
	sta	VDUHH
	lda	#<RAM_BOOT_LEN
	sta	$17
	lda	#>RAM_BOOT_LEN
	sta	$18
COPY_RAMBOOT:
	lda	(STRLL),y
	sta	(VDULL),y
	inc	STRLL
	bne	COPY_SRC_OK
	inc	STRHH
COPY_SRC_OK:
	inc	VDULL
	bne	COPY_DST_OK
	inc	VDUHH
COPY_DST_OK:
	lda	$17
	bne	COPY_DEC_LO
	dec	$18
COPY_DEC_LO:
	dec	$17
	lda	$17
	ora	$18
	bne	COPY_RAMBOOT
	jmp	RAMBOOT

	; This code is copied to $0100 before it is run. It uses only relative
	; branches and deliberate ROM reads at $E0xx, so it remains valid there.
RAM_BOOT_SRC:
RAM_LOAD_TARGET_OPERAND		.equ	RAMBOOT + (RAM_LOAD_TARGET_ARG - RAM_BOOT_SRC) + 1
RAM_NVWRITE_BYTE_OPERAND	.equ	RAMBOOT + (RAM_NVWRITE_BYTE_ARG - RAM_BOOT_SRC) + 1
RAM_NVWRITE_STAGE_OPERAND	.equ	RAMBOOT + (RAM_NVWRITE_STAGE_ARG - RAM_BOOT_SRC) + 1
RAM_SWITCH_TARGET_OPERAND	.equ	RAMBOOT + (RAM_SWITCH_TARGET_ARG - RAM_BOOT_SRC) + 1

	; Re-sync the One ROM host-control plugin using the spec reset sequence:
	; five raw RESETs, one raw RESET, then a knocked RESET.
	ldx	#5
RAM_RST_FLUSH:
	lda	EDITROM+$AA
	lda	EDITROM+$AA
	dex
	bne	RAM_RST_FLUSH
	ldx	#$20
RAM_RST_PA1:
	ldy	#0
RAM_RST_PB1:
	dey
	bne	RAM_RST_PB1
	dex
	bne	RAM_RST_PA1
	lda	EDITROM+$AA
	lda	EDITROM+$AA
	ldx	#$20
RAM_RST_PA2:
	ldy	#0
RAM_RST_PB2:
	dey
	bne	RAM_RST_PB2
	dex
	bne	RAM_RST_PA2
	lda	EDITROM+$21
	lda	EDITROM+$52
	lda	EDITROM+$42
	lda	EDITROM+$43
	lda	EDITROM+$50
	lda	EDITROM+$21
	lda	EDITROM+$AA
	lda	EDITROM+$AA
	ldx	#$20
RAM_RST_PA3:
	ldy	#0
RAM_RST_PB3:
	dey
	bne	RAM_RST_PB3
	dex
	bne	RAM_RST_PA3

	; ENTER_CMD_RESP:
	; command page relative = $0000, back-channel = $E7F0, size = 16.
	; E7F0-E7FF is padding, so the NV read path can return to this ROM.
	lda	#5		; E
	sta	RAM_PHASE
	lda	EDITROM+$7F2
	sta	$17
	lda	EDITROM+$21
	lda	EDITROM+$52
	lda	EDITROM+$42
	lda	EDITROM+$43
	lda	EDITROM+$50
	lda	EDITROM+$21
	lda	EDITROM+$00	; CONTROL
	lda	EDITROM+$01	; ENTER_CMD_RESP
	lda	EDITROM+$00	; command page rel lo
	lda	EDITROM+$00	; command page rel hi
	lda	EDITROM+$F0	; back-channel start lo
	lda	EDITROM+$07	; back-channel start hi
	lda	EDITROM+$00	; back-channel start bank
	lda	EDITROM+$10	; back-channel size lo
	lda	EDITROM+$00	; back-channel size hi
	lda	EDITROM+$BB	; complete
	lda	EDITROM+$CC	; status OK
	ldx	#0
RAM_ENTER_TOK:
	lda	EDITROM+$7F2
	cmp	$17
	bne	RAM_ENTER_PROG
	dex
	bne	RAM_ENTER_TOK
	jmp	RAM_FAIL_T
RAM_ENTER_PROG:
	ldx	#0
RAM_ENTER_PROG_LOOP:
	lda	EDITROM+$7F4
	cmp	#$BB
	beq	RAM_ENTER_RESP
	dex
	bne	RAM_ENTER_PROG_LOOP
	jmp	RAM_FAIL_P
RAM_ENTER_RESP:
	lda	EDITROM+$7F5
	cmp	#$CC
	beq	RAM_ENTER_OK
	jmp	RAM_FAIL_S
RAM_ENTER_OK:
	lda	RBCP_MODE
	bne	RAM_BOOT_ACTION

RAM_NV_READ:
	lda	#14		; N
	sta	RAM_PHASE
	lda	#$FF
	sta	RBCP_NVBYTE
	lda	EDITROM+$7F2
	sta	$17
	lda	EDITROM+$03	; NV storage
	lda	EDITROM+$01	; NV_PEEK
	lda	EDITROM+$01	; one byte
	lda	EDITROM+$00	; location LSB
	lda	EDITROM+$00	; location MSB
	ldx	#0
RAM_NVREAD_TOK:
	lda	EDITROM+$7F2
	cmp	$17
	bne	RAM_NVREAD_PROG
	dex
	bne	RAM_NVREAD_TOK
	jmp	RAM_FAIL_T
RAM_NVREAD_PROG:
	ldx	#0
RAM_NVREAD_PROG_LOOP:
	lda	EDITROM+$7F4
	cmp	#$BB
	beq	RAM_NVREAD_RESP
	dex
	bne	RAM_NVREAD_PROG_LOOP
	jmp	RAM_FAIL_P
RAM_NVREAD_RESP:
	lda	EDITROM+$7F5
	cmp	#$CC
	bne	RAM_NVREAD_EXIT
	lda	EDITROM+$7F8
	sta	RBCP_NVBYTE
RAM_NVREAD_EXIT:
	lda	EDITROM+$00	; CONTROL
	lda	EDITROM+$03	; EXIT_CMD_RESP_SILENT
	ldx	#$20
RAM_NVREAD_EXIT_PA:
	ldy	#0
RAM_NVREAD_EXIT_PB:
	dey
	bne	RAM_NVREAD_EXIT_PB
	dex
	bne	RAM_NVREAD_EXIT_PA
	jmp	NV_READ_DONE

RAM_BOOT_ACTION:
	; GET_RAM_SLOT_INFO_ALL. Data at $E7F8: total, active, rom_type, reserved.
	lda	#9		; I
	sta	RAM_PHASE
	lda	EDITROM+$7F2
	sta	$17
	lda	EDITROM+$01	; READ
	lda	EDITROM+$03	; GET_RAM_SLOT_INFO_ALL
	ldx	#0
RAM_INFO_TOK:
	lda	EDITROM+$7F2
	cmp	$17
	bne	RAM_INFO_PROG
	dex
	bne	RAM_INFO_TOK
	jmp	RAM_FAIL_T
RAM_INFO_PROG:
	ldx	#0
RAM_INFO_PROG_LOOP:
	lda	EDITROM+$7F4
	cmp	#$BB
	beq	RAM_INFO_RESP
	dex
	bne	RAM_INFO_PROG_LOOP
	jmp	RAM_FAIL_P
RAM_INFO_RESP:
	lda	EDITROM+$7F5
	cmp	#$CC
	beq	RAM_INFO_OK2
	jmp	RAM_FAIL_S
RAM_INFO_OK2:
	lda	EDITROM+$7F8	; total RAM slots
	cmp	#2
	bcs	RAM_INFO_OK
	jmp	RAM_FAIL_R
RAM_INFO_OK:
	lda	EDITROM+$7F9	; active RAM slot
	eor	#1
	sta	RAM_LOAD_TARGET_OPERAND
	sta	RAM_NVWRITE_STAGE_OPERAND
	sta	RAM_SWITCH_TARGET_OPERAND

	lda	RBCP_MODE
	cmp	#2
	beq	RAM_SELECT_LOAD
	lda	#$FF
	ldx	BOOTSEL
	cpx	#1
	bne	RAM_NVWRITE_BYTE_OK
	lda	#1
RAM_NVWRITE_BYTE_OK:
	sta	RAM_NVWRITE_BYTE_OPERAND
	lda	#14		; N
	sta	RAM_PHASE
	lda	EDITROM+$7F2
	sta	$17
	lda	EDITROM+$03	; NV storage
	lda	EDITROM+$06	; NV_POKE_COMMIT_BYTE
RAM_NVWRITE_BYTE_ARG:
	lda	EDITROM+$FF	; patched to $01 for edit, $FF otherwise
	lda	EDITROM+$00	; location LSB
	lda	EDITROM+$00	; location MSB
RAM_NVWRITE_STAGE_ARG:
	lda	EDITROM+$00	; patched to inactive RAM slot
	ldx	#0
RAM_NVWRITE_TOK:
	lda	EDITROM+$7F2
	cmp	$17
	bne	RAM_NVWRITE_PROG
	dex
	bne	RAM_NVWRITE_TOK
	jmp	RAM_FAIL_T
RAM_NVWRITE_PROG:
	ldy	#0
RAM_NVWRITE_PROG_OUTER:
	ldx	#0
RAM_NVWRITE_PROG_LOOP:
	lda	EDITROM+$7F4
	cmp	#$BB
	beq	RAM_SELECT_LOAD
	dex
	bne	RAM_NVWRITE_PROG_LOOP
	dey
	bne	RAM_NVWRITE_PROG_OUTER
	jmp	RAM_FAIL_P

RAM_SELECT_LOAD:
	lda	#12		; L
	sta	RAM_PHASE
	lda	EDITROM+$7F2
	sta	$17
	lda	EDITROM+$02	; MODIFY
	lda	EDITROM+$02	; LOAD_SLOT
RAM_LOAD_TARGET_ARG:
	lda	EDITROM+$00	; patched to inactive RAM slot
	ldx	BOOTSEL
	lda	EDITROM,x	; flash slot matches menu selection

RAM_LOAD_POLL:
	ldy	#0
RAM_LOAD_TOK_OUTER:
	ldx	#0
RAM_LOAD_TOK:
	lda	EDITROM+$7F2
	cmp	$17
	bne	RAM_LOAD_PROG
	dex
	bne	RAM_LOAD_TOK
	dey
	bne	RAM_LOAD_TOK_OUTER
	jmp	RAM_FAIL_T
RAM_LOAD_PROG:
	ldx	#0
RAM_LOAD_PROG_LOOP:
	lda	EDITROM+$7F4
	cmp	#$BB
	beq	RAM_LOAD_RESP
	dex
	bne	RAM_LOAD_PROG_LOOP
	jmp	RAM_FAIL_P
RAM_LOAD_RESP:
	lda	EDITROM+$7F5
	cmp	#$CC
	beq	RAM_SWITCH
	jmp	RAM_FAIL_S

RAM_SWITCH:
	lda	EDITROM+$00	; CONTROL
	lda	EDITROM+$04	; SWITCH_AND_EXIT
RAM_SWITCH_TARGET_ARG:
	lda	EDITROM+$00	; patched to inactive RAM slot
	ldx	#$20
RAM_SW_PA:
	ldy	#0
RAM_SW_PB:
	dey
	bne	RAM_SW_PB
	dex
	bne	RAM_SW_PA
	jmp	($FFFC)

RAM_FAIL_T:
	lda	RAM_PHASE
	sta	vdu0
	lda	#20		; T
	sta	vdu0+1
	lda	#bad1
	sta	vdu0+2
	lda	#19		; S
	sta	vdu0+4
	lda	$17
	jsr	RAM_HEX_A
	stx	vdu0+5
	sta	vdu0+6
	lda	#3		; C
	sta	vdu0+8
	lda	EDITROM+$7F2
	jsr	RAM_HEX_A
	stx	vdu0+9
	sta	vdu0+10
	jmp	RAM_FAIL_HALT
RAM_HEX_A:
	pha
	lsr
	lsr
	lsr
	lsr
	jsr	RAM_HEX_NIBBLE
	tax
	pla
	and	#$0F
RAM_HEX_NIBBLE:
	cmp	#10
	bcc	RAM_HEX_DIGIT
	sec
	sbc	#9
	rts
RAM_HEX_DIGIT:
	clc
	adc	#$30
	rts
RAM_FAIL_P:
	lda	RAM_PHASE
	sta	vdu0
	lda	#16		; P
	sta	vdu0+1
	jmp	RAM_FAIL_END
RAM_FAIL_S:
	lda	RAM_PHASE
	sta	vdu0
	lda	#19		; S
	sta	vdu0+1
	jmp	RAM_FAIL_END
RAM_FAIL_R:
	lda	RAM_PHASE
	sta	vdu0
	lda	#18		; R
	sta	vdu0+1
RAM_FAIL_END:
	lda	#bad1
	sta	vdu0+2
RAM_FAIL_HALT:
	jmp	RAM_FAIL_HALT
RAM_BOOT_END:
RAM_BOOT_LEN	.equ	RAM_BOOT_END - RAM_BOOT_SRC

WARMUP_BOOT:
	jsr	DETECT_SCREEN
	jsr	CLEAR_SCREEN
	SET_POS 0,0
	SET_STR MSG_WARMUP
	jsr	PRINTZ
WARMUP_COUNT_INIT:
	lda	#5
	sta	CNTDOWN
WARMUP_COUNT:
	lda	CNTDOWN
	ora	#$30
	sta	vdu0+7
	lda	#3
WARMUP_DELAY_REP:
	ldx	#0
	ldy	#0
WARMUP_DELAY:
	dex
	bne	WARMUP_DELAY
	dey
	bne	WARMUP_DELAY
	sec
	sbc	#1
	bne	WARMUP_DELAY_REP
	dec	CNTDOWN
	bne	WARMUP_COUNT
	ldx	#0
	jmp	TEST_VDU

MSG_TITLE:	.byte	scr("   * RETRO RESCUES *"),0
MSG_BRAND:	.byte	scr("PET ONE ROM BOOT MENU"),0
MSG_VERSION:	.byte	scr("V1.02"),0
MSG_TESTS:	.byte	scr("VDU + PAGE 0/1 RAM OK"),0
MSG_MODE_40:	.byte	scr("40 COLUMN / 1K VIDEO RAM"),0
MSG_MODE_80:	.byte	scr("80 COLUMN / 2K VIDEO RAM"),0
MSG_MENU1_DEFAULT:	.byte	scr("NORMAL EDIT ROM"),0
MSG_MENU2_DEFAULT:	.byte	scr("PETTESTER"),0
MSG_MENU3_DEFAULT:	.byte	scr("IEEE-488 TEST"),0
MSG_MENU4_DEFAULT:	.byte	scr("ROM CRC ID"),0
MSG_MENU5_DEFAULT:	.byte	scr("DIAG CLIP"),0
MSG_HINT1:	.byte	scr("KEY NEXT  ENTER BOOT"),0
MSG_HINT2:	.byte	scr("NO KEY"),0
MSG_COUNT:	.byte	scr("BOOT IN 30"),0
MSG_BOOTING:	.byte	scr("BOOTING ROM"),0
MSG_WARMUP:	.byte	scr("WARMUP 5"),0

	.org	$E800
