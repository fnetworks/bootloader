TARGET_DIR := target

STAGE0_SOURCE = stage0.s
STAGE0_OBJ = $(TARGET_DIR)/stage0.o

STAGE1_SOURCE = stage1.s
STAGE1_OBJ = $(TARGET_DIR)/stage1.o

BL_DEBUG = $(TARGET_DIR)/bootloader.debug
BL_ELF = $(TARGET_DIR)/bootloader.elf
BL_BIN = $(TARGET_DIR)/bootloader.bin

all: $(BL_BIN)
.PHONY: all

run: $(BL_BIN)
	qemu-system-x86_64 -drive file=$<,format=raw,if=floppy -boot a
.PHONY: run

debug: $(BL_BIN) $(BL_DEBUG)
	qemu-system-i386 -s -S -drive file=$<,format=raw,if=floppy -boot a &
	gdb \
		-ex "symbol-file $(BL_DEBUG)" \
		-ex "set architecture i8086" \
		-ex "target remote localhost:1234" \
		-ex "set disassembly-flavor intel"
.PHONY: debug

$(STAGE0_OBJ): $(STAGE0_SOURCE)
	@mkdir -p $(TARGET_DIR)
	as $< -c -o $@ -msyntax=intel --32 -march=i386

$(STAGE1_OBJ): $(STAGE1_SOURCE)
	@mkdir -p $(TARGET_DIR)
	as $< -c -o $@ -msyntax=intel --32 -march=i386

$(BL_ELF): $(STAGE0_OBJ) $(STAGE1_OBJ)
	ld -T bootloader.ld -nostdlib $^ -o $@

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
