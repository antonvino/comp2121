.include "m2560def.inc"
.equ loop_count = 124
.equ times = 16
.def iH = r29
.def iL = r28
.def countH = r17
.def countL = r16
.def miH = r27
.def miL = r26
.def mcountH = r19
.def mcountL = r18
.def patternH = r21
.def patternL = r20


; macro for one second delay
.macro oneSecondDelay
ldi mcountL, low(loop_count)	; 1 cycle
ldi mcountH, high(loop_count)
clr miH						; 1 cycle
clr miL
macro_loop: 
	cp miL, mcountL		; 1 cycle
	cpc miH, mcountH
	brsh macro_done		; 1 cycle, 2 if branch
	adiw miH:miL, 1		; 2 cycles
	nop
	rjmp macro_loop		; 2 cycles
macro_done:
.endmacro

.equ pattern = 0b1010101010101010; pattern defined

ser patternH
out DDRC, patternH 		; set Port C for output
ldi patternH, low(pattern)	; r15 is the low byte of pattern
ldi patternL, high(pattern)	; r14 is the high byte of pattern

; clear the increments
clr iH
clr iL
ldi countL, low(times)
ldi countH, high(times)
; loop through 16 bits
loop:
	lsr patternL				; shift the pattern
	ror patternH
	out PORTC, patternH			; write the pattern
	oneSecondDelay 				; 1 second delay

	; check if we've done it 16 times
	cp iL, countL				; 1 cycle
	cpc iH, countH
	brsh loop_end				; 1 cycle
	adiw iH:iL, 1				; 2 cycles
	rjmp loop					; otherwise keep shifting

loop_end:

end:
    rjmp end
