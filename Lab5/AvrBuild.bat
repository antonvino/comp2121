@ECHO OFF
"C:\Program Files (x86)\Atmel\AVR Tools\AvrAssembler2\avrasm2.exe" -S "C:\Users\mrbladers\Documents\COMP2121\comp2121\Lab5\labels.tmp" -fI -W+ie -C V3 -o "C:\Users\mrbladers\Documents\COMP2121\comp2121\Lab5\Lab5.hex" -d "C:\Users\mrbladers\Documents\COMP2121\comp2121\Lab5\Lab5.obj" -e "C:\Users\mrbladers\Documents\COMP2121\comp2121\Lab5\Lab5.eep" -m "C:\Users\mrbladers\Documents\COMP2121\comp2121\Lab5\Lab5.map" "C:\Users\mrbladers\Documents\COMP2121\comp2121\Lab5\LCD_example.asm"
upload_Anton.bat
