.code16
.intel_syntax noprefix

.section .text.stage1,"ax",@progbits

# The entry point. The Stage 0 loader jumps here.
.globl stage1_entrypoint
.type stage1_entrypoint,@function
stage1_entrypoint:
	mov ah, 0xE
	mov al, 0x47
	xor bx, bx
	int 0x10
.size stage1_entrypoint, .-stage1_entrypoint

# hlt in a loop. Must be placed directly after stage1_entrypoint
.type halt_loop,@function
halt_loop:
	cli
	hlt
	jmp halt_loop
.size halt_loop, .-halt_loop

# vim: ft=gas
