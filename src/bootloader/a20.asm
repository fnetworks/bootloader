bits 16

section .text.stage0 progbits alloc exec nowrite align=2

extern bios_print
extern panic

global enable_a20:function (enable_a20.end - enable_a20)
enable_a20:
    call test_a20
    jnc .try_enable_a20
    ret

.try_enable_a20:
    ; A20 not enabled.
    call a20_enable_bios

    ; We currently don't support any other A20 activation methods
    jnc .a20_panic

    call test_a20
    jnc .a20_panic
    ret

.a20_panic:
    mov si, no_a20_msg
    call bios_print
    xor ax, ax
    jmp panic
.end:

; Checks if the A20 gate is enabled (https://wiki.osdev.org/A20). Sets the carry flag if it is.
static test_a20
test_a20:
    push ds
    push es

    xor ax, ax
    mov es, ax

    not ax
    mov ds, ax

    mov di, 0x500
    mov si, 0x510

    mov al, byte [es:di]
    push ax

    mov al, byte [ds:si]
    push ax

    mov byte [es:edi], 0x00
    mov byte [ds:esi], 0xFF

    cmp byte [es:di], 0xFF

    pop ax
    mov byte [ds:si], al

    pop ax
    mov byte [es:di], al

    clc
    je .test_a20_exit

    stc
.test_a20_exit:
    pop es
    pop ds
    ret

; Tries to enable the A20 gate via BIOS (https://wiki.osdev.org/A20); Sets the carry flag if it
; succeeded.
static a20_enable_bios
a20_enable_bios:
    ; A20-related _very well documented_ interrupts (https://www.win.tue.nl/~aeb/linux/kbd/A20.html):
    ; INT 15h AX=2400 - disable A20
    ; INT 15h AX=2401 - enable A20
    ; INT 15h AX=2402 - query status A20
    ; INT 15h AX=2403 - query A20 support (kbd or port 92)

    mov ax, 0x2403   ; Query A20-Gate support
    int 0x15
    jc .unsupported  ; Carry is set if failure
    cmp ah, 0
    jne .unsupported ; AH != 0 if failure

    mov ax, 0x2402   ; Query A20-Gate status (return codes same as above)
    int 0x15
    jc .unsupported
    cmp ah, 0
    jne .unsupported

    cmp ah, 1        ; AH = 1: The Gate is already enabled (shouldn't happen, because this has been
                     ; checked before, but whatever)
    je .enabled

    mov ax, 0x2401   ; Enable A20-Gate (return codes same as above)
    int 0x15
    jc .unsupported
    cmp ah, 0
    jne .unsupported

    ; At this point, the BIOS has reported that A20 was successfully enabled. However, this should
    ; still be tested with test_a20, as the BIOS can be unreliable.
.enabled:
    stc
    ret ; Return 1

.unsupported:
    clc
    ret ; Return 0

section .rodata.stage0 progbits alloc noexec nowrite align=2
static no_a20_msg
no_a20_msg:
    db "Error: A20",13,10,0

; vim: ft=nasm
