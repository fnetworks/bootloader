.code16
.intel_syntax noprefix

.section .text.stage0,"ax",@progbits

# The entry point. The BIOS jumps here.
.globl bios_entrypoint
.type bios_entrypoint,@function
bios_entrypoint:
	cld # Clear direction flag

	# Set segment registers to zero
	xor ax, ax
	mov ds, ax
	mov es, ax

	# Canonicalize address to 0:7Cxxh (might be 07C0:0000 on entry, but we want 0000:7C00)
	ljmp 0, _canon_addr
_canon_addr:

	# Disk IO
	# DL contains the boot disk (BIOS spec)

	# Reset disk controller to a known state
	mov ah, 0x0
	int 0x13
	jc panic

	# Get drive type
	mov ah, 0x15
	int 0x13
	jc panic
	# 0x1 or 0x2 in AH indicate floppy. Other types are unsupported (currently).
	sub ah, 1
	cmp ah, 2
	jae panic

	mov ah, 0x2
	mov al, 1
	mov ch, 0
	mov cl, 0x02
	mov dh, 0
	mov bx, 0x8000
	int 0x13
	jc panic

	jmp stage1_entrypoint
.size bios_entrypoint, .-bios_entrypoint

# hlt in a loop.
.type halt_loop,@function
halt_loop:
	cli
	hlt
	jmp halt_loop
.size halt_loop, .-halt_loop

# Print a panic message and halt. An error code must be in AH.
.type panic,@function
panic:
	movzx ecx, ah # Copy error code and zero extend rest

	mov ah, 0xE # Write teletype mode
	xor bx, bx  # Video page number / Foreground color

	mov si, offset panic_message
_print_str:
	lodsb
	test al, al
	jz _print_done
	int 0x10
	jmp _print_str
_print_done:

	movzx edx, cl # Copy error code and zero extend rest
	shr dl, 4     # Shift upper 4 bits to first 4 bits
	mov al, byte ptr [edx + hex_alphabet]
	int 0x10      # Print the first hex char

	and cl, 0x0F  # And with 0b00001111 (lower 4 bits)
	mov al, byte ptr [ecx + hex_alphabet]
	int 0x10      # Print the second hex char

	# Print newline (2 chars). SI is already at the start of `newline` from the print loop above.
	lodsb
	int 0x10
	lodsb
	int 0x10

	jmp halt_loop
.size panic, .-panic

.section .rodata.stage0,"aMS",@progbits,1
.type hex_alphabet,@object
hex_alphabet:
	.ascii "0123456789ABCDEF"
.size hex_alphabet, 16

.type panic_message,@object
panic_message:
	.string "Panic: 0x"
.size panic_message, 8

# Newline characters. Must be directly after panic_message.
.type newline,@object
newline:
	.ascii "\r\n"
.size newline, 2

# vim: ft=gas
