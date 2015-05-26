; The program gets input from keypad and displays its ascii value on the ; LED bar
.include "m2560def.inc"
.def row = r16              ; current row number
.def col = r17              ; current column number
.def rmask = r18            ; mask for current row during scan
.def cmask = r19            ; mask for current column during scan
.def temp1 = r20 
.def temp2 = r21
.equ PORTLDIR = 0xF0        ; PH7-4: output, PH3-0, input
.equ INITCOLMASK = 0xEF     ; scan from the rightmost column,
.equ INITROWMASK = 0x01     ; scan from the top row
.equ ROWMASK = 0x0F         ; for obtaining input from Port L


RESET:
    ldi temp1, low(RAMEND)  ; initialize the stack
    out SPL, temp1
    ldi temp1, high(RAMEND)
    out SPH, temp1
    ldi temp1, PORTLDIR     ; PB7:4/PB3:0, out/in
    sts DDRL, temp1         ; PORTB is input
    ser temp1               ; PORTC is output
    out DDRC, temp1
    out PORTC, temp1


main:
    ldi cmask, INITCOLMASK  ; initial column mask
    clr col                 ; initial column

colloop:
    cpi col, 4
    breq main               ; If all keys are scanned, repeat.
    sts PORTL, cmask        ; Otherwise, scan a column.
  
    ldi temp1, 0xFF         ; Slow down the scan operation.

delay:
    dec temp1
    brne delay              ; until temp1 is zero? - delay

    lds temp1, PINL          ; Read PORTL
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
    jmp rowloop
    
nextcol:                    ; if row scan is over
     lsl cmask
     inc col                ; increase col value
     jmp colloop            ; go to the next column
     
convert:
    cpi col, 3              ; If the pressed key is in col 3
    breq letters            ; we have letter
    
                            ; If the key is not in col 3 and
    cpi row, 3              ; if the key is in row 3,
    breq symbols            ; we have a symbol or 0
    
    mov temp1, row          ; otherwise we have a number 1-9
    lsl temp1
    add temp1, row
    add temp1, col          ; temp1 = row*3 + col
    subi temp1, -'1'        ; add the value of character '1'
    jmp convert_end
    
letters:
    ldi temp1, 'A'
    add temp1, row          ; Get the ASCII value for the key
    jmp convert_end

symbols:
    cpi col, 0              ; Check if we have a star
    breq star
    cpi col, 1              ; or if we have zero
    breq zero
    ldi temp1, '#'          ; if not we have hash
    jmp convert_end
star:
    ldi temp1, '*'          ; set to star
    jmp convert_end
zero:
    ldi temp1, '0'          ; set to zero

convert_end:
    out PORTC, temp1        ; write value to PORTC
    jmp main                ; restart the main loop

