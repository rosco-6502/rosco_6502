/**
 * VLINK script for rosco_6502 ROM (8KB single-bank version)
 *
 * Copyright (c)2023 Ross Bamford & Contributors
 */

SECTIONS {
    .bank0 0xe000 : AT(0) {
        *(.bank0.rtable)
        *(.bank0.irq)
        *(.bank0.text*)
        *(.bank0.rodata*)
        . = 0xfffa;
        *(.bank0.vectors)
    }
};

