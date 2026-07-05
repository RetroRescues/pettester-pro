AS ?= cbmasm

ROMS = roms/petmenu2k.bin roms/pettester.bin roms/petieee2k.bin roms/petromid2k.bin roms/diagclipedit2k.bin

.PHONY: all clean

all: $(ROMS)

roms/%.bin: src/%.asm | roms
	$(AS) -output plain $< $@

roms/diagclipedit2k.bin: src/diagclip_body_u2u3.bin

roms:
	mkdir -p roms

clean:
	rm -f $(ROMS)
