## comp2121
AVR labs and the project

## Project planning

##Modules

# Start button *
If door flag is 0 - don't do anything (door opened)
If time is not set - increase the minutes by 1 i.e. if 00:00 -> 01:00
Sets the mode to running (updates the mode flag)
Inverts the turntable direction flag

If time is set and mode is running just increase the minutes by 1

# Stop button #
If entry mode - clear minutes and seconds
If running mode - set mode to pause

# Open door button
If running mode - set mode to pause
Set door flag to 0

# Close door button
If door flag is 0, set door flag to 1
Set mode to previous mode

# C button
If running mode - add 30 seconds

# D button
If running mode - subtract 30 seconds

# Digit 0-9
Updates the time
If minutes are not set - update the minutes:
	00:00
	4 pressed sets 40:00
	5 pressed sets 45:00
	another 4 pressed sets 45:40
	So on the press if decimal is set, update the ones, if both set - update the seconds
	If seconds are set - don’t do anything on digits
*Use key debounce - prevent from digit doubling on holding the key

# Turntable
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
If mode = running
If power 0 - spin for 1/4 of a second and stop
If power 1 - spin for 1/2 of a second and stop
If power 2 - spin for 1 second and stop (never stop)
Spin motor at 75 rev/sec

# Timer
Decrement seconds if > 0
If seconds == 0, decrement minutes if > 0, set seconds to 60
If minutes == 0, set mode to Finished