	; pettester.asm
	;

	; pettester - A program to replace the editor ROM of a Commodore PET computer
	;           - with the purpose of testing out key functionality of the machine.
	; Copyright (C) 2019  David E. Roberts.
	; Copyright (C) 2023  Andreas Signer.
	; Updated 2026  RetroRescues.
	; 
	; This program is free software: you can redistribute it and/or modify
	; it under the terms of the GNU General Public License as published by
	; the Free Software Foundation, either version 3 of the License, or
	; (at your option) any later version.
	;
	; This program is distributed in the hope that it will be useful,
	; but WITHOUT ANY WARRANTY; without even the implied warranty of
	; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	; GNU General Public License for more details.
	;
	; You should have received a copy of the GNU General Public License
	; along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    
	; Modification history.
	; =====================
	;
	; Version: 1.0
	;   Date : 14th July 2018.
	; Author : Dave Roberts. Mainly plagiarised from Eudimorphodon with bits copied from dave_m...
	; Change : First creation.
	;
	; Version: 2.0
	;   Date : 17th July 2018.
	; Author : Dave Roberts.
	; Change : Add $00 to $FF 1K memory test.
	;
	; Version: 3.0
	;   Date : 29th July 2018.
	; Author : Dave Roberts.
	; Change : Some major edits....
	;
	; Version: 4.0
	;   Date : 21st December 2018.
	; Author : Dave Roberts.
	; Change : Continue with edits....
	;
	; Version: 4.1 + 4.2
	;   Date : 9th January 2019. 6th June 2019.
	; Author : Dave Roberts.
	; Change : Tweak a bit... BETA release!
	;
	; Version: 4.3
	;   Date : 2nd October 2019.
	; Author : Dave Roberts.
	; Change : Fix a bug where the '.' overwrote the character read on a $00 to $FF test if the test failed.
	;
	; Version: 5?
	;   Date: 2023
	; Author :Andreas Signer
	; Checksums are not computed over the full 4KB anymore, but rather over
	; the 2KB that are contained in a single ROM.
	; For every ROM, the first 16 bytes are shown on the screen.	
	;
	; Version: 6
	;   Date : 18th June 2026.
	; Author : RetroRescues.
	; Added "beep" on startup for machines with a buzzer
	; Added 1k/2k vram check for simple 40/80 column detection at first boot Displays 1k4 or 2k8. 
	; (Nothing is really done with this as space is limited.)
	; Added 10s boot up delay to allow for CRT warmup
	; Added basic IEEE-488 self-test for DIO, NDAC, DAV, NRFD, EOI, ATN 


SET_POS	.macro y,x
	lda	#<(vdu0+y*40+x)		; VDU screen low address.
	sta	VDULL		; "   "   "   "   "   "
	lda	#>(vdu0+y*40+x)		; VDU screen low address.
	sta	VDUHH		; "   "   "   "   "   "
	.endm


EDITROM	.equ	$E000
via	.equ	$E840		; 6522 VIA base address. CB2 drives the PET beeper.
	.org	EDITROM

	; This is the entry point into the initialisation portion
	; of the EDIT ROM. It is called from the kernel ROM ($F000)
	; after a small amount of processing (i.e. maskable interrupts
	; have been inhibited and the decimal arithmetic flag cleared).
	;
	; This entry point is CALLED by the kernel ROM - but the 
	; page 0 RAM may not be working (so the return address may not 
	; actually work). We have no plans of returning anyhow...
	;
	; Bypass fixed data stored in the ROM, including the CRTC initialisation
	; table, then run the boot chirp.
	;  
	; This is the EDIT ROM entry point for kernal-4 (at address $E000).
	; =================================================================
	;
	jmp	BOOT_BEEP

CRTC_INIT:

	; PET/CBM 60Hz Business CRTC initialisation table.
	.byte	49		; Register 0.
	.byte	40		; Register 1.
	.byte	41		; Register 2.
	.byte	15		; Register 3.
	.byte	32		; Register 4.
	.byte 	3		; Register 5.
	.byte	25		; Register 6.
	.byte	29		; Register 7.
	.byte 	0		; Register 8.
	.byte 	9		; Register 9.
	.byte 	0		; Register 10.
	.byte 	0		; Register 11.
	.byte	16		; Register 12.
	.byte 	0		; Register 13.
	.byte 	0		; Register 14.
	.byte 	0		; Register 15.
	.byte 	0		; Register 16.
	.byte 	0		; Register 17.
    
	; Initialisation table for the CRT Controller. One byte for 
	; each register (in numerical order starting at register 0).
	;

	; Table obtained from http://cbm-hackers.2304266.n4.nabble.com/PET-50Hz-editor-ROMS-td4658493.html
	; ================================================================================================
	;
	;           PET/CBM PET/CBM PET/CBM  8296D   NTSC     PAL 
	;            60 Hz   50 Hz   50 Hz   50 HZ   60 Hz   50 Hz 
	;
	; Business 
	; ========
	;
	; reg.  0     49      49      50      48      63      63 
	; reg.  1     40      40      40      40      40      40 
	; reg.  2     41      41      40      44      49      50 
	; reg.  3     15      15       8       8      15       8 
	; reg.  4     32      39      38      32      31      32 
	; reg.  5      3       0       2       9       7      16 
	; reg.  6     25      25      25      25      25      25 
	; reg.  7     29      32      32      29      29      29 
	; reg.  8      0       0       0       0       0       0 
	; reg.  9      9       9       9       9       7       8 
	; reg. 10      0       0       0       0       0       0 
	; reg. 11      0       0       0       0       0       0 
	; reg. 12     16      16      16      16      16      16 
	; reg. 13      0       0       0       0       0       0 
	; reg. 14      0       0       0       0       0       0 
	; reg. 15      0       0       0       0       0       0 
	; reg. 16      0       0       0       0       0       0 
	; reg. 17      0       0       0       0       0       0 
	;
	; Graphic 
	; =======
	;
	; reg.  0     49      49      50      48      63      63 
	; reg.  1     40      40      40      40      40      40 
	; reg.  2     41      41      40      44      49      50 
	; reg.  3     15      15       8       8      15       8 
	; reg.  4     40      49      48      41      31      36 
	; reg.  5      5       0       0       3       7      17 
	; reg.  6     25      25      25      25      25      25 
	; reg.  7     33      37      37      34      29      32 
	; reg.  8      0       0       0       0       0       0 
	; reg.  9      7       7       7       7       7       7 
	; reg. 10      0       0       0       0       0       0 
	; reg. 11      0       0       0       0       0       0 
	; reg. 12     16      16      16      16      16      16 
	; reg. 13      0       0       0       0       0       0 
	; reg. 14      0       0       0       0       0       0 
	; reg. 15      0       0       0       0       0       0 
	; reg. 16      0       0       0       0       0       0 
	; reg. 17      0       0       0       0       0       0 

	; ******************
	; ***            ***
	; ***  EQUATES.  ***
	; ***            ***
	; ******************

	; DELAY parameters. 
	; =================

dlyx	.equ	$00		; Inner delay counter.
dlyy	.equ	$00		; Outer delay counter.

	; VDU memory.
	; ===========

vdu0	.equ	$8000		; Screen block 0.
vdu1	.equ	$8100		; Screen block 1.
vdu2	.equ	$8200		; Screen block 2.
vdu3	.equ	$8300		; Screen block 3.
vdu4	.equ	$8400		; Screen block 4.
vdu5	.equ	$8500		; Screen block 5.
vdu6	.equ	$8600		; Screen block 6.
vdu7	.equ	$8700		; Screen block 7.

	; Low RAM memory.
	; ===============

mem0	.equ	$0000		; Memory block 0.
mem1	.equ	$0100		; Memory block 1.

	; PETSCII character codes.
	; ========================

gud1	.equ	$07		; PETSCII 'G' character code.
bad1	.equ	$02		; PETSCII 'B' character code.
spc	.equ	$20		; PETSCII ' ' character code.
dot	.equ	$2E		; PETSCII '.' character code.

PETSCII_EQ	.equ	$3D	; PETSCII '='.
PETSCII_COLON	.equ	$3A	; PETSCII ':'.

	; Memory test values.
	; ===================

tst55	.equ	$55		; Memory test value 1.		
tstAA	.equ	$AA		; Memory test value 2.

	; CRT Controller addresses.
	; =========================

crtca	.equ	$E880		; CRT Controller address register.
crtcd	.equ	$E881		; CRT Controller data    register.

	; PIA addresses.
	; ==============
	
pia1	.equ	$E810
pia2	.equ	$E820

	; ***************************************************
	; ***                                             ***
	; ***  THIS IS THE REAL ENTRY POINT OF THE TEST.  ***
	; ***                                             ***
	; ***************************************************

BOOT_BEEP:

	; PET 40xx/80xx machines have a simple beeper on the 6522 VIA CB2 pin.
	; ACR=$10 makes the VIA shift register free-run on CB2 using timer 2.
	; The timer is swept quickly so the power-on sound is a chirp rather than
	; a single click-like tone. It falls through into START to avoid JSR/RTS.
	lda	#$10
	sta	via+$0B		; ACR: shift register output on CB2, clocked by T2.
	sta	via+$0A		; Shift register pattern.
	ldx	#0		; Sweep T2 high/low until X wraps back to zero.
BOOT_BEEPa:
	stx	via+$08		; Timer 2 low byte.
	stx	via+$09		; Timer 2 high byte, starts the timer.
BOOT_BEEPb:
	dey
	bne	BOOT_BEEPb
	dex
	bne	BOOT_BEEPa
	stx	via+$0B		; X is zero here; stop the shift-register output.

start:

	; Initialise the CRTC (if it exists).
	; ===================================
	;
	; Older PETs without a CRTC ignore these accesses, so the usual editor-ROM
	; table changes for 50/60Hz or display geometry still live in CRTC_INIT
	; without breaking non-CRTC machines.
    
more_crtc:
	lda	CRTC_INIT,x	; Pick up the initialisation value for this register.
	stx	crtca		; Tell the CRT Controller which register we are going to initialise.
	sta	crtcd		; Initialisation value for the register just defined.
	inx			; Index the next CRT Controller register.
	cpx	#$12		; Have we finished initialising the CRT Controller?
	bne	more_crtc	; If not, skip back and initialise more registers.
	
	; The CRT Controller should be now initialised and displaying random rubbish 
	; on the screen! The CRT itself may need time to 'warm up' before
	; the next tests can be seen, so a delay is added!

	; *************************************************************************************
	; ***                                                                               ***
	; ***  Write known contents to the screen (all of the characters from $00 to $FF).  ***
	; ***                                                                               ***
	; *************************************************************************************
	
	jmp	WARMUP_BOOT	; One-time VDU size report and CRT warmup delay.
TEST_VDU:

	ldx	#0		; Retry failed VDU tests without repeating the warmup.
more_vduW:
	txa			; Pick up the index (which is also the character to display).
	sta	vdu0,x		; Screen block 0.
	sta	vdu1,x		; Screen block 1.
	sta	vdu2,x		; Screen block 2.
	sta	vdu3,x		; Screen block 3.
	sta	vdu4,x		; Screen block 4.
	sta	vdu5,x		; Screen block 5.
	sta	vdu6,x		; Screen block 6.
	sta	vdu7,x		; Screen block 7.
	inx			; Move on to the next location in the screen memory.
	bne	more_vduW	; Keep looping until we have finished.
	
	; Note that this assumes an 80 column VDU. If the PET is 40 columns - this shouldn't matter.
	; (it will just overwrite what has been written previously).
	
	; Check that the first 1K of screen memory has taken the value that has been written.
	; If not - keep looping. If it has, perform a delay and move on to the next test.
	
	ldx	#0		; Starting index into the blocks of screen memory & the character itself.
more_vduR:
	txa			; Pick up the index (which is also the character to check for).
	cmp	vdu0,x		; Check screen block 0.
	bne	TEST_VDU	; If not the same, keep looping.
	cmp	vdu1,x		; Check screen block 1.
	bne	TEST_VDU	; If not the same, keep looping.
	cmp	vdu2,x		; Check screen block 2.
	bne	TEST_VDU	; If not the same, keep looping.
	cmp	vdu3,x		; Check screen block 3.
	bne	TEST_VDU	; If not the same, keep looping.
	inx			; Move on to the next location in the screen memory.
	bne	more_vduR	; Keep looping until we have finished.
	
	; The first 1K of screen memory appears to be OK. If we have a 2K screen (80 column PET)
	; then there is the possibility that the second 1K could be faulty. However, because the
	; 80 column PET interleaves the two banks of 1K of VDU memory - this should be pretty
	; apparent. Furthermore, I would expect the 40 column VDU RAM check to catch it!

	; *************************************************************************************************
	; ***                                                                                           ***
	; ***  Perform a 'long' delay to permit the human to view the results displayed on the screen.  ***
	; ***                                                                                           ***
	; *************************************************************************************************

	ldx	#dlyx		; Inner delay count.
	ldy	#dlyy		; Outer delay count.
		
delayloop1:
	lda	mem0,x		; Pick up a 'dummy' value from memory.
	inx			; Increment the inner delay count.
	bne	delayloop1	; Have we reached the end? If not, keep looping until we have.
	iny			; Increment the outer delay count.
	bne	delayloop1	; Have we reached the end? If not, keep looping until we have.

	; **********************************
	; ***                            ***
	; ***  Clear the entire screen.  ***
	; ***                            ***
	; **********************************
	
	ldx	#0		; Starting index into the blocks of screen memory.
	lda	#spc		; PETSCII ' ' character.
more_vduE:
	sta	vdu0,x		; Screen block 0.
	sta	vdu1,x		; Screen block 1.
	sta	vdu2,x		; Screen block 2.
	sta	vdu3,x		; Screen block 3.
	sta	vdu4,x		; Screen block 4.
	sta	vdu5,x		; Screen block 5.
	sta	vdu6,x		; Screen block 6.
	sta	vdu7,x		; Screen block 7.
	inx			; Move on to the next location in the screen memory.
	bne	more_vduE	; Keep looping until we have finished.

	; ************************************************************
	; ***                                                      ***
	; ***  Initialise pages 0 and 1 to repeats of $00 to $FF.  ***
	; ***                                                      ***
	; ************************************************************

TEST_00FF:

	ldx	#0		; Memory index.
add2mem:
	txa			; Transfer the memory index from 'X' into 'A'.
	sta	mem0,x		; Block 0 of memory.
	sta	mem1,x		; Block 1 of memory.
	inx			; Move index along.
	bne	add2mem		; Keep looping until finished.

	cld			; The D flag (decimal) is used to indicate a fault (i.e. to 
				; continuously repeat this set of tests if an error is detected).

	; *****************************************************
	; ***                                               ***
	; ***  Test memory block 0 for the value we wrote.  ***
	; ***                                               ***
	; *****************************************************

	ldx	#0		; Memory block index. X should be 0 anyhow at this point...
	
memread0Fa:
	lda	#dot		; PETSCII character '.'.
	sta	vdu1,x		; Store a default '.' if no error so we can count characters on the screen easily!
	txa			; Transfer the memory index from X to A.
	ldy	#gud1		; PETSCII character 'G' (standing for Good). Default memory status.
	cmp	mem0,x		; Compare what is in memory to what we expect it to be (the address).
	beq	memread0Fb	; YES - OK
	; Memory value was BAD.
	ldy	#bad1		; PETSCII character 'B' (standing for Bad). Overwrite the default.
	sed			; Flag an error in the test for later.
	lda	mem0,x		; Pickup the character value in error.
	sta	vdu1,x		; Store the actual value we found to the VDU memory - for diagnostic pusposes.
memread0Fb:
	tya			; Recover the status character.
	sta	vdu0,x		; Store the status character in A to the corresponding memory location in block 0 of the screen. 
	inx			; Move on to the next byte in the memory block.
	bne	memread0Fa	; Have we reached the end? If not, keep looping until we have.

	; *****************************************************
	; ***                                               ***
	; ***  Test memory block 1 for the value we wrote.  ***
	; ***                                               ***
	; *****************************************************

	ldx	#0		; Memory block index. X should be 0 anyhow at this point...
	
memread0Fc:
	lda	#dot		; PETSCII character '.'.
	sta	vdu3,x		; Store a default '.' if no error so we can count characters on the screen easily!
	txa			; Transfer the memory index from X to A.
	ldy	#gud1		; PETSCII character 'G' (standing for Good). Default memory status.
	cmp	mem1,x		; Compare what is in memory to what we expect it to be (the address).
	beq	memread0Fd	; YES - OK
	; Memory value was BAD.
	ldy	#bad1		; PETSCII character 'B' (standing for Bad). Overwrite the default.
	sed			; Flag an error in the test for later.
	lda	mem1,x		; Pickup the character value in error.
	sta	vdu3,x		; Store the actual value we found to the VDU memory - for diagnostic pusposes.
memread0Fd:
	tya			; Recover the status character.
	sta	vdu2,x		; Store the status character in A to the corresponding memory location in block 2 of the screen. 
	inx			; Move on to the next byte in the memory block.
	bne	memread0Fc	; Have we reached the end? If not, keep looping until we have.

	; *************************************************************************************************
	; ***                                                                                           ***
	; ***  Perform a 'long' delay to permit the human to view the results displayed on the screen.  ***
	; ***                                                                                           ***
	; *************************************************************************************************

	ldx	#dlyx		; Inner delay count.
	ldy	#dlyy		; Outer delay count.
		
delayloop2:
	lda	mem0,x		; Pick up a 'dummy' value from memory.
	inx			; Increment the inner delay count.
	bne	delayloop2	; Have we reached the end? If not, keep looping until we have.
	iny			; Increment the outer delay count.
	bne	delayloop2	; Have we reached the end? If not, keep looping until we have.

	; ***********************************************************************
	; ***                                                                 ***
	; ***  Did an error occur? If so, keep repeating this bit of code...  ***
	; ***                                                                 ***
	; ***********************************************************************

	; There is no instruction to test the state of the D flag. If the D flag
	; is clear - then no error occurred. If the D flag is set - then an error occurred.
	;
	; We 'fake' a D flag test by seeing what happens if we add $01 to $99.
	;
	; If the carry flag becomes SET - this indicates DECIMAL mode is active and (therefore) the
	; D flag is set thus indicating a fault has occurred.
	;
	; Conversely, if the carry flag is CLEAR - this indicates DECIMAL mode is not active and
	; (therefore) the D flag is clear thus indicating no fault occurred.
	 
	lda	#$99		; $99 = 10011001
	clc			; Clear the CARRY flag. 
	adc	#1		; Add 1 to regsister 'A'.
	bcc	OK_00FF		; If the carry flag is clear - no error was detected...
	jmp	TEST_00FF	; Keep repeating the test as an error was detected. 

OK_00FF:

	; ***************************************************************
	; ***                                                         ***
	; ***  Initialise Pages 0 and 1 of memory to 55h = 01010101.  ***
	; ***                                                         ***
	; ***************************************************************

	; Register A contains the value to write into memory. A value of 
	; 55 (hex) is used which equates to binary 01010101 (i.e. alternating
	; 1's and 0's).

TEST_55AA:

	cld			; The D flag (decimal) is used to indicate a fault (i.e. to 
				; continuously repeat this set of tests if an error is detected).
					 
	lda	#tst55		; Value to write into memory blocks (01010101).
	ldx	#0		; Block index.
	
memwrite55a:
	sta	mem0,x		; Block 0 of memory.
	sta	mem1,x		; Block 1 of memory.
	inx			; Move on to the next byte in the memory block.
	bne	memwrite55a	; Have we reached the end? If not, keep looping until we have.

	; *****************************************************
	; ***                                               ***
	; ***  Test memory block 0 for the value we wrote.  ***
	; ***                                               ***
	; *****************************************************

	ldx	#0		; Memory block index. X should be 0 anyhow at this point...
	
memread55a:
	ldy	#gud1		; PETSCII character 'G' (standing for Good). Default memory status.
	lda	mem0,x		; Pick up the value from memory block 0.
	cmp	#tst55		; Is the value what we expect?
	beq	memread55b	; YES - OK
	; Memory value was BAD.
	ldy	#bad1		; PETSCII character 'B' (standing for Bad). Overwrite the default.
	sed			; Flag an error in the test for later.
memread55b:
	tya			; Recover the status character.
	sta	vdu0,x		; Store the status character in A to the corresponding memory location in block 0 of the screen. 
	inx			; Move on to the next byte in the memory block.
	bne	memread55a	; Have we reached the end? If not, keep looping until we have.

	; *****************************************************
	; ***                                               ***
	; ***  Test memory block 1 for the value we wrote.  ***
	; ***                                               ***
	; *****************************************************

	ldx	#0		; Memory block index. X should be 0 anyhow at this point...
	
memread55c:
	ldy	#gud1		; PETSCII character 'G' (standing for Good). Default memory status.
	lda	mem1,x		; Pick up the value from memory block 1.
	cmp	#tst55		; Is the value what we expect?
	beq	memread55d	; YES - OK
	; Memory value was BAD.
	ldy	#bad1		; PETSCII character 'B' (standing for Bad). Overwrite the default.
	sed			; Flag an error in the test for later.
memread55d:
	tya			; Recover the status character.
	sta	vdu1,x		; Store the status character in A to the corresponding memory location in block 1 of the screen. 
	inx			; Move on to the next byte in the memory block.
	bne	memread55c	; Have we reached the end? If not, keep looping until we have.

	; **************************************************************
	; ***                                                        ***
	; ***  Initialise Page 0 and 1 of memory to AAh = 10101010.  ***
	; ***                                                        ***
	; **************************************************************

	; Register A contains the value to write into memory. A value of 
	; AA (hex) is used which equates to binary 10101010 (i.e. alternating
	; 1's and 0's).
    
	lda	#tstAA		; Value to write into memory blocks (10101010).
	ldx	#0		; Block index.
	
memwriteAAa:
	sta	mem0,x		; Block 0 of memory.
	sta	mem1,x		; Block 1 of memory.
	inx			; Move on to the next byte in the memory block.
	bne	memwriteAAa	; Have we reached the end? If not, keep looping until we have.

	; *****************************************************
	; ***                                               ***
	; ***  Test memory block 0 for the value we wrote.  ***
	; ***                                               ***
	; *****************************************************

	ldx	#0		; Memory block index. X should be 0 anyhow at this point...
	
memreadAAa:
	ldy	#gud1		; PETSCII character 'G' (standing for Good). Default memory status.
	lda	mem0,x		; Pick up the value from memory block 0.
	cmp	#tstAA		; Is the value what we expect?
	beq	memreadAAb	; YES - OK
	; Memory value was BAD.
	ldy	#bad1		; PETSCII character 'B' (standing for Bad). Overwrite the default.
	sed			; Flag an error in the test for later.
memreadAAb:
	tya			; Recover the status character.
	sta	vdu2,x		; Store the status character in A to the corresponding memory location in block 2 of the screen. 
	inx			; Move on to the next byte in the memory block.
	bne	memreadAAa	; Have we reached the end? If not, keep looping until we have.

	; *****************************************************
	; ***                                               ***
	; ***  Test memory block 1 for the value we wrote.  ***
	; ***                                               ***
	; *****************************************************

	ldx	#0		; Memory block index. X should be 0 anyhow at this point...
	
memreadAAc:
	ldy	#gud1		; PETSCII character 'G' (standing for Good). Default memory status.
	lda	mem1,x		; Pick up the value from memory block 1.
	cmp	#tstAA		; Is the value what we expect?
	beq	memreadAAd	; YES - OK
	; Memory value was BAD.
	ldy	#bad1		; PETSCII character 'B' (standing for Bad). Overwrite the default.
	sed			; Flag an error in the test for later.
memreadAAd:
	tya			; Recover the status character.
	sta	vdu3,x		; Store the status character in A to the corresponding memory location in block 3 of the screen. 
	inx			; Move on to the next byte in the memory block.
	bne	memreadAAc	; Have we reached the end? If not, keep looping until we have.

	; *************************************************************************************************
	; ***                                                                                           ***
	; ***  Perform a 'long' delay to permit the human to view the results displayed on the screen.  ***
	; ***                                                                                           ***
	; *************************************************************************************************

	ldx	#dlyx		; Inner delay count.
	ldy	#dlyy		; Outer delay count.
		
delayloop3:
	lda	mem0,x		; Pick up a 'dummy' value from memory.
	inx			; Increment the inner delay count.
	bne	delayloop3	; Have we reached the end? If not, keep looping until we have.
	iny			; Increment the outer delay count.
	bne	delayloop3	; Have we reached the end? If not, keep looping until we have.

	; ***********************************************************************
	; ***                                                                 ***
	; ***  Did an error occur? If so, keep repeating this bit of code...  ***
	; ***                                                                 ***
	; ***********************************************************************

	; There is no instruction to test the state of the D flag. If the D flag
	; is clear - then no error occurred. If the D flag is set - then an error occurred.
	;
	; We 'fake' a D flag test by seeing what happens if we add $01 to $99.
	;
	; If the carry flag becomes SET - this indicates DECIMAL mode is active and (therefore) the
	; D flag is set thus indicating a fault has occurred.
	;
	; Conversely, if the carry flag is CLEAR - this indicates DECIMAL mode is not active and
	; (therefore) the D flag is clear thus indicating no fault occurred.
	 
	lda	#$99		; $99 = 10011001
	clc			; Clear the CARRY flag. 
	adc	#1		; Add 1 to regsister 'A'.
	bcc	OK_55AA		; If the carry flag is clear - no error was detected...
	jmp	TEST_55AA	; Keep repeating the test as an error was detected. 

OK_55AA:

	; ***************************************************************************************************
	; ***                                                                                             ***
	; ***  Prepare the screen. Blank except for block 0 containing all of the PETSCII character set.  ***
	; ***                                                                                             ***
	; ***************************************************************************************************

	ldx	#0		; Starting index into the blocks of screen memory.
more_vduZ:
	lda	#spc		; PETSCII ' ' character initially for all VDU memory blocks.
	sta	vdu0,x		; Screen block 0.
	sta	vdu1,x		; Screen block 1.
	sta	vdu2,x		; Screen block 2.
	sta	vdu3,x		; Screen block 3.
	sta	vdu4,x		; Screen block 4.
	sta	vdu5,x		; Screen block 5.
	sta	vdu6,x		; Screen block 6.
	sta	vdu7,x		; Screen block 7.
	txa			; The PETSCII character for VDU blocks 0 is the same as the index.
	sta	vdu0,x		; Screen block 0.
	inx			; Move on to the next location in the screen memory.
	bne	more_vduZ	; Keep looping until we have finished.

	; Initialise the stack pointer.
	; =============================
	;
	ldx	#$FF		; Top of page 1.
	txs			; Store to stack pointer.
	
	cld			; Let's switch off DECIMAL mode - just in case it was on by accident!
	
	; Initialise the keyboard PIA.
	; ============================
	;
	; Port A.
	; =======
	;
	lda	#$0F		; DDRA pins. 0=IN, 1=OUT. IIIIOOOO.
	sta	pia1 + 0	; Initialise DDRA.
	lda	#$04		; Change to data register - but no CA1/CA2 interrupts!
	sta	pia1 + 1	; Output to CRA.
	lda	#$09		; Last row for the decimal keyboard decoder (enable ROW 9 for RUN/STOP key).
	sta	pia1 + 0	; Send to the keyboard PIA output port.
	;
	; Port B.
	; =======
	;
	lda	#$00		; DDRB pins. 0=IN, 1=OUT. IIIIIIII.
	sta	pia1 + 2	; Initialise DDRB.
	lda	#$04		; Change to data register - but no CB1/CB2 interrupts!
	sta	pia1 + 3	; Output to CRB.
	
	; ***************************************
	; ***                                 ***
	; ***  Zap out pages 0 and 1 to $00.  ***
	; ***                                 ***
	; ***************************************

	inx			; Memory index. X was $FF from initialising the stack pointer.
	lda	#0		; Zap all of memory to $00.
	
more_zap:	
	sta	mem0,x		; Zap Page 0.
	sta	mem1,x		; Zap page 1.
	inx			; Move on to the next memory location within the block.
	bne	more_zap	; Keep looping until completed.

; ********************************************************************************************

	jmp	SKIPKVEC	; Skip the kernal-1 and kernal-2 EDIT ROM entry vectors.

	; This is the EDIT ROM entry point for kernal-2 (at address $E1DE).
	; =================================================================
	;
	.org	EDITROM + $1DE
	jmp	start		; Go do the test ROM code!
	
	; This is the EDIT ROM entry point for kernal-1 (at address $E1E1).
	; =================================================================
	;
	.org	EDITROM + $1E1
	jmp	start		; Go do the test ROM code!
		
	; Continue with the test ROM code.
	;
	.org	EDITROM + $1F0
	
SKIPKVEC:			

; ********************************************************************************************
	
	; ********************************
	; ***                          ***
	; ***  PAGE 0 RAM definitions  ***
	; ***                          ***
	; ********************************

ROMLL	.equ	0
ROMHH	.equ	1

ROMSIZ	.equ	2

VDULL	.equ	3
VDUHH	.equ	4

TEMPA	.equ	5

CKSUMLL	.equ	6
CKSUMHH	.equ	7

CNTDOWN	.equ	8

STARTLL	.equ	9
STARTHH	.equ	10

ENDLL	.equ	11
ENDHH	.equ	12

ADDRLL	.equ	13
ADDRHH	.equ	14

BITMASK	.equ	15

TESTNO	.equ	16

PASSLL	.equ	17
PASSMM	.equ	18
PASSHH	.equ	19

MEMSIZE	.equ	20

SEQ	.equ	21

	; Initialise the KEY/ROM screen countdown.
	;
	;
	lda	#$FF		; Start at the highest value...
	sta	CNTDOWN
	
KEYROM:

	; ************************************************************************************
	; ***                                                                              ***
	; ***  Checksum each ROM. Note that checksumming the $Exxx ROM is not sensible...  ***
	; ***                                                                              ***
	; ************************************************************************************

	; Initialise where we are going to write the results to the screen.
	; =================================================================
	;
	SET_POS 8,0
	
	; Output some (helpful) text to the screen...
	; ===========================================
	;
	ldx	#ROMMSG_LEN		; Length of character string.
	ldy	#0		; Index to string.
ROMMSGa:
	lda	ROMMSG,y	; Pickup the first/next character
	jsr	OUTCHAR		; Display to screen.
	iny			; Index to the next character.
	dex			; One less character to output.
	bne	ROMMSGa		; Loop until all done.	

		 
	lda	#$B0		; Checksum the 2K rom at B000 - B7FF.
	jsr	ROMCKSUM	; Do it...
	lda	#$C0		; Checksum the 2K rom at C000 - C7FF.
	jsr	ROMCKSUM	; Do it...
	lda	#$D0		; Checksum the 2K rom at D000 - D7FF.
	jsr	ROMCKSUM	; Do it...
	lda	#$F0		; Checksum the 2K rom at F000 - F7FF.
	jsr	ROMCKSUM	; Do it...

	; Move to next line (or 2nd half), skip 4 chars
	SET_POS 9,4
	
	lda	#$B8		; Checksum the 2K rom at B800 - BFFF.
	jsr	ROMCKSUM	; Do it...
	lda	#$C8		; Checksum the 2K rom at C800 - CFFF.
	jsr	ROMCKSUM	; Do it...
	lda	#$D8		; Checksum the 2K rom at D800 - DFFF.
	jsr	ROMCKSUM	; Do it...
	lda	#$F8		; Checksum the 2K rom at F800 - FFFF.
	jsr	ROMCKSUM	; Do it...


	; ************************************************************************************
	; ***                                                                              ***
	; ***  Dump ROM starts                                                             ***
	; ***                                                                              ***
	; ************************************************************************************

	SET_POS 10,0
	lda	#$B0		
	jsr	DUMPROM
	SET_POS 11,0
	lda	#$B8		
	jsr	DUMPROM

	SET_POS 12,0
	lda	#$C0		
	jsr	DUMPROM
	SET_POS 13,0
	lda	#$C8		
	jsr	DUMPROM

	SET_POS 14,0
	lda	#$D0		
	jsr	DUMPROM
	SET_POS 15,0
	lda	#$D8		
	jsr	DUMPROM

	SET_POS 16,0
	lda	#$F0		
	jsr	DUMPROM
	SET_POS 17,0
	lda	#$F8		
	jsr	DUMPROM


	; ***************************************************************************************
	; ***                                                                                 ***
	; ***  Scan the key matrix and display the results (in hex) on a line on the screen.  ***
	; ***                                                                                 ***
	; ***************************************************************************************

	; Initialise where we are going to write the results to the screen.
	; =================================================================
	;
	SET_POS 20,0
		
	; Output some (helpful) text to the screen...
	; ===========================================
	;
	ldx	#KBDMSG_LEN		; Length of character string.
	ldy	#0		; Index to string.
KBDMSGa:
	lda	KBDMSG,y	; Pickup the first/next character
	jsr	OUTCHAR		; Display to screen.
	iny			; Index to the next character.
	dex			; One less character to output.
	bne	KBDMSGa		; Loop until all done.	

	jsr	KEYMAT		; Display the keyboard matrix.
	jsr	IEEETEST	; Display compact IEEE-488 interface status.

	; Initialise where we are going to write the results to the screen.
	; =================================================================
	;
	SET_POS 24,0	
	
	; Output some (helpful) text to the screen...
	; ===========================================
	;
	ldx	#CNTMSG_LEN	; Length of character string.
	ldy	#0		; Index to string.
CNTMSGa:
	lda	CNTMSG,y	; Pickup the first/next character
	jsr	OUTCHAR		; Display to screen.
	iny			; Index to the next character.
	dex			; One less character to output.
	bne	CNTMSGa		; Loop until all done.	

	; Output the current countdown value to the screen as two hex digits.
	; The A-F characters are expected; this is a byte countdown, not decimal.
	; ==================================================
	;
	lda	CNTDOWN		; Pick up the count down value.
	jsr	OUTHEXA		; And display it on the screen.
	

	; **********************************
	; ***                            ***
	; ***  Terminate or continue...  ***
	; ***                            ***
	; **********************************

	dec	CNTDOWN		; One less to do...
	lda	CNTDOWN		; What is the current countdown?
	cmp	#$FF		; Is it one less than 0?
	beq	ENDKEYROM	; all done if Z flag is set.	
    jmp	KEYROM		; Play it again Sam...	
ENDKEYROM:

	jsr	DRAMCHECK	; Let's go and check the DRAM!!!
	
ALLDONE:	
	jmp	ALLDONE		; Just sit here forever in a loop...
	
; **********************
; ***                ***
; ***  SUBROUTINES.  ***
; ***                ***
; **********************

	; =================================================================================
	
; ******************
; ***            ***
; ***  ROMCKSUM  ***
; ***            ***
; ******************

ROMCKSUM:

	; Store the ROM we are performing a checksum on into page 0 memory.
	;
	sta	ROMHH
	
	; Display the ROM we are checksumming to the human...
	;
	jsr	OUTHEXA
	
	; Display an '=' sign...
	;
	lda	#PETSCII_EQ
	jsr	OUTCHAR
	
	lda	#0		; Initialise the low byte of the ROM address in page 0 memory.
	sta	ROMLL		; "   "   "   "   "   "   "   "   "   "   "   "   "   "   "
	
	lda	#$8		; Number of pages of 256 bytes in 2K.
	sta	ROMSIZ	; "   "   "   "   "   "   "   "   "   "   "
		
	lda	#0		; Initially zero the checksum value.
	sta	CKSUMLL		; Low byte.
	sta	CKSUMHH		; High byte.
	
	; Do the actual CHECKSUM!!!
	; =========================
	
CKSUMouter:

	ldy	#0		; First block byte index.

CKSUMinner:

	lda	(ROMLL),y	; Pick up the first/next byte of the block.
	clc			; No carry flag.
	adc	CKSUMLL		; Merge in to the checksum low byte.
	sta	CKSUMLL		; "   "   "   "   "   "   "   "   "
	lda	#0		; Merge in any carry to the high byte of the checksum.
	adc	CKSUMHH		; "   "   "   "   "   "   "   "   "   "   "   "   "   
	sta	CKSUMHH		; "   "   "   "   "   "   "   "   "   "   "   "   "   
	
	iny			; Next byte of the block.
	bne	CKSUMinner	; Keep looping until finished.
	
	; We have done at least one block of the checksum.
	
	; Increment the ROM block pointer for the next time around the loop (if any).
	;
	inc	ROMHH		; High byte of ROM address.
	
	; Decrement the number of 256-byte blocks (since we have just processed one block).
	;
	dec	ROMSIZ
	
	bne	CKSUMouter	; Keep looping until finished.
	
	; Done!!!
	; =======

	lda	CKSUMHH		; Pick up the high byte of the checksum.
	jsr	OUTHEXA		; Display the result.
	lda	CKSUMLL		; Pick up the low byte of the checksum.
	jsr	OUTHEXA		; Display the result.
	
	jsr	OUTSPACE	; Output a space.
	
	rts			; Return back to caller.

	; =================================================================================

; ******************
; ***            ***
; ***  DUMPROM   ***
; ***            ***
; ******************

DUMPROM:
	
	sta	ROMHH	; Store the ROM we are dumping into page 0 memory.

	
	; Display the ROM addr followed by ': '
	jsr	OUTHEXA	
	lda	#PETSCII_COLON
	jsr	OUTCHAR
	jsr	OUTSPACE

	; Dump 16 bytes of data
	ldy #0
	sty ROMLL	; Make sure the low byte of the address is correctly set
_l	lda (ROMLL),y
	jsr	OUTHEXA
	iny
	cpy #16
	bne _l

	; Done!!!
	; =======
	
	rts			; Return back to caller.

	; =================================================================================

; ****************
; ***          ***
; ***  KEYMAT  ***
; ***          ***
; ****************

KEYMAT:

	; Initialise the keyboard PIA for keyboard row 0.
	; ===============================================
	;
	lda	#0		; Start at keyboard row 0.
	sta	pia1 + 0	; Initialise the PIA.
	
	; Ten rows to the key matrix.
	; ===========================
	;
	ldx	#10
	
KEYMATa:

	; Simple delay to allow the keyboard logic to register any keypress.
	;
	ldy	#0		; Initial value.
KEYMATb:
	nop			; Do nothing...
	nop			; Do nothing...
	dey			; Decrement delay counter.
	bne	KEYMATb		; Keep looping until the delay has expired.
	
	; Input the current keyboard matrix value from the PIA.
	; =====================================================
	;
	lda	pia1 + 2	; PIA1 B data port.
		
	; Invert (1's complement) the value so the default is $00 and a key press is reported
	; as a '1' bit in the appropriate location of the byte.
	;
	eor	#$FF
	
	; Output the value to the screen. Note the subroutine doesn't corrupt 'A'.
	;
	jsr	OUTHEXA

	; Followed by a space character to format the screen in a simple manner.
	;
	jsr	OUTSPACE
	
	; Increment the keyboard row in the PIA.
	; ======================================
	;
	inc	pia1 + 0
	
	dex			; One less row
	bne	KEYMATa		; Loop until all done.
	
	; Leave the row set to '9' so I can check the status of the RUN/STOP key.
	; =======================================================================
	;
	lda	#$09
	sta	pia1+0
	
	rts			; Return back to caller.

	; =================================================================================
	
; *******************
; ***             ***
; ***  DRAMCHECK  ***
; ***             ***
; *******************

DRAMCHECK:

	; ========================================
	; Initialise for full DRAM memory testing.
	; ========================================
	
	lda	#$02		; Start of DRAM to test (high byte).
	sta	STARTHH		; "   "   "   "   "   "   "   "   "
	
	lda	#$00		; Start of DRAM to test (low byte).
	sta	STARTLL		; "   "   "   "   "   "   "   "   "
	
	; Find top of ram. Assume either 4K, 8K, 16K or 32K.
	
	lda	#$FF		; Must end on a 256-byte boundary.
	sta	ENDLL
	sta	ADDRLL
	
	lda	#$0F		; Assume 4K (0FFF) to start with.
	sta	ENDHH
	sta	ADDRHH
	
	lda	#$04		; 4K
	sta	MEMSIZE
	sta	TEMPA
	
	lda	#0		; Used as a 'dummy index'.
	tay

MEMSIZEa:

	lda	#tst55
	sta	(ADDRLL),y
	cmp	(ADDRLL),y
	bne	MEMSIZEb
	
	lda	#tstAA
	sta	(ADDRLL),y
	cmp	(ADDRLL),y
	bne	MEMSIZEb

	lda	ADDRLL
	sta	ENDLL
	
	lda	ADDRHH
	sta	ENDHH
	
	lda	TEMPA
	sta	MEMSIZE
	
	sec
	
	rol	ADDRHH
	
	sed
	lda	TEMPA
	clc
	adc	TEMPA
	sta	TEMPA
	cld
	
	jmp	MEMSIZEa
	
MEMSIZEb:
		
	lda	#$00		; Initialise the 24-bit pass counter to zero.
	sta	PASSLL		; "   "   "   "   "   "   "   "   "   "   "  
	sta	PASSMM		; "   "   "   "   "   "   "   "   "   "   "  
	sta	PASSHH		; "   "   "   "   "   "   "   "   "   "   "  
	
	; Clear the screen
	
	ldx	#0		; Starting index into the blocks of screen memory.
DRAMCHECKa:
	lda	#spc		; PETSCII ' ' character for all VDU memory blocks.
	sta	vdu0,x		; Screen block 0.
	sta	vdu1,x		; Screen block 1.
	sta	vdu2,x		; Screen block 2.
	sta	vdu3,x		; Screen block 3.
	sta	vdu4,x		; Screen block 4.
	sta	vdu5,x		; Screen block 5.
	sta	vdu6,x		; Screen block 6.
	sta	vdu7,x		; Screen block 7.
	inx			; Move on to the next location in the screen memory.
	bne	DRAMCHECKa	; Keep looping until we have finished.
	
	; Display a useful message to the user...
	
	; Initialise where we are going to write the text message to the screen.
	; ======================================================================
	;
	lda	#$00		; VDU screen low address.
	sta	VDULL		; "   "   "   "   "   "
	lda	#$80		; VDU screen high address.
	sta	VDUHH		; "   "   "   "   "   "
	
	lda	MEMSIZE
	jsr	OUTHEXA
	
	; Output some (helpful) text to the screen...
	; ===========================================
	;
	ldx	#DRAMMSG_LEN	; Length of character string.
	ldy	#0		; Index to string.
DRAMCHECKb:
	lda	DRAMMSG,y	; Pickup the first/next character
	jsr	OUTCHAR		; Display to screen.
	iny			; Index to the next character.
	dex			; One less character to output.
	bne	DRAMCHECKb	; Loop until all done.	

DRAMLOOP:

	; Initialise where we are going to write the results of the memory test (good or bad) to the screen.
	; ==================================================================================================
	;
	lda	#$A0		; VDU screen low address.
	sta	VDULL		; "   "   "   "   "   "
	lda	#$80		; VDU screen high address.
	sta	VDUHH		; "   "   "   "   "   "

	; Output '.'s to the screen to indicate how many individual tests we have for 1 pass of the DRAM test.
	;
	lda	#10		; 10+1 dots required.
	tay			; Get it to the correct register.
	lda	#dot		; PETSCII '.'.
DoMoreDots:
	sta	(VDULL),y	; Display on screen.
	dey			; One less '.' to display.
	bne	DoMoreDots	; Keep repeating until almost done.
	sta	(VDULL),y	; Didn't quite do the last one - so do it now!
		
	lda	#$00		; Y is used as a dummy index and it ***MUST*** be preserved as 0 throughout the test.
	tay

	lda	#0
	sta	SEQ
	
	jmp	TEST0		; Go do it...
	
	; =======
	; Test 0.
	; =======

TEST0:

	lda	#0		; Start off with test number 0 - set all of memory to 0 and test for 0 (i.e.
				; test for a stuck '1').
	sta	TESTNO
	lda	TESTNO		; DEBUG
	jsr	OUTHEXAL	; DEBUG
	
	; Write 0's to all of memory...
	
	jsr	INIASCEND	; We are going to go up the memory.
T0loop1:
	jsr	W0		; Write a '0' bit into memory.
	jsr	INCBIT		; Move on to the next bit of memory.
	bcc	T0loop1		; Keep looping until done...
	
	; Verify that 0's are still in all of memory...
	 
	jsr	INIASCEND	; We are going to go up the memory.
T0loop2:
	jsr	R0		; Read the bit and check for '0'.
	bcs	T0error		; Check for an error.
	jsr	INCBIT		; Move on to the next bit of memory.
	bcc	T0loop2		; Keep looping until done...

	; ====================
	; Test 0 completed OK.
	; ====================
	
	jmp	TEST1		; Next test...
	
T0error:

	jmp	DRAMERROR	; Abandon the testing...
	
	; =======
	; Test 1.
	; =======

TEST1:

	inc	TESTNO		; Move on to test number 1 - set all of memory to 1 and test for 1 (i.e.
				; test for a stuck '0').
	lda	TESTNO		; DEBUG
	jsr	OUTHEXAL	; DEBUG
					
	; Write 1's to all of memory...
	
	jsr	INIASCEND	; We are going to go up the memory.
T1loop1:
	jsr	W1		; Write a '1' bit into memory.
	jsr	INCBIT		; Move on to the next bit of memory.
	bcc	T1loop1		; Keep looping until done...
	
	; Verify that 1's are still in all of memory...
	 
	jsr	INIASCEND	; We are going to go up the memory.
T1loop2:
	jsr	R1		; Read the bit and check for '1'.
	bcs	T1error		; Check for an error.
	jsr	INCBIT		; Move on to the next bit of memory.
	bcc	T1loop2		; Keep looping until done...

	; ====================
	; Test 1 completed OK.
	; ====================
	
	jmp	TEST2		; Next test...
	
T1error:

	jmp	DRAMERROR	; Abandon the testing...
	
	; =======
	; Test 2.
	; =======

TEST2:

	inc	TESTNO		; Move on to test 2 - Checkerboard test.
	lda	TESTNO		; DEBUG
	jsr	OUTHEXAL	; DEBUG
				
	; Write alternate 0's and 1's to all of memory...
	
	jsr	INIASCEND	; We are going to go up the memory.
T2loop1:
	jsr	W0		; Write a '0' bit into memory.
	jsr	INCBIT		; Move on to the next bit of memory.
	bcs	T2endloop1	; Reached the end of memory.
	jsr	W1		; Write a '1' bit into memory.
	jsr	INCBIT		; Move on to the next bit of memory.
	bcc	T2loop1		; Keep looping until done...
T2endloop1:

	; Verify that alternate 0's and 1's are still in all of memory...

	jsr	INIASCEND	; We are going to go up the memory.
T2loop2:
	jsr	R0		; Read the bit and check for '0'.
	bcs	T2error		; Check for an error.
	jsr	INCBIT		; Move on to the next bit of memory.
	bcs	T2endloop2	; Reached the end of memory.
	jsr	R1		; Read the bit and check for '1'.
	bcs	T2error		; Check for an error.
	jsr	INCBIT		; Move on to the next bit of memory.	
	bcc	T2loop2		; Keep looping until done...
T2endloop2:

	; ====================
	; Test 2 completed OK.
	; ====================
	
	jmp	TEST3		; Next test...
	
T2error:

	jmp	DRAMERROR	; Abandon the testing...
	
	; =======
	; Test 3.
	; =======
	
TEST3:

	inc	TESTNO		; Move on to test 3 - MARCH C.
	lda	TESTNO		; DEBUG
	jsr	OUTHEXAL	; DEBUG
		
	lda	#0		; Reset the test sequence indicator (for error/diagnostic reporting purposes) - 0.
	sta	SEQ
	lda	SEQ		; DEBUG
	jsr	OUTHEXAL	; DEBUG
			
	; /\(w0); /\(r0,w1); /\(r1,w0);
	; /\(r0); \/(r0,w1); \/(r1,w0); /\(r0);

	; /\(w0);
	;	
	jsr	INIASCEND	; We are going to go up the memory.
T3loop1:
	jsr	W0		; Write a '0' bit into memory.
	jsr	INCBIT		; Move on to the next bit of memory.
	bcc	T3loop1		; Keep looping until done...
	
	inc	SEQ		; Move the test sequence indicator on (for error/diagnostic reporting purposes) - 1.
	lda	SEQ		; DEBUG
	jsr	OUTHEXAL	; DEBUG
	
	; /\(r0,w1);
	;
	jsr	INIASCEND	; We are going to go up the memory.
T3loop2:
	jsr	R0		; Read the bit and check for '0'.
	bcs	T3error		; Check for an error.
	jsr	W1		; Write a '1' bit into memory.
	jsr	INCBIT		; Move on to the next bit of memory.
	bcc	T3loop2		; Keep looping until done...

	inc	SEQ		; Move the test sequence indicator on (for error/diagnostic reporting purposes) - 2.
	lda	SEQ		; DEBUG
	jsr	OUTHEXAL	; DEBUG
	
	; /\(r1,w0);
	;
	jsr	INIASCEND	; We are going to go up the memory.
T3loop3:
	jsr	R1		; Read the bit and check for '1'.
	bcs	T3error		; Check for an error.
	jsr	W0		; Write a '0' bit into memory.
	jsr	INCBIT		; Move on to the next bit of memory.
	bcc	T3loop3		; Keep looping until done...

	inc	SEQ		; Move the test sequence indicator on (for error/diagnostic reporting purposes) - 3.
	lda	SEQ		; DEBUG
	jsr	OUTHEXAL	; DEBUG
	
	; /\(r0);
	;
	jsr	INIASCEND	; We are going to go up the memory.
T3loop4:
	jsr	R0		; Read the bit and check for '0'.
	bcs	T3error		; Check for an error.
	jsr	INCBIT		; Move on to the next bit of memory.
	bcc	T3loop4		; Keep looping until done...
	
	inc	SEQ		; Move the test sequence indicator on (for error/diagnostic reporting purposes) - 4.
	lda	SEQ		; DEBUG
	jsr	OUTHEXAL	; DEBUG
	
	; \/(r0,w1);
	;
	jsr	INIDESCEND	; We are going to go down the memory.
T3loop5:
	jsr	R0		; Read the bit and check for '0'.
	bcs	T3error		; Check for an error.
	jsr	W1		; Write a '1' bit into memory.
	jsr	DECBIT		; Move on to the previous bit of memory.
	bcc	T3loop5		; Keep looping until done...

	inc	SEQ		; Move the test sequence indicator on (for error/diagnostic reporting purposes) - 5.
	lda	SEQ		; DEBUG
	jsr	OUTHEXAL	; DEBUG
	
	; \/(r1,w0);
	;
	jsr	INIDESCEND	; We are going to go down the memory.
T3loop6:
	jsr	R1		; Read the bit and check for '1'.
	bcs	T3error		; Check for an error.
	jsr	W0		; Write a '0' bit into memory.
	jsr	DECBIT		; Move on to the previous bit of memory.
	bcc	T3loop6		; Keep looping until done...

	inc	SEQ		; Move the test sequence indicator on (for error/diagnostic reporting purposes) - 6.
	lda	SEQ		; DEBUG
	jsr	OUTHEXAL	; DEBUG
	
	; /\(r0);
	;
	jsr	INIASCEND	; We are going to go up the memory.
T3loop7:
	jsr	R0		; Read the bit and check for '0'.
	bcs	T3error		; Check for an error.
	jsr	INCBIT		; Move on to the next bit of memory.
	bcc	T3loop7		; Keep looping until done...

	; ====================
	; Test 3 completed OK.
	; ====================

	jmp	DRAMOK		; All done...
	
T3error:

	jmp	DRAMERROR	; Abandon the testing...
	
DRAMOK:

	; Output a PASS message to the screen...
	; ======================================
	;
	ldx	#DRAMPASS_LEN	; Length of character string.
	ldy	#0		; Index to string.
DRAMPASSa:
	lda	DRAMPASS,y	; Pickup the first/next character
	jsr	OUTCHAR		; Display to screen.
	iny			; Index to the next character.
	dex			; One less character to output.
	bne	DRAMPASSa	; Loop until all done.	

	; Increment the PASS counter.
	;
	clc
	lda	#1
	adc	PASSLL
	sta	PASSLL
	lda	#0
	adc	PASSMM
	sta	PASSMM
	lda	#0
	adc	PASSHH
	sta	PASSHH
	
	; Output the PASS counter.
	;
	lda	PASSHH
	jsr	OUTHEXA
	lda	PASSMM
	jsr	OUTHEXA
	lda	PASSLL
	jsr	OUTHEXA
	lda	#dot		; PETSCII '.'.
	jsr	OUTCHAR

	jmp	DRAMLOOP	; Keep repeating (for now)...
	
	clc			; NO ERROR OCCURRED!!!
		
	rts			; Return back to caller.

DRAMERROR:

	; Output a FAIL message to the screen...
	; ======================================
	;
	lda	#$40		; VDU screen low address.
	sta	VDULL		; "   "   "   "   "   "
	lda	#$81		; VDU screen high address.
	sta	VDUHH		; "   "   "   "   "   "

	ldx	#DRAMFAIL_LEN	; Length of character string.
	ldy	#0		; Index to string.
DRAMFAILa:
	lda	DRAMFAIL,y	; Pickup the first/next character
	jsr	OUTCHAR		; Display to screen.
	iny			; Index to the next character.
	dex			; One less character to output.
	bne	DRAMFAILa	; Loop until all done.	
	
	lda	TESTNO
	jsr	OUTHEXAL
	jsr	OUTSPACE
	
	lda	SEQ
	jsr	OUTHEXAL
	jsr	OUTSPACE
	
	lda	ADDRHH
	jsr	OUTHEXA
	lda	ADDRLL
	jsr	OUTHEXA
	jsr	OUTSPACE
	
	lda	BITMASK
	jsr	OUTHEXA
	jsr	OUTSPACE
	
	lda	#0		; Y must be 0!
	tay			; -- ditto --
	lda	(ADDRLL),y
	jsr	OUTHEXA
	lda	#$21		; PETSCII '!'
	jsr	OUTCHAR
	
	sec			; AN ERROR OCCURRED!!!
	
	rts			; Return back to caller.

	; =================================================================================

INIASCEND:

	; Start at the beginning of the DRAM block to test and work upwards.
	
	lda	STARTLL		; Start address high byte
	sta	ADDRLL
	
	lda	STARTHH		; Start address low byte
	sta	ADDRHH
	
	lda	#$01		; First bit of the byte.
	sta	BITMASK
	
	rts			; Return back to caller.

INIDESCEND:

	; Start at the end of the DRAM block to test and work downwards.
	
	lda	ENDLL		; End address high byte
	sta	ADDRLL
	
	lda	ENDHH		; End address low byte
	sta	ADDRHH
	
	lda	#$80		; Last bit of the byte.
	sta	BITMASK
		
	rts			; Return back to caller.

INCBIT:

	clc

	lda	ADDRLL
	cmp	ENDLL
	bne	INCBITa
	lda	ADDRHH
	cmp	ENDHH
	bne	INCBITa
	lda	BITMASK
	cmp	#$80
	bne	INCBITa
	sec
	rts			; Return back to caller.

INCBITa:
	
	asl	BITMASK
	bcc	INCBITb
	lda	#$01
	sta	BITMASK
	inc	ADDRLL
	bne	INCBITb
	inc	ADDRHH

INCBITb:

	clc
	rts			; Return back to caller.

DECBIT:

	clc

	lda	ADDRLL
	cmp	STARTLL
	bne	DECBITa
	lda	ADDRHH
	cmp	STARTHH
	bne	DECBITa
	lda	BITMASK
	cmp	#$01
	bne	DECBITa
	sec
	rts			; Return back to caller.

DECBITa:

	lsr	BITMASK
	bcc	DECBITb
	lda	#$80
	sta	BITMASK
	dec	ADDRLL
	lda	#$FF
	cmp	ADDRLL
	bne	DECBITb
	dec	ADDRHH
			
DECBITb:

	clc
	rts			; Return back to caller.

W0:

	lda	BITMASK
	eor	#$FF
	and	(ADDRLL),y
	sta	(ADDRLL),y
	
	rts			; Return back to caller.

W1:

	lda	BITMASK
	ora	(ADDRLL),y
	sta	(ADDRLL),y

	rts			; Return back to caller.

R0:

	clc
	lda	BITMASK
	and	(ADDRLL),y
	beq	R0a
	sec
R0a:

	rts			; Return back to caller.

R1:

	clc
	lda	BITMASK
	and	(ADDRLL),y
	bne	R1a
	sec
R1a:

	rts			; Return back to caller.

	; =================================================================================
	
; *****************
; ***           ***
; ***  OUTCHAR  ***
; ***           ***
; *****************

	; ********************************************************************************************
	; ***                                                                                      ***
	; ***  Output the PETSCII character in register 'A' to the current location of the screen  ***
	; ***                       and advance the screen pointer.                                ***
	; ***                                                                                      ***
	; ***       No registers are harmed during the execution of this subroutine!               ***
	; ***                                                                                      ***
	; ********************************************************************************************

OUTCHAR:

	; Store the registers onto the stack.
	;
	php			; Save the flags onto the stack.
	pha			; Save register 'A' onto the stack.
	sta	TEMPA		; Preserve the value of register 'A' for later.
	txa			; Store register 'X' onto the stack.
	pha			; "   "   "   "   "   "   "   "   "
	tya			; Store register 'Y' onto the stack.
	pha			; "   "   "   "   "   "   "   "   "
	lda	TEMPA		; Recover the character to be output to the screen.
	
	ldy	#0		; Use register 'Y' as a 'dummy' index.
	sta	(VDULL),y	; Store the character in 'A' to the screen.
	
	; Move the screen pointer on.
	;
	clc			; No carry
	lda	#1		; + 1
	adc	VDULL		; Low address.
	sta	VDULL		; Low address.
	lda	#0		; Just add any carry to the high address.
	adc	VDUHH		; High address.
	sta	VDUHH		; High address.
	
	; Recover the registers from the stack.
	;
	pla			; Y register.
	tay			; "   "   "
	pla			; X register.
	tax			; "   "   "
	pla			; 'A' register.
	plp			; Flag register.
	
	; Return to caller.
	;
	rts			; Bye bye.

	; =================================================================================
	
; ******************
; ***            ***
; ***  OUTSPACE  ***
; ***            ***
; ******************

OUTSPACE:

	pha			; Save register 'A' onto the stack.
	
	lda	#spc		; PETSCII ' '.
	jsr	OUTCHAR		; And display it.
	
	pla			; Recover register 'A' from the stack.
	
	; Return to caller.
	;
	rts			; Bye bye.

	; =================================================================================
	
; *****************
; ***           ***
; ***  OUTHEXA  ***
; ***           ***
; *****************

OUTHEXA:

	; Output the high nibble of register 'A' in hexadecimal first.
	;
	jsr	OUTHEXAH
	
	; Followed by the low nibble of register 'A' in hexadecimal second.
	;
	jsr	OUTHEXAL
	
	; Return to caller.
	;
	rts			; Bye bye.

	; =================================================================================
	
; ******************
; ***            ***
; ***  OUTHEXAH  ***
; ***            ***
; ******************

OUTHEXAH:

	; Store the registers onto the stack.
	;
	php			; Save the flags onto the stack.
	pha			; Save register 'A' onto the stack.
	sta	TEMPA		; Preserve the value of register 'A' for later.
	txa			; Store register 'X' onto the stack.
	pha			; "   "   "   "   "   "   "   "   "
	tya			; Store register 'Y' onto the stack.
	pha			; "   "   "   "   "   "   "   "   "
	lda	TEMPA		; Recover the character to be output.

	; Move the bits in register 'A' four bits to the right.
	;
	lsr
	lsr
	lsr
	lsr
	
	; And display the lower nibble in hexadecimal to the screen.
	;
	jsr	OUTHEXAL 
	
	; Recover the registers from the stack.
	;
	pla			; Y register.
	tay			; "   "   "
	pla			; X register.
	tax			; "   "   "
	pla			; 'A' register.
	plp			; Flag register.

	; Return to caller.
	;
	rts			; Bye bye.

	; =================================================================================
	
; ******************
; ***            ***
; ***  OUTHEXAL  ***
; ***            ***
; ******************

OUTHEXAL:

	; Store the registers onto the stack.
	;
	php			; Save the flags onto the stack.
	pha			; Save register 'A' onto the stack.
	sta	TEMPA		; Preserve the value of register 'A' for later.
	txa			; Store register 'X' onto the stack.
	pha			; "   "   "   "   "   "   "   "   "
	tya			; Store register 'Y' onto the stack.
	pha			; "   "   "   "   "   "   "   "   "
	lda	TEMPA		; Recover the character to be output.

	; Mask off all but the lower 4 bits of register 'A'.
	;
	and	#$0F		; 00001111.
	
	; Use 'Y' as the index register to lookup the corresponding PETSCII character code.
	;
	tay
	
	; Index the lookup table using register 'Y'.
	;
	lda	HEXLUT,y
	
	; Display the character (now in register 'A') on to the screen.
	;
	jsr	OUTCHAR

	; Recover the registers from the stack.
	;
	pla			; Y register.
	tay			; "   "   "
	pla			; X register.
	tax			; "   "   "
	pla			; 'A' register.
	plp			; Flag register.

	; Return to caller.
	;
	rts			; Bye bye.
	
	; =================================================================================
	
	; Lookup table to convert a 4-bit hexadecimal code into the corresponding
	; PETSCII character to display on the Commodore PET screen.
	
HEXLUT:
	.byte	$30		; '0'.
	.byte	$31		; '1'.
	.byte	$32		; '2'.
	.byte	$33		; '3'.
	.byte	$34		; '4'.
	.byte	$35		; '5'.
	.byte	$36		; '6'.
	.byte	$37		; '7'.
	.byte	$38		; '8'.
	.byte	$39		; '9'.
	.byte	$01		; 'A'.
	.byte	$02		; 'B'.
	.byte	$03		; 'C'.
	.byte	$04		; 'D'.
	.byte	$05		; 'E'.
	.byte	$06		; 'F'.
	
	; =================================================================================
	
ROMMSG:
	.byte scr("r")
ROMMSG_LEN	.equ * - ROMMSG	
	
	; =================================================================================
	
KBDMSG:
	.byte scr("k")
KBDMSG_LEN: .equ * - KBDMSG
	
	; =================================================================================

CNTMSG:
	.byte scr("c")
CNTMSG_LEN	.equ * - CNTMSG
		
	; =================================================================================
	
DRAMMSG:
	.byte scr("K")
DRAMMSG_LEN	.equ * - DRAMMSG

	; =================================================================================
	
DRAMPASS:
	.byte scr("OK")
DRAMPASS_LEN	.equ * - DRAMPASS

	; =================================================================================
	
DRAMFAIL:
	.byte scr("F ")
DRAMFAIL_LEN	.equ * - DRAMFAIL

	; =================================================================================

IEEETEST:

	; Compact IEEE-488 self-test. Prints DDCC, where DD is the DIO fault mask
	; and CC is: $10 NDAC, $08 DAV, $04 NRFD, $02 EOI, $01 ATN.
	; Result is printed after the ROM CRC checks it's not friendly as we're out of space.
	; as an example:
	; 0000 = no IEEE fault detected
	; 0010 = NDAC fault
	; 0001 = ATN fault
	; 0011 = NDAC and ATN faults
	; 8000 = DIO bit 7 fault
	; The PET IEEE port has separate write and read paths through the PIA/VIA
	; chips and the MC3446 bus transceivers. For the data lines, write PIA #1
	; port B ($E822 / BASIC 59426) and read PIA #1 port A ($E820 / 59424).
	; A bit in DD means that data line could not be driven low and high again.
	;
	; The control lines below are checked by writing one side of the bus circuit,
	; reading the matching input, and comparing the two expected states. The
	; tables are ordered EOI, NRFD, DAV, NDAC, but the result is shifted into CC
	; as NDAC/DAV/NRFD/EOI before the separate ATN test appends bit 0.
	;
	; VIA port B must not be made all-output here. PB0/PB6/PB7 are the NDAC,
	; NRFD, and DAV read inputs. Only PB1 (NRFD output) and PB2 (ATN output)
	; are driven, hence DDRB=$06.

	SET_POS 21,0

	; Data bus test: force all eight DIO outputs low, read back, then force
	; them high and read back inverted. ORing the two reads leaves a bit set
	; for any data line that failed either state.
	lda	#0
	sta	pia2 + 2
	lda	pia2
	sta	TEMPA
	lda	#$FF
	sta	pia2 + 2
	lda	pia2
	eor	#$FF
	ora	TEMPA
	jsr	OUTHEXA

	; Set VIA DDRB so NRFD and ATN can be driven without trampling the read
	; inputs. CKSUMHH accumulates the compact control-line fault mask.
	lda	#$06
	sta	$E842
	lda	#0
	sta	CKSUMHH
	lda	#$E8
	sta	ADDRHH
	ldy	#0
	ldx	#3

IEEE_LOOP:

	; For each table entry:
	; 1. write the first control value and read/mask the matching input,
	; 2. write the second control value and read/mask the input again,
	; 3. compare both reads with the expected values,
	; 4. rotate carry into CKSUMHH, where carry=1 means failed.
	lda	IEEE_W,x
	sta	ADDRLL
	lda	IEEE_V0,x
	sta	(ADDRLL),y
	lda	IEEE_R,x
	sta	ADDRLL
	lda	(ADDRLL),y
	and	IEEE_M,x
	sta	TEMPA
	lda	IEEE_W,x
	sta	ADDRLL
	lda	IEEE_V1,x
	sta	(ADDRLL),y
	lda	IEEE_R,x
	sta	ADDRLL
	lda	(ADDRLL),y
	and	IEEE_M,x
	sta	ROMSIZ
	lda	TEMPA
	cmp	IEEE_E0,x
	bne	IEEE_BAD
	lda	ROMSIZ
	cmp	IEEE_E1,x
	bne	IEEE_BAD
	clc
	bcc	IEEE_ROL
IEEE_BAD:
	sec
IEEE_ROL:
	rol	CKSUMHH
	dex
	bpl	IEEE_LOOP

	; ATN is read through PIA #2 CA1, so test it as an edge/latch rather than
	; as a static port bit. Reading PIA #2 port A clears the CA1 latch, then
	; VIA PB2 is pulsed high-low-high. PIA #2 CRA bit 7 should then be set.
	lda	pia2
	lda	#4
	sta	$E840
	sty	$E840
	sta	$E840
	lda	pia2 + 1
	eor	#$80
	asl
	rol	CKSUMHH
	stx	$E840
	lda	CKSUMHH
	jsr	OUTHEXA
	rts

	; Write address low byte, read address low byte, two write values, read
	; mask, and two expected masked reads for: EOI, NRFD, DAV, NDAC.
IEEE_W:
	.byte	$11,$40,$23,$21
IEEE_R:
	.byte	$10,$40,$40,$40
IEEE_V0:
	.byte	52,255,52,52
IEEE_V1:
	.byte	60,253,60,60
IEEE_M:
	.byte	64,64,128,1
IEEE_E0:
	.byte	0,64,0,0
IEEE_E1:
	.byte	64,0,128,1

	; =================================================================================

WARMUP_BOOT:

	; Only perform the warmup once. If the VDU test has to retry, restart the VDU
	; pattern immediately rather than forcing another delay.
	lda	CNTDOWN
	cmp	#$42
	beq	WARMUP_REPEAT

WARMUP_RUN:

	; Detect whether $8400 is independent VRAM or mirrors back into the first 1K.
	; This does not depend on the CRTC; it only checks whether the second 1K of
	; screen RAM is really present.
	lda	#$55
	sta	vdu0
	lda	#$AA
	sta	vdu4
	ldy	#1		; Assume 2K / 80 columns, then disprove it below.
	lda	vdu0
	cmp	#$55
	bne	WARMUP_1K
	lda	vdu4
	cmp	#$AA
	beq	WARMUP_SCREEN
WARMUP_1K:
	dey			; Looks like 1K / 40 columns.

WARMUP_SCREEN:

	ldx	#0
	lda	#spc
WARMUP_CLEAR:
	sta	vdu0,x
	sta	vdu1,x
	sta	vdu2,x
	sta	vdu3,x
	sta	vdu4,x
	sta	vdu5,x
	sta	vdu6,x
	sta	vdu7,x
	inx
	bne	WARMUP_CLEAR

	ldx	#0
WARMUP_DELAY_MSG:
	lda	WARMUP_DELAY_MSG_TXT,x
	sta	vdu0,x
	inx
	cpx	#WARMUP_DELAY_MSG_LEN
	bne	WARMUP_DELAY_MSG

	tya
	beq	WARMUP_COUNT_INIT
	lda	#$32		; '2'.
	sta	vdu0
	lda	#$38		; '8'.
	sta	vdu0+2

WARMUP_COUNT_INIT:

	; Use zero-page for the countdown. Do not use spare-looking video RAM as
	; scratch here; on 1K video systems higher VDU addresses can mirror onto
	; the visible screen and show raw binary values as odd characters.
	lda	#9
	sta	CNTDOWN
WARMUP_COUNT:
	lda	CNTDOWN
	ora	#$30
	sta	vdu0+5

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
	lda	#$42
	sta	CNTDOWN

WARMUP_REPEAT:

	ldx	#0
	jmp	more_vduW

WARMUP_DELAY_MSG_TXT:
	.byte scr("1K4")
WARMUP_DELAY_MSG_LEN	.equ * - WARMUP_DELAY_MSG_TXT

ROMSIG:
	; Plain ASCII signature so the ROM image can be identified in a hex dump.
	.byte	$50,$45,$54,$54,$45,$53,$54,$2B	; "PETTEST+"

		
	; Force binary to be exactly 2k
	.org $E800
