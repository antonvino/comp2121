; This program implements a timer that counts one second using 
; Timer0 interrupt
.include "m2560def.inc"

.def temp = r16
.def temp1 = r17 
.def temp2 = r18

.include "macros.asm"
                        
.dseg
Timer1Counter:
   .byte 2              ; Temporary counter. Used to determine 
                        ; if one time inc = 1/4 second has passed
MagnetronCounter:		; Counts how many time incs have passed
	.byte 1
MagnetronOn:			; sets for how many time incs it should be on
	.byte 1
MagnetronOff:			; sets for how many time incs it should be off
	.byte 1
PowerLevel:
    .byte 1             ; 0 - no spin
						; 1 - spin for 1 second (i.e. don't stop)
						; 2 - spin for 1/2 second
						; 3 - spin for 1/4 second

.cseg
.org 0x0000
	jmp RESET
	jmp DEFAULT          ; No handling for IRQ1.
	jmp DEFAULT          ; No handling for IRQ1.

.org OVF0addr
   jmp Timer0OVF        ; Jump to the interrupt handler for
;.org OVF3addr
;   jmp Timer3OVF        ; Jump to the interrupt handler for
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

Timer0OVF: ; interrupt subroutine to Timer0
    in temp, SREG
    push temp       ; Prologue starts.
    push temp2      ; Save all conflict registers in the prologue.
    push temp1      
    push YH         
    push YL
	push r27
	push r26
    push r25
    push r24
	; Prologue ends.


	spinMagnetron:
		lds temp, PowerLevel
		cpi temp, 0
		breq endSpinMagnetron 		; don't spin until the power is set

		; if power is set
		; spin if MagnetronCounter is less than MagnetronOn
		lds temp1, MagnetronOn
		lds temp2, MagnetronOff

		ldi temp, 0
		sts TCCR3A, temp

		cpi temp1, 0				; if MagnetronOn is 0
		breq checkMagnetronOff
		; Magnetron is ON
		lds temp, MagnetronCounter
		cp temp1, temp 				; if MagnetronOn = MagnetronCounter
		breq switchMagnetronOff		; switch it off
		; otherwise just spin
		;out PORTC, temp

		ldi temp, 75
		sts TCCR3A, temp			; set the speed

		checkMagnetronOff:
		cpi temp2, 0	; if MagnetronOff is 0
						; this means both flags are 0
						; and power is set, so switch on
		breq switchMagnetronOn
		; Magnetron is OFF
		lds temp, MagnetronCounter
		cp temp1, temp 			; if MagnetronOff = MagnetronCounter
		breq switchMagnetronOn		; switch it on now
		; otherwise stop spinning
		ldi temp, 0
		sts TCCR3A, temp			; clear the speed

	    lds r24, Timer1Counter ; Load the value of the temporary counter.
    	lds r25, Timer1Counter+1
    	adiw r25:r24, 1 ; Increase the temporary counter by one.

    	cpi r24, low(1953)      ; 1953 is what we need Check if (r25:r24) = 7812 ; 7812 = 10^6/128
    	ldi temp, high(1953)    ; 7812 = 10^6/128
    	cpc r25, temp
    	brne NotQuarter
		
		QuarterPassed: 			; 1/4 of a second passed
								; increase magnetron counter
		lds temp, MagnetronCounter
		out PORTC, temp
		inc temp
		sts MagnetronCounter, temp

	endSpinMagnetron:
 
    rjmp EndIF

NotQuarter: ; Store the new value of the temporary counter.
    sts Timer1Counter, r24
    sts Timer1Counter+1, r25 
	rjmp EndIF 

switchMagnetronOn:
	lds temp, PowerLevel
	cpi temp, 1
	breq switchMagnetronOn1
	cpi temp, 2
	breq switchMagnetronOn2
	cpi temp, 3
	breq switchMagnetronOn3
	rjmp spinMagnetron
switchMagnetronOff:
	lds temp, PowerLevel
	cpi temp, 1
	breq switchMagnetronOff1
	cpi temp, 2
	breq switchMagnetronOff2
	cpi temp, 3
	breq switchMagnetronOff3
	rjmp spinMagnetron

; MagnetronOn length depending on Power Level
switchMagnetronOn1:
	lds temp, MagnetronCounter	; reset magnetron counter
	clr temp
	sts MagnetronCounter, temp
	lds temp, MagnetronOn		
	ldi temp, 4					; set to spin for 2 time incs
	sts MagnetronOn, temp
	rjmp spinMagnetron
switchMagnetronOn2:
	lds temp, MagnetronCounter	; reset magnetron counter
	clr temp
	sts MagnetronCounter, temp
	lds temp, MagnetronOn
	ldi temp, 2					; set to spin for 2 time incs
	sts MagnetronOn, temp
	rjmp spinMagnetron
switchMagnetronOn3:
	lds temp, MagnetronCounter	; reset magnetron counter
	clr temp
	sts MagnetronCounter, temp
	lds temp, MagnetronOn
	ldi temp, 1					; set to spin for 1 time inc
	sts MagnetronOn, temp
	rjmp spinMagnetron
; MagnetronOff length depending on Power Level
switchMagnetronOff1:
	lds temp, MagnetronCounter
	clr temp
	sts MagnetronCounter, temp
	lds temp, MagnetronOff
	ldi temp, 0
	sts MagnetronOff, temp
	rjmp spinMagnetron
switchMagnetronOff2:
	lds temp, MagnetronCounter
	clr temp
	sts MagnetronCounter, temp
	lds temp, MagnetronOff
	ldi temp, 2
	sts MagnetronOff, temp
	rjmp spinMagnetron
switchMagnetronOff3:
	lds temp, MagnetronCounter
	clr temp
	sts MagnetronCounter, temp
	lds temp, MagnetronOff
	ldi temp, 3
	sts MagnetronOff, temp
	rjmp spinMagnetron
    
EndIF:
	pop r24         ; Epilogue starts;
    pop r25         ; Restore all conflict registers from the stack.
	pop r26         
    pop r27         
    pop YL
    pop YH
	pop temp1
	pop temp2
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.


main:
    clear Timer1Counter       	; init the main counter to 0
	clear_byte MagnetronCounter ; init the magnetron
	clear_byte MagnetronOn
	clear_byte MagnetronOff

	; TEMP set the power level manually
	ldi temp, 2
	sts PowerLevel, temp

	; Timer0 initilaisation
    ldi temp, 0b00000000
    out TCCR0A, temp
    ldi temp, 0b00000010
    out TCCR0B, temp        ; Prescaling value=8
    ldi temp, 1<<TOIE0      ; = 128 microseconds
    sts TIMSK0, temp        ; T/C0 interrupt enable

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

	; Timer3 initialisation
	;ldi temp, 0b00001000
	;sts DDRL, temp
	
	;ldi temp, 0x4A
	;sts OCR3AL, temp
	;clr temp
	;sts OCR3AH, temp

	;ldi temp, (1<<CS50)
	;sts TCCR3B, temp
	;ldi temp, (1<<WGM30)|(1<<COM3A1)
	;sts TCCR3A, temp
	
	;ldi temp, 1<<TOIE3	
    ;sts TIMSK3, temp        ; T/C0 interrupt enable

    sei                     ; Enable global interrupt
                            ; loop forever
    loop: rjmp loop
