.include "m2560def.inc"

.def temp1 = r18 
.def temp2 = r19
.def temp = r17
.def lcd = r16

.dseg

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

; Interrupts handling
.cseg
.org 0x0000
	jmp RESET
    jmp DEFAULT
    jmp DEFAULT
.org INT2addr
    jmp EXT_INT2

	jmp DEFAULT          ; default service for all other interrupts.
DEFAULT:  reti          ; no service



RESET:
	ldi lcd, low(RAMEND)
	out SPL, lcd
	ldi lcd, high(RAMEND)
	out SPH, lcd

	ser lcd					; LCD setup
	out DDRF, lcd
	out DDRA, lcd
	clr lcd
	out PORTF, lcd
	out PORTA, lcd

	ser temp1               ; PORTC is output
    out DDRC, temp1
    out PORTC, temp1

	sei

	ldi temp, (2 << ISC00)      ; set INT0 as falling-
    sts EICRA, temp             ; edge triggered interrupt
    in temp, EIMSK              ; enable INT0
    ori temp, (1<<INT2)
    out EIMSK, temp



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

	do_lcd_data 'H'
	do_lcd_data 'e'
	do_lcd_data 'l'
	do_lcd_data 'l'
	do_lcd_data 'o'

    rjmp main         	; restart the main loop

main:
	sei                     ; Enable global interrupt
halt:
	rjmp main

EXT_INT2:
	in temp, SREG
	push temp

	do_lcd_data '!';
	; INTERRUPT READING WORKS
	; TO-DO:
	; read how many times it is HIGH
	; count
	; divide by the time it takes (possibly in another timer)

	ldi temp, 0b01010101
	out PORTC, temp

    pop temp
    out SREG, temp
;	out SREG, temp
;	pop temp
	reti

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
