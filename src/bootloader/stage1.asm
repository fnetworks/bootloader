bits 16

%include "symbols.inc"

; Symbols from stage 0
extern panic ; Panic routine
extern halt_loop
extern bios_print
extern boot_disk ; The disk which we are on
extern printf

extern bios_disk

extern load_elf

; The entry point. The Stage 0 loader jumps here.
section stage1_entry progbits alloc exec nowrite align=1
global stage1_entrypoint:function; (stage1_entrypoint.end - stage1_entrypoint)
stage1_entrypoint:
    mov si, stage1_msg
    call bios_print

    ; Check that int13 extensions are present (should be).
    call check_int13_ext

    call enter_unreal_mode

    call find_kernel_sector

    push edx
    push eax

    call load_elf
    ; eax = entry point

    lgdt [protected_gdt_ptr]

    ; Set PE bit (enter protected mode)
    mov edx, cr0
    or dl, 1
    mov cr0, edx

    mov dx, 0x08
    mov ds, dx
    mov es, dx
    mov fs, dx
    mov gs, dx
    mov ss, dx

static jmpd
jmpd:
    push dword 0x10 ; code segment
    push eax  ; jump target
    retfd   ; indirect far jump, emulated by ret
.end:


section .text.stage1 progbits alloc exec nowrite align=4
static check_int13_ext
check_int13_ext:
    mov dl, [bios_disk]
    mov ah, INT13_EXT_CHECK
    mov bx, INT13_EXT_CHECK_MAGIC
    int INT13
    jc .not_present
    ret

.not_present:
    mov si, no_int13_extensions_msg
    call bios_print
    jmp panic

; returns eax=sector lba, edx=sector size
static find_kernel_sector
find_kernel_sector:
    push ebx

    ; loop counter, 4 entries
    xor al, al

.loop:
    ; get base address of mbr entry
    movzx ebx, al
    shl ebx, 4 ; * 16
    lea ebx, [MBR_PARTITION_ARRAY + ebx] ; mbr partition size = 16

    test byte [ebx], 0x80 ; active bit
    jz .cont

    mov eax, [ebx + 8]
    mov edx, [ebx + 12]

    jmp .fin
.cont:
    inc al
    cmp al, 4
    jne .loop
    jmp panic

.fin:
    pop ebx
    ret

static enter_unreal_mode
enter_unreal_mode:
    ; Interrupts must be disabled here and should still be from stage0

    ; Save real mode segment
    push ds

    ; Load a flat GDT
    lgdt [unreal_gdt_ptr]

    ; Set PE bit (enter protected mode)
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; OSDev Wiki suggests to do a jump to prevent a crash for whatever reason
    jmp .pemode_jmp
.pemode_jmp:

    ; Set DS to descriptor 1
    mov bx, 0x08
    mov ds, bx

    ; Unset PE bit (back to real mode)
    and al, 0xFE
    mov cr0, eax

    ; Restore previous real mode segment
    pop ds

    ret

section .rodata.stage1 progbits alloc noexec nowrite align=2

static s_ADDR
s_ADDR:
    db "Jumping to kernel at address %4",13,10,0

static no_int13_extensions_msg
no_int13_extensions_msg:
    db "INT13 extensions not present.",13,10,0

static stage1_msg
stage1_msg:
    db "Stage 1 reached!",13,10,0

; GDT for unreal mode
align 2, db 0
static unreal_gdt_ptr
unreal_gdt_ptr:
    dw unreal_gdt.end - unreal_gdt - 1
    dd unreal_gdt
static unreal_gdt
unreal_gdt:
    dd 0, 0 ; Null descriptor
    db 0xFF, 0xFF, 0x00, 0x00, 0x00, 10010010b, 11001111b, 0x00 ; Flat 4G data
.end:

; GDT for protected mode
align 2, db 0
static protected_gdt_ptr
protected_gdt_ptr:
    dw protected_gdt.end - protected_gdt - 1
    dd protected_gdt
static protected_gdt
protected_gdt:
    dd 0, 0 ; Null descriptor
    db 0xFF, 0xFF, 0x00, 0x00, 0x00, 10010010b, 11001111b, 0x00 ; Flat 4G data
    db 0xFF, 0xFF, 0x00, 0x00, 0x00, 10011010b, 11001111b, 0x00 ; Flat 4G code
.end:

; vim: ft=nasm
