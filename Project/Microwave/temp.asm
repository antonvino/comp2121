		lds temp, PowerLevel
		cpi temp, 0
		breq endMagnetron 		; don't spin until the power is set

		; if power is set
		lds temp1, MagnetronOn
		lds temp2, MagnetronOff

		cpi temp1, 1				; if Magnetron is ON >= 1
		brge spinMagnetron			; spin it
		
		cpi temp2, 0				; if Magnetron is not ON or OFF
		breq switchMagnetronOn		; set it to on
									
									; Magnetron is OFF
		lds temp, MagnetronCounter
		cp temp2, temp 				; if MagnetronOff = MagnetronCounter
		breq switchMagnetronOn		; switch it on now
									; otherwise stop spinning
		ldi temp, 0b00000000
		out PORTB, temp

		countMagnetron:

	    lds r26, MagnetronTempCounter 	; Load the value of the temporary counter.
    	lds r27, MagnetronTempCounter+1
    	adiw r27:r26, 1 				; Increase the temporary counter by one.

    	cpi r26, low(1953)      		; 1953 is what we need
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

