VASM=vasm6502_oldstyle
VLINK=vlink
ASFLAGS=-c02 -Fvobj -quiet 
LDFLAGS=-brawbin1

all: boot8k.bin boot32k.bin

%.o : %.asm
	$(VASM) $(ASFLAGS) -L $<.lst -o $@ $<

boot8k.bin: bank0.o 
	$(VLINK) $(LDFLAGS) -T link8.ld -o $@ -M$@.sym $^

boot32k.bin: bank0.o bank1.o bank2.o bank3.o
	$(VLINK) $(LDFLAGS) -T link32.ld -o $@ -M$@.sym $^

burn8: boot8k.bin
	minipro -p AT28C64B -s -w $<

burn32: boot32k.bin
	minipro -p AT28C256 -s -w $<

clean:
	$(RM) -f *bin *.o *.lst

.PHONY: all burn clean

