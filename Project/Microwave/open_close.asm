; This program implements a timer that counts one second using 
; Timer0 interrupt
.include "m2560def.inc"

.def temp = r16
.def temp1 = r18 
.def temp2 = r19
.def lcd = r20				; lcd handle
.def debounceFlag0 = r21	; button 1 debounce
.def debounceFlag1 = r22	; button 2 debounce

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
DisplayCounter:
    .byte 2              ; Display counter. Used to determine 
                         ; if 100ms have passed
DebounceCounter:
    .byte 2              ; Debounce counter. Used to determine 
                         ; if 50ms have passed
DoorState:
    .byte 1              ; 0 if the door is closed, 1 if the door is opened

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



.cseg
.org 0x0000
   jmp RESET
.org INT0addr
    jmp EXT_INT0
.org INT1addr
	jmp EXT_INT1
	jmp DEFAULT          ; No handling for IRQ1.
	jmp DEFAULT          ; No handling for IRQ1.


.org OVF0addr
   jmp Timer0OVF        ; Jump to the interrupt handler for
;.org OVF3addr
;   jmp Timer3OVF        ; Jump to the interrupt handler for
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

Timer0OVF: ; interrupt subroutine to Timer0
    in temp, SREG
    push temp       ; Prologue starts.
    push YH         ; Save all conflict registers in the prologue.
    push YL
	push r27
	push r26
    push r25
    push r24
	; Prologue ends.

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

	newSecond:
	    lds r24, Timer1Counter ; Load the value of the temporary counter.
    	lds r25, Timer1Counter+1
    	adiw r25:r24, 1 ; Increase the temporary counter by one.

    	cpi r24, low(1953)      ; 1953 is what we need Check if (r25:r24) = 7812 ; 7812 = 10^6/128
    	ldi temp, high(1953)    ; 7812 = 10^6/128
    	cpc r25, temp
    	brne NotSecond
		
		secondPassed: ; 1/4 of a second passed
			do_lcd_speed 		; show current speed
			clr measured_speed
			clear Timer1Counter

    rjmp EndIF

NotSecond: ; Store the new value of the temporary counter.
    sts Timer1Counter, r24
    sts Timer1Counter+1, r25 
	rjmp EndIF 

notFifty: 	; Store the new value of the debounce counter.
	sts DebounceCounter, r26
	sts DebounceCounter+1, r27
	rjmp EndIF

    
EndIF:
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
	       			; Prologue ends.
                    ; Load the value of the temporary counter.

	; debounce check
	cpi debounceFlag0, 1		; if the button is still debouncing, ignore the interrupt
	breq END_INT0	

	ldi debounceFlag0, 1		; set the debounce flag

	ldi temp, 20
	add target_speed, temp		; increase the speed
	sts OCR3BH, target_speed	; set the speed

	rjmp END_INT0

; Epilogue of push button 0
END_INT0:
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.
	
; subroutine for push button 1
EXT_INT1:
    in temp, SREG	; Prologue starts.
    push temp       ; Save all conflict registers in the prologue.
	       			; Prologue ends.
                    ; Load the value of the temporary counter.

	; debounce check
	cpi debounceFlag1, 1		; if the button is still debouncing, ignore the interrupt
	breq END_INT1	

	ldi debounceFlag1, 1		; set the debounce flag

	subi target_speed, 20		; increase the speed
	sts OCR3BH, target_speed	; set the speed

	rjmp END_INT1

; Epilogue of push button 1
END_INT1:
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.

main:
    clear Timer1Counter       ; Initialize the temporary counter to 0

	; INT0 (PB1) init
	ldi temp, (2 << ISC00)      ; set INT0 as falling-
    sts EICRA, temp             ; edge triggered interrupt
    in temp, EIMSK              ; enable INT0
    ori temp, (1<<INT0)
    out EIMSK, temp

	; INT1 (PB2) init
	ldi temp, (2 << ISC10)      ; set INT1 as falling-
    sts EICRA, temp             ; edge triggered interrupt
    in temp, EIMSK              ; enable INT1
    ori temp, (1<<INT1)
    out EIMSK, temp

	; INT2 (opto-interrupter) init
	ldi temp, (2 << ISC20)      ; set INT2 as falling-
    sts EICRA, temp             ; edge triggered interrupt
    in temp, EIMSK              ; enable INT2
    ori temp, (1<<INT2)
    out EIMSK, temp

	; Timer0 initilaisation
    ldi temp, 0b00000000
    out TCCR0A, temp
    ldi temp, 0b00000010
    out TCCR0B, temp        ; Prescaling value=8
    ldi temp, 1<<TOIE0      ; = 128 microseconds
    sts TIMSK0, temp        ; T/C0 interrupt enable

	; PWM Configuration
	; Configure bit PE2 as output
	ldi temp, 0b00010000
	ser temp
	out DDRE, temp ; Bit 3 will function as OC3B
	ldi temp, 0xFF ; the value controls the PWM duty cycle (store the value in the OCR registers)
	sts OCR3BL, temp
	clr temp
	sts OCR3BH, temp

	; Timer3 initialisation
	;ldi temp, 0b00001000
	;sts DDRL, temp
	
	;ldi temp, 0x4A
	;sts OCR3AL, temp
	;clr temp
	;sts OCR3AH, temp

	;ldi temp, (1<<CS50)
	;sts TCCR3B, temp
	;ldi temp, (1<<WGM30)|(1<<COM3A1)
	;sts TCCR3A, temp
	
	;ldi temp, 1<<TOIE3	
    ;sts TIMSK3, temp        ; T/C0 interrupt enable

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
