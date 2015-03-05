; weizi 2015-02-15
; Github https://github/weizi1994
; email: 740232441@qq.com
[bits 32]
global  divide_error,debug,nmi,int3,overflow,bounds,invalid_op
global  double_fault,coprocessor_segment_overrun
global  invalid_TSS,segment_not_present,stack_segment
global  general_protection,coprocessor_error,irq13,reserved
global  alignment_check

extern do_overflow,do_invalid_op,do_coprocessor_segment_overrun
extern do_nmi,do_int3,do_debug,do_bounds,do_reserved,do_invalid_TSS
extern do_divide_error,coprocessor_error,do_alignment_check,do_general_protection
extern do_stack_segment,do_double_fault,do_segment_not_present

divide_error:
	push do_divide_error
no_error_code:
	xchg eax,[esp]
	push ebx
	push ecx
	push edx
	push edi
	push esi
	push ebp
	push ds
	push es
	push fs
	push 0		; "error code"
	lea edx,[esp+44]
	push edx
	mov edx,0x10
	mov ds,dx
	mov es,dx
	mov fs,dx
	call eax
	add esp,8
	pop fs
	pop es
	pop ds
	pop ebp
	pop esi
	pop edi
	pop edx
	pop ecx
	pop ebx
	pop eax
	iret

debug:
	push do_int3		; do_debug
	jmp no_error_code

nmi:
	push do_nmi
	jmp no_error_code

int3:
	push do_int3
	jmp no_error_code

overflow:
	push do_overflow
	jmp no_error_code

bounds:
	push do_bounds
	jmp no_error_code

invalid_op:
	push do_invalid_op
	jmp no_error_code

coprocessor_segment_overrun:
	push do_coprocessor_segment_overrun
	jmp no_error_code

reserved:
	push do_reserved
	jmp no_error_code

irq13:
	push eax
	xor al,al
	out 0xF0,al
	mov al,0x20
	out 0x20,al
	jmp .f1
.f1:	out 0xA0,al
	pop eax
	jmp coprocessor_error

double_fault:
	push do_double_fault
error_code:
	xchg eax,[esp+4]		; error code <-> eax
	xchg ebx,[esp]		; &function <-> ebx
	push ecx
	push edx
	push edi
	push esi
	push ebp
	push ds
	push es
	push fs
	push eax			; error code
	lea eax,[esp+44]		; offset
	push eax
	mov eax,0x10
	mov ds,ax
	mov es,ax
	mov fs,ax
	call ebx
	add esp,8
	pop fs
	pop es
	pop ds
	pop ebp
	pop esi
	pop edi
	pop edx
	pop ecx
	pop ebx
	pop eax
	iret

invalid_TSS:
	push do_invalid_TSS
	jmp error_code

segment_not_present:
	push do_segment_not_present
	jmp error_code

stack_segment:
	push do_stack_segment
	jmp error_code

general_protection:
	push do_general_protection
	jmp error_code

alignment_check:
	push do_alignment_check
	jmp error_code
