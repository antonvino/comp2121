@ECHO OFF
"C:\Program Files (x86)\Atmel\AVR Tools\AvrAssembler2\avrasm2.exe" -S "C:\Users\mrbladers\Documents\COMP2121\comp2121\Lab4\labels.tmp" -fI -W+ie -C V3 -o "C:\Users\mrbladers\Documents\COMP2121\comp2121\Lab4\Lab4.hex" -d "C:\Users\mrbladers\Documents\COMP2121\comp2121\Lab4\Lab4.obj" -e "C:\Users\mrbladers\Documents\COMP2121\comp2121\Lab4\Lab4.eep" -m "C:\Users\mrbladers\Documents\COMP2121\comp2121\Lab4\Lab4.map" "C:\Users\mrbladers\Documents\COMP2121\comp2121\Lab4\LCD_Example.asm"
upload_Anton.bat
