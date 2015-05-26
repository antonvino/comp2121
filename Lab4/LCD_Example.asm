.include "m2560def.inc"

.def temp1 = r20 
.def temp2 = r21
.def temp = r17
.def currentNumber = r25	; the current number we want to add/subtract etc.
.def digit = r18			; used to display decimal numbers digit by digit
.def digitCount = r19		; how many digits do we have to display?
.def lcd = r23


.macro do_lcd_command
	ldi lcd, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro
.macro do_lcd_data
	ldi lcd, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro
.macro do_lcd_rdata
	mov lcd, @0
	subi lcd, -'0'
	rcall lcd_data
	rcall lcd_wait
.endmacro


.org 0
	jmp RESET


RESET:
	ldi lcd, low(RAMEND)
	out SPL, lcd
	ldi lcd, high(RAMEND)
	out SPH, lcd

	ser lcd
	out DDRF, lcd
	out DDRA, lcd
	clr lcd
	out PORTF, lcd
	out PORTA, lcd

	ser temp1               ; PORTC is output
    out DDRC, temp1
    out PORTC, temp1


	;do_lcd_command 0b00111000 ; 2x5x7
	;rcall sleep_5ms
	;do_lcd_command 0b00111000 ; 2x5x7
	;rcall sleep_1ms
	;do_lcd_command 0b00111000 ; 2x5x7
	;do_lcd_command 0b00111000 ; 2x5x7
	;do_lcd_command 0b00001000 ; display off?
	;do_lcd_command 0b00000001 ; clear display
	;do_lcd_command 0b00000110 ; increment, no display shift
	;do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	;do_lcd_data 'H'
	;do_lcd_data 'e'
	;do_lcd_data 'l'
	;do_lcd_data 'l'
	;do_lcd_data 'o'



	ldi currentNumber, 238	; 238

	ldi temp2, 238
	ldi temp1, 100
	cp temp2, temp1
	brge skip_second_less; I STOPPED HERE - TRYING TO CHECK IF COMPARISON WORKS
	; WHICH ARGUMNET SHOULD BE FIRST AND SECOND??? GO ON FROM HERE
	; THEN MAKE IT WORK JUST ON LCD THEN GO BACK TO LAB4s
	do_lcd_data '!';
	skip_second_less:

	ldi temp2, 238
	ldi temp1, 100
	subi temp2, 100
	out PORTC, temp2


	; displaying current number by digit in ASCII using stack
	; hundreds
	;ldi currentNumber, 0b11101110	; 238
	ldi currentNumber, 238
	clr digitCount				; initialize digit stuff
	clr digit	
	clr temp
	clr lcd				
	mov temp, currentNumber		; temp is currentNumber
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

    rjmp halt         	; restart the main loop

; hundreds digit
hundredsDigit:
	inc digit			; if YES increase the digit count
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
	rjmp halt

dispTwoDigits:
	pop temp2
	pop temp1
	do_lcd_rdata temp1
	do_lcd_rdata temp2
	rjmp halt

dispOneDigit:
	pop temp
	do_lcd_rdata temp
	rjmp halt


halt:
	rjmp halt

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

;
; Send a command to the LCD (lcd)
;

lcd_command:
	out PORTF, lcd
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, lcd
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push lcd
	clr lcd
	out DDRF, lcd
	out PORTF, lcd
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in lcd, PINF
	lcd_clr LCD_E
	sbrc lcd, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser lcd
	out DDRF, lcd
	pop lcd
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret
