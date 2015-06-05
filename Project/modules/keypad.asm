; Keypad processing specific for Microwave emulator
; Authors: Ali Mokdad
; Based on COMP2121 Lab and lecture examples
; License: MIT
; UNSW 2015

initKeypadClear:
	rcall sleep_5ms
	clr digit
initKeypad:
	lds temp, DoorState		; if the door is open don't accept any input
	cpi temp, 1
	breq initKeypad

    lds temp, RefreshFlag   ; only display data if the refresh flag is set
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

	lds temp, DoorState
	cpi temp, 1
	breq initKeypad 		; ignore the keypad when the door is opened
	clr temp

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

	lds temp, Mode			; if not in power entry mode
	cpi temp, 4				; display digits
	brne digitDisplay

	PowerLevelSet:			; if in power entry mode
	cpi temp1, 4			; if number is less than 4, not valid
	brlt PowerLevelCheck0
	jmp convert_end

	PowerLevelCheck0:		; check if zero
	cpi temp1, 0
	brne valid_power_level	; if not it's 1-3
	jmp convert_end

	valid_power_level:		; now set the power level
	sts PowerLevel, temp1
	ldi temp, 0
	sts Mode, temp
	rjmp convert_end
 
digitDisplay:					; shift current numbers over to make space
	lds YL, EnteredDigits		; for input
	inc YL
	sts EnteredDigits, YL
	cpi YL, 5
	brlt display
	jmp convert_end
	
	display:
	shift_left_once DisplayDigits
	sts DisplayDigits+3, temp1	
	rjmp convert_end

letters:					; break to the relevant branches for letters
	cpi row, 0
	breq letterA
	cpi row, 2
	breq letterC
	cpi row, 3
	breq letterD
	rjmp convert_end

letterA:
	lds temp, Mode			; if entry mode - show power select
	cpi temp, 0
	breq PowerModeSet
	rjmp convert_end

	PowerModeSet:
	ldi temp, 4
	sts Mode, temp
	rjmp convert_end

letterC:
	lds temp, Mode			; only add if in running mode
	cpi temp, 1
	breq setMore
	rjmp convert_end

	setMore:
	ldi temp, 1
	sts MoreFlag, temp
	rjmp convert_end

letterD:
	lds temp, Mode			; only subtract if in running mode
	cpi temp, 1
	breq setLess
	jmp convert_end

	setLess:
	ldi temp, 1
	sts LessFlag, temp
	rjmp convert_end

symbols:
    cpi col, 0              ; check if we have a star
    breq star
    cpi col, 1              ; or if we have zero
    breq zero
	cpi col, 2
	breq hash
    rjmp convert_end

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
	rcall stopMagnetron			; stop the magnetron is it's working
	ldi temp, 2					
	sts Mode, temp				; set mode to Pause
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
	lds temp, Mode				; in entry mode - start the microwave
	cpi temp, 0
	breq startMicrowave
	cpi temp, 2					; in pause mode - restart the microwave
	breq startMicrowave
								; otherwise
	cpi temp, 1					; only add minute if we're in the running mode
	brne star_end
	;cpi temp, 4
	;breq star_end				; end, we're in power level screen

	;cpi temp, 3					; end we're in finished screen
	;breq star_end

	out PORTC, temp
	lds temp, Minutes
	inc temp
	sts Minutes, temp
	rjmp star_Set_Entry

	startMicrowave:
	; check if a time has been entered
	lds temp, EnteredDigits
	cpi temp, 0
	brne digitsEntered
	
	noDigitsEntered:			; if no digits have been entered, 
	ldi temp, 1					; default 1 minute
	sts Minutes, temp
	ldi temp, 0
	sts Seconds, temp
	rjmp star_Set_Entry

	digitsEntered:					; if digits have been entered
 	lds temp1, DisplayDigits+2		; set timer variables
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
	;ldi temp, 0
	;sts StopFlag, temp

	lds temp, TurntableDirection	; reverse the turntable rotation
	ldi temp1, 1
	eor temp, temp1
	sts TurntableDirection, temp
	rcall turn_table				; start turning

	star_end:
 	rjmp convert_end
    
convert_end:
	clr temp					; clear seconds idle
	sts SecondsIdle, temp

	do_lcd_command 0b00000001 ; clear display
	rcall display_data
	;rcall display_time
	
Finish:
	ldi digit, 1				; use digit as flag - key is pressed but not released yet
    rjmp initKeypad         	; restart the main loop
