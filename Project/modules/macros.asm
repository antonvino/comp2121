; Macros
; Authors: Ali Mokdad, Anton Vinokurov
; Based on COMP2121 Lab and lecture examples
; License: MIT
; 2015

;
; Memory macros
;

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
    ldi YL, low(@0)    ; load the memory address to Y
    clr temp 
    st Y, temp         ; clear the byte at @0 in SRAM
.endmacro

;
; LCD macros
;

; Commands to LCD
.macro do_lcd_command
	ldi lcd, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

; Data in ASCII to LCD by 1 char
.macro do_lcd_data
	ldi lcd, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

; Data from a register to LCD
.macro do_lcd_rdata
	mov lcd, @0
	subi lcd, -'0'
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

;
; Working with decimal numbers
;

; digit entering macro
.macro shift_left_once
	lds YL, @0+1
	sts @0, YL
	lds YL, @0+2
	sts @0+1, YL
	lds YL, @0+3
	sts @0+2, YL
.endmacro

; digit displaying macro
.macro do_lcd_digits
	clr digit
	clr digitCount
	mov temp, @0			; temp is given number
	rcall convert_digits	; call a function
.endmacro
