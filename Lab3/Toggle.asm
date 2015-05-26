/*
 * toggle.asm
 *
 *  Created: 9/05/2012 9:07:24 PM
 *   Author: Luke Cameron (lukecameron)
 *
 *	Toggle the led's when pb0 is pressed.
 *  wire pb0 to pd0, leds to portc
 *  some code copied from example 3.1
 */ 
 
.include "m64def.inc"
.def temp = r16
 
 
;; set up the interrupt vector
jmp reset
.org INT0addr ; INT0addr is the address of EXT_INT0
jmp handle_pb0
.org INT1addr ; INT1addr is the address of EXT_INT1
jmp handle_pb1
 
/*
by the way, INT0 means External Interrupt 0.
Don't ask me why...

note: it so happens that INT0 is hooked up to the PD0 pin.
Here are the mappings:
INT0: PD0
INT1: PD1
INT2: PD2
INT3: PD3
INT4: PE4
INT5: PE5
INT6: PE6
INT7: PE7
(from pg2 of atmega64 datasheet)
*/
 
 
reset:
	;; init the stack
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
 
	;; set DDRC to 0xFF.
	;; DDRC is data direction register C
	;; there are 8 pins, so setting 8 bits
	;; to 1 sets the 8 pins for output.
	ser temp
	out DDRC, temp
 
	;; set int1 and int0 for falling edge trigger.
	;; this one's gonna need some explanation
	ldi temp, (1 << ISC11) | (1 << ISC01)
	sts EICRA, temp
 
	;; so EICRA is the External Interrupt Control
	;; Register A. (Atmega64 datasheet pg 88).
	;; It controls the interrupt mode of INT0-INT3
 
	;; each of these four interrupts has two bits
	;; associated with it. The order is like this:
	;; 33221100, where 0 means INT0.
 
	;; In each pair, the right-most bit is called bit 0,
	;; and the left-most bit is called bit 1.
 
	;; table 48 on pg89 of the atmega64 datasheet
	;; shows you what they do. we're looking for 
	;; falling edge, so we need to set each pair to '10'
 
	;; however, we're given some handy constants in m64def.inc
	;; that mean we don't have to do this. They store the number
	;; of left-shifts you would need to do to 1 to set only that bit.
 
	;; for example, to set bit 1 of int3, you would set EICRA to
	;; 1 << ISC31. If you want to set multiple bits, just keep
	;; writing them and ORing them together with "|".
 
	;; by the way, ISC stands for "interrupt sense control"
 
	;; |   is bitwise Or
	;; <<  is left shift
 
	;; that was long..
 
 
	;; enable int0 and int1
	in temp, EIMSK 
	ori temp, (1<<INT0) | (1<<INT1)
	out EIMSK, temp
 
	;; so EIMSK is the External Interrupt Mask Register
	;; its eight bits are used to enable the eight
	;; external interupts int0-int7.
 
	;; it's basically the same setup as before.
	;; we use the ori instruction to preserve any previously
	;; enabled interrupts even though there obviously aren't any.
 
	;; this just enables the interrupt enable bit
	;; of the status register. This is needed.
	sei
 
main:
	rjmp main
 
;; this is the handler for PushButton0
handle_pb0:
	;; push conflict registers
	push temp
	in temp, SREG
	push temp
 
	in temp, PORTC
	com temp
	out PORTC, temp
 
	;; restore conflict registers
	pop temp
	out SREG, temp
	pop temp
	reti
 
 
;; this is exactly the same as the handler for PushButton0
handle_pb1:
	;; push conflict registers
	push temp
	in temp, SREG
	push temp
 
	in temp, PORTC
	com temp
	out PORTC, temp
 
	;; restore conflict registers
	pop temp
	out SREG, temp
	pop temp
	reti
