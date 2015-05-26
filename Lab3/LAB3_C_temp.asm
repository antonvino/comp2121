	; first counter - 50ms debounce counter
	checkFlagSet:				; if either flag is set - run the debounce timer
		cpi debounceFlag0, 1
		breq newFifty
		cpi debounceFlag1, 1
		breq newFifty
		; otherwise - don't need the debounce timer
		rjmp newSecond ; go to second counter

	newFifty:			;	if flag is set continue counting until 50 milliseconds
		lds r24, DebounceCounter
    	lds r25, DebounceCounter+1
    	adiw r25:r24, 1 ; Increase the temporary counter by one.

    	cpi r24, low(3900)      ; Check if (r25:r24) = 390 ; 7812 = 10^6/128/20 ; 50 milliseconds
    	ldi temp, high(3900)    ; 390 = 10^6/128/20 
    	cpc temp, r25
    	brne notFifty			; 50 milliseconds have not passed

		clr debounceFlag0 		;	once 50 milliseconds have passed, set the debounceFlag to 0
		clr debounceFlag1 		;	once 50 milliseconds have passed, set the debounceFlag to 0
	   	clear DebounceCounter	; Reset the debounce counter.
		clr r24
		clr r25	; Reset the debounce counter.
