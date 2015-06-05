; All times aspects specific to Microwave emulator
; Includes debouncing, microwave countdown, magnetron etc
; Authors: Ali Mokdad, Anton Vinokurov
; Based on COMP2121 Lab and lecture examples
; License: MIT
; 2015

Timer0OVF: ; interrupt subroutine to Timer0
    in temp, SREG
    push temp       ; Prologue starts.
	push temp1
	push temp2
    push YH         ; Save all conflict registers in the prologue.
    push YL
	push r27
	push r26
	; Prologue ends.

	;
	; PB debounce for PB0 and PB1
	; Using 50ms timer
	;
	checkPBDebounce:				; if either flag is set - run the debounce timer
		cpi debounceFlag0, 1
		breq newPBDebounce
		cpi debounceFlag1, 1
		breq newPBDebounce
		; otherwise - don't need the debounce timer
		rjmp endPBDebounce ; go to the end of debounce

	newPBDebounce:				;	if flag is set continue counting until 50 milliseconds
		clr r26
		clr r27
		clr temp

		lds r26, DebounceCounter
    	lds r27, DebounceCounter+1
    	adiw r27:r26, 1 ; Increase the temporary counter by one.

    	cpi r26, low(50)     	; Check if (r25:r24) = 390
    	ldi temp, high(50)    	; 390
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

	;
	; Keypad debounce
	; Using 50ms timer
	;
	checkKeypadDebounce:		; if flag is set - run the debounce timer
		cpi debounceFlag, 1
		breq newKeypadDebounce	; i.e. set to 1
		; otherwise - don't need the debounce timer
		rjmp endKeypadDebounce 	; end of Debouncing

	newKeypadDebounce:			; if flag is set continue counting until 100 milliseconds
		clr r26
		clr r27
		clr temp

		lds r26, DebounceCounter
    	lds r27, DebounceCounter+1
    	adiw r27:r26, 1 		; Increase the temporary counter by one.

    	cpi r26, low(50)      	; Check if (r25:r24) = 390
    	ldi temp, high(50)    	; 390
    	cpc temp, r27
    	brne notKeypadFifty		; 50 milliseconds have not passed

		clr debounceFlag 		; once 50 milliseconds have passed, set the debounceFlag to 0
	   	clear DebounceCounter	; Reset the debounce counter.
		clr r26
		clr r27	; Reset the debounce counter.
	endKeypadDebounce:
		rjmp turntableSpinning	

	notKeypadFifty: 			; Store the new value of the debounce counter.
		sts DebounceCounter, r26
		sts DebounceCounter+1, r27
		rjmp endKeypadDebounce

	;
	; Turntable spinning timer
	;
	turntableSpinning:			; Turntable spins whenever the mode is running
		clr r26
		clr r27
		clr temp
		
		lds temp, Mode			; If mode is not "running"
		cpi temp, 1				; We do not turn the table
		brne endTurntableSpinning
	
		lds r26, TurntableCounter
    	lds r27, TurntableCounter+1
    	adiw r27:r26, 1 		; Increase the turntable counter by one.

    	cpi r26, low(19530)     ; 2.5 seconds 19530
    	ldi temp, high(19530)
    	cpc temp, r27
    	brne notTurning			; 2.5s have not passed

		; 2.5 seconds have passed
		rcall turn_table		; make the turn
		clear TurntableCounter	; reset the counter

	endTurntableSpinning:
		rjmp checkMagnetron	

	notTurning: 				; Store the new value of the turntable counter.
		sts TurntableCounter, r26
		sts TurntableCounter+1, r27
		rjmp endTurntableSpinning

	;
	; Magnetron timer
	;
	checkMagnetron:
		clr r26
		clr r27
		clr temp

		lds temp, DoorState
		cpi temp, 1
		breq endMagnetron			; stop spinning if the door is opened

		lds temp, Mode
		cpi temp, 1
		brne endMagnetron 			; don't spin until in running mode

		lds temp, PowerLevel
		cpi temp, 0
		breq endMagnetron 			; don't spin until the power is set
		
		powerSet:					; if power is set
		lds temp, MagnetronOn
		cpi temp, 1					; if Magnetron is ON >= 1
		brge spinMagnetron			; spin it
		
		lds temp, MagnetronOff
		cpi temp, 0					; if Magnetron is not ON or OFF
		breq switchMagnetronOn		; set it to on
									
									; Magnetron is OFF
		lds timerTemp, MagnetronCounter
		cp temp, timerTemp 			; if MagnetronOff = MagnetronCounter
		breq switchMagnetronOn		; switch it on now
									; otherwise stop spinning
		ldi temp, 0b00000000
		out PORTB, temp

		countMagnetron:

	    lds r26, MagnetronTempCounter 	; Load the value of the temporary counter.
    	lds r27, MagnetronTempCounter+1
    	adiw r27:r26, 1 				; Increase the temporary counter by one.

    	cpi r26, low(1953)      		; 1953 is what we need for 1/4 second
    	ldi temp, high(1953)
    	cpc r27, temp
    	brne notQuarter
										; 1/4 of a second passed
										; increase magnetron counter
		lds temp, MagnetronCounter
		inc temp
		sts MagnetronCounter, temp

		clear MagnetronTempCounter

	endMagnetron:
		rjmp microwaveRunning	

	; magnetron timer supplementary branches
	.include "modules/magnetron.asm"


	;
	; Microwave running timer
	;
	microwaveRunning:
		clr temp
		clr temp1
		clr temp2
		clr r26
		clr r27

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
			cpi temp, 99
			breq ReachedMax

			inc temp
			sts Minutes, temp
			lds temp, Seconds
			ldi temp1, 30
			sub temp, temp1
			sts Seconds, temp
			rjmp EndMore

			ReachedMax:
			lds temp, Seconds
			cpi temp, 69
			brlt NotMax

			ldi temp, 99
			sts Seconds, emp
			rjmp EndMore
	
			NotMax:
			ldi temp1, 30
			add temp, temp1
			sts Seconds, temp
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
	pop temp2
	pop temp1
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.
