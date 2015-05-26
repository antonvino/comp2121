.include "m2560def.inc"

.def counter = r17
.def next = r18
.def current_h = r19
.def current_l = r20

.set NEXT_STRING = 0x0000
.macro defstring	; str
	.set T = PC
	.dw NEXT_STRING << 1
	.set NEXT_STRING = T
	.if strlen(@0) & 1	; odd length + null byte
	.db @0, 0
	.else				; even length + null byte, add padding byte
	.db @0, 0, 0
	.endif
.endmacro

.cseg rjmp main
defstring "a"
defstring "macro"
defstring "isdwfjweklfwelrkfwfjewklj"
defstring "fun"
defstring "reallyreallybigword"
defstring "ror"

main:
	; before calling callee store actual parameters in designated registers
	ldi zh, high(NEXT_STRING<<1)
	ldi zl, low(NEXT_STRING<<1)
	
	clr r16
	clr counter	

	rcall find_highest

end: rjmp end

find_highest:

prologue:
	; save the registers that are going to be used in our recursion
	push current_h
	push current_l

	push counter

body:
	; store the current location 
	mov current_h, zh
	mov current_l, zl

	; store the pointer to the next entry in x temporarily
	lpm xl, z+ 
	lpm xh, z+
	clr counter

	; count how long the string is
loop:
	lpm next, z+
	cpi next, 0
	breq check_last
	inc counter
rjmp loop

	; check if this is the last string in the linked list
check_last:
	cpi xh, 0
	brne not_last
	cpi xl, 0
	brne not_last

	; if this is the last string, make it the longest word
last:
	mov r16, counter
	mov zh, current_h
	mov zl, current_l
	rjmp epilogue		

not_last:
	;	point z to the next string 
	mov zh, xh	
	mov zl, xl	
	
	rcall find_highest

	; see if this is the highest string
	cp counter, r16
	brlt epilogue

	; if this is highest, lets point to it, and change r16
	mov r16, counter 
	mov zh, current_h
	mov zl, current_l

epilogue: 
	pop counter
	pop current_l
	pop current_h
	ret
