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
