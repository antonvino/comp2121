 .include "m2560def.inc"

.def temp = r16

// Configure bit PE2 as output
ldi temp, 0b00010000
ser temp
out DDRE, temp ; Bit 3 will function as OC3B
ldi temp, 0x4A ; the value controls the PWM duty cycle (store the value in the OCR registers)
sts OCR3BL, temp
clr temp
sts OCR3BH, temp

ldi temp, (1 << CS00) ; no prescaling
sts TCCR3B, temp

// PWM phase correct 8-bit mode (WGM30)
// Clear when up counting, set when down-counting
ldi temp, (1<< WGM30)|(1<<COM3B1)
sts TCCR3A, temp

loop:
rjmp loop
