# Cheesy FAT32 file test

Prepare an SD card with "/Some Folder/Deep Folder/data512k.bin" and some files on root directory.

It will show root dir, then load file above (up to 512KB, about ~3 seconds at 10MHz for me).

NOTE: This includes files from ../sd_test for the moment (not sure how to make vasm library)
