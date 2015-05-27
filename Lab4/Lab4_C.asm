; Lab 4 C - calculator with decimals
; Added Lab 4D here as well - multiplication and division
.include "m2560def.inc"

.def row = r16              ; current row number
.def col = r17              ; current column number
.def rmask = r18            ; mask for current row during scan
.def cmask = r19            ; mask for current column during scan
.def temp1 = r20 
.def temp2 = r21
.def temp = r22
.def lcd = r23
.def accumulator = r24		; the accumulator at the top line
.def currentNumber = r25	; the current number we want to add/subtract etc.
.def operation = r26		; operation (A/B/C/D = 1/2/3/4)
.def digit = r27			; used to display decimal numbers digit by digit
.def debounceFlag = r30		; the debounce flag
.def digitCount = r31		; how many digits do we have to display?
.equ PORTLDIR = 0xF0        ; PH7-4: output, PH3-0, input
.equ INITCOLMASK = 0xEF     ; scan from the rightmost column,
.equ INITROWMASK = 0x01     ; scan from the top row
.equ ROWMASK = 0x0F         ; for obtaining input from Port L

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
TempCounter:
    .byte 2             ; Temporary counter. Counts milliseconds
DebounceCounter:		; Debounce counter. Used to determine
    .byte 2             ; if 100ms have passed  
                        

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

; Interrupts handling
.cseg
.org 0x0000
    jmp RESET
    jmp DEFAULT          ; No handling for IRQ0.
    jmp DEFAULT          ; No handling for IRQ1.
.org OVF0addr
    jmp Timer0OVF        ; Jump to the interrupt handler for
                        ; Timer0 overflow.
	jmp DEFAULT          ; default service for all other interrupts.
DEFAULT:  reti          ; no service


RESET:
	ldi temp1, low(RAMEND)  ; initialize the stack
    out SPL, temp1
    ldi temp1, high(RAMEND)
    out SPH, temp1

	sei                     ; enable Global Interrupt

	; keypad setup
    ldi temp1, PORTLDIR     ; PB7:4/PB3:0, out/in
    sts DDRL, temp1         ; PORTB is input
    ser temp1               ; PORTC is output
    out DDRC, temp1
    out PORTC, temp1
	
	; LCD setup
	ser temp
	out DDRE, temp
	out DDRA, temp
	clr temp
	out PORTE, temp
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

	;do_lcd_command 0b00000001 ; clear display
	;out PORTC, currentNumber

	; clear calculator stuff
	clr accumulator
	clr currentNumber
	clr operation

	do_lcd_digits accumulator	; display the accumulator data every time
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	do_lcd_command 0b11000000	; break to the next line
	do_lcd_digits currentNumber	; output current number

    rjmp main         	; restart the main loop

halt:
	rjmp main ; not halt

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
	; Prologue ends.

	; first counter - 50ms debounce counter
	checkFlagSet:				; if either flag is set - run the debounce timer
		cpi debounceFlag, 1
		breq newDebounce		; i.e. set to 1
		; otherwise - don't need the debounce timer
		rjmp EndIF ; go to the epilogue

	newDebounce:	;	if flag is set continue counting until 100 milliseconds
		;ldi temp, 0b11000011
		;out PORTC, temp
		lds r26, DebounceCounter
    	lds r27, DebounceCounter+1
    	adiw r27:r26, 1 ; Increase the temporary counter by one.

    	cpi r26, low(100)      ; Check if (r25:r24) = 390 ; 7812 = 10^6/128/20 ; 50 milliseconds
    	ldi temp, high(100)    ; 390 = 10^6/128/20 
    	cpc temp, r27
    	brne notHundred			; 100 milliseconds have not passed

		clr debounceFlag 		;	once 100 milliseconds have passed, set the debounceFlag to 0
	   	clear DebounceCounter	; Reset the debounce counter.
		clr r26
		clr r27	; Reset the debounce counter.

    rjmp EndIF

; supplementary functions

notHundred: 		; Store the new value of the debounce counter.
	sts DebounceCounter, r26
	sts DebounceCounter+1, r27
	rjmp EndIF
	    
EndIF:
    pop r26         ; Epilogue starts;
    pop r27         ; Restore all conflict registers from the stack.
    pop YL
    pop YH
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.


main:
	clear DebounceCounter       ; Initialize the temporary counter to 0

    ldi temp, 0b00000000
    out TCCR0A, temp
    ldi temp, 0b00000010
    out TCCR0B, temp        ; Prescaling value=8
    ldi temp, 1<<TOIE0      ; = 128 microseconds
    sts TIMSK0, temp        ; T/C0 interrupt enable
    sei                     ; Enable global interrupt

initKeypadClear:
	clr digit
initKeypad:
    ldi cmask, INITCOLMASK  ; initial column mask
    clr col                 ; initial column
	clr temp
	clr temp1
	clr temp2

	; debounce check
	cpi debounceFlag, 1		; if the button is still debouncing, ignore the keypad
	breq initKeypad	

	ldi debounceFlag, 1		; otherwise set the flag now to init the debounce

colloop:
    cpi col, 4
    breq initKeypadClear    ; If all keys are scanned, repeat. UPD: button was released
    sts PORTL, cmask        ; Otherwise, scan a column.
  
    ldi temp1, 0xFF         ; Slow down the scan operation.

delay:
    dec temp1
    brne delay              ; until temp1 is zero? - delay

    lds temp1, PINL         ; Read PORTL
    andi temp1, ROWMASK     ; Get the keypad output value
    cpi temp1, 0xF          ; Check if any row is low
    breq nextcol            ; if not - switch to next column

                            ; If yes, find which row is low
    ldi rmask, INITROWMASK  ; initialize for row check
    clr row

; and going into the row loop
rowloop:
    cpi row, 4              ; is row already 4?
    breq nextcol            ; the row scan is over - next column
    mov temp2, temp1
    and temp2, rmask        ; check un-masked bit
    breq convert            ; if bit is clear, the key is pressed
    inc row                 ; else move to the next row
    lsl rmask
    rjmp rowloop
    
nextcol:                    ; if row scan is over
    lsl cmask
    inc col                 ; increase col value
    rjmp colloop            ; go to the next column
     
convert:
	cpi digit, 1			; button has not been released yet
	breq initKeypad			; don't use it, scan again

	; NOTE: cols and rows are counter-intuitive (swap)
	mov temp, col
	mov col, row
	mov row, temp

	; DEBUG show the column and row pressed
	;do_lcd_data 'c'
	;do_lcd_rdata col
	;do_lcd_data 'r'
	;do_lcd_rdata row
	;out PORTC, row
	
    cpi col, 3              ; If the pressed key is in col 3
    breq letters            ; we have letter
                            ; If the key is not in col 3 and
    cpi row, 3              ; if the key is in row 3,
    breq symbols            ; we have a symbol or 0

    mov temp1, row          ; otherwise we have a number 1-9
    lsl temp1
    add temp1, row
    add temp1, col          ; temp1 = row*3 + col
	subi temp1, -1			; add the value of binary 1
							; i.e. 0,0 will be 1

	ldi temp, 10			; add a digit to the current number
	mul currentNumber, temp
	mov currentNumber, r0
	;out PORTC, currentNumber
	add currentNumber, temp1

    rjmp convert_end
    
letters:
    ;ldi temp1, 'A'
    ;add temp1, row          ; Get the ASCII value for the key

	cpi row, 1
	breq letterB
	cpi row, 2
	breq letterC
	cpi row, 3
	breq letterD
	
    rjmp letterA

letterA: ; addition
	ldi operation, 1
	rjmp doOperation
letterB: ; subtraction
	ldi operation, 2
	rjmp doOperation
letterC: ; multiplication
	do_lcd_data 'm'
	ldi operation, 3
	rjmp doOperation
letterD: ; division
	ldi operation, 4
	rjmp doOperation

doOperation:
	cpi operation, 0
	breq convert_end
	cpi operation, 1
	breq doAdd
	cpi operation, 2
	breq doSubtract
	cpi operation, 3
	breq doMultiply
	cpi operation, 4
	breq doDivide
	rjmp convert_end

doAdd:
	add accumulator, currentNumber
	clr currentNumber
	rjmp convert_end
doSubtract:
	sub	accumulator, currentNumber
	clr currentNumber
	rjmp convert_end
doMultiply:
	mul accumulator, currentNumber
	mov accumulator, r0
	clr currentNumber
	rjmp convert_end
doDivide:
	mov temp2, currentNumber
	rcall division
	clr currentNumber
	rjmp convert_end

symbols:
    cpi col, 0              ; Check if we have a star
    breq star
    cpi col, 1              ; or if we have zero
    breq zero
    ;ldi temp1, '#'         ; if not we have hash
	;clr temp1				; TEMP: not handling the hash now
    rjmp initKeypad
star:
	clr accumulator
	clr currentNumber
    rjmp convert_end
zero:
	ldi temp, 10			; add a digit to the current number
	mul currentNumber, temp
	mov currentNumber, r0
	rjmp convert_end

convert_end:
	do_lcd_command 0b00000001 ; clear display
	out PORTC, currentNumber

	do_lcd_digits accumulator	; display the accumulator data every time
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	;do_lcd_data ' ';
	do_lcd_command 0b11000000	; break to the next line
	do_lcd_digits currentNumber	; output current number

	ldi digit, 1				; use digit as flag - key is pressed but not released yet
    rjmp initKeypad         	; restart the main loop


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
	out PORTE, lcd
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTE, lcd
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
	out PORTE, lcd
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in lcd, PINE
	lcd_clr LCD_E
	sbrc lcd, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser lcd
	out DDRE, lcd
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

; Div8 divides a 8-bit-number by a 8-bit-number
division:
	; save registers
	push temp1
	push temp2
	push temp

	; Divide accumulator by temp2
	div8:
		clr temp1 	; clear interim register
		clr temp  	; clear result (the result registers
		     		; are also used to count to 16 for the
		inc temp  	; division steps, is set to 1 at start)

	; Here the division loop starts
	div8a:
		clc      			; clear carry-bit
		rol accumulator  	; rotate the next-upper bit of the number
			 				; to the interim register (multiply by 2)
		rol temp1
		brcs div8b 			; a one has rolled left, so subtract
		cp temp1,temp2 		; Division result 1 or 0?
		brcs div8c  		; jump over subtraction, if smaller
	div8b:
		sub temp1,temp2		; subtract number to divide with
		sec      			; set carry-bit, result is a 1
		rjmp div8d  		; jump to shift of the result bit
	div8c:
		clc      			; clear carry-bit, resulting bit is a 0
	div8d:
		rol temp   			; rotate carry-bit into result registers
		brcc div8a  		; as long as zero rotate out of the result
	            			; registers: go on with the division loop

	mov accumulator, temp ; move result to the accumulator
	; restore registers
	pop temp
	pop temp2
	pop temp1
	; End of the division reached
	ret
