; Decimal digits output using LCD functions
; Authors: Anton Vinokurov
; Based on COMP2121 Lab and lecture examples
; License: MIT
; UNSW 2015

; function: displaying given number by digit in ASCII using stack
convert_digits:
	push digit
	push temp
	push temp1
	push temp2
	checkHundreds:
		cpi temp, 100			; is the number still > 100?
		brsh hundredsDigit		; if YES - increase hundreds digit
		cpi digit, 0			
		brne pushHundredsDigit	; If digit ! 0 => this digit goes into stack
		
	checkTensInit:
		clr digit
	checkTens:
		ldi temp1, 10
		cp temp, temp1			; is the number still > 10? 
		brsh tensDigit			; if YES - increase tens digit
		cpi digitCount, 1		; were there hundred digits?
		breq pushTensDigit		; if YES i.e. digitCount==1 -> push the tens digit even if 0
								; otherwise: no hundreds are present
		cpi digit, 0			; is tens digit = 0?
		brne pushTensDigit		; if digit != 0 push it to the stack			 

	saveOnes:
		clr digit				; ones are always saved in stack
		mov digit, temp			; whatever is left in temp is the ones digit
		push digit				
		inc digitCount
	; now all digit temp data is in the stack
	; unload data into temp2, temp1, temp
	; and the do_lcd_rdata in reverse order
	; this will display the currentNumber value to LCD
	; it's not an elegant solution but will do for now
	cpi digitCount, 3
	breq dispThreeDigits
	cpi digitCount, 2
	breq dispTwoDigits
	cpi digitCount, 1
	breq dispOneDigit

	endDisplayDigits:
	pop temp2
	pop temp1
	pop temp
	pop digit
	ret

; hundreds digit
hundredsDigit:
	inc digit				; if YES increase the digit count
	subi temp, 100			; and subtract a 100 from the number
	rjmp checkHundreds		; check hundreds again

; tens digit
tensDigit:
	inc digit				; if YES increase the digit count
	subi temp, 10			; and subtract a 10 from the number
	rjmp checkTens			; check tens again

pushHundredsDigit:
	push digit
	inc digitCount
	rjmp checkTensInit

pushTensDigit:
	push digit
	inc digitCount
	rjmp saveOnes

dispThreeDigits:
	pop temp2
	pop temp1
	pop temp
	do_lcd_rdata temp
	do_lcd_rdata temp1
	do_lcd_rdata temp2
	rjmp endDisplayDigits

dispTwoDigits:
	pop temp2
	pop temp1
	do_lcd_rdata temp1
	do_lcd_rdata temp2
	rjmp endDisplayDigits

dispOneDigit:
	ldi temp, 0
	do_lcd_rdata temp
	pop temp
	do_lcd_rdata temp
	rjmp endDisplayDigits

