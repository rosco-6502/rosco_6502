#------------------------------------------------------------
#                            ___ ___ ___ ___
#  ___ ___ ___ ___ ___      |  _| __|   |__ |
# |  _| . |_ -|  _| . |     | . |__ | | | __|
# |_| |___|___|___|___|_____|___|___|___|___|
#                     |_____|   BIOS Firmware
#------------------------------------------------------------
# Copyright (c)2022-2024 Ross Bamford and contributors
# See top-level LICENSE.md for licence information.
#
# Makefile - rosco_6502 firmware Makefile
#------------------------------------------------------------

# Makefile "best practices" from https://tech.davis-hansson.com/p/make/ (but not forcing gmake)
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# using cc65 tools (assumed in path, add path if needed)
AS := ca65
LN := ld65
DA := da65

AS_FLAGS := -g -D__ROSCO__=1 --cpu 65SC02 --feature string_escapes --list-bytes 0 -I inc
LD_FLAGS := -v

all: boot8k.bin boot32k.bin

%.o : %.s $(S_INCLUDES) $(MAKEFILE_LIST)
	$(AS) $(AS_FLAGS) -l $(basename $<).lst $< -o $@

boot8k.bin: bank0.o 
	$(LN) $(LD_FLAGS) -C rosco_6502_8K.cfg -Ln $(basename $@).sym -vm -m $(basename $@).map $^ -o $@
	-$(DA) --comments 4 --cpu 65SC02 --start-addr 0xE000 $@ >$(basename $@).dis

boot32k.bin: bank0.o bank1.o bank2.o bank3.o
	$(LN) $(LD_FLAGS) -C rosco_6502_32K.cfg -Ln $(basename $@).sym -vm -m $(basename $@).map $^ -o $(basename $@)
	-$(DA) --comments 4 --cpu 65SC02 --start-addr 0xE000 $(basename $@).0.bin >$(basename $@).0.dis
	-$(DA) --comments 4 --cpu 65SC02 --start-addr 0xE000 $(basename $@).1.bin >$(basename $@).1.dis
	-$(DA) --comments 4 --cpu 65SC02 --start-addr 0xE000 $(basename $@).2.bin >$(basename $@).2.dis
	-$(DA) --comments 4 --cpu 65SC02 --start-addr 0xE000 $(basename $@).3.bin >$(basename $@).3.dis
	cat $(basename $@).0.bin $(basename $@).1.bin $(basename $@).2.bin $(basename $@).3.bin >$@

burn8: boot8k.bin
	minipro -p AT28C64B -s -w $<

burn32: boot32k.bin
	minipro -p AT28C256 -s -w $<

clean:
	$(RM) *.bin *.o *.lst *.sym *.map *.dis

.PHONY: all burn8 burn32 clean rom8K rom32K

