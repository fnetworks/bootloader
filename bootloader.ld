OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)
ENTRY(bios_entrypoint)

SECTIONS
{
    /* data area for storage of boot information */
    . = 0x500;
    bss_start = .;
    .bss . : {
        *(.bss);
    }
    . = ALIGN(4);
    bss_end = .;
    bss_size = bss_end - bss_start;
    bss_size_words = bss_size / 4;

    /* top of the stack; seems to be the same as used by QEMU on entry */
    . = 0x6F00;
    stack_top = .;


    . = 0x7C00;
    .stage0 . :    {
        *(stage0_entry);
        *(.text.stage0);
        *(.rodata.stage0);
    }

    . = 0x7C00 + 0x01BE;
    MBR_PARTITION_ARRAY = .;
    .stage0.partitions . : {
        /* Partition 1 (Kernel): */
        /*BYTE(0x80) /* active partition */

        /* start CHS */
        /*BYTE(0x00) /* head */
        /*BYTE(0x03) /* cylinder / sector */
        /*BYTE(0x00) /* cylinder */

        /*BYTE(0x7F) /* partition type */

        /* end CHS */
        /*BYTE(0x00) /* head */
        /*BYTE(0x03) /* cylinder / sector */
        /*BYTE(0x00) /* cylinder */

        /*LONG(0x02) /* first LBA */
        /*LONG(0x01) /* sector size */
        /* Partition 1 (Kernel): */
        LONG(0x00000000) LONG(0x00000000) LONG(0x00000000) LONG(0x00000000);

        /* Partition 2: */
        LONG(0x00000000) LONG(0x00000000) LONG(0x00000000) LONG(0x00000000);

        /* Partition 3: */
        LONG(0x00000000) LONG(0x00000000) LONG(0x00000000) LONG(0x00000000);

        /* Partition 4: */
        LONG(0x00000000) LONG(0x00000000) LONG(0x00000000) LONG(0x00000000);
    }
    .stage0.boot_signature . : {
        BYTE(0x55) BYTE(0xAA)
    }

    /* second-stage bootloader */
    . = 0x7E00;
    stage1_start = .;
    .stage1 . : {
        *(stage1_entry);
        *(.text.stage1)
        *(.rodata.stage1)
    }

    . = ALIGN(512);
    stage1_end = .;
    stage1_size = stage1_end - stage1_start;
    stage1_sectors = stage1_size / 512; /* stage1_size is already a multiple of 512 */

    kernel_buffer_area = .;

    . = 0x100000;
    kernel_start = .;
}
