bits 16

%include "symbols.inc"

section .text.stage1 progbits alloc exec nowrite align=4

extern panic
extern bios_disk
extern printf

global disk_init:function (disk_init.end-disk_init)
disk_init:
    mov [dap_buffer + disk_addr_packet.psize], byte disk_addr_packet_size
    mov [dap_buffer + disk_addr_packet.sector_count], word 1
    ret
.end:

; > uint32_t disk_load_block(uint32_t block_addr)
; loads a block from disk (cannot be block 0), and returns its address in eax
global disk_load_block:function (disk_load_block.end-disk_load_block)
disk_load_block:
    push ebp
    mov ebp, esp

    push dword [ebp + 6]
    push dword s_LOADING_BLOCK
    call printf
    add esp, 8

    mov eax, [ebp + 6] ; source block
    test eax, eax
    jz panic
    cmp [last_loaded_block], eax
    je .cached
    mov [last_loaded_block], eax
    mov dword [dap_buffer + disk_addr_packet.start_lba_lower], eax
    mov dword [dap_buffer + disk_addr_packet.start_lba_upper], 0

    mov eax, disk_buffer ; target address
    mov word [dap_buffer + disk_addr_packet.transfer_buf_offset], ax
    mov word [dap_buffer + disk_addr_packet.transfer_buf_segment], 0

    push esi

    xor eax, eax
    xor edx, edx
    xor esi, esi

    mov ds, ax

    mov ah, 0x42
    mov dl, [bios_disk]
    mov si, dap_buffer

    int INT13
    jc .error
    ; todo check transferred block count == 1

    pop esi
.done:
    mov esp, ebp
    pop ebp
    mov eax, disk_buffer
    ret

.cached:
    push dword s_BLOCK_CACHED
    call printf
    add esp, 4
    jmp .done

.error:
    push ax
    push dword [ebp + 6]
    push dword s_LOAD_BLOCK_ERROR
    call printf
    add esp, 8
    pop ax
    jmp panic
.end:

; disk_read_bytes(uint32_t disk_offset, uint32_t target_address, uint32_t length)
global disk_read_bytes:function (disk_read_bytes.end-disk_read_bytes)
disk_read_bytes:
    push ebp
    mov ebp, esp
    sub esp, 12
    push ebx
    push ecx

    mov eax, [ebp + 6]
    mov [ebp - 4], eax  ; disk_offset
    mov eax, [ebp + 10]
    mov [ebp - 8], eax  ; target_address
    mov eax, [ebp + 14]
    mov [ebp - 12], eax ; length

    test eax, eax ; if length == 0, do nothing
    jz .done

    push dword [ebp - 8]
    push dword [ebp - 4]
    push eax
    push dword s_LOAD_ADDR
    call printf
    add esp, 16

    mov eax, [ebp - 4]
    mov ecx, eax
    shr eax, 9 ; div 512
    and ecx, (BLOCK_SIZE - 1) ; mod 512
    ; eax = block addr, ecx = offset in block

    ; eax = disk_load_block(eax)
    push eax
    call disk_load_block
    add esp, 4

    ; calculate remaining bytes in block
    mov edx, BLOCK_SIZE
    sub edx, ecx

    ; buffer offset
    add eax, ecx

    ; check if we need to load more than one sector (i.e. length > remaining in sector)
    cmp [ebp - 12], edx
    jg .multiple_sectors

    ; copy bytes
    push dword [ebp - 12] ; length
    push dword [ebp - 8]  ; target address
    push eax              ; buffer + offset
    call copy_bytes
    add esp, 12
    jmp .done

.multiple_sectors:
    push edx              ; remaining in sector
    push dword [ebp - 8]  ; target address
    push eax              ; buffer + offset
    call copy_bytes
    add esp, 8
    pop edx

    sub dword [ebp - 12], edx ; decrease length
    add dword [ebp - 8], edx  ; increase target address
    add dword [ebp - 4], edx  ; increase disk offset

    ; We are now aligned to a block boundary (length % 512 == 0).
    ; Length must be > 0, since we're only here if length > edx => length - edx > 0
.copy_loop:
    mov eax, [ebp - 4] ; disk offset
    shr eax, 9 ; div 512

    ; eax = disk_load_block(eax)
    push eax
    call disk_load_block
    add esp, 4

    cmp dword [ebp - 12], BLOCK_SIZE
    jg .more_remaining

    push dword [ebp - 12] ; length
    push dword [ebp - 8]  ; target address
    push eax              ; buffer
    call copy_bytes
    add esp, 12
    jmp .done

.more_remaining:
    push dword BLOCK_SIZE ; length
    push dword [ebp - 8]  ; target address
    push eax              ; buffer
    call copy_bytes
    add esp, 12

    sub dword [ebp - 12], BLOCK_SIZE ; decrease length
    add dword [ebp - 8], BLOCK_SIZE  ; increase target address
    add dword [ebp - 4], BLOCK_SIZE  ; increase disk offset

    ; Length must still be > 0, since we're here because length > BLOCK_SIZE before => length - BLOCK_SIZE > 0
    jmp .copy_loop

.done:
    pop ecx
    pop ebx
    mov esp, ebp
    pop ebp
    ret
.end:

; copy_bytes(uint32_t from, uint32_t to, uint32_t size)
static copy_bytes
copy_bytes:
    ; basic copy implementation, might be improved
    push esi
    push edi
    push ecx

    mov esi, [esp + 14]
    mov edi, [esp + 18]
    mov ecx, [esp + 22]
    rep a32 movsb

    pop ecx
    pop edi
    pop esi
    ret

section .bss

; A Disk Address Packet structure
struc disk_addr_packet
    .psize:                resb 1  ; Size of the structure
    .resv:                 resb 1  ; Reserved - always 0
    .sector_count:         resw 1  ; Sector count to transfer
    .transfer_buf_offset:  resw 1  ; Offset of the transfer buffer
    .transfer_buf_segment: resw 1  ; Segment of the tranfer buffer
    .start_lba_lower:      resd 1  ; 48-bit starting LBA (lower dword)
    .start_lba_upper:      resd 1  ; 48-bit starting LBA (upper dword)
endstruc

static dap_buffer
dap_buffer:
istruc disk_addr_packet
    at disk_addr_packet.psize,                resb 1
    at disk_addr_packet.resv,                 resb 1
    at disk_addr_packet.sector_count,         resw 1
    at disk_addr_packet.transfer_buf_offset,  resw 1
    at disk_addr_packet.transfer_buf_segment, resw 1
    at disk_addr_packet.start_lba_lower,      resd 1
    at disk_addr_packet.start_lba_upper,      resd 1
iend

static last_loaded_block
last_loaded_block:
    resd 1

align 4
disk_buffer: resb 512

section .rodata.stage1 progbits alloc noexec nowrite align=2

static s_LOAD_ADDR
s_LOAD_ADDR:
    db "DISK: Loading %4 bytes from %4 to %4",13,10,0

static s_BLOCK_CACHED
s_BLOCK_CACHED:
    db "DISK: (Block was cached)",13,10,0

static s_LOADING_BLOCK
s_LOADING_BLOCK:
    db "DISK: Loading block %4",13,10,0

static s_LOAD_BLOCK_ERROR
s_LOAD_BLOCK_ERROR:
    db "DISK: Error loading block %4: %2",13,10,0

; vim: ft=nasm
