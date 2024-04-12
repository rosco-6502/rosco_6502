# vim: set noet ts=8 sw=8
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
# from srecord package
SREC_CAT := srec_cat

AS_FLAGS := -D__ROSCO__=1 --cpu 65SC02 --feature string_escapes --list-bytes 0 -I ../../firmware/rosco_6502/inc
LD_FLAGS := -v

# normal rosco_6502 RAM start address
START_ADDR	:=	0x0800

TARGET := msg_test
SOURCES := $(wildcard *.asm)
OBJECTS := $(TARGET).o $(filter-out $(TARGET).o,$(addsuffix .o,$(basename $(SOURCES))))

all: $(TARGET).hex $(TARGET).bin

%.o : %.s $(S_INCLUDES) $(MAKEFILE_LIST)
	$(AS) $(AS_FLAGS) -l $(basename $<).lst $< -o $@

$(TARGET).bin: $(OBJECTS) 
	$(LN) $(LD_FLAGS) -C rosco_6502_1bank.cfg -S $(START_ADDR) -Ln $(basename $@).sym -vm -m $(basename $@).map $^ -o $@
	-$(DA) --comments 4 --cpu 65SC02 --start-addr $(START_ADDR) $@ >$(basename $@).dis

$(TARGET).hex: $(TARGET).bin
	$(SREC_CAT) $^ -Binary -offset $(START_ADDR) -o $@ -Intel -address-length=2

clean:
	$(RM) *.o *.lst *.sym *.map *.o *.bin *.dis

.PHONY: all clean
