# PETTESTER Pro / PET One ROM diagnostics

This repository contains the RetroRescues adaptation of the Commodore PET/CBM
PETTESTER ROM, plus a 2 KB boot menu for the RP2350 based One ROM emulator from
piers.rocks (https://onerom.org/).

The menu is designed to use the One ROM host-control plugin and the
[rom-bus-control-protocol](https://github.com/piersfinlayson/rom-bus-control-protocol)
so a PET can choose between several EDIT-socket diagnostic ROM images at boot.

## Release ROMs

The current publish-facing ROM images are:

| File | Purpose |
| --- | --- |
| `petmenu2k.bin` | Slot 0 boot menu. Checks One ROM non-volatile boot preference, allows key/timer menu selection, then boots the selected slot. |
| `pettester.bin` | RetroRescues V6 PETTESTER build. Adds startup beep, simple 40/80 column VRAM detection, CRT warmup delay, and compact IEEE-488 self-test output. |
| `petieee2k.bin` | Standalone IEEE-488/GPIB diagnostic ROM with clearer per-line status display. |
| `petromid2k.bin` | Standalone ROM CRC16 identifier. Computes CRCs for CPU-visible PET ROM ranges and names known matches from common PET ROM sets. |

The matching sources are `petmenu2k.asm`, `pettester.asm`, `petieee2k.asm`, and
`petromid2k.asm`. Most implementation notes are in the ASM files. The IEEE test
translation notes are in `IEEE_TEST_TRANSLATION.md`.

## One ROM layout

`petmenu2k-onerom-hostcontrol.json` is the One ROM Studio / web app config used
to build the full One ROM image with USB and host-control plugins enabled.

Expected flash layout:

| Slot | Image |
| --- | --- |
| 0 | `petmenu2k.bin` |
| 1 | normal PET EDIT ROM, not included here |
| 2 | `pettester.bin` |
| 3 | `petieee2k.bin` |
| 4 | `petromid2k.bin` |

The JSON currently references `c:/pet/*.bin`. Put the ROM files there, or edit
the paths before compiling the One ROM image.

At boot, holding a key forces the PETMENU path ignoring the boot marker.
With no key held, the menu checks the One ROM non-volatile boot marker and if set will boot the slot 1 ROM,
If not set it will continue to the menu. Only the Edit rom will currently set the boot marker to slot 1
Any other option will wipe the boot marker and always boot to menu.
In the menu, any key (excluding RETURN) cycles the selected test,
RETURN boots immediately, and the timeout boots the current selection.
Default option is full Pettester rom and when initially compiled no boot marker will exist,
Meaning this will boot pettester on a machine with no keyboard after a 30s delay.

## Known limitations and future work

- If the One ROM boot marker is set to boot the normal EDIT ROM and the PET then
  fails badly enough that keyboard input cannot be read, the menu may not be
  reachable by holding a key. Recovery is still possible by re-imaging One ROM or
  using the One ROM jumpers to force a diagnostic slot, but there may be a nicer
  future rescue path.

- `petmenu2k.bin` currently runs the PETTESTER-derived VRAM size check before
  showing the menu. If PETTESTER is then launched from the menu, its initial VRAM
  check can report 1K on a 2K machine. This does not affect the main tests, but
  should be cleaned up.

## Building

Install [`cbmasm`](https://github.com/asig/cbmasm), then either put it on `PATH`
or set `CBMASM` to the executable path.

PowerShell:

```powershell
.\build-petmenu2k.ps1
.\build-pettester.ps1
.\build-split-tests.ps1
```

Make:

```sh
make
```

The PowerShell scripts can optionally copy built ROMs into a VICE PET ROM
directory if `PETTESTER_VICE_PET_DIR` is set.

## Archive

Development byproducts, VICE launch helpers, duplicate/test binaries, older
intermediate notes, and the original PETTESTE2K reference files are under
`archive/` so the root stays focused on the current release.

## Credits and license

PETTESTER is based on PETTESTE2K by David E. Roberts, with later work by Andreas
Signer and RetroRescues updates in this repository.

Licensed under GPLv3. See `LICENSE`.
