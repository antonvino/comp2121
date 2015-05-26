.include "m2560def.inc"
.def temp = r16
.def output = r17
.def count = r18
.def debounceFlag = r19
.equ PATTERN = 0b01010101
                                ; set up interrupt vectors

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
jmp RESET 
.org INT0addr
jmp EXT_INT0
.org OVF0addr
jmp Timer0OVF        ; Jump to the interrupt handler for
                    ; Timer0 overflow.

RESET:
    ldi temp, low(RAMEND)       ; initialize stack
    out SPL, temp
    ldi temp, high(RAMEND)
    out SPH, temp

    ser temp                    ; set Port C as output
    out DDRC, temp
    out PORTC, temp
    ldi output, PATTERN
	out PORTC, output
	clr debounceFlag

    ldi temp, (2 << ISC00)      ; set INT0 as falling-
    sts EICRA, temp             ; edge triggered interrupt
    in temp, EIMSK              ; enable INT0
    ori temp, (1<<INT0)
    out EIMSK, temp
    sei                         ; enable Global Interrupt
    jmp main

EXT_INT0:
	    push temp               ; save register
	    in temp, SREG           ; save SREG
	    push temp

		cpi debounceFlag, 1		; if the button is still debouncing, ignore the interrupt
		breq EXT_epilogue	

	    com output              ; flip the pattern
	    ;out PORTC, output
	    inc count

		ser debounceFlag

	EXT_epilogue:
	    pop temp                ; restore SREG 
	    out SREG, temp
	    pop temp                ; restore register 
	    reti

Timer0OVF: ; interrupt subroutine to Timer0
	    in temp, SREG
	    push temp       ; Prologue starts.

	timerPrologue:
		push r24
		push r25
		push YH
		push YL

	    out PORTC, output; show the refreshed pattern all the time

	checkFlagSet:		;	if flag isn't set we don't need the timer, so just skip

		cpi debounceFlag, 0
		breq TimerEpilogue

	newFifty:			;	if flag is set continue counting until 50 milliseconds
		lds r24, TempCounter
    	lds r25, TempCounter+1
    	adiw r25:r24, 1 ; Increase the temporary counter by one.

    	cpi r24, low(390)      ; Check if (r25:r24) = 390 ; 7812 = 10^6/128/20 ; 50 milliseconds
    	ldi temp, high(390)    ; 390 = 10^6/128/20 
    	cpc temp, r25
    	brne NotFifty

	timerDone:			;	once 50 milliseconds have passed, set the debounceFlag to 0
		clr debounceFlag
		rjmp timerEpilogue

	notFifty: ; Store the new value of the temporary counter.
	    sts TempCounter, r24
	    sts TempCounter+1, r25 
		ldi output, 0b00100000
		out PORTC, output


	timerEpilogue:						; epilogue
		
		pop YL
		pop YH
		pop r25
		pop r24	
	    pop temp		
	    out SREG, temp
	    reti            ; Return from the interrupt.
        
                                ; main - does nothing but increment a counter
main:
    clr count
    clr temp
	clr debounceFlag 

    clear TempCounter       ; Initialize the temporary counter to 0
    clear SecondCounter     ; Initialize the second counter to 0

    ldi temp, 0b00000000
    out TCCR0A, temp
    ldi temp, 0b00000010
    out TCCR0B, temp        ; Prescaling value=8
    ldi temp, 1<<TOIE0      ; = 128 microseconds
    sts TIMSK0, temp        ; T/C0 interrupt enable
    sei                     ; Enable global interrupt
loop:
    inc temp                    ; a dummy task in main
    rjmp loop
