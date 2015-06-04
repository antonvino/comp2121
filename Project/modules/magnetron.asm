; Magnetron module for Microwave emulator
; Includes only the Timer0 subroutines
; To be used only inside of Timer0 (see timer0.asm)
; Authors: Anton Vinokurov
; Based on COMP2121 Lab and lecture examples
; License: MIT
; 2015

notQuarter: 						; Store the new value of the temporary counter.
	sts MagnetronTempCounter, r24
	sts MagnetronTempCounter+1, r25 
	rjmp endMagnetron 

spinMagnetron:
	lds temp1, MagnetronOn
	lds temp, MagnetronCounter
	cp temp1, temp 				; if MagnetronOn = MagnetronCounter
	breq switchMagnetronOff		; switch it off
								; otherwise just spin
	ldi temp, 0b11111111
	out PORTB, temp
	rjmp countMagnetron
	
stopMagnetron:
	ldi temp, 0b00000000
	out PORTB, temp
	rjmp endMagnetron			
	
; switching magnetron ON for some time
; depending on the power level
switchMagnetronOn:
	clear_byte MagnetronCounter
	clear_byte MagnetronOff
	lds temp, PowerLevel		; check the power level
	cpi temp, 1
	breq switchMagnetronOn1
	cpi temp, 2
	breq switchMagnetronOn2
	cpi temp, 3
	breq switchMagnetronOn3
	endSwitchMagnetronOn:
	rjmp endMagnetron

; switching magnetron OFF for some time
; depending on the power level
switchMagnetronOff:
	clear_byte MagnetronCounter
	clear_byte MagnetronOn
	lds temp, PowerLevel		; check power level
	cpi temp, 1
	breq switchMagnetronOff1
	cpi temp, 2
	breq switchMagnetronOff2
	cpi temp, 3
	breq switchMagnetronOff3
	endSwitchMagnetronOff:
	rjmp endMagnetron

; MagnetronOn length depending on Power Level
switchMagnetronOn1:
	lds temp, MagnetronOn		
	ldi temp, 4					; set to spin for 4 time incs
	sts MagnetronOn, temp
	rjmp endSwitchMagnetronOn
switchMagnetronOn2:
	lds temp, MagnetronOn
	ldi temp, 2					; set to spin for 2 time incs
	sts MagnetronOn, temp
	rjmp endSwitchMagnetronOn
switchMagnetronOn3:
	lds temp, MagnetronOn
	ldi temp, 1					; set to spin for 1 time inc
	sts MagnetronOn, temp
	rjmp endSwitchMagnetronOn
; MagnetronOff length depending on Power Level
switchMagnetronOff1:
	lds temp, MagnetronOff
	ldi temp, 0
	sts MagnetronOff, temp
	rjmp endSwitchMagnetronOff
switchMagnetronOff2:
	lds temp, MagnetronOff
	ldi temp, 2
	sts MagnetronOff, temp
	rjmp endSwitchMagnetronOff
switchMagnetronOff3:
	lds temp, MagnetronOff
	ldi temp, 3
	sts MagnetronOff, temp
	rjmp endSwitchMagnetronOff
