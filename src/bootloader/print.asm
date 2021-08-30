bits 16

%include "symbols.inc"

extern bios_print
extern hex_alphabet

section .text.stage1 progbits alloc exec nowrite align=4

; printf(char* fmt, ...)
global printf:function (printf.end-printf)
printf:
    push ebx
    push esi
    push edi

    mov ebx, [esp + 14]
    lea edi, [esp + 18]
.loop:
    movzx ax, byte [ebx]
    test al, al
    jz .fin

    cmp al, '%'
    je .format

    push ax
    call print_char
    add esp, 2
    inc ebx
    jmp .loop

.format:
    inc ebx

    movzx ax, byte [ebx]

    test al, al
    jz .fin

    cmp al, '1'
    jne .f1
    mov al, byte [edi]
    add edi, 2
    push ax
    call print_hex_byte
    add esp, 2
    jmp .cont
.f1:
    cmp al, '2'
    jne .f2
    mov ax, word [edi]
    add edi, 2
    push ax
    call print_hex_word
    add esp, 2
    jmp .cont
.f2:
    cmp al, '4'
    jne .f3
    mov eax, dword [edi]
    add edi, 4
    push eax
    call print_hex_dword
    add esp, 4
    jmp .cont
.f3:
    cmp al, 's'
    jne .f4
    mov esi, dword [edi]
    add edi, 4
    call bios_print
    jmp .cont
.f4:
    cmp al, 'n'
    jne .f5
    call print_nl
    jmp .cont
.f5:
    push '?'
    call print_char
    add esp, 2
.cont:
    inc ebx
    jmp .loop
.fin:
   pop edi
   pop esi
   pop ebx
   ret
.end:

static print_nl
print_nl:
    dec esp
    mov byte [esp], 13
    call print_char
    mov byte [esp], 10
    call print_char
    inc esp
    ret

static print_char
print_char:
    push ebx

    mov ah, INT10_WRITE_TTY
    xor bx, bx

    mov al, byte [esp + 6]
    int INT10

    pop ebx
    ret

static print_hex_byte
print_hex_byte:
    push ebx
    push ecx

    mov ah, INT10_WRITE_TTY
    xor bx, bx

    movzx ecx, byte [esp + 10]

    mov edx, ecx
    shr dl, 4
    mov al, byte [hex_alphabet + edx]
    int INT10

    and cl, 0x0F
    mov al, byte [hex_alphabet + ecx]
    int INT10

    pop ecx
    pop ebx
    ret

static print_hex_word
print_hex_word:
    push ebx
    sub esp, 2

    mov bx, word [esp + 8]
    mov [esp], bh
    call print_hex_byte
    mov [esp], bl
    call print_hex_byte

    add esp, 2
    pop ebx
    ret

static print_hex_dword
print_hex_dword:
    push ebx
    sub esp, 4

    mov ebx, dword [esp + 10]
    mov eax, ebx
    shr eax, 16
    mov [esp], ax
    call print_hex_word
    mov [esp], bx
    call print_hex_word

    add esp, 4
    pop ebx
    ret

; vim: ft=nasm
