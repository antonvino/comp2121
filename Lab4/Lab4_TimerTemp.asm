; This program implements a timer that counts one second using 
; Timer0 interrupt
.include "m2560def.inc"

.equ PATTERN = 0b11001100; test pattern defined
.def temp = r16
.def new_pattern = r17
.def curr_pattern = r18
.def pattern_shown_once = r19
.def bit_counter = r20
.def debounceFlag0 = r21
.def debounceFlag1 = r22
.def seconds = r23

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
DebounceCounter:
    .byte 2              ; Debounce counter. Used to determine 
                        ; if 50ms have passed


.cseg
.org 0x0000
    jmp RESET
.org INT0addr
    jmp EXT_INT1
.org INT1addr
    jmp EXT_INT0

    jmp DEFAULT          ; No handling for IRQ0.
    jmp DEFAULT          ; No handling for IRQ1.
.org OVF0addr
    jmp Timer0OVF        ; Jump to the interrupt handler for
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

	sei                         ; enable Global Interrupt

	ldi temp, (2 << ISC00)      ; set INT0 as falling-
    sts EICRA, temp             ; edge triggered interrupt
    in temp, EIMSK              ; enable INT0
    ori temp, (1<<INT0)
    out EIMSK, temp

	sei                         ; enable Global Interrupt

	ldi temp, (2 << ISC00)      ; set INT0 as falling-
    sts EICRA, temp             ; edge triggered interrupt
    in temp, EIMSK              ; enable INT0
    ori temp, (1<<INT1)
    out EIMSK, temp

	sei                         ; enable Global Interrupt

	rjmp main

Timer0OVF: ; interrupt subroutine to Timer0
    in temp, SREG
    push temp       ; Prologue starts.
    push YH         ; Save all conflict registers in the prologue.
    push YL
	push r27
	push r26
    push r25
    push r24
	;push debounceFlag1
	;push debounceFlag0
	;push bit_counter
	;push pattern_shown_once
	;push curr_pattern
	;push new_pattern
	; Prologue ends.

	;out PORTC, new_pattern

	; first counter - 50ms debounce counter
	checkFlagSet:				; if either flag is set - run the debounce timer
		cpi debounceFlag0, 1
		breq newFifty
		cpi debounceFlag1, 1
		breq newFifty
		; otherwise - don't need the debounce timer
		rjmp newSecond ; go to second counter

	newFifty:			;	if flag is set continue counting until 50 milliseconds
		lds r26, DebounceCounter
    	lds r27, DebounceCounter+1
    	adiw r27:r26, 1 ; Increase the temporary counter by one.

    	cpi r26, low(780)      ; Check if (r25:r24) = 390 ; 7812 = 10^6/128/20 ; 50 milliseconds
    	ldi temp, high(780)    ; 390 = 10^6/128/20 
    	cpc temp, r27
    	brne notFifty			; 50 milliseconds have not passed

		clr debounceFlag0 		;	once 50 milliseconds have passed, set the debounceFlag to 0
		clr debounceFlag1 		;	once 50 milliseconds have passed, set the debounceFlag to 0
	   	clear DebounceCounter	; Reset the debounce counter.
		clr r26
		clr r27	; Reset the debounce counter.

	; second counter - for displaying the pattern 3 times
	newSecond:
	    lds r24, TempCounter		; Load the value of the temporary counter.
    	lds r25, TempCounter+1
    	adiw r25:r24, 1 			; Increase the temporary counter by one.

    	cpi r24, low(7812)      ; Check if (r25:r24) = 7812 ; 7812 = 10^6/128
    	ldi temp, high(7812)    ; 7812 = 10^6/128
    	cpc r25, temp
    	brne notSecond

		cpi pattern_shown_once, 1		; if pattern has been shown - hide
		breq hidePattern		
		
		showPattern:
		
			out PORTC, curr_pattern			; show the pattern
			ldi pattern_shown_once, 1
		
		checkPattern:

			cpi bit_counter, 8			; if the whole new pattern has been set	
			breq reloadPattern			; reload it: copy to curr_pattern


	   	clear TempCounter       ; Reset the temporary counter.
                            
	    ;lds r24, SecondCounter      ; Load the value of the second counter.
	    ;lds r25, SecondCounter+1
	    ;adiw r25:r24, 1             ; Increase the second counter by one.
    	;sts SecondCounter, r24
    	;sts SecondCounter+1, r25
		inc seconds

		;do the showing 3 times 1 second long (during 6 seconds)
		;ldi temp, high(6)
		;cpi r24, low(6)				; check if 6 seconds have passed
		;cpc r25, temp
		cpi seconds, 6
		brne newSecond				; if not - count a new second

		; if 6 seconds have passed clear pattern
		clr curr_pattern
		;ldi curr_pattern, 0b11001100
		out PORTC, curr_pattern
		clr seconds


    rjmp EndIF

; supplementary functions

notSecond: 			; Store the new value of the temporary counter.
    sts TempCounter, r24
    sts TempCounter+1, r25
	rjmp EndIF 

notFifty: 			; Store the new value of the debounce counter.
	sts DebounceCounter, r26
	sts DebounceCounter+1, r27
	rjmp EndIF

reloadPattern:
	clr curr_pattern
	;ldi new_pattern, 0b10000001 ; TEMP DEBUG
	mov curr_pattern, new_pattern
	clr new_pattern
	clr bit_counter
	clr pattern_shown_once
	clr seconds
	;clear SecondCounter
	;rjmp showPattern
	rjmp EndIF

hidePattern:
	ldi temp, 0b00000000
	;clr curr_pattern
	out PORTC, temp
	clr pattern_shown_once
	rjmp checkPattern
	;rjmp EndIF
	    
EndIF:
	;pop new_pattern
	;pop curr_pattern
	;pop pattern_shown_once
	;pop bit_counter
	;pop debounceFlag0
	;pop debounceFlag1
    pop r24         ; Epilogue starts;
    pop r25         ; Restore all conflict registers from the stack.
	pop r26
	pop r27
    pop YL
    pop YH
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.

; subroutine for push button 0
EXT_INT0:
    in temp, SREG	; Prologue starts.
    push temp       ; Save all conflict registers in the prologue.
	;push bit_counter
	;push new_pattern
	;push debounceFlag0
	       			; Prologue ends.
                    ; Load the value of the temporary counter.
	; debounce check
	cpi debounceFlag0, 1		; if the button is still debouncing, ignore the interrupt
	breq END_INT0	

	ldi debounceFlag0, 1		; set the debounce flag

	cpi bit_counter, 8			; if bit counter is not 8 bit yet
	brlt writeZero				; write 0 in the pattern and increase bit counter

	;out PORTC, new_pattern			; write the pattern

	rjmp END_INT0

writeZero:
	; push button 0 wants to put 0 in LSB
	lsl new_pattern				; shift the pattern to the left by 1 bit
	ldi temp, 0b11111110		; load the complement of 00000001
	and new_pattern, temp 		; and the new pattern and r19

	inc bit_counter
	;ldi temp, 0b11101111
	;out PORTC, new_pattern			; write the pattern
	rjmp END_INT0

; Epilogue of push button 0
END_INT0:
	;pop debounceFlag0		; Epilogue starts;
	;pop new_pattern			; Restore all conflict registers from the stack.
	;pop bit_counter
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.
	
; subroutine for push button 1
EXT_INT1:
    in temp, SREG	; Prologue starts.
    push temp       ; Save all conflict registers in the prologue.
	;push bit_counter
    ;push new_pattern
    ;push debounceFlag1
	       			; Prologue ends.
                    ; Load the value of the temporary counter.
	
	; debounce check
	cpi debounceFlag1, 1		; if the button is still debouncing, ignore the interrupt
	breq END_INT1

	ldi debounceFlag1, 1		; set the debounce flag

	cpi bit_counter, 8			; if bit counter is not 8 bit yet
	brlt writeOne				; write 1 in the pattern and increase bit counter

	rjmp END_INT1

;test_debounce:
	;ldi new_pattern, 0b11101111
	;rjmp END_INT1

writeOne:
	; push button 1 wants to put 1 in LSB
	lsl new_pattern				; shift the pattern to the left by 1 bit
	ldi temp, 0b00000001
	or new_pattern, temp 		; or the new pattern and temp
	;out PORTC, new_pattern			; write the pattern
	;ldi new_pattern, 0b10101010
	;ldi new_pattern, 0b10101010

	inc bit_counter
	;ldi temp, 0b00001111
	;out PORTC, new_pattern			; write the pattern
	rjmp END_INT1	

; Epilogue of push button 1
END_INT1:
	;pop debounceFlag1		; Epilogue starts;
	;pop new_pattern			; Restore all conflict registers from the stack.
	;pop bit_counter
	pop temp
    out SREG, temp
    reti            ; Return from the interrupt.


main:

	ser curr_pattern
	out DDRC, curr_pattern 		; set Port C for output
	;ldi curr_pattern, high(PATTERN)
	;ldi curr_pattern, low(PATTERN)

	clr curr_pattern
	clr new_pattern

	;ldi new_pattern, 0b00000000 ; temp new pattern

	;ldi temp, 0b11111110		; load the complement of 00000001
	;and new_pattern, temp 		; and the new pattern and temp
	;lsl new_pattern
	;ldi temp, 0b11111110		; load the complement of 00000001
	;and new_pattern, temp
	;lsl new_pattern
	;ldi temp, 0b00000001		; load the complement of 00000001
	;or new_pattern, temp

    clear DebounceCounter       ; Initialize the temporary counter to 0
    clear TempCounter       ; Initialize the temporary counter to 0
    ;clear SecondCounter     ; Initialize the second counter to 0

	; clear debounce flags
	clr debounceFlag0
	clr debounceFlag1
	;ldi debounceFlag1, 1

	clr pattern_shown_once
	clr bit_counter
	clr seconds

    ldi temp, 0b00000000
    out TCCR0A, temp
    ldi temp, 0b00000010
    out TCCR0B, temp        ; Prescaling value=8
    ldi temp, 1<<TOIE0      ; = 128 microseconds
    sts TIMSK0, temp        ; T/C0 interrupt enable
    sei                     ; Enable global interrupt
                            ; loop forever
    loop: rjmp loop
