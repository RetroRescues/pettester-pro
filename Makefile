AS ?= cbmasm

ROMS = petmenu2k.bin pettester.bin petieee2k.bin petromid2k.bin

.PHONY: all clean

all: $(ROMS)

%.bin: %.asm
	$(AS) -output plain $< $@

clean:
	rm -f $(ROMS)
