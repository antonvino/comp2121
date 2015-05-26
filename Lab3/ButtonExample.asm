.include "m2560def.inc"
.def temp =r16
.def output = r17
.def count = r18
.equ PATTERN = 0b01010101
                                ; set up interrupt vectors
jmp RESET 
.org INT0addr
jmp EXT_INT0



RESET:
    ldi temp, low(RAMEND)       ; initialize stack
    out SPL, temp
    ldi temp, high(RAMEND)
    out SPH, temp

    ser temp                    ; set Port C as output
    out DDRC, temp
    out PORTC, temp
    ldi output, PATTERN

    ldi temp, (2 << ISC00)      ; set INT0 as falling-
    sts EICRA, temp             ; edge triggered interrupt
    in temp, EIMSK              ; enable INT0
    ori temp, (1<<INT0)
    out EIMSK, temp
    sei                         ; enable Global Interrupt
    jmp main

EXT_INT0:
        push temp               ; save register
        in temp, SREG           ; save SREG
        push temp
        com output              ; flip the pattern
        out PORTC, output
        inc count

        pop temp                ; restore SREG 
        out SREG, temp
        pop temp                ; restore register 
        reti
        
                                ; main - does nothing but increment a counter
main:
    clr count
    clr temp 
loop:
    inc temp                    ; a dummy task in main
    rjmp loop
