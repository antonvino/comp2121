## comp2121
AVR labs and the project

## Project planning

##Modules

# Start button *
If door flag is 1 - don't do anything (door opened)
If time is not set - increase the minutes by 1 i.e. if 00:00 -> 01:00
Sets the mode to running (updates the mode flag)
Inverts the turntable direction flag

If time is set and mode is running just increase the minutes by 1

# Stop button #
If power entry flag is 0
    if entry mode
        clear minutes and seconds
    If running mode
        set mode to pause
Else
    Set to entry mode
    Set power entry flag to 0
    powerOn = 1 (switch the magnetron on)
    displayPower

# Open door button
If door flag is not 1:
    Set door flag to 1
    Set mode to pause
    Call displayData

# Close door button
If door flag is not 0:
    Set door flag to 0
    Set mode to pause
    Call displayData

# C button
If door flag is 1 - don't do anything (door opened)
If running mode - add 30 seconds

# D button
If door flag is 1 - don't do anything (door opened)
If running mode - subtract 30 seconds

# A button
If door flag is 1 - don't do anything (door opened)
If entry mode - set to Power entry flag to 1


# Digit 0-9
If door flag is 1:
    don't do anything (door opened)

If power entry mode flag is 0:
    Updates the time
    If minutes are not set - update the minutes:
    	00:00
    	4 pressed sets 40:00
    	5 pressed sets 45:00
    	another 4 pressed sets 45:40
    	So on the press if decimal is set, update the ones, if both set - update the seconds
    	If seconds are set - don’t do anything on digits

Else
    if digits are 1-3
    set power = digit

*Use key debounce - prevent from digit doubling on holding the key

# Turntable
If door flag is 1 - don't do anything (door opened)
8 states assigned to binary
00000001 |
00000010 /
00000100 -
00001000 \
00010000 |
00100000 /
01000000 -
10000000 \
00000000 |

Three revs per minute means state changes 20 (sec) / 8 = once in 2.5 seconds

Direction flag flips every time the mode is set to running
If flag is 1, shift 1 bit to right
If flag is 0, shift 1 bit to left

Display turntable symbol - separate function

# Magnetron
If door flag is 1 - don't do anything (door opened)
If mode is running
    If power 3 - spin for 1/4 of a second and stop
    If power 2 - spin for 1/2 of a second and stop 
    If power 1 - spin for 1 second and stop (never stop)
*Spin motor at 75 rev/sec

# Timer
If door flag is 1 - don't do anything (door opened)

Decrement seconds if > 0
If seconds == 0, decrement minutes if > 0, set seconds to 60
If minutes == 0, set mode to Finished

Each 2.5 seconds call Turntable

Each 0.25 seconds call Magnetron

# displayData
Move the cursor to time place (top-left)
Display current time (displayDigits)
Move the cursor to turntable place (top-right)
Display turntable state (displayTurntable)
Move the cursor to the door place (bottom-left)
Display the text (displayText)
Move the cursor to the door place (bottom-right)
Display the door state (displayDoor) 

# displayDoor
open/closed door show "O" or "C"
light the top-most LED if opened

# displayDigits
[to be updated]

# displayText
if text = 1
    "Entry" "Pause" "Running" depending on the mode
if text = 2 // power
    "Set Power 1/2/3"
[to be updated]

# displayPower
light the 8 LEDs according to power
if power = 3 light up 11000000
if power = 2 light up 11110000
if power = 1 light up 11111111
