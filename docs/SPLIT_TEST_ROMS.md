# Split PET Test ROMs

This folder now has three standalone 2K EDIT-ROM diagnostics for use from the One ROM boot menu:

- `petieee2k.bin`
- `petromid2k.bin`
- `diagclipedit2k.bin`

Build them with:

```powershell
.\scripts\build-split-tests.bat
```

The build writes the binaries into `roms/`. If `PETTESTER_VICE_PET_DIR` is set, it also copies them into that VICE PET ROM directory.

## IEEE-488 Test

Source: `src/petieee2k.asm`

This is the IEEE/GPIB test split out from PETTESTER and expanded into a clearer screen display. It loops continuously and shows:

- `DIO1` to `DIO8`
- `NDAC`
- `DAV`
- `NRFD`
- `EOI`
- `ATN`

`OK` means the PET can drive/read the tested path. `BAD` means the line failed one of the expected states.

The data test writes PIA #2 port B and reads PIA #2 port A. The control tests use the same PIA/VIA paths as the original Commodore BASIC listing. VIA DDRB is set to `$06` so only PB1/PB2 are driven; PB0/PB6/PB7 stay as inputs.

## ROM CRC16 ID Test

Source: `src/petromid2k.asm`

This computes CRC-16/CCITT over CPU-visible ROM ranges and compares them with known values generated from:

```text
https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/pet/
```

The original downloaded corpus used to generate the table is not included in the publish-facing repository. The development notes referred to it under:

```text
pettester/rom-corpus/zimmers-pet/
```

Inventory files:

- `manifest-rom-candidates.txt`: downloaded `.bin` and `.zip` URLs
- `rom-inventory.csv`: all binary files and extracted zip contents with size, sum16, CRC16, CRC32, SHA1
- `romid-candidates.csv`: CPU-visible standard-slot candidates used for the first table

The diagnostic ROM itself occupies `$E000`, so it cannot verify the machine's original EDIT ROM in place. Current scan ranges are:

- `B4`: `$B000-$BFFF`
- `B2`: `$B000-$B7FF`
- `C4`: `$C000-$CFFF`
- `C0`: `$C000-$C7FF`
- `C8`: `$C800-$CFFF`
- `D4`: `$D000-$DFFF`
- `D0`: `$D000-$D7FF`
- `D8`: `$D800-$DFFF`
- `F4`: `$F000-$FFFF`
- `F0`: `$F000-$F7FF`
- `F8`: `$F800-$FFFF`

The first table contains 33 unique CPU-visible 2K/4K ROM contents from the corpus, excluding EDIT ROMs. CRC-16/CCITT was chosen because the old PETTESTER additive 16-bit checksum had collisions in the downloaded ROM set, while CRC-16/CCITT had none in this corpus.

## Diagnostic Clip Wrapper

Source: `src/diagclipedit2k.asm`

This is an experimental proof-of-life wrapper for the Commodore Diagnostic Clip
ROM. It is not a clean port yet.

The original diagnostic clip starts at `$F000`, copies its main diagnostic body
to RAM at `$0200`, asks the user to remove the CPU clip, then runs the RAM copy.
This wrapper starts from the EDIT ROM entry point at `$E000`, copies the
extracted RAM body to `$0200`, and jumps to it directly.

Payload:

- `src/diagclip_body_u2u3.bin`
- extracted from `ROM_Images.zip`
- source ROMs: `U-2 DIA` + `U-3 DIA`
- copied body length: `$07AE` bytes

Limitations of this first wrapper:

- It does not initialise the CRTC because the 2K image is nearly full.
- It is intended to be launched from the One ROM menu after the menu has already
  set up the display.
- Adapter-dependent tests are expected to fail unless the diagnostic keyboard,
  user-port, and cassette loopback plugs are fitted.
- It depends on low zero page being good enough for the copy loop; the menu's
  early RAM checks should already have proved that.
