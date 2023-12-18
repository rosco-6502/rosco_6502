VASM=vasm6502_oldstyle 
ASFLAGS=-c02 -Fbin 
LDFLAGS=

all: rom.bin

boot64k.bin: boot.asm wozmon.asm
	$(VASM) $(ASFLAGS) -L $<.lst -o $@ $<

rom.bin: boot64k.bin
	tail -c 8192 $< > $@

burn: rom.bin
	minipro -p AT28C64B -s -w $<

clean:
	$(RM) -f boot64k.bin rom.bin *.o *.lst

.PHONY: all burn clean

