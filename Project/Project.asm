; Microwave emulator
; Main project file
;
; Authors: Ali Mokdad, Anton Vinokurov
; Based on COMP2121 Lab and lecture examples
; License: MIT
; UNSW 2015
.include "m2560def.inc"

;
; Registers in ascending order
;
.def row = r16              ; current row number
.def col = r17              ; current column number
.def rmask = r18            ; mask for current row during scan
.def cmask = r19            ; mask for current column during scan
.def temp1 = r20            ; temporary register for various ops
.def temp2 = r21            ; temporary register for various ops
.def temp = r22             ; temporary register for various ops
.def lcd = r23              ; lcd handle
.def debounceFlag0 = r24	; button 1 debounce
.def debounceFlag1 = r25	; button 2 debounce
.def timerTemp = r26        ; temporary register for timer ops
.def digit = r27			; used to display decimal numbers digit by digit
.def debounceFlag = r30		; the debounce flag
.def digitCount = r31		; how many digits do we have to display?
.equ PORTLDIR = 0xF0        ; PH7-4: output, PH3-0, input
.equ INITCOLMASK = 0xEF     ; scan from the rightmost column,
.equ INITROWMASK = 0x01     ; scan from the top row
.equ ROWMASK = 0x0F         ; for obtaining input from Port L

.include "modules/macros.asm"

;
; The data structures
;                        
.dseg
TempCounter:
    .byte 2             ; Temporary counter. Counts milliseconds
DisplayCounter:			; Used to call display_data every 100ms
    .byte 1
DebounceCounter:		; Debounce counter. Used to determine
    .byte 2             ; if 100ms have passed
MicrowaveCounter:       ; used to count 1 second decrements of time
	.byte 2
DisplayDigits:          ; digits to display (4 bytes)
	.byte 4
EnteredDigits:          ; digits that have been entered
	.byte 1
DoorState:				; Door state 0: closed | 1: opened
    .byte 1             
Mode:					; Current mode 0: Entry | 1: Running | 2: Pause | 3: Finished | 4: Power Level
	.byte 1
Minutes:                ; Minutes in the microwave timer
	.byte 1
Seconds:                ; Seconds in the microwave timer
	.byte 1
RefreshFlag:            ; Flag to check whether to display data on keypress or not
	.byte 1
MoreFlag:               ; Flag for addition of 30s
	.byte 1
LessFlag:               ; Flag for subraction of 30s
	.byte 1	
;StopFlag:               ; not used
;	.byte 1
PowerLevel:             ; Power level for magnetron 0: not set | 1: 100% | 2: 50% | 3: 25% 
	.byte 1
;SecondsIdle:           ; not used
;	.byte 1
;FadingFlag:             ; not used
;	.byte 1
TurntableCounter:		; counts 2.5s
	.byte 2
TurntableState:			; stores the state of turntable 8bit - 8 states
	.byte 1
TurntableDirection:		; stores the turntable direction flag 0 CW / 1 CCW
	.byte 1
MagnetronTempCounter:	; Temporary counter. Used to determine
	.byte 2				; if one time inc = 1/4 second has passed                        
MagnetronCounter:		; Counts how many time incs have passed
	.byte 1
MagnetronOn:			; sets for how many time incs it should be on
	.byte 1
MagnetronOff:			; sets for how many time incs it should be off
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
    ldi temp1, PORTLDIR     ; PL7:4/PL3:0, out/in
    sts DDRL, temp1         ; PORTL is input
    ser temp1               
    out DDRC, temp1			; Port C is output (LEDs)
    out DDRB, temp1 		; Port B is output (Motor)
	
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

	do_lcd_data 'E'
	do_lcd_data 'n'
	do_lcd_data 't'
	do_lcd_data 'e'
	do_lcd_data 'r'
	do_lcd_data ' '
	do_lcd_data 't'
	do_lcd_data 'i'
	do_lcd_data 'm'
	do_lcd_data 'e'

	do_lcd_command 0b11000000	; break to the next line

	do_lcd_data 'O'
	do_lcd_data 'R'
	do_lcd_data ' '
	do_lcd_data 'S'
	do_lcd_data 't'
	do_lcd_data 'a'
	do_lcd_data 'r'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data '('
	do_lcd_data '*'
	do_lcd_data ')'

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
	clear DebounceCounter       ; Initialize all counters to 0
	clear TempCounter       	
	clear_byte DisplayCounter
	clear MicrowaveCounter
	       
	clear_byte Mode				; Reset all values for microwave
	clear_byte Minutes
	clear_byte Seconds

	clear_byte RefreshFlag		; Initialize all flags to 0
	clear_byte MoreFlag
	clear_byte LessFlag
	;clear_byte StopFlag
	;clear_byte FadingFlag

    clear_byte DoorState        ; Initialize the door state to closed

	clear TurntableCounter	    ; Initialize the turntable counter to 0
	clear_byte TurntableState	; init turntable stuff
	clear_byte TurntableDirection 

	clear_byte PowerLevel		; init the power level to 0 (not set)
    clear MagnetronTempCounter  ; init the temp magnetron counter to 0
	clear_byte MagnetronCounter ; init the magnetron
	clear_byte MagnetronOn
	clear_byte MagnetronOff

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

.include "modules/turntable.asm"


;
; Display the data
;
display_data:
	push temp

	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	; Finished mode
	lds temp, Mode
	cpi temp, 3
	breq displayFinishedMode
	rjmp endDisplayFinishedMode	

	displayFinishedMode:
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
		; set the cursor for the bottom right
		do_lcd_data ' '
		do_lcd_data ' '
		do_lcd_data ' '
		do_lcd_data ' '
		rcall display_door 			; display door state
	rjmp display_end
	endDisplayFinishedMode:
	
	; Power input mode
	lds temp, Mode
	cpi temp, 4
	breq displayPowerInputMode
	rjmp endDisplayPowerInputMode

	displayPowerInputMode:
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
		rcall cursor_bottom_right
		rcall display_door
	rjmp display_end		
	endDisplayPowerInputMode:

	; Microwave timer display - running mode or pause mode
	rcall display_time
	; move cursor to the top right
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
	rcall display_turntable
	rcall cursor_bottom_right
	rcall display_door
	rjmp display_end
			
	display_end:
	pop temp
	ret

display_time:
	push temp
	lds temp, Mode
	cpi temp, 0
	breq display_input				; if in entry mode display input
	rjmp display_countdown			; otherwise display current time
	endDisplayTime:
	pop temp
	ret

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
	rjmp endDisplayTime

display_countdown:
	lds temp, Minutes
	do_lcd_digits temp
	do_lcd_data ':'
	lds temp, Seconds
	do_lcd_digits temp
	rjmp endDisplayTime

cursor_bottom_right:
	do_lcd_command 0b11000000	; break to the next line
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
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	ret
