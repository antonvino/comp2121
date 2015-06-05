; Backlight module for Microwave emulator
; Includes Timer3 subroutine
; Authors: Anton Vinokurov
; Based on COMP2121 Lab and lecture examples
; License: MIT
; 2015

Timer3OVF: ; interrupt subroutine to Timer0
    in temp, SREG
    push temp       ; Prologue starts.
    ;push YH         ; Save all conflict registers in the prologue.
    ;push YL
    ;push r27
    ;push r26
	;push r30
	; Prologue ends.      

	;ldi r30, 0b01010101
	;out PORTC, r30

    rjmp EndTimer3

Not500ms: ; Store the new value of the temporary counter.
    sts BacklightCounter, r26
    sts BacklightCounter+1, r27
	rjmp EndTimer3
    
EndTimer3:
;	pop r30
    ;pop r26         ; Epilogue starts;
    ;pop r27         ; Restore all conflict registers from the stack.
    ;pop YL
    ;pop YH
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.

backlight_on:
	push temp1
	push temp2

	ldi temp1, high(MAXBRIGHTNESS)
	ldi temp2, low(MAXBRIGHTNESS)
	
	sts Backlight, temp2
	sts Backlight+1, temp1

	sts OCR3BL, temp1	; update the brightness
	
	pop temp1
	pop temp2	
	ret

backlight_off:
	push temp

	ldi temp, 0b00000000
	sts OCR3BL, temp	; update the brightness
	
	pop temp
	ret


