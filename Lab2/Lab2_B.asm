.include "m2560def.inc"

; This program loads a linked list of strings
; Recursive function finds the longest string in the list and returns the address of it
; if there are same strings - return the address of the first one

.cseg
.set NEXT_STRING = 0x0000
.macro defstring
	.set T = PC
	.dw NEXT_STRING << 1
	.set NEXT_STRING = T

	.if strlen(@0) & 1 ; odd length + null byte
		.db @0, 0
	.else ; even length + null byte, add padding byte
		.db @0, 0, 0
	.endif
.endmacro

main:
	defstring "macros"
	defstring "are"
	defstring "fun"

end:
	rjmp end
