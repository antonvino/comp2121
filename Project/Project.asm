; Microwave emulator
; Main project file
;
; Authors: Ali Mokdad, Anton Vinokurov
; Based on COMP2121 Lab and lecture examples
; License: MIT
; UNSW 2015
.include "m2560def.inc"

.def row = r16              ; current row number
.def col = r17              ; current column number
.def rmask = r18            ; mask for current row during scan
.def cmask = r19            ; mask for current column during scan
.def temp1 = r20 
.def temp2 = r21
.def temp = r22
.def lcd = r23
.def debounceFlag0 = r24	; button 1 debounce
.def debounceFlag1 = r25	; button 2 debounce
.def digit = r27			; used to display decimal numbers digit by digit
.def debounceFlag = r30		; the debounce flag
.def digitCount = r31		; how many digits do we have to display?
.equ PORTLDIR = 0xF0        ; PH7-4: output, PH3-0, input
.equ INITCOLMASK = 0xEF     ; scan from the rightmost column,
.equ INITROWMASK = 0x01     ; scan from the top row
.equ ROWMASK = 0x0F         ; for obtaining input from Port L

.include "modules/macros.asm"
                        
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
DoorState:				; Door state 0: closed | 1: opened
    .byte 1             
Mode:					; Current mode 0: Entry | 1: Running | 2: Pause | 3: Finished | 4: Power Level
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

; Interrupts handling
.cseg
.org 0x0000
    jmp RESET
.org INT0addr
    jmp EXT_INT0
.org INT1addr
	jmp EXT_INT1
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

	do_lcd_command 0b00000001 ; clear display

  	rjmp main         	; restart the main loop


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

.include "modules/timer0.asm"

main:
	clear DebounceCounter       ; Initialize the temporary counter to 0
    clear_byte DoorState        ; Initialize the door state to closed

	; Timer 0 init
    ldi temp, 0b00000000
    out TCCR0A, temp
    ldi temp, 0b00000010
    out TCCR0B, temp        ; Prescaling value=8
    ldi temp, 1<<TOIE0      ; = 128 microseconds
    sts TIMSK0, temp        ; T/C0 interrupt enable


	; INT0 (PB1) init
	ldi temp, (2 << ISC00)      ; set INT0 as falling-
    sts EICRA, temp             ; edge triggered interrupt
    in temp, EIMSK              ; enable INT0
    ori temp, (1<<INT0)
    out EIMSK, temp

	; INT1 (PB2) init
	ldi temp, (2 << ISC00)      ; set INT1 as falling-
    sts EICRA, temp             ; edge triggered interrupt
    in temp, EIMSK              ; enable INT1
    ori temp, (1<<INT1)
    out EIMSK, temp

    sei                     ; Enable global interrupt

.include "modules/keypad.asm"

.include "modules/digits.asm"

.include "modules/lcd.asm"

.include "modules/open_close.asm"

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
		
	rcall display_door
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

display_door:
	push temp
	lds temp, DoorState
	cpi temp, 1
	breq display_door_opened
	do_lcd_data 'C'			; if closed show C at the top-right
	ldi temp, 0b00000000	; switch LEDs off
	out PORTC, temp
	end_display_door:
	pop temp
	ret

display_door_opened:
	ldi temp, 0b10000000	; light up the top-most LED
	out PORTC, temp
	do_lcd_data 'O'			; show O at the top-right
	rjmp end_display_door
