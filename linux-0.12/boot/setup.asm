INITSEG  equ 0x9000
SYSSEG   equ 0x1000
SETUPSEG equ 0x9020

start:
	mov	ax,INITSEG
	mov	ds,ax

; BIOS中断0x15， 功能号 ah=0x88
; 获取扩展内存的大小值(KB).
; 返回：ax 从0x100000(1M)处开始的扩展内存大小(KB)
	mov	ah,0x88
	int	0x15
	mov	[2],ax

; BIOS中断0x10， 功能号 ah=0x12, bl=0x10
; 检查显示方式(EGA/VGA)并获取参数。
	mov	ah,0x12
	mov	bl,0x10
	int	0x10
	mov	[8],ax
	mov	[10],bx
	mov	[12],cx

; 检测屏幕当前行列值
	mov	ax,0x5019
	cmp	bl,0x10
	je	novga
	call	chsvga

novga:
    mov	[14],ax ;保存屏幕当前行列值


; BIOS中断0x10， 功能号 ah=0x03
; 输入 bh=页号
; 返回 dh=行号 dl=列号
	mov	ah,0x03
	xor	bh,bh
	int	0x10
	mov	[0],dx

; BIOS中断0x10， 功能号 ah=0x0f
; 取显卡当前显示模式
	mov	ah,0x0f
	int	0x10
	mov	[4],bx
	mov	[6],ax

; 取第一个硬盘的信息
	mov	ax,0x0000
	mov	ds,ax
	lds	si,[4*0x41]
	mov	ax,INITSEG
	mov	es,ax
	mov	di,0x0080
	mov	cx,0x10
	rep
	movsb

; 取第二个硬盘的信息
	mov	ax,0x0000
	mov	ds,ax
	lds	si,[4*0x46]
	mov	ax,INITSEG
	mov	es,ax
	mov	di,0x0090
	mov	cx,0x10
	rep
	movsb

; 判断是否有第二个硬盘
	mov	ax,0x01500
	mov	dl,0x81
	int	0x13
	jc	no_disk1
	cmp	ah,3
	je	is_disk1

; 没有第二个硬盘， 将第二个硬盘的参数清空
no_disk1:
	mov	ax,INITSEG
	mov	es,ax
	mov	di,0x0090
	mov	cx,0x10
	mov	ax,0x00
	rep
	stosb

is_disk1:
	cli  ;关闭中断
	cld
	mov	ax,0x0000

; 将system模块从0x10000移动到0x00000
do_move:
	mov	es,ax
	add	ax,0x1000
	cmp	ax,0x9000
	jz	end_move
	mov	ds,ax
	sub	di,di
	sub	si,si
	mov cx,0x8000
	rep
	movsw
	jmp	do_move

end_move:
	mov	ax,SETUPSEG
	mov	ds,ax
	lidt	[idt_48]  ;加载IDTR
	lgdt	[gdt_48]  ;加载GDTR


; 开启地址线A20(更改了原linux-0.12 setup.S 代码)
    in al, 0x92
    or al, 0x02
    out 0x92, al

; 开始初始化中断控制器Intel 8259A芯片
; ICW1
	mov	al,0x11 ;使用ICW4，级联，使用ICW3
	out	0x20,al
	out	0xA0,al

; ICW2 设置中断号
	mov	al,0x20 ; 主片起始中断号 0x20
	out	0x21,al
	mov	al,0x28 ; 从片起始中断号 0x28
	out	0xA1,al

; ICW3
	mov	al,0x04 ; 主片,从片接在主片的IR2
	out	0x21,al
	mov	al,0x02
	out	0xA1,al

; ICW4
	mov	al,0x01 ; 8086/8088模式,普通EOI, 无缓冲模式
	out	0x21,al
	out	0xA1,al
; 完成初始化中断控制器Intel 8259A芯片

; OCW1 中断屏蔽字寄存器IMR
	mov	al,0xFF  ;屏蔽所有中断
	out	0x21,al
	out	0xA1,al

; 开启保护模式
	mov	eax, cr0
	or eax,0x01
    mov cr0, eax
	jmp	0x08:0x00

chsvga:
    cld
	push ds
	push cs
	pop	ds
	mov ax,0xc000
	mov	es,ax
	mov	si,msg1
	call prtstr
nokey:
    in al,0x60
	cmp	al,0x82
	jb nokey
	cmp	al,0xe0
	ja nokey
	cmp	al,0x9c
	je	svga
	mov	ax,0x5019
	pop	ds
	ret
svga:	mov 	si,idati
	mov	di,0x31
	mov 	cx,0x09
	repe
	cmpsb
	jne	noati
	mov	si,dscati
	mov	di,moati
	mov	cx,selmod
	jmp	cx
noati:	mov	ax,0x200f
	mov	dx,0x3ce
	out	dx,ax
	inc	dx
	in	al,dx
	cmp	al,0x20
	je	isahed
	cmp	al,0x21
	jne	noahed
isahed:	mov	si,dscahead
	mov	di,moahead
	mov	cx,selmod
	jmp	cx
noahed:	mov	dx,0x3c3
	in	al,dx
	or	al,0x10
	out	dx,al
	mov	dx,0x104
	in	al,dx
	mov	bl,al
	mov	dx,0x3c3
	in	al,dx
	and	al,0xef
	out	dx,al
	cmp	bl,[idcandt]
	jne	nocant
	mov	si,dsccandt
	mov	di,mocandt
	mov	cx,selmod
	jmp	cx
nocant:	mov	dx,0x3d4
	mov	al,0x0c
	out	dx,al
	inc	dx
	in	al,dx
	mov	bl,al
	xor	al,al
	out	dx,al
	dec	dx
	mov	al,0x1f
	out	dx,al
	inc	dx
	in	al,dx
	mov	bh,al
	xor	ah,ah
	shl	al,4
	mov	cx,ax
	mov	al,bh
	shr	al,4
	add	cx,ax
	shl	cx,8
	add	cx,6
	mov	ax,cx
	mov	dx,0x3c4
	out	dx,ax
	inc	dx
	in	al,dx
	and	al,al
	jnz	nocirr
	mov	al,bh
	out	dx,al
	in	al,dx
	cmp	al,0x01
	jne	nocirr
	call	rst3d4
	mov	si,dsccirrus
	mov	di,mocirrus
	mov	cx,selmod
	jmp	cx
rst3d4:	mov	dx,0x3d4
	mov	al,bl
	xor	ah,ah
	shl	ax,8
	add	ax,0x0c
	out	dx,ax
	ret
nocirr:	call	rst3d4
	mov	ax,0x7000
	xor	bx,bx
	int	0x10
	cmp	al,0x70
	jne	noevrx
	shr	dx,4
	cmp	dx,0x678
	je	istrid
	cmp	dx,0x236
	je	istrid
	mov	si,dsceverex
	mov	di,moeverex
	mov	cx,selmod
	jmp	cx
istrid:	mov	cx,ev2tri
	jmp	cx
noevrx:	mov	si,idgenoa
	xor 	ax,ax
	mov	al,[es:0x37]
	mov	di,ax
	mov	cx,0x04
	dec	si
	dec	di
l1:	inc	si
	inc	di
	mov	al,[si]
	and	al,[es:di]
	cmp	al,[si]
	loope 	l1
	cmp	cx,0x00
	jne	nogen
	mov	si,dscgenoa
	mov	di,mogenoa
	mov	cx,selmod
	jmp	cx
nogen:	mov	si,idparadise
	mov	di,0x7d
	mov	cx,0x04
	repe
	cmpsb
	jne	nopara
	mov	si,dscparadise
	mov	di,moparadise
	mov	cx,selmod
	jmp	cx
nopara:	mov	dx,0x3c4
	mov	al,0x0e
	out	dx,al
	inc	dx
	in	al,dx
	xchg	ah,al
	mov	al,0x00
	out	dx,al
	in	al,dx
	xchg	al,ah
	mov	bl,al
	and	bl,0x02
	jz	setb2
	and	al,0xfd
	jmp	clrb2
setb2:	or	al,0x02
clrb2:	out	dx,al
	and	ah,0x0f
	cmp	ah,0x02
	jne	notrid
ev2tri:	mov	si,dsctrident
	mov	di,motrident
	mov	cx,selmod
	jmp	cx
notrid:	mov	dx,0x3cd
	in	al,dx
	mov	bl,al
	mov	al,0x55
	out	dx,al
	in	al,dx
	mov	ah,al
	mov	al,bl
	out	dx,al
	cmp	ah,0x55
 	jne	notsen
	mov	si,dsctseng
	mov	di,motseng
	mov	cx,selmod
	jmp	cx
notsen:	mov	dx,0x3cc
	in	al,dx
	mov	dx,0x3b4
	and	al,0x01
	jz	even7
	mov	dx,0x3d4
even7:	mov	al,0x0c
	out	dx,al
	inc	dx
	in	al,dx
	mov	bl,al
	mov	al,0x55
	out	dx,al
	in	al,dx
	dec	dx
	mov	al,0x1f
	out	dx,al
	inc	dx
	in	al,dx
	mov	bh,al
	dec	dx
	mov	al,0x0c
	out	dx,al
	inc	dx
	mov	al,bl
	out	dx,al
	mov	al,0x55
	xor	al,0xea
	cmp	al,bh
	jne	novid7
	mov	si,dscvideo7
	mov	di,movideo7
selmod:	push	si
	mov	si,msg2
	call	prtstr
	xor	cx,cx
	mov	cl,[di]
	pop	si
	push	si
	push	cx
tbl:	pop	bx
	push	bx
	mov	al,bl
	sub	al,cl
	call	dprnt
	call	spcing
	lodsw
	xchg	al,ah
	call	dprnt
	xchg	ah,al
	push	ax
	mov	al,0x78
	call	prnt1
	pop	ax
	call	dprnt
	call	docr
	loop	tbl
	pop	cx
	call	docr
	mov	si,msg3
	call	prtstr
	pop	si
	add	cl,0x80
nonum:	in	al,0x60
	cmp	al,0x82
	jb	nonum
	cmp	al,0x8b
	je	zero
	cmp	al,cl
	ja	nonum
	jmp	nozero
zero:	sub	al,0x0a
nozero:	sub	al,0x80
	dec	al
	xor	ah,ah
	add	di,ax
	inc	di
	push	ax
	mov	al,[di]
	int 	0x10
	pop	ax
	shl	ax,1
	add	si,ax
	lodsw
	pop	ds
	ret
novid7:	pop	ds
	mov	ax,0x5019
	ret

spcing:	mov	al,0x2e
	call	prnt1
	mov	al,0x20
	call	prnt1
	mov	al,0x20
	call	prnt1
	mov	al,0x20
	call	prnt1
	mov	al,0x20
	call	prnt1
	ret

prtstr:	lodsb
	and	al,al
	jz	fin
	call	prnt1
	jmp	prtstr
fin:	ret

dprnt:	push	ax
	push	cx
	mov	ah,0x00
	mov	cl,0x0a
	idiv	cl
	cmp	al,0x09
	jbe	lt100
	call	dprnt
	jmp	skip10
lt100:	add	al,0x30
	call	prnt1
skip10:	mov	al,ah
	add	al,0x30
	call	prnt1
	pop	cx
	pop	ax
	ret

prnt1:	push	ax
	push	cx
	mov	bh,0x00
	mov	cx,0x01
	mov	ah,0x0e
	int	0x10
	pop	cx
	pop	ax
	ret

docr:	push	ax
	push	cx
	mov	bh,0x00
	mov	ah,0x0e
	mov	al,0x0a
	mov	cx,0x01
	int	0x10
	mov	al,0x0d
	int	0x10
	pop	cx
	pop	ax
	ret

gdt:
	dw	0,0,0,0

	dd	0x000007FF       ;选择符0x08，基地址0x00000000，界限0x7FF，粒度4KB，总共8M，DPL=0
	dd	0x00C09A00       ;32位代码段，可读

	dd	0x000007FF       ;选择符0x10，基地址0x00000000，界限0x7FF，粒度4KB，总共8M，DPL=0
	dd	0x00C09200       ;32位数据段，可写

idt_48:
	dw	0
	dw	0,0

gdt_48:
	dw	0x800
	dw	512+gdt,0x9

msg1:		db	"Press <RETURN> to see SVGA-modes available or any other key to continue."
		db	0x0d, 0x0a, 0x0a, 0x00
msg2:		db	"Mode:  COLSxROWS:"
		db	0x0d, 0x0a, 0x0a, 0x00
msg3:		db	"Choose mode by pressing the corresponding number."
		db	0x0d, 0x0a, 0x00

idati:		db	"761295520"
idcandt:	db	0xa5
idgenoa:	db	0x77, 0x00, 0x66, 0x99
idparadise:	db	"VGA="

moati:		db	0x02,	0x23, 0x33
moahead:	db	0x05,	0x22, 0x23, 0x24, 0x2f, 0x34
mocandt:	db	0x02,	0x60, 0x61
mocirrus:	db	0x04,	0x1f, 0x20, 0x22, 0x31
moeverex:	db	0x0a,	0x03, 0x04, 0x07, 0x08, 0x0a, 0x0b, 0x16, 0x18, 0x21, 0x40
mogenoa:	db	0x0a,	0x58, 0x5a, 0x60, 0x61, 0x62, 0x63, 0x64, 0x72, 0x74, 0x78
moparadise:	db	0x02,	0x55, 0x54
motrident:	db	0x07,	0x50, 0x51, 0x52, 0x57, 0x58, 0x59, 0x5a
motseng:	db	0x05,	0x26, 0x2a, 0x23, 0x24, 0x22
movideo7:	db	0x06,	0x40, 0x43, 0x44, 0x41, 0x42, 0x45

dscati:		dw	0x8419, 0x842c
dscahead:	dw	0x842c, 0x8419, 0x841c, 0xa032, 0x5042
dsccandt:	dw	0x8419, 0x8432
dsccirrus:	dw	0x8419, 0x842c, 0x841e, 0x6425
dsceverex:	dw	0x5022, 0x503c, 0x642b, 0x644b, 0x8419, 0x842c, 0x501e, 0x641b, 0xa040, 0x841e
dscgenoa:	dw	0x5020, 0x642a, 0x8419, 0x841d, 0x8420, 0x842c, 0x843c, 0x503c, 0x5042, 0x644b
dscparadise:	dw	0x8419, 0x842b
dsctrident:	dw 	0x501e, 0x502b, 0x503c, 0x8419, 0x841e, 0x842b, 0x843c
dsctseng:	dw	0x503c, 0x6428, 0x8419, 0x841c, 0x842c
dscvideo7:	dw	0x502b, 0x503c, 0x643c, 0x8419, 0x842c, 0x841c
