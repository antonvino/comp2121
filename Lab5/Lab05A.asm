; This program implements a timer that counts one second using 
; Timer0 interrupt
.include "m2560def.inc"

.def temp = r16
.def counter = r17

; The macro clears a word (2 bytes) in a memory
; the parameter @0 is the memory address for that word
.macro clear
    ldi YL, low(@0)     ; load the memory address to Y
    ldi YH, high(@0)
    clr temp 
    st Y+, temp         ; clear the two bytes at @0 in SRAM
    st Y, temp
.endmacro
                        
.dseg
Timer1Counter:
   .byte 2              ; Temporary counter. Used to determine 
                        ; if one second has passed
Timer3Counter:
	.byte 2
VoltageFlag:
	.byte 1
.cseg
.org 0x0000
   jmp RESET
   jmp DEFAULT          ; No handling for IRQ0.
   jmp DEFAULT          ; No handling for IRQ1.
.org INT2addr
    jmp EXT_INT2
.org OVF0addr
   jmp Timer0OVF        ; Jump to the interrupt handler for
.org OVF3addr
   jmp Timer3OVF        ; Jump to the interrupt handler for
jmp DEFAULT          ; default service for all other interrupts.
DEFAULT:  reti          ; no service

RESET: 
    ldi temp, high(RAMEND) ; Initialize stack pointer
    out SPH, temp
    ldi temp, low(RAMEND)
    out SPL, temp
    ser temp
    out DDRC, temp ; set Port C as output
	rjmp main

EXT_INT2:
	in temp, SREG
	push temp
	push r18

	lds r18, VoltageFlag
	cpi r18, 1
	breq END_INT2

	inc counter
	ldi r18, 1
	sts VoltageFlag, r18

	END_INT2:
		pop r18
		pop temp
		out SREG, temp
		reti

Timer0OVF: ; interrupt subroutine to Timer0
    in temp, SREG
    push temp       ; Prologue starts.
    push YH         ; Save all conflict registers in the prologue.
    push YL
    push r25
    push r24
	        ; Prologue ends.
                    ; Load the value of the temporary counter.

	newSecond:
	    lds r24, Timer1Counter
    	lds r25, Timer1Counter+1
    	adiw r25:r24, 1 ; Increase the temporary counter by one.

    	cpi r24, low(1953)      ; Check if (r25:r24) = 7812 ; 7812 = 10^6/128
    	ldi temp, high(1953)    ; 7812 = 10^6/128
    	cpc r25, temp
    	brne NotSecond
		
		secondPassed:
			inc counter
			out PORTC, counter
			clear Timer1Counter

    rjmp EndIF

NotSecond: ; Store the new value of the temporary counter.
    sts Timer1Counter, r24
    sts Timer1Counter+1, r25 
    
EndIF:
	pop r24         ; Epilogue starts;
    pop r25         ; Restore all conflict registers from the stack.
    pop YL
    pop YH
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.

Timer3OVF: ; interrupt subroutine to Timer3
	in temp, SREG
	push temp
	push r26
	push r27
	push temp

	lds r26, VoltageFlag
	cpi r26, 1
	brne EndTimer3

	lds r26, Timer3Counter
	lds r27, Timer3Counter+1
	adiw r27:r26, 1
		 
	cpi r26, low(20)
	ldi temp, high(20)
	cpc temp, r19
	brne EndTimer3

	clear Timer3Counter
	ldi r26, 0
	sts VoltageFlag, r26

EndTimer3:
	pop temp
	pop r27
	pop r26
	pop temp
	out SREG, temp
reti



main:
    clear Timer1Counter       ; Initialize the temporary counter to 0
	clear Timer3Counter
	ldi r26, 0
	sts VoltageFlag, r26	

	ldi temp, (2 << ISC00)      ; set INT0 as falling-
    sts EICRA, temp             ; edge triggered interrupt
    in temp, EIMSK              ; enable INT0
    ori temp, (1<<INT2)
    out EIMSK, temp

	; Timer0 initilaisation

    ldi temp, 0b00000000
    out TCCR0A, temp
    ldi temp, 0b00000010
    out TCCR0B, temp        ; Prescaling value=8
    ldi temp, 1<<TOIE0      ; = 128 microseconds
    sts TIMSK0, temp        ; T/C0 interrupt enable

	; Timer3 initialisation
	ldi temp, 0b00001000
	sts DDRL, temp
	
	ldi temp, 0x4A
	sts OCR3AL, temp
	clr temp
	sts OCR3AH, temp

	ldi temp, (1<<CS50)
	sts TCCR3B, temp
	ldi temp, (1<<WGM30)|(1<<COM3A1)
	sts TCCR3A, temp
	
	ldi temp, 1<<TOIE3	
    sts TIMSK3, temp        ; T/C0 interrupt enable


    sei                     ; Enable global interrupt
                            ; loop forever
    loop: rjmp loop
