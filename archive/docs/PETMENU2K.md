# PETMENU2K

`petmenu2k.asm` is a separate 2 KB PET EDIT ROM menu based on the RetroRescues V6 PETTESTER startup path. It does not modify the existing PETTESTER files.

Expected One ROM flash layout:

- Slot 0: `petmenu2k.bin`
- Slot 1: normal PET EDIT ROM
- Slot 2: PETTESTER V6 ROM
- Slot 3: `petieee2k.bin`
- Slot 4: `petromid2k.bin`

The ROM runs the early V6-style video RAM detection/check and page 0/1 RAM check before showing the menu. This avoids presenting a menu when the display RAM or the RAM needed for zero page/stack use is already failing.

V1.01 keeps the One ROM NV boot preference and fixes menu positioning on 80-column machines. Startup initializes the keyboard, checks for a held key, reads the saved NV marker when no key is held, and can boot the normal EDIT ROM before the warmup timer. Holding a key forces the normal warmup/tests/menu path.

Menu controls:

- Any non-RETURN key selects the next ROM.
- RETURN boots the selected ROM immediately.
- If no key is pressed, the menu counts down from 30 and boots the selected ROM.
- The warmup timer now starts at 5.

The NV response back-channel uses `E7F0-E7FF`, which is kept as padding in the built 2 KB ROM.

`petromid2k.bin` reports CPU-visible ROM ranges only: `B000`, `C000`, `D000`, and `F000`. It cannot verify the original `E000` EDIT ROM because this diagnostic ROM is running in that socket, and it cannot verify the character ROM because that ROM is not CPU-readable like the main firmware ROMs.

Build:

```powershell
.\build-petmenu2k.ps1
```

The script writes `petmenu2k.bin` in this directory and also copies it to `PET\petmenu2k.bin` for VICE testing.
