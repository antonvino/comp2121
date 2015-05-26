.include "m2560def.inc"
.equ pattern = 0xE5

ser r18;
out DDRC, r18; set Port C for output
ldi r18, pattern;
out PORTC, r18; write the pattern
end:
	rjmp end
