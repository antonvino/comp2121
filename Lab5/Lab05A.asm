; This program implements a timer that counts one second using 
; Timer0 interrupt
.include "m2560def.inc"

.def temp = r16
.def temp1 = r18 
.def temp2 = r19
.def counter = r17
.def lcd = r20				; lcd handle
.def digit = r21			; used to display decimal numbers digit by digit
.def digitCount = r22		; how many digits do we have to display?

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
Timer1Counter:
   .byte 2              ; Temporary counter. Used to determine 
                        ; if one second has passed
Timer3Counter:
	.byte 2
VoltageFlag:
	.byte 1

; LCD macros
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
.macro do_lcd_digits
	clr digit
	clr digitCount
	mov temp, @0			; temp is given number
	rcall convert_digits	; call a function
.endmacro



.cseg
.org 0x0000
   jmp RESET
   jmp DEFAULT          ; No handling for IRQ0.
   jmp DEFAULT          ; No handling for IRQ1.
.org INT2addr
    jmp EXT_INT2
.org OVF0addr
   jmp Timer0OVF        ; Jump to the interrupt handler for
.org OVF3addr
   jmp Timer3OVF        ; Jump to the interrupt handler for
jmp DEFAULT          ; default service for all other interrupts.
DEFAULT:  reti          ; no service

RESET: 
    ldi temp, high(RAMEND) ; Initialize stack pointer
    out SPH, temp
    ldi temp, low(RAMEND)
    out SPL, temp
    ser temp
    out DDRC, temp ; set Port C as output

	; LCD setup
	ser temp
	out DDRF, temp
	out DDRA, temp
	clr temp
	out PORTF, temp
	out PORTA, temp

	; LCD: init the settings
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	do_lcd_data 'S';
	do_lcd_data 'p';
	do_lcd_data 'e';
	do_lcd_data 'e';
	do_lcd_data 'd';
	do_lcd_data ':';
	do_lcd_data ' ';

	;do_lcd_digits accumulator	; display the accumulator data every time
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_command 0b11000000	; break to the next line
	;do_lcd_digits currentNumber	; output current number

	rjmp main

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



EXT_INT2:
	in temp, SREG
	push temp
	push temp2

	;lds temp2, VoltageFlag
	;cpi temp2, 1
	;breq END_INT2

	inc counter

			;do_lcd_command 0b00000001 ; clear display
			;do_lcd_command 0b00000110 ; increment, no display shift
			;do_lcd_command 0b00001110 ; Cursor on, bar, no blink

			;do_lcd_data 'S';
			;do_lcd_data 'p';
			;do_lcd_data 'e';
			;do_lcd_data 'e';
			;do_lcd_data 'd';
			;do_lcd_data ':';
			;do_lcd_data ' ';

			;do_lcd_digits counter

	ldi temp2, 1
	sts VoltageFlag, temp2

	END_INT2:
		pop temp2
		pop temp
		out SREG, temp
		reti

Timer0OVF: ; interrupt subroutine to Timer0
    in temp, SREG
    push temp       ; Prologue starts.
    push YH         ; Save all conflict registers in the prologue.
    push YL
    push r25
    push r24
;	push counter
	        ; Prologue ends.
                    ; Load the value of the temporary counter.

	newSecond:
	    lds r24, Timer1Counter
    	lds r25, Timer1Counter+1
    	adiw r25:r24, 1 ; Increase the temporary counter by one.

    	cpi r24, low(600)      ; 1953 is what we need Check if (r25:r24) = 7812 ; 7812 = 10^6/128
    	ldi temp, high(600)    ; 7812 = 10^6/128
    	cpc r25, temp
    	brne NotSecond
		
		secondPassed:
			do_lcd_command 0b00000001 ; clear display
			do_lcd_command 0b00000110 ; increment, no display shift
			do_lcd_command 0b00001110 ; Cursor on, bar, no blink

			do_lcd_data 'S';
			do_lcd_data 'p';
			do_lcd_data 'e';
			do_lcd_data 'e';
			do_lcd_data 'd';
			do_lcd_data ':';
			do_lcd_data ' ';

			do_lcd_digits counter
			out PORTC, counter
			clr counter
			clear Timer1Counter

    rjmp EndIF

NotSecond: ; Store the new value of the temporary counter.
    sts Timer1Counter, r24
    sts Timer1Counter+1, r25 

    
EndIF:
	;pop counter
	pop r24         ; Epilogue starts;
    pop r25         ; Restore all conflict registers from the stack.
    pop YL
    pop YH
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.

Timer3OVF: ; interrupt subroutine to Timer3
	in temp, SREG
	push temp
	push r26
	push r27

	;lds temp, VoltageFlag	; if motor debounce is not set
	;cpi temp, 1				; don't even bother
	;brne EndTimer3

	lds r26, Timer3Counter	; increase temp counter
	lds r27, Timer3Counter+1
	adiw r27:r26, 1
		 
    cpi r26, low(5)		; check if the debounce time is over
    ldi temp, high(5)
    cpc r27, temp
    brne NotYet

	ldi temp, 0b00000000 	; debug LED
	out PORTC, temp

	clear Timer3Counter
	ldi temp, 0				; clear the debounce flag for motor interrupt
	sts VoltageFlag, temp

NotYet: ; Store the new value of the temporary counter.
    sts Timer3Counter, r26
    sts Timer3Counter+1, r27 


EndTimer3:
	pop r27
	pop r26
	pop temp
	out SREG, temp
	reti

main:
    clear Timer1Counter       ; Initialize the temporary counter to 0
	clear Timer3Counter
	ldi r26, 0
	sts VoltageFlag, r26	

	ldi temp, (2 << ISC00)      ; set INT0 as falling-
    sts EICRA, temp             ; edge triggered interrupt
    in temp, EIMSK              ; enable INT0
    ori temp, (1<<INT2)
    out EIMSK, temp

	; Timer0 initilaisation

    ldi temp, 0b00000000
    out TCCR0A, temp
    ldi temp, 0b00000010
    out TCCR0B, temp        ; Prescaling value=8
    ldi temp, 1<<TOIE0      ; = 128 microseconds
    sts TIMSK0, temp        ; T/C0 interrupt enable

	; Timer3 initialisation
	ldi temp, 0b00001000
	sts DDRL, temp
	
	ldi temp, 0x4A
	sts OCR3AL, temp
	clr temp
	sts OCR3AH, temp

	ldi temp, (1<<CS50)
	sts TCCR3B, temp
	ldi temp, (1<<WGM30)|(1<<COM3A1)
	sts TCCR3A, temp
	
	ldi temp, 1<<TOIE3	
    sts TIMSK3, temp        ; T/C0 interrupt enable


    sei                     ; Enable global interrupt
                            ; loop forever
    loop: rjmp loop

; function: displaying given number by digit in ASCII using stack
convert_digits:
	push digit
	;push temp
	;push temp1
	;push temp2
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
	;pop temp2
	;pop temp1
	;pop temp
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
	pop temp
	do_lcd_rdata temp
	rjmp endDisplayDigits

;
; Send a command to the LCD (lcd register)
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
