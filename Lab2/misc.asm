.include "m2560def.inc"

; This program loads a string from PROM
; and then searches for a character in the string

.equ length = 11
.equ search = 'D' ; the char we are searching for
.def counter = r18
.def target = r16
.def temp = r17

; Data memory init
.dseg
.org 0x500
reversed_string: .byte 11

; Program memory init
.cseg rjmp start; skip the initialization

my_string: .db "hello world"

start:
	; initialize a pointer to the string in PROM
	ldi zl, low(my_string << 1)
	ldi zh, high(my_string << 1)
	; initialize a pointer to the string in RAM
	ldi yl, low(reversed_string << 1)
	ldi yh, high(reversed_string << 1)
	clr counter; index in the string = 0

main:
	lpm temp, z+; load a character in r16
	inc counter
	cpi counter, length	; if counter == length
	breq store_null		; store null in r16
 	cpi temp, search		; if r17 == search, as in character is found
	breq store_index	; store the current counter value in r16
	rjmp main			; otherwise keep running the loop

; store index of the character in the string in r16 and finish
store_index:
	mov target, counter
	rjmp end
; store null in the r16 and finish
store_null:
	ldi target, 0xFF
	rjmp end 

end: rjmp end
