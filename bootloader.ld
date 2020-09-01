OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)
ENTRY(bios_entrypoint)

SECTIONS
{
	. = 0x7C00;
	.stage0 . :
	{
		*(.text.stage0);
		*(.rodata.stage0);
	}
	. = 0x7DFE; /* 0x7C00 + 512 - 2 */
	.stage0.bios_magic . : {
		BYTE(0x55);
		BYTE(0xAA);
	}
	. = 0x8000;
	.stage1 . : {
		*(.text.stage1)
	}
}
