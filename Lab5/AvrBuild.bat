@ECHO OFF
"C:\Program Files (x86)\Atmel\AVR Tools\AvrAssembler2\avrasm2.exe" -S "C:\Users\Ali\.ssh\COMP2121\comp2121\Lab5\labels.tmp" -fI -W+ie -C V3 -o "C:\Users\Ali\.ssh\COMP2121\comp2121\Lab5\Lab5.hex" -d "C:\Users\Ali\.ssh\COMP2121\comp2121\Lab5\Lab5.obj" -e "C:\Users\Ali\.ssh\COMP2121\comp2121\Lab5\Lab5.eep" -m "C:\Users\Ali\.ssh\COMP2121\comp2121\Lab5\Lab5.map" "C:\Users\Ali\.ssh\COMP2121\comp2121\Lab5\TimerExample.asm"
upload.bat
