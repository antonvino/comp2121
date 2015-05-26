.include "m2560def.inc"

.def counter = r17
.def next = r18
.def number_h = r19
.def number_l = r20

.set NEXT_INT = 0x0000
.macro defint	; int
	.set T = PC
	.dw NEXT_INT << 1
	.set NEXT_INT = T
	.dw @0
.endmacro

.cseg rjmp main
defint 0x1111
defint 0x2222
defint 0x3333
defint 0x4444
defint 0x5555

main:
	; before calling callee store actual parameters in designated registers
	
	ldi zh, high(NEXT_INT<<1)
	ldi zl, low(NEXT_INT<<1)
	
	rcall find_highlow

end: rjmp end

find_highlow:

prologue:
	; save the registers that are going to be used in our recursion
	push number_h
	push number_l

body:
	; store the pointer to the next entry in x temporarily
	lpm xl, z+ 
	lpm xh, z+
	
	; get the next entry
	lpm number_l, z+
	lpm number_h, z
	
check_last:
	cpi xh, 0
	brne not_last
	cpi xl, 0
	brne not_last

last:
	; if the number is the last in the list, make it both the highest and lowest
	mov xh, number_h
	mov xl, number_l
	mov yh, number_h
	mov yl, number_l
	rjmp epilogue		

not_last:
	;	point z to the next string 
	mov zh, xh
	mov zl, xl
		
	rcall find_highlow

	;	check if this is the highest integer
check_highest:

	;	check the high bits
	cp number_h, xh
	brlt check_lowest

	;	check the lower bits
	cp number_h, xl
	brlt check_lowest

	;	this is the highest
	mov xh, number_h
	mov xl, number_l

	;		check if this is the lowest integer

check_lowest:

	;	check the high bits
	cp number_h, yh
	brlt new_lowest

	;	check the low bits
	cp number_l, yl
	brge epilogue

new_lowest:
	;	this is the lowest
	mov yh, number_h
	mov yl, number_l

epilogue: 
	 pop number_l
	 pop number_h
	 ret
