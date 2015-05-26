@ECHO OFF
"C:\Program Files (x86)\Atmel\AVR Tools\AvrAssembler2\avrasm2.exe" -S "C:\Users\mrbladers\Documents\Lab3\labels.tmp" -fI -W+ie -C V3 -o "C:\Users\mrbladers\Documents\Lab3\Lab3.hex" -d "C:\Users\mrbladers\Documents\Lab3\Lab3.obj" -e "C:\Users\mrbladers\Documents\Lab3\Lab3.eep" -m "C:\Users\mrbladers\Documents\Lab3\Lab3.map" "C:\Users\mrbladers\Documents\Lab3\Lab3_C.asm"
