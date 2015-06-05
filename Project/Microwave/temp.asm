Timer3OVF: ; interrupt subroutine to Timer0
    in temp, SREG
    push temp       ; Prologue starts.
    push YH         ; Save all conflict registers in the prologue.
    push YL
    push r27
    push r26
	; Prologue ends.      

	lds timerTemp, SecondsIdle		; only dim if 10 seconds idle
	cpi timerTemp, 10
	brne endBacklightDim

	backlightDim:
	    lds r26, BacklightCounter
    	lds r27, TempCounter+1
    	adiw r27:r26, 1 		; Increase the temporary counter by one.

    	cpi r26, low(3906)		; 500ms have passed?
    	ldi timerTemp, high(3906)
    	cpc r27, timerTemp
    	brne Not500ms
		
		lds timerTemp, high(Backlight)
		lds temp, low(Backlight)
		sts OCR3BL, timerTemp	; write the value

		ror timerTemp			; shift the pattern
		ror temp

		sts Backlight, temp		; store the backlight value
		sts Backlight+1, timerTemp

	    clear BacklightCounter       ; Reset the temporary counter.
                            
	endBacklightDim:

    rjmp EndTimer3

Not500ms: ; Store the new value of the temporary counter.
    sts BacklightCounter, r26
    sts BacklightCounter+1, r27
	rjmp EndTimer3
    
EndTimer3:
    pop r26         ; Epilogue starts;
    pop r27         ; Restore all conflict registers from the stack.
    pop YL
    pop YH
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.
