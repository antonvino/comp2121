; This program implements a timer that counts one second using 
; Timer0 interrupt
.include "m2560def.inc"

.equ MAXBRIGHTNESS = 0b1111111111111111; pattern defined
.def temp = r16
.def BrightnessH = r18
.def BrightnessL = r17

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
SecondCounter:
   .byte 2              ; Two-byte counter for counting seconds.
TempCounter:
   .byte 2              ; Temporary counter. Used to determine 
                        ; if one second has passed
.cseg
.org 0x0000
   jmp RESET
   jmp DEFAULT          ; No handling for IRQ0.
   jmp DEFAULT          ; No handling for IRQ1.
.org OVF3addr
   jmp Timer3OVF        ; Jump to the interrupt handler for
                        ; Timer0 overflow.
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

Timer3OVF: ; interrupt subroutine to Timer0
    in temp, SREG
    push temp       ; Prologue starts.
    push YH         ; Save all conflict registers in the prologue.
    push YL
    push r25
    push r24
	push r20
	push r19
	        ; Prologue ends.
                    ; Load the value of the temporary counter.

	newSecond:
	    lds r24, TempCounter
    	lds r25, TempCounter+1
    	adiw r25:r24, 1 ; Increase the temporary counter by one.

    	cpi r24, low(7812)  ; Check if (r25:r24) = 7812 ; 7812 = 10^6/128
    	ldi temp, high(7812)    ; 7812 = 10^6/128
    	cpc r25, temp
    	brne NotSecond
		
		showPattern:
			sts OCR3BL, BrightnessH

			; our stuff - shift pattern and write it
			lsr BrightnessH				; shift the pattern
			ror BrightnessL
			;brcs setCarry				; carry was set -> put 1 in front

	    	clear TempCounter       ; Reset the temporary counter.
                            
	    	lds r24, SecondCounter      ; Load the value of the second counter.
	    	lds r25, SecondCounter+1
	    	adiw r25:r24, 1             ; Increase the second counter by one.

    		sts SecondCounter, r24
    		sts SecondCounter+1, r25

			ldi r19, high(16)
			cpi r24, low(16)			; check if 16 seconds have passed
			cpc r25, r19
			brne newSecond

			rjmp reloadPattern

    rjmp EndIF
    
reloadPattern:
	ldi BrightnessH, high(MAXBRIGHTNESS)
	ldi BrightnessL, low(MAXBRIGHTNESS)
	clear SecondCounter
	rjmp newSecond

setCarry:
	ldi r20, 0b00000001
	or BrightnessH, r20
	rjmp showPattern

NotSecond: ; Store the new value of the temporary counter.
    sts TempCounter, r24
    sts TempCounter+1, r25 
    
EndIF:
	pop r19
	pop r20
    pop r24         ; Epilogue starts;
    pop r25         ; Restore all conflict registers from the stack.
    pop YL
    pop YH
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.


main:

	ser BrightnessH
	out DDRC, BrightnessH 		; set Port C for output
	ldi BrightnessH, high(MAXBRIGHTNESS)
	ldi BrightnessL, low(MAXBRIGHTNESS)

    clear TempCounter       ; Initialize the temporary counter to 0
    clear SecondCounter     ; Initialize the second counter to 0

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
    sts TIMSK3, temp        ; T/C3 interrupt enable
   	
	; PWM Configuration
	; Configure bit PE2 as output
	ldi temp, 0b00010000
	ser temp
	out DDRE, temp ; Bit 3 will function as OC3B
	ldi temp, 0xFF ; the value controls the PWM duty cycle (store the value in the OCR registers)
	sts OCR3BL, temp
	clr temp
	sts OCR3BH, temp

	ldi temp, (1 << CS00) ; no prescaling
	sts TCCR3B, temp

	; PWM phase correct 8-bit mode (WGM30)
	; Clear when up counting, set when down-counting
	ldi temp, (1<< WGM30)|(1<<COM3B1)
	sts TCCR3A, temp

	sei
   
    loop: rjmp loop
