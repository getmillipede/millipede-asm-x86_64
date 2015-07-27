[BITS 64]
org 0xBA400000

;;;
;;; ELF HEADER
;;; 
elf_hdr:
	.magic db 0x7f, 'E', 'L', 'F'             ; ELF magic number
	.class db 0x02		                  ; class ELF64
	.data  db 0x01		                  ; little endian
	.vers  db 0x01		                  ; file version
	.binty db 0x09				  ; bin type
	.zero  db 0,0,0,0,0,0,0,0                 ; zerooooooooooo
	.type  dw 0x0002	                  ; ELF EXEC
	.mach  dw 0x003e	                  ; AMD x86_64
	.overs dd 0x00000001	                  ; object file version 1
	.entry dq _start	                  ; entry point
	.phoff dq prog_hdr - $$	                  ; program header offset
	.shoff dq 0      	                  ; section header offset
	.flags dd 0x00000000	                  ; processor-specific flags
	.ehsz  dw elf_hdr.end - elf_hdr           ; ELF header size
	.phsz  dw 56                              ; program header size
	.phent dw (prog_hdr_end - prog_hdr) / 56  ; n of program header entries
	.shsz  dw 64                      	  ; section header size
	.shent dw 0				  ; n of section header entries
	.shstr dw 0			          ; string table index
	.end:

;;;
;;; PROGRAM HEADER
;;; 
prog_hdr:
prog_idx0:
	.type  dd 0x00000001	                  ; type LOAD
	.flags dd 0x00000005			  ; RX
	.offs  dq code_start - $$		  ; offset from file start
	.vaddr dq code_start			  ; link addr
	.paddr dq 0				  ; reserved
	.flsz  dq code_end - code_start		  ; size in file
	.memsz dq code_end - code_start		  ; size in mem
	.align dq 0x0000000000000010		  ; alignment
prog_idx1:
	.type  dd 0x00000001	                  ; type LOAD
	.flags dd 0x00000006			  ; RW
	.offs  dq 0				  ; offset from file start
	.vaddr dq bss_start			  ; link addr
	.paddr dq 0				  ; reserved
	.flsz  dq 0				  ; size in file
	.memsz dq bss_end - bss_start		  ; size in mem
	.align dq 0x0000000000001000		  ; alignment
prog_idx2:
	.type  dd 0x00000004	                  ; type NOTE
	.flags dd 0x00000004			  ; R
	.offs  dq _note_open - $$		  ; offset from file start
	.vaddr dq _note_open		  	  ; link addr
	.paddr dq 0				  ; reserved
	.flsz  dq _note_open_end - _note_open	  ; size in file
	.memsz dq _note_open_end - _note_open	  ; size in mem
	.align dq 0x0000000000000002		  ; alignment
prog_idx3:
	.type  dd 0x00000004	                  ; type NOTE
	.flags dd 0x00000004			  ; R
	.offs  dq _note_net - $$		  ; offset from file start
	.vaddr dq _note_net			  ; link addr
	.paddr dq 0				  ; reserved
	.flsz  dq _note_net_end - _note_net	  ; size in file
	.memsz dq _note_net_end - _note_net	  ; size in mem
	.align dq 0x0000000000000002		  ; alignment
prog_hdr_end:

;;;
;;; NOTE SECTION for OpenBSD
;;;
align 2
_note_open:
	dd 0x00000008
	dd 0x00000004
	dd 0x00000001
	db 'O', 'p', 'e', 'n', 'B', 'S', 'D', 0
	dd 0
_note_open_end:

;;;
;;; NOTE SECTION for NetBSD
;;;
align 2
_note_net:
	dd 0x00000007
	dd 0x00000004
	dd 0x00000001
	db 'N', 'e', 't', 'B', 'S', 'D', 0, 0
	dd 200000000
_note_net_end:

;;;
;;; CODE section
;;; 
align 16
code_start:

;;; exit
;;; in : rdi - exit code
;;; out: none
exit:
	mov rax, 1
	mov r15, 60
	cmp byte [rel ostype], 3
	cmove rax, r15
	syscall
ret

;;; nanosleep
;;; in : none
;;; out: none
nanosleep:
	push r9
	push r10
	xor rsi, rsi
	mov rdi, timeout
	mov rax, 91
	mov r15, 240
	cmp byte [rel ostype], 2
	cmove rax, r15
	mov r15, 35
	cmp byte [rel ostype], 3
	cmove rax, r15
	syscall
.end:
	pop r10
	pop r9
ret
	
;;; strlen
;;; in : rdi - pointer to string
;;; out: rax - len
strlen:
	xor al, al
	mov rcx, -1
	repne scasb
	mov rax, -2
	sub rax, rcx	
ret
	
;;; write
;;; in : rsi - pointer to string
;;; out: none
write:
	push rcx
	push r8
	push r9
	push r10
	mov rdi, rsi
	call strlen
	mov rdx, rax
        mov rax, 4
	mov r15, 1
	cmp byte [rel ostype], 3
	cmove rax, r15
	mov rdi, 1		; stdout
	syscall
	pop r10
	pop r9
	pop r8
	pop rcx
ret

;;; strcpy
;;; in : rsi - str to copy
;;;    : rdi - destination
;;; out: none
strcpy:
	mov al, [rsi]
	inc rsi
	mov [rdi], al
	inc rdi
	cmp al, 0
	jne strcpy
ret

;;; tonum
;;; in : rsi str ptr
;;; out: rax num
tonum:
	push rcx
	mov rdi, rsi
	call strlen
	cmp rax, 0
	je .end
	mov rcx, rsi
	add rcx, rax
	dec rcx
	dec rsi
	xor rax, rax
	xor r11, r11
.loop:
	xor rbx, rbx
	mov bl, [rcx]
	cmp bl, '0'
	jb .end
	cmp bl, '9'
	ja .end
	sub bl, '0'
	xor r12, r12
	mov r13, rbx
.loop2:
	cmp r12, r11
	je .endloop2
	shl r13, 3
	shl rbx, 1
	add r13, rbx
	inc r12
	jmp .loop2
.endloop2:
	add rax, r13
	dec rcx
	cmp rcx, rsi
	je .end
	inc r11
	jmp .loop
.end:
	pop rcx
ret	
	
;;; arg_parse
;;; in : none
;;; out: none
arg_parse:
	mov r8, 1
	mov rcx, [rel argv]
.loop:	
	cmp r8, [rel argc]
	je .end
	mov r9, [rcx]
	cmp byte [r9], '-'
	je .match
	cmp qword [rel text], 0
	jne .argerr
	mov [rel text], r9
.next:
	inc r8
	add rcx, 8
	jmp .loop
.match:
	cmp byte [r9 + 1], 'r'
	je .set_reverse
	cmp byte [r9 + 1], 's'
	je .check_size
	cmp byte [r9 + 1], 'a'
	je .set_animate
.argerr:
	mov rsi, arg_error
	call write
	mov rdi, 1
	call exit
.set_animate:
	cmp byte [r9 + 2], 0
	jne .argerr
	or byte [rel mode], 2
	jmp .next
.set_reverse:
	cmp byte [r9 + 2], 0
	jne .argerr
	or byte [rel mode], 1
	jmp .next
.check_size:
	cmp byte [r9 + 2], 0
	jne .argerr	
	inc r8
	add rcx, 8
	cmp r8, [rel argc]
	je .argerr
	mov rsi, [rcx]
	call tonum
	cmp rax, 0
	je .argerr
	mov [rel size], ax
	jmp .next
.end:
ret

;;; spaces
;;; in : rcx number of spaces to print
;;; out: none
spaces:
	cmp rcx, 0
	je .end
	mov rsi, milli_space
	call write
	dec rcx
	jmp spaces
.end:
ret
	
;;; millipede
;;; in : none
;;; out: none
millipede:
	xor r8, r8
	mov r8w, [rel size]
	mov r9, 3		; start offset
	mov r10, -1		; offset direction
.restart:
	test byte [rel mode], 1
	jne .start
	cmp qword [rel text], 0
	je .next3
	mov rsi, [rel text]
	call write
	mov rsi, milli_nl
	call write
	mov rsi, milli_nl
	call write
.next3:
	mov rcx, r9
	add rcx, 2
	call spaces
	mov rsi, milli_head
	call write	
.start:	
	mov rcx, r9
	call spaces
	mov rsi, milli_body
	call write
	dec r8d
	cmp r8d, 0
	je .endloop
	add r9, r10		; increment/decrement the counter
	cmp r9, -1
	jne .next2
	neg r10			; change direction
	mov r9, 1
	jmp .start
.next2:
	cmp r9, 4
	jne .start
	neg r10			; change direction
	mov r9, 3
	jmp .start
.endloop:
	test byte [rel mode], 1
	je .end
	mov rcx, r9
	add rcx, 2
	call spaces
	mov rsi, milli_head
        call write
	cmp qword [rel text], 0
	je .end
	mov rsi, milli_nl
	call write
	mov rsi, [rel text]
	call write
	mov rsi, milli_nl
	call write
.end:
	test byte [rel mode], 2
	je .ret
	mov qword [rel timeout], 0
	mov dword [rel timeout + 8], 100000000
	call nanosleep
	mov rsi, milli_clear
	call write
	xor r8, r8
	mov r8w, [rel size]
	jmp .restart
.ret:
ret

;;; milli_gen
;;; in : none
;;; out: none
milli_gen:
	mov rsi, ro_milli_head
	mov rdi, milli_head
	call strcpy
	mov rsi, ro_milli_body
	mov rdi, milli_body
	call strcpy
	test byte [rel mode], 1
	je .end
	;; mode is reverse we have to invert mandible and legs
	mov byte [rel milli_head + 2], 0x94
	mov byte [rel milli_head + 12], 0x97
	mov byte [rel milli_body + 2], 0x94
	mov byte [rel milli_body + 22], 0x97
.end:
ret
	
;;; our entry point
_start:
	;; try to detect if we run under linux
	cmp rcx, 0
	jne openbsd
	cmp rdi, 0
	jne freebsd
	mov byte [rel ostype], 3
	jmp get_arg
freebsd:
	mov byte [rel ostype], 2
	;; save argc
	mov rax, [rdi]
	mov [rel argc], rax
	;; save argv
	mov rax, rdi
	add rax, 16
	mov [rel argv], rax
	jmp start
openbsd:
	mov byte [rel ostype], 1
get_arg:
	;; save argc
	mov rax, [rsp]
	mov [rel argc], rax
	;; save argv
	mov rax, rsp
	add rax, 16
	mov [rel argv], rax

start:
	;; set defaults
	mov word [rel size], 20
	mov byte [rel mode], 0
	mov qword [rel text], 0

	;; check if we have arguments
	cmp qword [rel argc], 2
	jl no_args
	call arg_parse
no_args:	

	;; generate correst body/head parts
	call milli_gen
	
	;; print !
	call millipede

	;; exit
	xor rdi, rdi
	call exit

;;; some RO data at the end of code segment
milli_nl:
	db 0xa, 0
milli_space:
	db 0x20, 0
milli_clear:
	db 0x1b, '[', '2', 'J', 0x1b, '[', ';', 'H', 0
ro_milli_head:
	db 0xe2, 0x95, 0x9a	; open mandible
	db 0xe2, 0x8a, 0x99	; eye
	db 0x20			; space
	db 0xe2, 0x8a, 0x99	; eye
	db 0xe2, 0x95, 0x9d	; close mandible
	db 0xa			; \n
	db 0			; \0
ro_milli_head_end:
ro_milli_body:
	db 0xe2, 0x95, 0x9a	; right leg
	db 0xe2, 0x95, 0x90	; leg part
	db 0x28			; open chest
	db 0xe2, 0x96, 0x88	; chest part 1
	db 0xe2, 0x96, 0x88	; chest part 2
	db 0xe2, 0x96, 0x88	; chest part 3
	db 0x29			; close chest
	db 0xe2, 0x95, 0x90	; leg part
	db 0xe2, 0x95, 0x9d	; left leg
	db 0xa			; \n
	db 0			; \0
ro_milli_body_end:
	
arg_error:
	db 'argument parse error', 0xa, 0
	
;;;
;;; END of CODE section
;;; 
code_end:

;;;
;;; BSS section
;;;
section .bss
align 4096
bss_start:

ostype:		resb 1
argc:		resq 1
argv:		resq 1
size:		resw 1
mode:		resb 1
text:		resq 1
milli_head:	resb ro_milli_head_end - ro_milli_head
milli_body:	resb ro_milli_body_end - ro_milli_body
timeout:	resq 2
	
;;;
;;; END of BSS section
;;;
bss_end:
