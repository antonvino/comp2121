; All times aspects specific to Microwave emulator
; Includes debouncing, microwave countdown, magnetron etc
; Authors: Ali Mokdad, Anton Vinokurov
; Based on COMP2121 Lab and lecture examples
; License: MIT
; 2015

Timer0OVF: ; interrupt subroutine to Timer0
    in temp, SREG
    push temp       ; Prologue starts.
    push YH         ; Save all conflict registers in the prologue.
    push YL
	push r27
	push r26
	; Prologue ends.

	; PB debounce for PB0 and PB1
	; 50ms debounce counter
	checkPBDebounce:				; if either flag is set - run the debounce timer
		cpi debounceFlag0, 1
		breq newPBDebounce
		cpi debounceFlag1, 1
		breq newPBDebounce
		; otherwise - don't need the debounce timer
		rjmp endPBDebounce ; go to the end of debounce

	newPBDebounce:				;	if flag is set continue counting until 50 milliseconds
		lds r26, DebounceCounter
    	lds r27, DebounceCounter+1
    	adiw r27:r26, 1 ; Increase the temporary counter by one.

    	cpi r26, low(50)     	; Check if (r25:r24) = 390 ; 7812 = 10^6/128/20 ; 50 milliseconds
    	ldi temp, high(50)    	; 390 = 10^6/128/20 
    	cpc temp, r27
    	brne notPBFifty			; 50 milliseconds have not passed

		clr debounceFlag0 		;	once 50 milliseconds have passed, set the debounceFlag to 0
		clr debounceFlag1 		;	once 50 milliseconds have passed, set the debounceFlag to 0
	   	clear DebounceCounter	; Reset the debounce counter.
		clr r26
		clr r27	; Reset the debounce counter.
	endPBDebounce:
		rjmp checkKeypadDebounce	

	notPBFifty: 	; Store the new value of the debounce counter.
		sts DebounceCounter, r26
		sts DebounceCounter+1, r27
		rjmp endPBDebounce

	; Keypad debounce
	; 50ms debounce counter
	checkKeypadDebounce:		; if flag is set - run the debounce timer
		cpi debounceFlag, 1
		breq newKeypadDebounce	; i.e. set to 1
		; otherwise - don't need the debounce timer
		rjmp endKeypadDebounce 	; end of Debouncing

	newKeypadDebounce:			; if flag is set continue counting until 100 milliseconds
		;ldi temp, 0b11000011
		;out PORTC, temp
		lds r26, DebounceCounter
    	lds r27, DebounceCounter+1
    	adiw r27:r26, 1 		; Increase the temporary counter by one.

    	cpi r26, low(50)      	; Check if (r25:r24) = 390 ; 7812 = 10^6/128/20 ; 50 milliseconds
    	ldi temp, high(50)    	; 390 = 10^6/128/20 
    	cpc temp, r27
    	brne notKeypadFifty		; 50 milliseconds have not passed

		clr debounceFlag 		; once 50 milliseconds have passed, set the debounceFlag to 0
	   	clear DebounceCounter	; Reset the debounce counter.
		clr r26
		clr r27	; Reset the debounce counter.
	endKeypadDebounce:
		rjmp microwaveRunning	

	notKeypadFifty: 			; Store the new value of the debounce counter.
		sts DebounceCounter, r26
		sts DebounceCounter+1, r27
		rjmp endKeypadDebounce

	microwaveRunning:
		lds temp, Mode
		cpi temp, 1
		breq runningMode
		jmp ENDIF

		runningMode:
		
		CheckDoorOpen:
		lds temp, DoorState
		cpi temp, 1
		brne CheckMoreOrLess
		jmp EndIF
				
		CheckMoreOrLess:

		checkMore:
		lds temp, MoreFlag
		cpi temp, 1
		brne checkLess

		More:
			lds temp, Seconds
			cpi temp, 30
			brlt NoCarryMore

		CarryMore:
			lds temp, Minutes
			inc temp
			sts Minutes, temp
			lds temp, Seconds
			ldi temp1, 30
			sub temp, temp1
			sts Seconds, temp
			do_lcd_data '-'
			do_lcd_digits temp
			rjmp EndMore

		NoCarryMore:
			ldi temp1, 30
			add temp, temp1
			sts Seconds, temp

		EndMore:
			ldi temp, 0
			sts MoreFlag, temp

		checkLess:
			lds temp, LessFlag
			cpi temp, 1
			brne checkTimer

		Less:
			lds temp, Seconds
			cpi temp, 30
			brge NoCarryLess

		CarryLess:
			; check if minutes is already 0
			lds temp, Minutes
			cpi temp, 0
			breq LessFinished
			
			dec temp
			sts Minutes, temp
			lds temp, Seconds
			ldi temp1, 30
			add temp, temp1
			sts Seconds, temp
			rjmp EndLess

			LessFinished:
			clr temp
			sts Seconds, temp
			jmp EndLess

		NoCarryLess:
			ldi temp1, 30
			sub temp, temp1
			sts Seconds, temp

		EndLess:
			ldi temp, 0
			sts LessFlag, temp

		checkTimer:
		
		lds r26, MicrowaveCounter
    	lds r27, MicrowaveCounter+1	
		
		adiw r27:r26, 1 ; Increase the temporary counter by one.

    	cpi r26, low(7812)      ; Check if (r25:r24) = 7812, one second
    	ldi temp, high(7812)    ; 390 = 10^6/128/20 
    	cpc temp, r27
    	breq OneSecond
		jmp notOneSecond			; 1 second hasn't passed

		OneSecond:
		ldi temp, 1
		sts RefreshFlag, temp
	
		clear MicrowaveCounter
		clr r26
		clr r27	
		; decrement timer by one second

		;do_lcd_data 'T'

		decrementTimer:
		lds temp, Seconds
		cpi temp, 0
		breq decrementMinutes

		dec temp
		sts Seconds, temp
		rjmp endDecrement
	
		decrementMinutes:
		lds temp, Minutes
		cpi temp, 0
		breq finishedCountdown

		continueCountdown:
		dec temp
		sts Minutes, temp

		ldi temp, 59
		sts Seconds, temp
		rjmp endDecrement

		finishedCountdown:
		ldi temp, 3
		sts Mode, temp
		rjmp endDecrement

	endDecrement:

    rjmp EndIF

;
; supplementary functions
;
notOneSecond:
	sts MicrowaveCounter, r26
	sts MicrowaveCounter+1, r27
	rjmp EndIF	
	    
EndIF:
    pop r26         ; Epilogue starts;
    pop r27         ; Restore all conflict registers from the stack.
    pop YL
    pop YH
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.
