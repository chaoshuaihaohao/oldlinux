global page_fault
extern do_no_page,do_wp_page

page_fault:
	xchg [esp],eax
	push ecx
	push edx
	push ds
	push es
	push fs
	mov edx,0x10
	mov ds,dx
	mov es,dx
	mov fs,dx
	mov edx,cr2
	push edx
	push eax
	test eax,1
	jne .1
	call do_no_page
	jmp .2
.1:	call do_wp_page
.2:	add esp,8
	pop fs
	pop es
	pop ds
	pop edx
	pop ecx
	pop eax
	iret
