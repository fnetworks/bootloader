bits 16

%include "symbols.inc"

extern panic
extern bios_disk
extern bios_print
extern printf

extern disk_init
extern disk_load_block
extern disk_read_bytes

extern halt_loop

EI_MAG0     equ 0
EI_MAG1     equ 1
EI_MAG2     equ 2
EI_MAG3     equ 3
EI_CLASS    equ 4
EI_DATA     equ 5
EI_VERSION  equ 6
EI_PAD      equ 7

ELFMAG0     equ 0x7F
ELFMAG1     equ 'E'
ELFMAG2     equ 'L'
ELFMAG3     equ 'F'

ELFCLASS32  equ 1
ELFDATA2LSB equ 1
EV_CURRENT  equ 1
ET_EXEC     equ 2
EM_386      equ 3

PT_LOAD     equ 1

section .text.stage1 progbits alloc exec nowrite align=4

; todo stack registers

; load_elf(uint32_ block_addr, uint32_t block_count)
global load_elf:function
load_elf:
    ; create 16-byte stack frame
    push ebp
    mov ebp, esp
    sub esp, 20

    mov eax, [ebp + 6] ; block_addr
    shl eax, 9 ; * 512
    mov [ebp - 20], eax ; base address in bytes

    mov eax, [ebp + 10] ; block_count
    push eax
    mov eax, [ebp + 6] ; block_addr
    push eax
    push dword s_LOADING_ELF
    call printf
    add esp, 12

    call disk_init

    push dword [ebp + 6]
    call disk_load_block
    add esp, 4
    ; eax = block buffer

.check_and_load_elf_header:
    mov bl, EI_MAG0
    cmp byte [eax + EI_MAG0], ELFMAG0
    jne .elf_header_invalid

    mov bl, EI_MAG1
    cmp byte [eax + EI_MAG1], ELFMAG1
    jne .elf_header_invalid

    mov bl, EI_MAG2
    cmp byte [eax + EI_MAG2], ELFMAG2
    jne .elf_header_invalid

    mov bl, EI_MAG3
    cmp byte [eax + EI_MAG3], ELFMAG3
    jne .elf_header_invalid

    mov bl, EI_CLASS
    cmp byte [eax + EI_CLASS], ELFCLASS32
    jne .elf_header_invalid

    mov bl, EI_DATA
    cmp byte [eax + EI_DATA], ELFDATA2LSB
    jne .elf_header_invalid

    mov bl, EI_VERSION
    cmp byte [eax + EI_VERSION], EV_CURRENT
    jne .elf_header_invalid

    mov bl, 0x80
    cmp word [eax + 16], ET_EXEC ; e_type
    jne .elf_header_invalid

    mov bl, 0x81
    cmp word [eax + 18], EM_386 ; e_machine
    jne .elf_header_invalid

    mov bl, 0x82
    cmp dword [eax + 20], EV_CURRENT ; e_version
    jne .elf_header_invalid

    mov ebx, dword [eax + 24]
    mov [ebp - 4], ebx ; e_entry
    mov ebx, dword [eax + 28]
    mov [ebp - 8], ebx ; e_phoff
    test ebx, ebx
    jz .elf_header_invalid
    movzx ebx, word [eax + 42]
    mov [ebp - 12], ebx ; e_phentsize
    movzx ebx, word [eax + 44]
    mov [ebp - 16], ebx ; e_phnum

    xor esi, esi
.phdr_loop:
    cmp esi, [ebp - 16]
    jge .phdr_end

    mov eax, esi
    imul dword [ebp - 12]    ; e_phentsize
    add eax, dword [ebp - 8] ; e_phoff
    mov ebx, dword [ebp + 6] ; block_addr
    shl ebx, 9 ; * 512
    add eax, ebx
    ; eax = program header addr on disk
    ; todo check bounds

    ; reserve e_phentsize bytes on stack
    sub esp, [ebp - 12]
    mov ebx, esp ; ebx = alloca(e_phentsize)

    push dword [ebp - 12] ; length
    push ebx              ; target_address
    push eax              ; disk_offset
    call disk_read_bytes
    add esp, 12

    cmp dword [esp], PT_LOAD ; p_type
    jne .phdr_cont

    mov eax, [esp + 16] ; p_filesz
    mov ecx, [esp + 20] ; p_memsz

    mov edx, [esp + 4] ; p_offset
    add edx, [ebp - 20] ; ELF base

    cmp eax, ecx
    jge .copy

.copy_and_zero_fill:
    push eax              ; size on disk
    push dword [esp + 12] ; p_paddr (memory location)
    push edx              ; offset on disk
    call disk_read_bytes
    add esp, 4
    pop edi ; mem offset
    pop eax ; filesz

    add edi, eax ; zero region start
    sub ecx, eax ; zero region size

    xor al, al
    rep a32 stosb

    jmp .phdr_cont

.copy:
    push ecx              ; memory size
    push dword [esp + 12] ; p_paddr (memory location)
    push edx              ; offset on disk
    call disk_read_bytes
    add esp, 12

.phdr_cont:
    add esp, [ebp - 12]
    inc esi
    jmp .phdr_loop
.phdr_end:

    ; return entry point
    mov eax, [ebp - 4]

    mov esp, ebp
    pop ebp
    ret
.elf_header_invalid:
    push bx
    mov si, s_INVALID_ELF_HEADER
    call bios_print
    pop bx
    mov ah, bl
    jmp panic

section .rodata.stage1 progbits alloc noexec nowrite align=2

static s_INVALID_ELF_HEADER
s_INVALID_ELF_HEADER:
    db "Invalid ELF header",13,10,0

static s_LOADING_ELF
s_LOADING_ELF:
    db "Loading ELF file, start block=%4, block count=%4",13,10,0

; vim: ft=nasm
