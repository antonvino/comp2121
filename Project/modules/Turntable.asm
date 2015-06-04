; Turntable module for Microwave emulator
; Authors: Anton Vinokurov
; Based on COMP2121 Lab and lecture examples
; License: MIT
; 2015

turn_table:
	lds YL, TurntableDirection
	cpi YL, 1
	breq turn_table_cw	; if direction is 1 CW
	rjmp turn_table_ccw	; if direction is 0 CCW

turn_table_cw:
	rcall display_data
	lds YL, TurntableState
	inc YL				; shift rotation by 1 bit to the left 
						;(clockwise, see displayTurntable)
	cpi YL, 9			; if rotation is finished - reset it
	breq turn_table_cw_reset
	sts TurntableState, YL
	ret
turn_table_cw_reset:
	ldi YL, 1			; the rightmost bit set
	sts TurntableState, YL
	rjmp turn_table_cw

turn_table_ccw:
	rcall display_data
	lds YL, TurntableState
	cpi YL, 1			; if rotation is finished - reset it
	breq turn_table_ccw_reset
	dec YL				; shift rotation by 1 bit to the right 
						;(counter-clockwise, see displayTurntable)
	sts TurntableState, YL
	ret
turn_table_ccw_reset:
	ldi YL, 9			; the leftmost bit set
	sts TurntableState, YL
	rjmp turn_table_ccw

display_turntable:
	;lds temp, Mode		; if not in running mode - show empty space
	;cpi temp, 1
	lds YL, TurntableState
	cpi YL, 0	; space
	breq display_turntable_empty
	cpi YL, 1	; |
	breq display_turntable_split
	cpi YL, 2	; /
	breq display_turntable_slash
	cpi YL, 3	; -
	breq display_turntable_dash
	cpi YL, 4	; \
	breq display_turntable_backslash
	cpi YL, 5	; |
	breq display_turntable_split
	cpi YL, 6	; /
	breq display_turntable_slash
	cpi YL, 7	; -
	breq display_turntable_dash
	cpi YL, 8	; \
	breq display_turntable_backslash
	cpi YL, 9	; |
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
display_turntable_empty:
	do_lcd_data ' '
	ret

