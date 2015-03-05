; 32位编译
[bits 32]
extern stack_start, main, printk

section .text
global idt, gdt, pg_dir, tmp_floppy_area

pg_dir:

global startup_32
startup_32:
   mov eax, 0x10   ;0~8M数据段选择符
   mov ds, eax
   mov es, eax
   mov fs, eax
   mov gs, eax

   lss esp, [stack_start]
   call setup_idt  ;设置 IDT
   call setup_gdt  ;设置 GDT
   mov eax, 0x10
   mov ds, eax
   mov es, eax
   mov fs, eax
   mov gs, eax

   lss esp, [stack_start]


; 检查地址线A20是否开启
    xor eax, eax
test_A20:
    inc eax
    mov [0x0], eax
    cmp eax, [0x100000]
    je test_A20

; 检查数学协处理器
    mov eax, cr0
    and eax, 0x80000011
    or eax, 0x2
    mov cr0, eax
    call check_x87
    jmp after_page_tables

check_x87:
    fninit
    fstsw ax
    cmp al, 0
    je .exist
    mov eax, cr0
    xor eax, 0x6
    mov cr0, eax
    ret
align 4
.exist:
    fsetpm
    ret

setup_idt:
    mov edx, ignore_int
    mov eax, 0x00080000
    mov ax, dx
    mov dx, 0x8E00
    mov edi, idt
    mov ecx, 256
rp_sidt:
    mov [edi], eax
    mov [edi+4], edx
    add edi, 0x8
    dec ecx
    jne rp_sidt
    lidt [idt_descr]
    ret

setup_gdt:
    lgdt [gdt_descr]
    ret

times 0x1000-($-$$) db 0
pg0:

times 0x2000-($-$$) db 0
pg1:

times 0x3000-($-$$) db 0
pg2:

times 0x4000-($-$$) db 0
pg3:

times 0x5000-($-$$) db 0

tmp_floppy_area:
    times 1024 db 0

after_page_tables:
    push 0
    push 0
    push 0
    push L6
    push main
    jmp setup_paging
L6:
    jmp L6

int_msg:
    db "Unknown interrupt\n\r",0

align 4
ignore_int:
    push eax
    push ecx
    push edx
    push ds
    push es
    push fs
    mov eax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    push int_msg
    call printk
    pop eax
    pop fs
    pop es
    pop ds
    pop edx
    pop ecx
    pop eax
    iret

align 4
setup_paging:
    mov ecx, 1024*5
    xor eax, eax
    xor edi, edi
    cld
    rep stosd

    mov dword [pg_dir],    pg0+7
    mov dword [pg_dir+4],  pg1+7
    mov dword [pg_dir+8],  pg2+7
    mov dword [pg_dir+12], pg3+7

    mov edi, pg3+4092
    mov eax, 0xfff007
    std
.fill:
    stosd
    sub eax, 0x1000
    jge .fill
    cld

    xor eax, eax
    mov cr3, eax
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    ret

align 4
    dw 0

idt_descr:
    dw 256*8-1
    dd idt
align 4
    dw 0

gdt_descr:
    dw 256*8-1
    dd gdt

align 8
idt: times 256 dq 0

    
gdt:
    dq 0x0000000000000000
	dq 0x00c09a0000000fff
	dq 0x00c0920000000fff
	dq 0x0000000000000000
    times 252 dq 0
