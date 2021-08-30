; Common file containing extern definitions and constants

; Top of the stack
extern stack_top

; The amount of sectors reserved by stage 1
extern stage1_sectors

; The start address of BSS
extern bss_start

; The size of BSS in 4-byte words
extern bss_size_words

; Base address of the MBR partition array
extern MBR_PARTITION_ARRAY

; BIOS interrupt constants
INT10 equ 0x10
INT10_WRITE_TTY equ 0xE
INT13 equ 0x13
INT13_RESET_DISK_CONTROLLER equ 0x0
INT13_READ_SECTOR equ 0x2
INT13_EXT_CHECK equ 0x41
INT13_EXT_CHECK_MAGIC equ 0x55AA

; Disk block size
BLOCK_SIZE equ 512

; vim: ft=nasm
