SETUPLEN equ 4
BOOTSEG equ 0x07c0
INITSEG equ 0x9000
SETUPSEG equ 0x9020
SYSSEG equ 0x1000
SYSSIZE equ 0x3000
ENDSEG equ SYSSEG+SYSSIZE

ROOT_DEV equ 0x0301
SWAP_DEV equ 0x0304


; 将此段代码移动到0x90000,并跳转到
; 移动后的位置执行
start:
    mov ax, BOOTSEG
    mov ds, ax
    mov ax, INITSEG
    mov es, ax
    mov cx, 256
    sub si, si
    sub di, di
    rep movsw
    jmp INITSEG:go

go:
    mov ax, cs
    mov dx, 0xfef4

    mov ds, ax
    mov es, ax

    mov ss, ax
    mov sp, dx


    xor ax, ax
    mov fs, ax
;    mov bx, 0x78
    lds si, [fs:0x78]
    mov di, dx
    mov cx, 6
    cld
    rep movsw

    mov ax, cs
    mov ds, ax

    mov di, dx
    mov byte [es:di+4], 18

    mov [fs:bx], di
    mov [fs:bx+2], es

    mov fs, ax
    mov gs, ax

    xor ah, ah
    xor dl, dl
    int 0x13

load_setup:
    xor dx, dx
    mov cx, 0x0002
    mov bx, 0x0200
    mov ax, 0x0200+SETUPLEN
    int 0x13
    jnc ok_load_setup

    push ax
    call print_nl
    mov bp, sp
    call print_hex
    pop ax

    xor dl, dl
    xor ah, ah
    int 0x13
    jmp load_setup

ok_load_setup:
    xor dl, dl
    mov ah, 0x08
    int 0x13
    xor ch, ch
    mov [sectors], cx
    mov ax, INITSEG
    mov es, ax

    mov ah, 0x03
    xor bh, bh
    int 0x10

    mov cx, 9
    mov bx, 0x7
    mov bp, msg1
    mov ax, 0x1301
    int 0x10

    mov ax, SYSSEG
    mov es, ax
    call read_it
    call kill_motor
    call print_nl

    mov ax,[root_dev]
    or ax, ax
    jne root_defined

    mov bx, [sectors]
    mov ax, 0x0208
    cmp bx, 15
    je root_defined
    mov ax, 0x021c
    cmp bx, 18
    je root_defined

undef_root:
    jmp undef_root
root_defined:
    mov [root_dev], ax

    jmp SETUPSEG:0

sread: dw 1+SETUPLEN
head:  dw 0
track: dw 0

read_it:
    mov ax, es
    test ax, 0xfff
die:
    jne die
    xor bx, bx

rp_read:
    mov ax, es
    cmp ax, ENDSEG
    jb ok1_read
    ret

ok1_read:
    mov ax, [sectors]
    sub ax, [sread]
    mov cx, ax
    shl cx, 9
    add cx, bx
    jnc ok2_read
    je ok2_read

    xor ax, ax
    sub ax, bx
    shr ax, 9

ok2_read:
    call read_track
    mov cx, ax
    add ax, [sread]
    cmp ax, [sectors]
    jne ok3_read

    mov ax, 1
    sub ax, [head]
    jne ok4_read
    inc word [track]

ok4_read:
    mov [head], ax
    xor ax, ax

ok3_read:
    mov [sread], ax
    shl cx, 9
    add bx, cx
    jnc rp_read

    mov ax, es
    add ah, 0x10
    mov es, ax
    xor bx, bx
    jmp rp_read

read_track:
    pusha
    pusha
    mov ax, 0xe2e
    mov bx, 7
    int 0x10
    popa

    mov dx,[track]
    mov cx,[sread]
    inc cx
    mov ch, dl
    mov dx, [head]
    mov dh, dl
    and dx, 0x0100
    mov ah, 2

    push dx
    push cx
    push bx
    push ax

    int 0x13
    jc bad_rt
    add sp, 8
    popa
    ret

bad_rt:
    push ax
    call print_all

    xor ah, ah
    xor dl, dl
    int 0x13

    add sp, 10
    popa
    jmp read_track

print_all:
    mov cx, 5
    mov bp, sp

print_loop:
    push cx
    call print_nl
    jae no_reg

    mov ax, 0xe05 + 0x41 - 1
    sub al, cl
    int 0x10

    mov al, 0x58
    int 0x10

    mov al, 0x3a
    int 0x10

no_reg:
    add bp, 2
    call print_hex
    pop cx
    loop print_loop
    ret

print_nl:
    mov ax, 0xe0d
    int 0x10
    mov al, 0xa
    int 0x10
    ret


print_hex:
    mov cx, 4
    mov dx, [bp]

print_digit:
    rol dx, 4
    mov ah, 0xe
    mov al, dl
    and al, 0xf

    add al, 0x30
    cmp al, 0x39
    jbe good_digit
    add al, 0x41 - 0x30 - 0xa
good_digit:
    int 0x10
    loop print_digit
    ret

kill_motor:
    push dx
    mov dx, 0x3f2
    xor al, al
    out dx, al
    pop dx
    ret

sectors dw 0
msg1 db 13, 10,'Loading'

times 506 - ($-$$) db 0
    
swap_dev dw SWAP_DEV
root_dev dw ROOT_DEV
boot_flag dw 0xaa55


