.include "m2560def.inc"

.def row = r16              ; current row number
.def col = r17              ; current column number
.def rmask = r18            ; mask for current row during scan
.def cmask = r19            ; mask for current column during scan
.def temp1 = r20 
.def temp2 = r21
.def temp = r22
.def lcd = r23
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

; The macro clears a byte (1 byte) in a memory
; the parameter @0 is the memory address for that byte
.macro clear_byte
    ldi YL, high(@0)     		; load the memory address to Y
    clr temp 
    st Y, temp         ; clear the byte at @0 in SRAM
.endmacro
                        
.dseg
TempCounter:
    .byte 2             ; Temporary counter. Counts milliseconds
DisplayCounter:			; Used to call display_data every 100ms
    .byte 1
DebounceCounter:		; Debounce counter. Used to determine
    .byte 2             ; if 100ms have passed
MicrowaveCounter:
	.byte 2
DisplayDigits:
	.byte 4
EnteredDigits:
	.byte 1
DoorState:
	.byte 1
Mode:					; 0: Entry | 1: Running | 2: Pause | 3: Finished | 4: Power Level
	.byte 1
Minutes:
	.byte 1
Seconds:
	.byte 1
RefreshFlag:
	.byte 1
MoreFlag:
	.byte 1
LessFlag:
	.byte 1	
StopFlag:
	.byte 1
PowerLevel:
	.byte 1
SecondsIdle:
	.byte 1
FadingFlag:
	.byte 1


; digit entering macro
.macro shift_left_once
	lds YL, @0+1
	sts @0, YL
	lds YL, @0+2
	sts @0+1, YL
	lds YL, @0+3
	sts @0+2, YL
.endmacro
	                        

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

	;do_lcd_command 0b00000001 ; clear display

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
		rjmp endDebounce 		; end of Debouncing

	newDebounce:	;	if flag is set continue counting until 100 milliseconds
		;ldi temp, 0b11000011
		;out PORTC, temp
		lds r26, DebounceCounter
    	lds r27, DebounceCounter+1
    	adiw r27:r26, 1 ; Increase the temporary counter by one.

    	cpi r26, low(50)      ; Check if (r25:r24) = 390 ; 7812 = 10^6/128/20 ; 50 milliseconds
    	ldi temp, high(50)    ; 390 = 10^6/128/20 
    	cpc temp, r27
    	brne notHundred			; 100 milliseconds have not passed

		clr debounceFlag 		;	once 100 milliseconds have passed, set the debounceFlag to 0
	   	clear DebounceCounter	; Reset the debounce counter.
		clr r26
		clr r27	; Reset the debounce counter.
	endDebounce:
		rjmp microwaveRunning	

	notHundred: 		; Store the new value of the debounce counter.
	sts DebounceCounter, r26
	sts DebounceCounter+1, r27
	rjmp endDebounce

	microwaveRunning:
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
			inc temp
			sts Minutes, temp
			lds temp, Seconds
			ldi temp1, 30
			sub temp, temp1
			sts Seconds, temp
			do_lcd_data '-'
			do_lcd_digits temp
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

		;do_lcd_data 'T'

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

; supplementary functions

notOneSecond:
	sts MicrowaveCounter, r26
	sts MicrowaveCounter+1, r27
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
	rcall sleep_5ms
	clr digit
initKeypad:
	lds temp, DoorState		; if the door is open don't accept any input
	cpi temp, 1
	breq initKeypad

    lds temp, RefreshFlag
	cpi temp, 1
	brne init_continue
	ldi temp, 0
	sts RefreshFlag, temp
	rcall display_data
	
	init_continue:	
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
    breq letters	 		; we have letter
                            ; If the key is not in col 3 and
	notLetter:
    cpi row, 3              ; if the key is in row 3,
    brne numbers			; we have a symbol or 0
	jmp symbols

	numbers:
    mov temp1, row          ; otherwise we have a number 1-9
    lsl temp1
    add temp1, row
    add temp1, col          ; temp1 = row*3 + col
	subi temp1, -1			; add the value of binary 1
							; i.e. 0,0 will be 1

	lds temp, Mode
	cpi temp, 4
	brne digitDisplay

	PowerLevelSet:
	cpi temp1, 4
	brlt PowerLevelCheck0
	jmp convert_end

	PowerLevelCheck0:
	cpi temp1, 0
	brne valid_power_level
	jmp convert_end

	valid_power_level:
	sts PowerLevel, temp
	ldi temp, 0
	sts Mode, temp
	rjmp convert_end

; TODO: do digit entry stuff here
digitDisplay:
	lds YL, EnteredDigits
	inc YL
	sts EnteredDigits, YL
	cpi YL, 5
	brlt display
	jmp convert_end
	
	display:
	shift_left_once DisplayDigits
	sts DisplayDigits+3, temp1	
	rjmp convert_end

letters:
	cpi row, 0
	breq letterA
	cpi row, 1
	breq letterB

letterA:
	ACheckEntry:
	lds temp, Mode			; Only add if in running mode
	cpi temp, 0
	breq PowerModeSet

	ACheckRunning:
	cpi temp, 1
	breq setMore
	rjmp convert_end

	PowerModeSet:
	ldi temp, 4
	sts Mode, temp
	rjmp convert_end

	setMore:
	ldi temp, 1
	sts MoreFlag, temp
	rjmp convert_end

letterB:
	lds temp, Mode			; Only add if in running mode
	cpi temp, 1
	breq setLess
	jmp convert_end

	setLess:
	ldi temp, 1
	sts LessFlag, temp
	rjmp convert_end

	rjmp convert_end

symbols:
    cpi col, 0              ; Check if we have a star
    breq star
    cpi col, 1              ; or if we have zero
    breq zero
	cpi col, 2
	breq hash
    rjmp initKeypad

hash:
	lds temp, Mode				; if in power level screen, return to entry
	cpi temp, 4
	brne hashCheckEntry

	ldi temp, 0
	sts Mode, temp
	rjmp convert_end

	hashCheckEntry:
	lds temp, Mode				; if in entry mode, clear the entered values
	cpi temp, 0
	breq hashEntryMode

	hashRunningMode:			; if in running mode, change it to pause mode
	lds temp, Mode
	cpi temp, 1
	breq hashSetPause
	
	hashPauseMode:				; if in running mode clear everything and reset
	clr temp
	sts Minutes, temp
	sts Seconds, temp
	sts Mode, temp
	rjmp hashEntryMode
	
	hashSetPause:
	ldi temp, 2
	sts Mode, temp
	rjmp convert_end 

	hashEntryMode: 				; clear any input
	clr temp					
	sts EnteredDigits, temp
	sts DisplayDigits, temp
	sts DisplayDigits+1, temp
	sts DisplayDigits+2, temp
	sts DisplayDigits+3, temp
	rjmp convert_end

zero:
	ldi temp1, 0
	rjmp digitDisplay

star:
	lds temp, Mode
	cpi temp, 0
	breq startMicrowave
	rjmp checkAddMinute

	checkAddMinute:
	cpi temp, 4
	breq star_end				; end, we're in power level screen

	cpi temp, 3					; end we're in finished screen
	breq star_end

	lds temp, Minutes
	inc temp
	sts Minutes, temp
	rjmp star_Set_Entry

	startMicrowave:
	; check if a time has been entered
	lds temp, EnteredDigits
	cpi temp, 0
	brne digitsEntered
	
	noDigitsEntered:
	ldi temp, 1
	sts Minutes, temp
	ldi temp, 0
	sts Seconds, temp
	rjmp star_Set_Entry

	digitsEntered:
 	lds temp1, DisplayDigits+2
 	ldi temp, 10
 	mul temp, temp1
 	lds temp1, DisplayDigits+3
 	add temp1, r0
 	sts Seconds, temp1

	lds temp1, DisplayDigits
	ldi temp, 10
  	mul temp, temp1
  	lds temp1, DisplayDigits+1
  	add temp1, r0
  	sts Minutes, temp1

	star_Set_Entry:
	ldi temp, 1
	sts Mode, temp
	ldi temp, 0
	sts StopFlag, temp
	
	star_end:
 	rjmp convert_end
    
convert_end:
	do_lcd_command 0b00000001 ; clear display
	rcall display_data
	;rcall display_time
	
Finish:
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
	ldi temp, 0
	do_lcd_rdata temp
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

;
; Display the data
;
display_data:
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	lds temp, Mode
	cpi temp, 3
	breq display_finished_mode
	
	displayOther:
	lds temp, Mode
	cpi temp, 4
	breq PowerLevelScreen

	rcall display_time
	; TODO: move cursor to the turntable spot
	;rcall display_turntable
	rjmp DoorDisplay
	
	PowerLevelScreen:
	do_lcd_data 'S'
	do_lcd_data 'e'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 'P'
	do_lcd_data 'o'
	do_lcd_data 'w'
	do_lcd_data 'e'
	do_lcd_data 'r'
	do_lcd_data ' '
	do_lcd_data '1'
	do_lcd_data '/'
	do_lcd_data '2'
	do_lcd_data '/'
	do_lcd_data '3'
	rjmp DoorDisplay		

	display_finished_mode:
	do_lcd_data 'D'
	do_lcd_data 'o'
	do_lcd_data 'n'
	do_lcd_data 'e'

	do_lcd_command 0b11000000	; break to the next line

	do_lcd_data 'R'
	do_lcd_data 'e'
	do_lcd_data 'm'
	do_lcd_data 'o'
	do_lcd_data 'v'
	do_lcd_data 'e'
	do_lcd_data ' '
	do_lcd_data 'f'
	do_lcd_data 'o'
	do_lcd_data 'o'
	do_lcd_data 'd'
	rjmp DoorDisplay

	DoorDisplay:
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
		
	DoorStatus:
	lds YL, DoorState
	cpi YL, 0
	breq DoorOpen

	DoorOpen:
	do_lcd_data 'O'
	rjmp display_end

	DoorClosed:
	do_lcd_data 'C'
	rjmp display_end

	display_end:
	ret


display_time:
	push temp
	lds temp, Mode
	cpi temp, 0
	breq display_input				; if in entry mode display input
	rjmp display_countdown			; otherwise display current time

display_input:
	;lds YL, EnteredDigits
	;do_lcd_digits YL :

	lds YL, DisplayDigits
	do_lcd_rdata YL
	lds YL, DisplayDigits+1
	do_lcd_rdata YL
	do_lcd_data ':'
	lds YL, DisplayDigits+2
	do_lcd_rdata YL
	lds YL, DisplayDigits+3
	do_lcd_rdata YL
	rjmp display_Turntable

display_countdown:
	lds temp, Minutes
	do_lcd_digits temp
	do_lcd_data ':'
	lds temp, Seconds
	do_lcd_digits temp

	rjmp display_Turntable

display_Turntable:
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data 'T'
	; display turntable here
	pop temp
	ret
