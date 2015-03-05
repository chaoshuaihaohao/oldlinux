 ; linux/kernel/system_call.asm
 ; just change linux/kernel/system_call.s to nasm assemble
 ; 2015 weizi

 ; system_call.s  contains the system-call low-level handling routines.
 ; This also contains the timer-interrupt handler, as some of the code is
 ; the same. The hd- and flopppy-interrupts are also here.
 ;
 ; NOTE: This code handles signal-recognition, which happens every time
 ; after a timer-interrupt and after each system call. Ordinary interrupts
 ; don't handle signal-recognition, as that would clutter them up totally
 ; unnecessarily.
 ;
 ; Stack layout in 'ret_from_system_call':
 ;
 ;	[esp+0x0]  - eax
 ;	[esp+0x4]  - ebx
 ;	[esp+0x8]  - ecx
 ;	[esp+0xC]  - edx
 ;	[esp+0x10] - original eax	(-1 if not system call)
 ;	[esp+0x14] - fs
 ;	[esp+0x18] - es
 ;	[esp+0x1C] - ds
 ;	[esp+0x20] - eip
 ;	[esp+0x24] - cs
 ;	[esp+0x28] - eflags
 ;	[esp+0x2C] - oldesp
 ;	[esp+0x30] - oldss

SIG_CHLD	equ 17

EAX_OFF		equ 0x00
EBX_OFF		equ 0x04
ECX_OFF		equ 0x08
EDX_OFF		equ 0x0C
ORIG_EAX_OFF	equ 0x10
FS_OFF		equ 0x14
ES_OFF		equ 0x18
DS_OFF		equ 0x1C
EIP_OFF		equ 0x20
CS_OFF		equ 0x24
EFLAGS_OFF	equ 0x28
OLDESP_OFF	equ 0x2C
OLDSS_OFF	equ 0x30

state	equ 0		; these are offsets into the task-struct.
counter	equ 4
priority equ 8
signal	equ 12
sigaction equ 16		; MUST be 16 (=len of sigaction)
blocked equ (33*16)

; offsets within sigaction
sa_handler equ 0
sa_mask equ 4
sa_flags equ 8
sa_restorer equ 12

nr_system_calls equ 82

ENOSYS equ 38

 ; Ok, I get parallel printer interrupts while using the floppy for some
 ; strange reason. Urgel. Now I just ignore them.
[bits 32]
global system_call,sys_fork,timer_interrupt,sys_execve
global hd_interrupt,floppy_interrupt,parallel_interrupt
global device_not_available, coprocessor_error

extern schedule,NR_syscalls,sys_call_table,current,task
extern do_signal,math_error,math_state_restore,math_emulate
extern jiffies,do_timer,do_execve,find_empty_process,copy_process
extern hd_timeout,do_hd,unexpected_hd_interrupt,do_floppy,unexpected_floppy_interrupt

align 4
bad_sys_call:
	push -ENOSYS
	jmp ret_from_sys_call
align 4
reschedule:
	push ret_from_sys_call
	jmp schedule
align 4
system_call:
	push ds
	push es
	push fs
	push eax		; save the orig_eax
	push edx		
	push ecx		; push ebx,ecx,edx as parameters
	push ebx		; to the system call
	mov edx,0x10		; set up ds,es to kernel space
	mov ds,dx
	mov es,dx
	mov edx,0x17	; fs points to local data space
	mov fs,dx
	cmp eax,NR_syscalls
	jae bad_sys_call
	call [eax*4+sys_call_table]
	push eax
.2:
	mov eax,[current]
	cmp dword [eax+state],0		; state
	jne reschedule
	cmp dword [eax+counter],0		; counter
	je reschedule
ret_from_sys_call:
	mov eax,[current]
	cmp eax,[task]		; task[0] cannot have signals
	je ret_from_sys_call.3
	cmp word [esp+CS_OFF],0x0f		; was old code segment supervisor ?
	jne ret_from_sys_call.3
	cmp word [esp+OLDSS_OFF],0x17		; was stack segment = 0x17 ?
	jne ret_from_sys_call.3
	mov ebx,[eax+signal]
	mov ecx,[eax+blocked]
	not ecx
	and ecx,ebx
	bsf ecx,ecx
	je ret_from_sys_call.3
	btr ebx,ecx
	mov [eax+signal],ebx
	inc ecx
	push ecx
	call do_signal
	pop ecx
	test eax, eax
	jne system_call.2		; see if we need to switch tasks, or do more signals
.3:	pop eax
	pop ebx
	pop ecx
	pop edx
	add esp,4 	; skip orig_eax
	pop fs
	pop es
	pop ds
	iret

align 4
coprocessor_error:
	push ds
	push es
	push fs
	push -1		; fill in -1 for orig_eax
	push edx
	push ecx
	push ebx
	push eax
	mov eax,0x10
	mov ds,ax
	mov es,ax
	mov eax,0x17
	mov fs,ax
	push ret_from_sys_call
	jmp math_error

align 4
device_not_available:
	push ds
	push es
	push fs
	push -1		; fill in -1 for orig_eax
	push edx
	push ecx
	push ebx
	push eax
	mov eax,0x10
	mov ds,ax
	mov es,ax
	mov eax,0x17
	mov fs,ax
	push ret_from_sys_call
	clts				; clear TS so that we can use math
	mov eax,cr0
	test eax,0x4			; EM (math emulation bit)
	je math_state_restore
	push ebp
	push esi
	push edi
	push 0		; temporary storage for ORIG_EIP
	call math_emulate
	add esp,4
	pop edi
	pop esi
	pop ebp
	ret

align 4
timer_interrupt:
	push ds		; save ds,es and put kernel data space
	push es		; into them. fs is used by system_call
	push fs
	push -1		; fill in -1 for orig_eax
	push edx		; we save eax,ecx,edx as gcc doesn't
	push ecx		; save those across function calls. ebx
	push ebx		; is saved as we use that in ret_sys_call
	push eax
	mov eax,0x10
	mov ds,ax
	mov es,ax
	mov eax,0x17
	mov fs,ax
	inc dword [jiffies]
	mov al,0x20		; EOI to interrupt controller ;1
	out 0x20,al
	mov eax,[esp+CS_OFF]
	and eax,3	; eax is CPL (0 or 3, 0=supervisor)
	push eax
	call do_timer		; 'do_timer(long CPL)' does everything from
	add esp,4		; task switching to accounting ...
	jmp ret_from_sys_call

align 4
sys_execve:
	lea eax,[esp+EIP_OFF]
	push eax
	call do_execve
	add esp,4
	ret

align 4
sys_fork:
	call find_empty_process
	test eax,eax
	js sys_fork.1
	push gs
	push esi
	push edi
	push ebp
	push eax
	call copy_process
	add esp,20
.1:	ret

hd_interrupt:
	push eax
	push ecx
	push edx
	push ds
	push es
	push fs
	mov eax,0x10
	mov ds,ax
	mov es,ax
	mov eax,0x17
	mov fs,ax
	mov al,0x20
	out 0xA0,al		; EOI to interrupt controller ;1
	jmp hd_interrupt.1	; give port chance to breathe
.1:	xor edx,edx
	mov edx,hd_timeout
	xchg edx,[do_hd]
	test edx,edx
	jne hd_interrupt.2
	mov edx,unexpected_hd_interrupt
.2:	out 0x20,al
	call edx		; "interesting" way of handling intr.
	pop fs
	pop es
	pop ds
	pop edx
	pop ecx
	pop eax
	iret

floppy_interrupt:
	push eax
	push ecx
	push edx
	push ds
	push es
	push fs
	mov eax,0x10
	mov ds,ax
	mov es,ax
	mov eax,0x17
	mov fs,ax
	mov al,0x20
	out 0x20,al		; EOI to interrupt controller ;1
	xor eax,eax
	xchg [do_floppy],eax
	test eax,eax
	jne floppy_interrupt.1
	mov eax,unexpected_floppy_interrupt
.1:	call eax		; "interesting" way of handling intr.
	pop fs
	pop es
	pop ds
	pop edx
	pop ecx
	pop eax
	iret

parallel_interrupt:
	push eax
	mov al,0x20
	out 0x20,al
	pop eax
	iret
