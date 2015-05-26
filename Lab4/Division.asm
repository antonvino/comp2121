; Div8 divides a 8-bit-number by a 8-bit-number
; Test: 16-bit-number: 0xB4 (180), 8-bit-number: 0xC (12)
;
.include "m2560def.inc"
;
; Registers
;
.DEF accumulator = R0 ; 8-bit-number to be divided
.DEF temp1 = R2 ; interim register
.DEF temp2  = R3 ; 8-bit-number to divide with
.DEF temp  = R4 ; result
.DEF rmp  = R16; multipurpose register for loading
;
.CSEG
.ORG 0
;
	rjmp start
;
start:
;
; Load the test numbers to the appropriate registers
;
	ldi rmp, 0xB4 ; in decimal 180
	mov accumulator, rmp
	ldi rmp,0xC ; in decimal 12
	mov temp2,rmp
;
; Divide accumulator by temp2
;
div8:
	clr temp1 ; clear interim register
	clr temp  ; clear result (the result registers
	 		; are also used to count to 16 for the
	inc temp  ; division steps, is set to 1 at start)
;
; Here the division loop starts
;
div8a:
	clc      ; clear carry-bit
	rol accumulator  ; rotate the next-upper bit of the number
			 ; to the interim register (multiply by 2)
	rol temp1
	brcs div8b ; a one has rolled left, so subtract
	cp temp1,temp2 ; Division result 1 or 0?
	brcs div8c  ; jump over subtraction, if smaller
div8b:
	sub temp1,temp2; subtract number to divide with
	sec      ; set carry-bit, result is a 1
	rjmp div8d  ; jump to shift of the result bit
div8c:
	clc      ; clear carry-bit, resulting bit is a 0
div8d:
	rol temp   ; rotate carry-bit into result registers
	brcc div8a  ; as long as zero rotate out of the result
	            ; registers: go on with the division loop
; End of the division reached
stop:
	rjmp stop   ; endless loop
