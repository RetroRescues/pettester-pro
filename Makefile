AS ?= cbmasm

ROMS = roms/petmenu2k.bin roms/pettester.bin roms/petieee2k.bin roms/petromid2k.bin

.PHONY: all clean

all: $(ROMS)

roms/%.bin: src/%.asm | roms
	$(AS) -output plain $< $@

roms:
	mkdir -p roms

clean:
	rm -f $(ROMS)
