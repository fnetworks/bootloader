TARGET_DIR := target

BL_OBJS := $(TARGET_DIR)/stage0.o $(TARGET_DIR)/stage1.o \
		   $(TARGET_DIR)/a20.o $(TARGET_DIR)/elf.o $(TARGET_DIR)/disk.o $(TARGET_DIR)/print.o

BL_DEBUG = $(TARGET_DIR)/bootloader.debug
BL_ELF = $(TARGET_DIR)/bootloader.elf
BL_BIN = $(TARGET_DIR)/bootloader.bin

KERNEL_ELF = $(TARGET_DIR)/kernel.elf

ISO = $(TARGET_DIR)/kernel.iso
ISO_DIR = $(TARGET_DIR)/iso

all: $(BL_BIN)
.PHONY: all

run: $(BL_BIN)
	qemu-system-x86_64 -drive file=$<,format=raw,if=floppy -boot a
.PHONY: run

debug: $(BL_BIN) $(BL_DEBUG)
	qemu-system-i386 -s -S -drive file=$<,format=raw -boot c &
	gdb \
		-ex "symbol-file $(BL_DEBUG)" \
		-ex "set architecture i8086" \
		-ex "target remote localhost:1234" \
		-ex "set disassembly-flavor intel"
.PHONY: debug

iso: $(ISO)
.PHONY: iso

diskrun: $(TARGET_DIR)/disk.img
	qemu-system-x86_64 -drive file=$<,format=raw
.PHONY: diskrun

diskdebug: $(TARGET_DIR)/disk.img $(BL_DEBUG)
	qemu-system-i386 -s -S -drive file=$<,format=raw &
	gdb \
		-ex "symbol-file $(BL_DEBUG)" \
		-ex "set architecture i8086" \
		-ex "target remote localhost:1234" \
		-ex "set disassembly-flavor intel"

clean:
	rm -rf target
.PHONY: clean

$(TARGET_DIR)/x86/debug/kernel:
	cargo build
.PHONY: $(TARGET_DIR)/x86/debug/kernel

$(TARGET_DIR)/kernel.elf: $(TARGET_DIR)/x86/debug/kernel
#	objcopy doesn't seem to work sometimes ("invalid bfd target")
	cp $< $@
	strip -s $<

$(TARGET_DIR)/disk.img: $(BL_BIN) $(KERNEL_ELF)
	cp $< $@
#   kernel_start_sector = ceil(sizeof(BL_BIN) / 512)
	$(eval kernel_start_sector := $(shell echo $$(( ($$(stat -c %s $(BL_BIN)) + 511) / 512 ))))
#   kernel_size_sectors = ceil(sizeof(KERNEL_ELF) / 512)
	$(eval kernel_size_sectors := $(shell echo $$(( ($$(stat -c %s $(KERNEL_ELF)) + 511) / 512 ))))
#   image_size_bytes = (kernel_start_sector + kernel_size_sectors) * 512
	$(eval image_size_bytes := $(shell echo $$(( ($(kernel_start_sector) + $(kernel_size_sectors)) * 512 ))))
	truncate -c -s $(image_size_bytes) $@
	@echo "Writing disk layout descriptor with kernel start = $(kernel_start_sector), size = $(kernel_size_sectors)"
	@echo "label: dos" > target/disk_image.sfdisk
	@echo "label-id: 0x00000000" >> target/disk_image.sfdisk
	@echo "device: target/disk.img" >> target/disk_image.sfdisk
	@echo "unit: sectors" >> target/disk_image.sfdisk
	@echo "grain: 512" >> target/disk_image.sfdisk
	@echo >> target/disk_image.sfdisk
	@echo "target/disk.img1 : start=$(kernel_start_sector), size=$(kernel_size_sectors), type=7f, bootable" >> target/disk_image.sfdisk
	sfdisk $@ < target/disk_image.sfdisk
	dd if=$(KERNEL_ELF) of=$@ bs=512 conv=nocreat,notrunc seek=$(kernel_start_sector)


$(TARGET_DIR)/%.o: src/bootloader/%.asm
	@mkdir -p $(TARGET_DIR)
	nasm -felf32 -g -Fdwarf -o $@ -i src/bootloader $<

$(BL_ELF): bootloader.ld $(BL_OBJS)
	ld -T $^ -nostdlib -o $@
	@echo "Sector Sizes:"
	@size -A $@ | grep -Ew 'section|\.stage0|\.stage1'

$(BL_DEBUG): $(BL_ELF)
	objcopy --only-keep-debug $< $@

$(TARGET_DIR)/stage0.bin: $(BL_ELF)
	objcopy -j '.stage0*' -O binary $< $(TARGET_DIR)/stage0.bin
	@if [ $$(wc -c < $@) -ne 512 ]; then \
		echo "ERROR: Stage 0 must be exactly 512 bytes"; \
		exit 1; \
	fi

$(TARGET_DIR)/stage1.bin: $(BL_ELF)
	objcopy -j '.stage1*' -O binary $< $(TARGET_DIR)/stage1.bin

$(BL_BIN): $(TARGET_DIR)/stage0.bin $(TARGET_DIR)/stage1.bin
	cat $^ > $@


# Iso creation

# Copy and pad the boot floppy image
$(ISO_DIR)/boot/boot.img: $(BL_BIN)
	mkdir -p $(ISO_DIR)/boot
	cp $< $@
	truncate -c -s 1440K $@

$(ISO): $(ISO_DIR)/boot/boot.img
	rm -f $@
	xorriso -as mkisofs -r -b /boot/boot.img -c boot/boot.catalog -o $@ $(ISO_DIR)
