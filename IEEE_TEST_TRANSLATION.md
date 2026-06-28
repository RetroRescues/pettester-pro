# PETTESTER IEEE-488 Test Notes

This note explains how the IEEE-488/GPIB BASIC test maps onto the compact
`IEEETEST` routine in `pettester.asm`.

The ROM displays the result as four hex digits:

```text
DDCC
```

`DD` is the 8-bit data-line fault mask. `CC` is the control-line fault mask:

```text
$10 NDAC
$08 DAV
$04 NRFD
$02 EOI
$01 ATN
```

A zero result, `0000`, means the ROM test did not detect a fault.

## PET IEEE Port Addresses

The PET IEEE port uses separate output and input paths. The ROM test writes one
side of the circuit and reads the other side back through the PIA/VIA and the
MC3446 bus transceivers.

| BASIC address | Hex | Use in ROM |
| --- | --- | --- |
| `59424` | `$E820` | PIA port A, data-line readback |
| `59426` | `$E822` | PIA port B, data-line output |
| `59408` | `$E810` | PIA port A, EOI readback |
| `59409` | `$E811` | PIA control A, EOI output via CA2 |
| `59425` | `$E821` | PIA control A, NDAC output via CA2 / ATN CA1 status |
| `59427` | `$E823` | PIA control B, DAV output via CB2 |
| `59456` | `$E840` | VIA port B, DAV/NRFD/NDAC readback and NRFD/ATN output |
| `59458` | `$E842` | VIA DDRB |

In the assembly source, `pia2` is `$E820`. The code uses absolute `$E840`
addresses for the VIA.

## Data-Line Test

The BASIC data test is:

```basic
POKE 59426,0
C=PEEK(59424)
C1=255 AND C
POKE 59426,255
C2=NOT PEEK(59424) AND 255
BAL=(ABS(NOT C1 AND NOT C2))-1
```

The intent is:

1. Drive all DIO outputs low.
2. Read the DIO inputs back.
3. Drive all DIO outputs high.
4. Read the DIO inputs back again, inverted.
5. Combine the two reads so any bit that failed either state is reported.

The ROM version is the same idea, but shorter:

```asm
lda #0
sta pia2 + 2      ; $E822 / 59426: drive DIO outputs low
lda pia2          ; $E820 / 59424: read DIO inputs
sta TEMPA

lda #$FF
sta pia2 + 2      ; drive DIO outputs high
lda pia2          ; read DIO inputs again
eor #$FF          ; invert the high-state read
ora TEMPA         ; combine both fault masks
jsr OUTHEXA       ; display DD
```

If a bit reads wrong when driven low, it appears in `TEMPA`. If it reads wrong
when driven high, it appears after the `EOR #$FF`. The `ORA` combines both cases
into the displayed `DD` byte.

## Control-Line Test

The BASIC listing tests each control line separately. For example, NDAC does:

```basic
POKE 59425,60
C=PEEK(59456)
POKE 59425,52
C1=PEEK(59456)
MSK=1
```

That means:

1. Write one state to the output side.
2. Read the matching input side.
3. Write the opposite state.
4. Read again.
5. Mask the bit belonging to that signal.
6. Compare both reads with the expected values.

The ROM does the same for EOI, NRFD, DAV, and NDAC using tables:

```asm
IEEE_W:   .byte $11,$40,$23,$21
IEEE_R:   .byte $10,$40,$40,$40
IEEE_V0:  .byte 52,255,52,52
IEEE_V1:  .byte 60,253,60,60
IEEE_M:   .byte 64,64,128,1
IEEE_E0:  .byte 0,64,0,0
IEEE_E1:  .byte 64,0,128,1
```

The table order is:

```text
EOI, NRFD, DAV, NDAC
```

Each entry supplies:

| Table | Meaning |
| --- | --- |
| `IEEE_W` | Low byte of the address to write |
| `IEEE_R` | Low byte of the address to read |
| `IEEE_V0` | First value to write |
| `IEEE_V1` | Second value to write |
| `IEEE_M` | Readback mask |
| `IEEE_E0` | Expected masked result after first write |
| `IEEE_E1` | Expected masked result after second write |

The high address byte is always `$E8`, so the assembly stores `$E8` in
`ADDRHH` once and only changes `ADDRLL` from the table.

The table loop is:

```asm
lda IEEE_W,x
sta ADDRLL
lda IEEE_V0,x
sta (ADDRLL),y

lda IEEE_R,x
sta ADDRLL
lda (ADDRLL),y
and IEEE_M,x
sta TEMPA

lda IEEE_W,x
sta ADDRLL
lda IEEE_V1,x
sta (ADDRLL),y

lda IEEE_R,x
sta ADDRLL
lda (ADDRLL),y
and IEEE_M,x
sta ROMSIZ

lda TEMPA
cmp IEEE_E0,x
bne IEEE_BAD
lda ROMSIZ
cmp IEEE_E1,x
bne IEEE_BAD
clc               ; carry clear means pass
bcc IEEE_ROL
IEEE_BAD:
sec               ; carry set means fail
IEEE_ROL:
rol CKSUMHH       ; shift this result into CC
```

Because the loop runs backwards from index 3 to 0, the four table-driven results
end up in this order before ATN is added:

```text
NDAC, DAV, NRFD, EOI
```

After ATN is appended, the final `CC` mask is:

```text
$10 NDAC
$08 DAV
$04 NRFD
$02 EOI
$01 ATN
```

## VIA DDRB Setup

Before testing the VIA-connected control lines, the ROM sets:

```asm
lda #$06
sta $E842
```

That writes VIA DDRB. Only PB1 and PB2 are outputs:

```text
PB1 = NRFD output
PB2 = ATN output
```

PB0, PB6, and PB7 must remain inputs:

```text
PB0 = NDAC readback
PB6 = NRFD readback
PB7 = DAV readback
```

This matters because an earlier draft used `$0F`, which made PB0 an output and
could falsely report NDAC as bad on good hardware.

## ATN Difference

The old BASIC listing treats ATN like a mostly static readback test:

```basic
POKE 59456,251
C=PEEK(59425)
POKE 59456,255
C1=PEEK(59425)
```

The ROM does not use that method. ATN is read through PIA CA1, which is an edge
input with a latch. The ROM therefore tests for a transition:

```asm
lda pia2          ; read $E820 to clear the PIA CA1 latch
lda #4
sta $E840         ; VIA PB2 high
sty $E840         ; VIA PB2 low, Y is zero
sta $E840         ; VIA PB2 high again
lda pia2 + 1      ; read PIA CRA at $E821
eor #$80
asl
rol CKSUMHH       ; append ATN fault bit as bit 0 of CC
stx $E840         ; restore VIA port B latch, X is $FF after the loop
```

If the ATN transition is detected, PIA CRA bit 7 should be set. The `EOR #$80`
and `ASL` turn that into the carry flag used by `ROL CKSUMHH`:

```text
CA1 bit set     -> pass -> carry clear
CA1 bit not set -> fail -> carry set
```

This is why ATN is handled separately instead of being another table entry.

## Why The ROM Output Is So Short

The BASIC version prints friendly text such as:

```text
NDAC IS BAD
ATN IS BAD
THE BAD GPIB DATA BITS ARE:
```

The ROM has almost no free space, so it prints just four hex digits. The compact
mask keeps the test useful while fitting into the 2K editor ROM.

Examples:

```text
0000 = no IEEE fault detected
0010 = NDAC fault
0001 = ATN fault
0011 = NDAC and ATN faults
8000 = DIO bit 7 fault
```

## Reading The Four Hex Digits

Read the result as two separate bytes:

```text
DDCC
```

`DD` is the data bus result. `CC` is the control-line result.

For example:

```text
8000
```

means:

```text
DD = $80
CC = $00
```

`$80` is binary `10000000`, so only bit 7 of the data mask is set. The PET
data lines are mapped directly to the PIA data bits:

| DD value | Binary bit | IEEE data line |
| --- | --- | --- |
| `$01` | bit 0 | DIO1 |
| `$02` | bit 1 | DIO2 |
| `$04` | bit 2 | DIO3 |
| `$08` | bit 3 | DIO4 |
| `$10` | bit 4 | DIO5 |
| `$20` | bit 5 | DIO6 |
| `$40` | bit 6 | DIO7 |
| `$80` | bit 7 | DIO8 |

So a result shown as:

```text
80XX
```

means the data-line byte has bit 7 set, i.e. DIO8 failed the data read/write
test. The `XX` part is not part of that data-bit result; it is the separate
control-line byte.

Multiple bad data bits add together. For example:

```text
C000 = $C0 data fault = $80 + $40 = DIO8 and DIO7
1800 = $18 data fault = $10 + $08 = DIO5 and DIO4
```

The control byte works the same way, but with the control-line mask:

| CC value | Control line |
| --- | --- |
| `$10` | NDAC |
| `$08` | DAV |
| `$04` | NRFD |
| `$02` | EOI |
| `$01` | ATN |

So:

```text
8012
```

means:

```text
DD = $80 = DIO8 fault
CC = $12 = $10 + $02 = NDAC and EOI faults
```

## Source Locations

Current assembly implementation:

```text
pettester.asm: IEEETEST
```

The routine is called after the keyboard matrix display, so the IEEE result is
shown on the same diagnostics screen before the ROM moves on to the DRAM test.
