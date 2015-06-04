.include "m2560def.inc"

.def row = r16              ; current row number
.def col = r17              ; current column number
.def rmask = r18            ; mask for current row during scan
.def cmask = r19            ; mask for current column during scan
.def temp1 = r20 
.def temp2 = r21
.def temp = r22
.def lcd = r23
.def debounceFlag = r25		; the debounce flag
.equ PORTLDIR = 0xF0        ; PH7-4: output, PH3-0, input
.equ INITCOLMASK = 0xEF     ; scan from the rightmost column,
.equ INITROWMASK = 0x01     ; scan from the top row
.equ ROWMASK = 0x0F         ; for obtaining input from Port L

.include "macros.asm"
                        
.dseg
TempCounter:
    .byte 2             ; Temporary counter. Counts milliseconds
TurntableCounter:		; counts 2.5s
	.byte 2
TurntableState:			; stores the state of turntable 8bit - 8 states
	.byte 1
TurntableDirection:		; stores the turntable direction flag 0 CW / 1 CCW
	.byte 1
DoorState:				; stores the state of door (closed 0, opened 1)
	.byte 1

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

Timer0OVF: ; interrupt subroutine to Timer0
    in temp, SREG
    push temp       ; Prologue starts.
    push YH         ; Save all conflict registers in the prologue.
    push YL
	push r27
	push r26
	; Prologue ends.

	; first counter - 50ms debounce counter
	;checkFlagSet:				; if either flag is set - run the debounce timer
	;	cpi debounceFlag, 1
	;	breq newDebounce		; i.e. set to 1
		; otherwise - don't need the debounce timer
	;	rjmp 50ms ; go to 50ms
	;rcall display_data

	newDebounce:	;	if flag is set continue counting until 100 milliseconds
		;ldi temp, 0b11000011
		;out PORTC, temp
		lds r26, TurntableCounter
    	lds r27, TurntableCounter+1
    	adiw r27:r26, 1 ; Increase the turntable counter by one.

    	cpi r26, low(3000)     ; 2.5 seconds 19530
    	ldi temp, high(3000)
    	cpc temp, r27
    	brne notTurning			; 2.5s have not passed

		; 2.5 seconds have passed
		rcall turn_table
		
		clear TurntableCounter			

    rjmp EndIF

; supplementary functions

notTurning: 		; Store the new value of the turntable counter.
	sts TurntableCounter, r26
	sts TurntableCounter+1, r27
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
	clear TurntableCounter	; Initialize the turntable counter to 0
	clear_byte TurntableState
	clear_byte TurntableDirection 

    ldi temp, 0b00000000
    out TCCR0A, temp
    ldi temp, 0b00000010
    out TCCR0B, temp        ; Prescaling value=8
    ldi temp, 1<<TOIE0      ; = 128 microseconds
    sts TIMSK0, temp        ; T/C0 interrupt enable
    sei                     ; Enable global interrupt

	rjmp halt

halt:
	rjmp halt 				; run infinitely

turn_table:
	lds YL, TurntableDirection
	cpi YL, 1
	breq turn_table_cw	; if direction is 1 CW
	rjmp turn_table_ccw	; if direction is 0 CCW

turn_table_cw:
	rcall display_data
	lds YL, TurntableState
	out PORTC, YL
	inc YL				; shift rotation by 1 bit to the left 
						;(clockwise, see displayTurntable)
	cpi YL, 9			; if rotation is finished - reset it
	breq turn_table_cw_reset
	sts TurntableState, YL
	ret
turn_table_cw_reset:
	ldi YL, 0			; the rightmost bit set
	sts TurntableState, YL
	rjmp turn_table_cw

turn_table_ccw:
	rcall display_data
	lds YL, TurntableState
	cpi YL, 0			; if rotation is finished - reset it
	breq turn_table_ccw_reset
	dec YL				; shift rotation by 1 bit to the right 
						;(counter-clockwise, see displayTurntable)
	sts TurntableState, YL
	ret
turn_table_ccw_reset:
	ldi YL, 8			; the leftmost bit set
	sts TurntableState, YL
	rjmp turn_table_ccw

;
; Display the data
;
display_data:
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	; TODO: move cursor to the turntable spot
	rcall display_turntable
	ret

display_turntable:
	lds YL, TurntableState
	cpi YL, 0	; |
	breq display_turntable_split
	cpi YL, 1	; /
	breq display_turntable_slash
	cpi YL, 2	; -
	breq display_turntable_dash
	cpi YL, 3	; \
	breq display_turntable_backslash
	cpi YL, 4	; |
	breq display_turntable_split
	cpi YL, 5	; /
	breq display_turntable_slash
	cpi YL, 6	; -
	breq display_turntable_dash
	cpi YL, 7	; \
	breq display_turntable_backslash
	cpi YL, 8	; |
	breq display_turntable_split
	do_lcd_data ' '; ELSE: none of the bits set
	ret	

display_turntable_split:
	do_lcd_data '|'
	ret
display_turntable_slash:
	do_lcd_data '/'
	ret
display_turntable_backslash:
	rcall build_bslash
	ret
display_turntable_dash:
	do_lcd_data '-'
	ret

.include "lcd.asm"
