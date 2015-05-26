.include "m2560def.inc"

; This program loads a string from PROM
; then loads the string by byte into the stack
; then puts the string in reverse order to the data memory

.equ length = 12
.def counter = r18
.def temp = r19

; Data memory init
.dseg
.org 0x500
reversed_string: .byte 12

; Program memory init
.cseg rjmp main; skip the initialization

my_string: .db "my world",0

main:
	; initializing the stack pointer
	ldi r16, low(RAMEND-4)	; 4 is the number of bytes
	ldi r17, high(RAMEND-4)	; for local variables in main
	out SPL, r16
	out SPH, r17

	; initialize a pointer to the string in PROM
	ldi zl, low(my_string << 1)
	ldi zh, high(my_string << 1)
	; initialize a pointer to the string in RAM
	ldi yl, low(reversed_string)
	ldi yh, high(reversed_string)
	clr counter; index in the string = 0
	; load null terminate in the beginning of the stack
	ldi temp, 0
	push temp

; a loop to load the string into the stack
load_to_stack:
	lpm temp, z+		; load a character in r16
	push temp 			; push the byte in temp into stack
	inc counter			; increment counter
	cpi counter, length-1	; if counter == length
	breq load_to_ram	; go to the loop to load from stack into data mem
	rjmp load_to_stack	; otherwise keep running the loop
	
; load from the stack into ram by using pop
load_to_ram:
	clr counter				; clear the counter again

load_to_ram_loop:
	pop temp				; pop the value into temp
	st y+, temp				; load whatever was in temp into RAM
	inc counter				; incremennt the counter
	cpi counter, length		; if counter == length
	breq end				; end the program
	rjmp load_to_ram_loop	; otherwise keep running the loop

end:
	rjmp end
