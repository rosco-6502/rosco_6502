/**
 * VLINK script for rosco_6502 ROM (8KB single-bank version)
 *
 * Copyright (c)2023 Ross Bamford & Contributors
 */

SECTIONS {
    .bank0 0xe000 : AT(0) {
        *(.bank0.rtable)
        *(.bank0.text*)
        *(.bank0.rodata*)
        *(.bank0.routines*)
        . = 0xf800;
        *(.bank0.bank*)
        . = 0xf900;
        *(.bank0.irq)
        . = 0xfa00;
        *(.bank0.wozmon)
        . = 0xfffa;
        *(.bank0.vectors)
    }
};

