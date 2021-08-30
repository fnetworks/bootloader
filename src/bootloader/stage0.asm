bits 16

%include "symbols.inc"

section .bss

global bios_disk
bios_disk: resb 1

extern enable_a20

; The entry point. The BIOS jumps here.
section stage0_entry progbits alloc exec nowrite align=1
global bios_entrypoint:function (bios_entrypoint.end - bios_entrypoint)
bios_entrypoint:
    cld ; Clear direction flag
    cli ; Disable interrupts

    ; Set segment registers to zero
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Canonicalize address to 0:7Cxxh (might be 07C0:0000 on entry, but we want 0000:7C00)
    jmp word 0:.canon_addr
.canon_addr:

    ; Zero out data area
    mov ecx, bss_size_words
    mov edi, bss_start
    xor eax, eax
    rep stosd

    ; Store the boot disk in memory to prevent overwriting the register
    mov [bios_disk], dl

    ; Setup a known stack
    mov sp, stack_top

    ; Enable address line 20
    call enable_a20

    ; Disk IO
    ; DL contains the boot disk (BIOS spec)

    ; Reset disk controller to a known state
    mov ah, INT13_RESET_DISK_CONTROLLER
    int INT13
    jc io_panic

    ; Load the second stage into memory
    ; stage1_start is a symbol defined in the linker script
    extern stage1_start
    mov ah, INT13_READ_SECTOR
    mov al, stage1_sectors ; Sector count
    mov ch, 0 ; Cylinder (low eight)
    mov cl, 2 ; Sector number (1-63)
    mov dh, 0 ; Head number
    mov bx, stage1_start ; Data buffer
    int INT13
    jc io_panic

    extern stage1_entrypoint
    jmp stage1_entrypoint
.end:

section .text.stage0 progbits alloc exec nowrite align=2

; hlt in a loop.
global halt_loop:function (halt_loop.end - halt_loop)
halt_loop:
    cli
    hlt
    jmp halt_loop
.end:

; ENSURE THIS IS BEFORE `panic`
static io_panic
io_panic:
    mov si, io_error_message
    call bios_print

; Print a panic message and halt. An error code must be in AH.
global panic:function (panic.end - panic)
panic:
    movzx ecx, ah ; Copy error code and zero extend rest

    mov ah, INT10_WRITE_TTY
    xor bx, bx    ; Video page number / Foreground color

    mov si, panic_message
.print_str:
    lodsb
    test al, al
    jz .print_done
    int INT10
    jmp .print_str
.print_done:

    movzx edx, cl ; Copy error code and zero extend rest
    shr dl, 4     ; Shift upper 4 bits to first 4 bits
    mov al, byte [edx + hex_alphabet]
    int INT10     ; Print the first hex char

    and cl, 0x0F  ; And with 0b00001111 (lower 4 bits)
    mov al, byte [ecx + hex_alphabet]
    int INT10     ; Print the second hex char

    ; Print newline (2 chars). SI is already at the start of `newline` from the print loop above.
    lodsb
    int INT10
    lodsb
    int INT10

    jmp halt_loop
.end:

; Print a message using the BIOS. The string argument is passed in SI. A terminating null
; byte is required.
global bios_print:function (bios_print.end - bios_print)
bios_print:
    pushf
    push ax
    push bx

    mov ah, INT10_WRITE_TTY
    xor bx, bx  ; Video page number / FG color

.print_loop:
    lodsb
    test al, al
    jz .print_done

    ; Print the character and continue loop
    int INT10
    jmp .print_loop

.print_done:
    pop bx
    pop ax
    popf
    ret
.end:

section .rodata.stage0 progbits alloc noexec nowrite align=1
global hex_alphabet:data (hex_alphabet.end - hex_alphabet)
hex_alphabet:
    db "0123456789ABCDEF"
.end:

static io_error_message
io_error_message:
    db "IO error",13,10,0

static panic_message
panic_message:
    db "Panic: 0x",0

; Newline characters. MUST BE DIRECTLY AFTER `panic_message`.
static newline
newline:
    db 13,10

; vim: ft=nasm
