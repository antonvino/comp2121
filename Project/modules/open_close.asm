; This program implements a timer that counts one second using 
; Timer0 interrupt
.include "m2560def.inc"

.def temp = r16
.def temp1 = r18 
.def temp2 = r19
.def lcd = r20				; lcd handle
.def debounceFlag0 = r21	; button 1 debounce
.def debounceFlag1 = r22	; button 2 debounce

.include "macros.asm"


.dseg
DoorState:
    .byte 1             ; Door state 0 closed, 1 opened
DebounceCounter:		; Debounce counter. Used to determine
    .byte 2             ; if 50ms have passed


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

	;do_lcd_command 0b00000001 ; clear display
	;do_lcd_command 0b00000110 ; increment, no display shift
	;do_lcd_command 0b00001110 ; Cursor on, bar, no blink
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
		rjmp endDebounce ; go to the end of debounce

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
	endDebounce:

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
; close the door
EXT_INT0:
    in temp, SREG	; Prologue starts.
    push temp       ; Save all conflict registers in the prologue.
	       			; Prologue ends.
                    ; Load the value of the temporary counter.

	; debounce check
	cpi debounceFlag0, 1		; if the button is still debouncing, ignore the interrupt
	breq END_INT0	

	ldi debounceFlag0, 1		; set the debounce flag

	lds temp, DoorState			; set door state to 0
	ldi temp, 0					
	sts DoorState, temp
	rcall display_data			; display that the door is closed

	rjmp END_INT0

; Epilogue of push button 0
END_INT0:
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.
	
; subroutine for push button 1
; open the door
EXT_INT1:
    in temp, SREG	; Prologue starts.
    push temp       ; Save all conflict registers in the prologue.
	       			; Prologue ends.
                    ; Load the value of the temporary counter.

	; debounce check
	cpi debounceFlag1, 1		; if the button is still debouncing, ignore the interrupt
	breq END_INT1	

	ldi debounceFlag1, 1		; set the debounce flag

	lds temp, DoorState			; set door state to 1
	ldi temp, 1				
	sts DoorState, temp
	rcall display_data			; display that the door is opened

	rjmp END_INT1

; Epilogue of push button 1
END_INT1:
    pop temp
    out SREG, temp
    reti            ; Return from the interrupt.

main:
    clear_byte DoorState       ; Initialize the door state to closed

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

    ldi temp, 0b00000000
    out TCCR0A, temp
    ldi temp, 0b00000010
    out TCCR0B, temp        ; Prescaling value=8
    ldi temp, 1<<TOIE0      ; = 128 microseconds
    sts TIMSK0, temp        ; T/C0 interrupt enable

    sei                     ; Enable global interrupt
                            ; loop forever
    loop: rjmp loop

;
; Display the data
;
display_data:
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	; TODO: move cursor to the top right (door spot)
	rcall display_door
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

;.include "digits.asm"
.include "lcd.asm"
