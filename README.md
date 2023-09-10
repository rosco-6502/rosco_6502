# Really Old-School Computer - 6502
## A 65C02 Single-Board Computer

This repository holds design files, firmware and software for the Really Old-School Computer 
(6502) single-board computer, AKA the rosco_6502. This is a fully-featured, programmable,
extensible and capable 8-bit retro computer that is completely open source  and will be
available in kit form (coming soon).

The rosco_6502 is the "little brother" of the popular [rosco_m68k](https://github.com/rosco-m68k)
m68k computer. It is made by the same people, and shares the ethos of being powerful, extensible
and above all, fun.

This project contains all the design files and source code for the project. 

* All Software released under the MIT licence. See LICENSE for details.
* All Hardware released under the CERN Open Hardware licence.See LICENCE.hardware.txt.
* All Documentation released under Creative Commons Attribution. See https://creativecommons.org/licenses/by/2.0/uk/

## Specifications

### Hardware

The hardware specifications for the rosco_6502 are:

* WDC 65C02 at up-to 14MHz (In theory, 10MHz testing target currently).
* XR68C681P provides two UARTs, Timers and SD Card / SPI / GPIO
* 528KB RAM 
    * 16KB low RAM ($0000 - $3FFF)
    * 16 x 32KB RAM banks ($4000 - $BFFF) 
    * 8KB IO space ($C000 - $DFFF)
    * 8KB or 32KB (banked) ROM $E000 - $FFFF (8KB)
* High-speed decode and glue logic handled by Atmel F22V10C PLDs.
* Comprehensive expansion and IO connectors allow the system to be easily expanded!

### Software

The first prototype boards are back from the fab, and work is underway on 
initial bringup and basic feature tests. You can see the code that's being
used for this in the [firstboot](code/firmware/firstboot) directory.

Along the way there have been a few modifications and improvements made to 
the board and schematic which will feed into the next batch of prototypes.
You can see the electrical design changes in the [kicad](design/kicad) 
directory, and the programmable logic changes in [pld](code/pld).

