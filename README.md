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
* 8KB or 32KB (banked) ROM $E000 - $FFFF
* High-speed decode and glue logic handled by Atmel F22V10C PLDs.
* Comprehensive expansion and IO connectors allow the system to be easily expanded!

You can see the electrical designs in the [kicad](design/kicad). Programmable logic lives in [pld](code/pld).

### Software

The board design is proven and working well, and work is underway on 
initial bringup code and user ROM. Currently, this means the board can
boot, initialize hardware, and drop into [WozMon](http://jefftranter.blogspot.com/2012/05/woz-mon.html)
allowing programs to be keyed in (slowly!) or pasted-to-terminal 
for running on the board.

You can see the code that's being used for this in the [firstboot](code/firmware/firstboot) 
directory. This is also where the banked ROM layout is being developed.


