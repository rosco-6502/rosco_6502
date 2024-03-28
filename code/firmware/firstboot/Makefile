VASM=vasm6502_oldstyle
VLINK=vlink
ASFLAGS=-quiet -wdc02 -opt-branch -Fvobj
LDFLAGS=-brawbin1
DA65=da65

all: boot8k.bin boot32k.bin

%.o : %.asm
	$(VASM) $(ASFLAGS) -L $<.lst -o $@ $<

boot8k.bin: bank0.o 
	$(VLINK) $(LDFLAGS) -T link8.ld -o $@ -M$@.sym $^
	-$(DA65) --comments 4 --cpu 65c02 --start-addr 0xE000 $@ >$(basename $@).dis

boot32k.bin: bank0.o bank1.o bank2.o bank3.o
	$(VLINK) $(LDFLAGS) -T link32.ld -o $@ -M$@.sym $^

burn8: boot8k.bin
	minipro -p AT28C64B -s -w $<

burn32: boot32k.bin
	minipro -p AT28C256 -s -w $<

clean:
	$(RM) -f *.bin *.o *.lst *.sym *.dis

.PHONY: all burn clean

