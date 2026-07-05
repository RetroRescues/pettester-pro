# Commodore Diagnostic Clip ROM Porting Notes

These notes cover the Rob Clarke disassembly linked from André Fachat's archived
PET Diagnostic Clip page. The immediate goal is to understand whether the ROM can
be turned into a One ROM menu option that runs from the PET EDIT ROM socket.

Development reference files used while porting:

- `new/andre-diag/index.html`
- `new/andre-diag/Diag_Clip_Disassembly.txt`
- `new/andre-diag/901447-30.dis`
- `new/andre-diag/diagnostics.txt`
- `new/andre-diag/ROM_Images.zip`
- `new/andre-diag/ROM_Images/U-2 DIA`
- `new/andre-diag/ROM_Images/U-3 DIA`

Proof-of-life wrapper files now promoted into the repo:

- `src/diagclipedit2k.asm`
- `src/diagclip_body_u2u3.bin`
- `roms/diagclipedit2k.bin`

Local VICE scratch files remain in `new/` and are not required for One ROM use:

- `new/diagclipedit-80.vrs`

## What The Original Hardware Does

The Commodore diagnostic clip is not only a ROM. It normally includes:

- a CPU clip
- diagnostic ROM hardware
- user-port loopback wiring
- keyboard connector loopback wiring
- cassette/tape connector loopback wiring

The CPU clip is there to make the PET boot from the diagnostic ROM before the
normal onboard ROM path has fully taken over.

There are two known boot styles:

- CRTC/later machines: use `/NOROM` at the CPU socket to disable onboard ROMs,
  letting the diagnostic ROM appear in the `$Fxxx` range.
- Older machines: force address lines so the diagnostic ROM is seen in a
  normally unused `$9xxx`-type range while the machine is starting.

The forum comment about using a larger EPROM on an 8032 fits the disassembly:
the diagnostic code initially needs to be visible at `$F000`, then after it has
copied itself to RAM the normal `$F000` ROM must be visible again.

## Top-Level ROM Flow

The Rob Clarke ROM is labelled as an 80-column diagnostic:

```text
80 COL DIAGNOSTIC V1.1
```

It is a two-stage program.

### Stage 1: ROM-Resident Loader At `$F000`

Entry starts at `$F000`:

```asm
$F000  SEI
$F001  LDX #$FF
$F003  TXS
$F004  CLD
```

It then:

1. Initializes the CRTC from the table at `$F260`.
2. Configures VIA PCR at `$E84C`.
3. Clears video RAM `$8000-$87FF`.
4. Prints the diagnostic title.
5. Tests video RAM enough to display failures.
6. Tests zero page.
7. Tests stack page.
8. Copies the second-stage diagnostic body from ROM to RAM.
9. Verifies the copy.
10. Prints `REMOVE CLIP`.
11. Jumps to `$0200`.

The copy source is `$F272`; the destination is `$0200`.

The copy length is effectively `$07B8` bytes:

```text
source:      $F272...
destination: $0200-$09B7
```

That is why the later disassembly is shown at `$0200` through `$09B8`: it is the
RAM-resident test program after the loader has copied it.

The Raymond Jett `ROM_Images.zip` version is slightly offset from Rob Clarke's
disassembly:

```text
combined ROM:  U-2 DIA + U-3 DIA
copy source:   $F266
copy dest:     $0200
copy length:   $07AE bytes
entry after copy: $0200
```

The first wrapper uses this `U-2 DIA`/`U-3 DIA` body because the zip downloaded
as clean raw binary. The archived Rob Clarke `40_80_80_col_diag.bin` link
currently comes back wrapped in Wayback HTML instead of raw binary.

### Stage 2: RAM-Resident Diagnostic At `$0200`

The second stage begins at `$0200`.

The first important behaviour is the "clip removed" check:

```asm
$0234  LDA #$00
$0236  CMP $FFFC
$0239  BNE continue
$023B  LDA #$F0
$023D  CMP $FFFD
$0240  BEQ $0200
```

It loops while the reset vector still reads `$F000`.

That means the original diagnostic expects this sequence:

1. Boot with diagnostic ROM visible at `$F000`.
2. Copy diagnostic body into RAM.
3. Tell user to remove the clip, or switch EPROM banking.
4. Wait until the normal `$F000` ROM is visible again.
5. Continue the diagnostics from RAM.

This explains the forum advice: on an 8032, a large EPROM plus an address-line
switch can emulate "remove the clip" without physically removing hardware.

## Tests Identified In The Disassembly

The string table at `$0918-$09B8` gives a useful map of the later tests:

```text
BAD OK VIDEO 50HZ IRQ VERT HORZ ROM
K-RAM -ADR KEYBRD TMR1 NO IRQ WRONG IRQ TMR2 TEST:
CASS1 CASS2 IEEE DIO IEEE CTRL ATN DAV NRFD NDAC EOI SRQ
CHKSM RFRSH UD CYCLE 000000
```

From the code and strings, the ROM appears to perform these diagnostics.

### Video And Display

- CRTC initialization.
- Video RAM write/read checks over `$8000-$87FF`.
- 50 Hz / vertical / horizontal timing-style checks using VIA/CRTC-visible
  timing signals.

Our PETTESTER already does video RAM tests and CRTC init, but it does not try to
classify `50HZ`, `VERT`, or `HORZ` timing.

### Zero Page, Stack, And Main RAM

Stage 1 tests zero page and stack before copying the main body.

Stage 2 performs wider RAM tests:

- video RAM test at `$8000-$87FF`
- RAM sizing / address probing
- patterned tests from roughly `$0A00` upward
- refresh-related test labelled `RFRSH`

Our PETTESTER has good visible RAM tests and a stronger-looking full DRAM test,
but it does not have a separately named refresh test.

### ROM Checksum

The second stage performs checksum-style ROM tests and prints `CHKSM`.

This is not the same as the new `petromid2k` test:

- Diagnostic clip: original built-in checksum expectations.
- `petromid2k`: CRC-16/CCITT matching against a known ROM corpus.

For an EDIT-ROM port, the diagnostic clip checksum logic would need review
because `$E000` contains the diagnostic/menu ROM, not the machine's original
EDIT ROM.

### Keyboard Loopback

The ROM has a `KEYBRD` test and the diagnostic connector notes describe a
keyboard plug that links selected rows/columns.

This is stronger than our PETTESTER keyboard display because it can
automatically pass/fail the keyboard scan circuitry when the loopback plug is
installed.

### VIA Timers And Interrupts

The ROM has `TMR1`, `TMR2`, `NO IRQ`, and `WRONG IRQ` messages. It enables
interrupts and checks that the expected interrupt source fires.

Our current tests do not verify VIA timer interrupt operation.

### Cassette Ports

The ROM has `CASS1` and `CASS2` tests. These appear to exercise tape-related
VIA lines, and they depend on the diagnostic tape connector wiring.

Our current tests do not check cassette motor/sense/read/write paths.

### IEEE-488

The ROM has:

```text
IEEE DIO
IEEE CTRL
ATN
DAV
NRFD
NDAC
EOI
SRQ
```

Our standalone IEEE ROM tests:

- DIO1-DIO8
- NDAC
- DAV
- NRFD
- EOI
- ATN

The diagnostic clip adds at least `SRQ`, and likely validates more of the rear
connector path if the loopback plug is fitted.

## Porting Implications For One ROM / EDIT ROM Use

The boot hardware problem is avoidable for us.

Our One ROM menu already launches a 2K EDIT ROM image at `$E000`. That means we
do not need to emulate the original CPU clip just to run diagnostic code. We can
instead make an EDIT-ROM wrapper that:

1. runs from `$E000`
2. initializes the CRTC enough to display output
3. copies the diagnostic body into RAM at `$0200`
4. skips the `$FFFC/$FFFD == $F000` "REMOVE CLIP" wait
5. jumps to `$0200`

That should preserve the original RAM-resident diagnostic model while fitting
the One ROM menu workflow.

Important constraints:

- The copied diagnostic body occupies `$0200-$09B7`.
- It uses zero page and stack heavily.
- It expects normal PET I/O at `$E800-$E8FF`.
- Some tests need external loopback connectors to pass.
- The ROM checksum test will need adaptation or disabling because the original
  EDIT ROM is replaced by the diagnostic image.
- Tests involving interrupts assume normal `$FFFE/$FFFF` IRQ vector behaviour
  after the normal `$F000` ROM is visible.

## Recommended Porting Strategy

Do not try to port everything at once.

### Step 1: Symbolize The Disassembly

Create a labelled source from the RAM-resident body:

- loader
- display routines
- delay routines
- IRQ routine
- CRTC/timing tests
- RAM tests
- checksum test
- keyboard test
- timer tests
- cassette tests
- IEEE tests

### Step 2: Make A Minimal EDIT-ROM Wrapper

Build a new 2K image that only proves:

```text
$E000 wrapper -> copy body to $0200 -> jump $0200
```

For the first proof, bypass the `REMOVE CLIP` vector wait.

### Step 3: Disable Tests That Need Hardware Plugs

Initially skip:

- keyboard loopback
- cassette loopback
- IEEE loopback/SRQ

Then add them back one by one once we know what each diagnostic plug must wire.

### Step 4: Merge Useful Tests Into Our Existing Split ROMs

Likely useful extra tests:

- SRQ into `petieee2k`
- VIA timer/IRQ into a new I/O diagnostic
- keyboard loopback into a new adapter-aware keyboard diagnostic
- cassette tests into a new cassette diagnostic

## First Conclusion

The diagnostic clip ROM looks portable, but not as a direct drop-in replacement.
The best route is to port its second-stage RAM diagnostic model and replace the
original CPU-clip boot handshake with an EDIT-ROM wrapper suitable for One ROM.

The highest-value additions over our current suite are:

1. VIA timer / IRQ testing.
2. Cassette 1 / Cassette 2 testing.
3. Keyboard loopback pass/fail testing.
4. SRQ and external-loopback-aware IEEE testing.
5. Refresh/timing tests if we can confirm exactly what they measure.

## Proof-Of-Life Wrapper Status

`src/diagclipedit2k.asm` now builds a 2K EDIT-ROM image:

```text
roms/diagclipedit2k.bin
```

The wrapper is deliberately minimal:

```text
$E000 loader
  copies src/diagclip_body_u2u3.bin to $0200-$09AD
  jumps to $0200
```

Current layout:

```text
loader:       $E000-$E034
payload:      $E035-$E7E2
zero tail:    29 bytes
```

This leaves no comfortable room for CRTC setup in the 2K image. It should be
launched from the One ROM menu after the menu has initialized the display.

For direct emulator testing, a scratch VICE romset was used:

```text
new/diagclipedit-80.vrs
```

Direct VICE launch may show a blank or odd display if the CRTC has not already
been initialized. The expected hardware test failures without loopback adapters
are acceptable at this stage.
