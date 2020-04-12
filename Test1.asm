#make_bin#

#LOAD_SEGMENT=FFFFh#
#LOAD_OFFSET=0000h#

#CS=0000h#
#IP=0000h#

#DS=0000h#
#ES=0000h#

#SS=0000h#
#SP=FFFEh#

#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#

	jmp     st1 ;clear interrupt 'ST1 IS THE LABEL ' 
;proteus allows you to change the reset address - hence changing it to 00000H - so every time 
;system is reset it will go and execute the instruction at address 00000H - which is jmp st1
         db     509 dup(0)
;jmp st1 will take up 3 bytes in memory - another 509 bytes are filled with '0s'
;509 + 3 bytes = 512 bytes
;first 1 k of memory is IVT - 00000 -00002H will now have the jmp instruction. 00003H - 001FFH will
;have 00000 - as vector number 0 to 79H are unused
;IVT entry for 80H - address for entry is 80H x 4 is 00200H       
         dw     int_sense ;THIS IS THE ISR 
; Inst Pointer Value 2 bytes
         dw     0000
;CS is 2 bytes
         db     508 dup(0)
;508 bytes filled with zeros for interrupt vectors 81H to FFH - that are not used.

; keyboard table
TABLE_K DB 0EEh,0EDH,0EBH,0E7H,0DEH,0DDH,0DBH,0D7H,0BEH,0BDH,0BBH,0B7H,07EH,07DH,07BH,077H

;display table
TABLE_D DB 3FH,06H,5BH,4FH,66H, 6DH,7DH,07H,7FH,67H  

;motor step table
TABLE_M DB 19H,13H,16H,1CH,19H,13H 

;variables
key0 db ?
key1 db ?
temp1 db ?
temp0 db ?
temp  db ?

;Temperature sensed by the Sensor
temp_sense1 db ?
temp_sense2 db ?
temp_sense3 db ?
temp_sense4 db ?
temp_sense5 db ?
temp_sense6 db ?

;BIOSLEEP mode 
hours db ?

cur_port db ?
cur_temp db ?

disp db ?
db	465 dup(0)  

;main program
st1:      cli

; intialize ds, es,ss to start of RAM
mov       ax,0200h 
mov       ds,ax
mov       es,ax
mov       ss,ax
mov       sp,0FFFEH


;initialize variables
mov key0,00h
mov key1,00h

mov temp1,02H	
mov temp0,03H
mov temp,23d	;The default temp

mov temp_sense1,25d
mov temp_sense2,25d
mov temp_sense3,25d
mov temp_sense4,25d
mov temp_sense5,25d
mov temp_sense6,25d

mov hours,01h

mov cur_port,10h
mov cur_temp,17h

mov disp,01h

;Intialisation of  8255s
;intialise keypad, Upper port C as (takes) input ,port B ,port A and lower port C as (gives) output, starting 00H
;Port A & B are for display output ports
	mov     al,10001000b	;CW
	out     06h,al	;creg

;initialize sensors, port A and upper port C (takes) input, port B and lower port C as (gives) output, starting 08H
	mov		al, 10011000b	;!!CAUTION!!	**DOUBT** The sensor to be used is ATS2000A
	out		0Eh, al
	
;initialize motors 1,2,3, port A,B,C (gives) output, starting 10H
	mov		al, 10000000b
	out		16h, al

;initialize motors 4,5,6, port A,B,C (gives) output, starting 18H
	mov		al, 10000000b
	out		1Eh, al
	
;initialize timer
	mov		al, 00110100b	;Rate generator
	out		26h, al
	mov     al, 01110110b	;Square wave generator
	out     26h, al
	mov     al, 10110110b	;Square wave generator
	out     26h, al

;send count of 0003h to clock 2 , send count of 208Dh to clock 1 , send count of 0030h to clock 0
	
	;CLOCK 0
	mov 	al,30h	;LSB
	out 	20h,al
	mov 	al,00h	;MSB
	out 	20h,al
	
	;CLOCK 1
	mov 	al,8Dh
	out 	22h,al
	mov 	al,20h
	out 	22h,al
	
	;CLOCK 2
	mov 	al,03h
	out 	24h,al
	mov 	al,00h
	out 	24h,al
	
;initialize timer 8255, port A input,port B port C output @ 28H
	mov		al, 10010000b
	out     2Eh, al
	mov     al,00h 
	out     2Ah, al
	
;initialize 8259

	mov al, 00010011b	;ICW1
	out 30h, al
	mov al, 10000000b	;ICW2
	out 32h, al
	mov al, 03h			;ICW4
	out 32h, al
	mov al, 11111110b	;OCW1
	out 32h, al
	sti


;start display with 23(default temp)
	mov al,4fh
	not al		;CAUTION!! Check this once **Mostly a common anode display is used**
	out 00h,al  ;TO PORT A OF LSB OF DISPLAY {3}
	mov al,5bh
	not al
	out 02h,al ;TO PORT A OF LSB OF DISPLAY {2}
	
;check for key release:
X0:
	mov            dh,00h
	MOV            AL,00H
	OUT            04H,AL 
X1:        
	IN             AL,04H ;'04H' IS THE PORTC ADDRESS WHICH IS CONNECTED TO KEYPAD 
	AND            AL,0F0H
	CMP            AL,0F0H
	JNZ            X1
	CALL           D20MS
;--------------------------------------------------------------------------------------------------------------------------------------------------------------------	
;core loop, first checks for biosleep timer then polling then checks for key press:
	MOV            AL,00H
	OUT            04H ,AL
X2: 

;checks rate generator for polling:	
	IN             AL,28H	;**DOUBT**
	AND            AL,0FH
	CMP            AL,00H
;	JE             SENSOR		****************
	JNE            KEYPRESS
		
;checks key press:
KEYPRESS:	
	IN             AL, 04H
	AND            AL,0F0H
	CMP            AL,0F0H
	JZ             X2
	CALL           D20MS
	MOV            AL,00H
	OUT            04H ,AL
	IN             AL, 04H
	AND            AL,0F0H
	CMP            AL,0F0H
	JZ             X2
;--------------------------------------------------------------------------------------------------------------------------------------------------------------------	
;decodes key matrix
	
;check column 0	
	MOV            AL, 0EH
	MOV            BL,AL
	OUT            04H,AL
	IN             AL,04H
	AND            AL,0F0H
	CMP            AL,0F0H
	JNZ            X3
	
;check column 1		
	MOV            AL, 0DH
	MOV            BL,AL
	OUT            04H ,AL
	IN             AL,04H
	AND            AL,0F0H
	CMP            AL,0F0H
	JNZ            X3
	
;check column 2		
	MOV            AL, 0BH
	MOV            BL,AL
	OUT            04H,AL
	IN             AL,04H
	AND            AL,0F0H
	CMP            AL,0F0H
	JNZ            X3
	
;check column 3		
	MOV            AL, 07H
	MOV            BL,AL
	OUT            04H,AL
	IN             AL,04H
	AND            AL,0F0H
	CMP            AL,0F0H
	JZ             X2
	
;decode key
X3:         
	OR             AL,BL
	MOV            CX,0FH
	MOV            DI,00H
X4:       
	CMP            AL,CS:TABLE_K[DI]
	JZ             X5
	INC            DI
	INC            dh
	LOOP           X4
	
;display key
X5: 
	cmp            dh,09h
	jg             BUTTON
	LEA            BX, TABLE_D
	MOV            AL, CS:[BX+DI]
	NOT            AL
	mov            dl,disp
	cmp            dl,00h
	jne            X6
	out            00h,al
	xor            dl,01h
	mov            disp,dl
	mov            key0,dh
	JMP            X0
	
X6: 
	out            02h,al
	xor            dl,01h
	mov            disp,dl
	mov            key1,dh
	JMP            X0

;If button pressed is not a number, this procedure checks which button and calls subsequent procedure	
BUTTON:
	cmp dh,0Ah
	je TUP
	cmp dh,0Bh
	je TDWN
	cmp dh,0Ch
	je ON
	cmp dh,0Dh
	je BIOSLEEP
	cmp dh,0Eh
	je OFF
	cmp dh,0Fh
	je REGULAR
	jmp X0

;Increase Temperature by 1(upto 25 degrees)
TUP:
	mov cl,temp0
	cmp cl,05h
	je X0
	inc cl
	mov temp0,cl
	mov al,temp
	add al,1
	mov temp,al
	call DISPLAY0
	jmp X0

;Decrease Temperature by 1(upto 20 degrees)
TDWN:
	mov cl,temp0
	cmp cl,00h
	je X0
	dec cl
	mov temp0,cl
	mov al,temp
	sub al,1
	mov temp,al
	call DISPLAY0
	jmp X0

;starts rate generator for taking input from sensors periodically	
ON:
	;starts timer
	mov     al,01h
	out     2Ah, al
	jmp X0

;sets sleep timer(upto 9 hours),after taking input resets display to temperature
BIOSLEEP:
	
	mov al,key0
	mov bl,key1
	mov ah,00
	mov cl,0Ah
	mul cl
	cmp ax,0009h
	jg hourH
	mov hours,al
	call DISPLAY0
	call DISPLAY1
	jmp timer_start
hourH:
	mov hours,09h
	call DISPLAY0
	call DISPLAY1
	jmp timer_start

;disables rate generator, shuts all ac vents	
OFF:
	mov al,06h
	out 10h,al
	out 12h,al
	out 14h,al
	out 18h,al
	out 1Ah,al
	out 1Ch,al
	mov     al,00h
	out     2Ah, al
	jmp X0

;sets temperature equal to number currently on display, if >25, automatically sets to 25,same with <20	
REGULAR:
	mov al,key1
	mov temp1,al
	mov cl,0ah
	mul cl
	mov cl,key0
	mov temp0,cl
	add al,cl
	mov temp,al
	cmp al,25d
	jg DEFH
	cmp al,20d
	jl DEFL
	jmp X0
	
DEFH:
	mov temp1,02h
	mov temp0,05h
	mov al,25d
	mov temp,al
	CALL DISPLAY0
	CALL DISPLAY1
	jmp X0
DEFL:
	mov temp1,02h
	mov temp0,00h
	mov al,20d
	mov temp,al
	CALL DISPLAY0
	CALL DISPLAY1
	jmp X0

;multiplies user input with 3600 and starts sleep timer
timer_start:
	mov     bl,hours
	mov     ax,0E10h
	mul     bl
dHour:
	call    D1S
	dec     ax
	jnz     dHour
	jmp     OFF


;compares desired temperature with Current temperature meaured and moves vent accordingly
MOTOR:
	mov bl,temp
	mov al,cur_temp
	sub al,bl
	cmp al,01h
	je P1
	cmp al,02h
	je P2
	cmp al,03h
	je P3
	cmp al,04h
	je P4
	cmp al,05h
	jge P5
	
	jmp NO
	
NO:
	mov dl,cur_port ;here the cur_port has the port pin of the corresponding motor
	mov dh,00h
	mov al,09H ;////////Doubt///////
	out dx,al
	ret
	
P1:
	mov dl,cur_port
	mov dh,00h
	mov al,11H
	out dx,al
	ret
	
P2:
	mov dl,cur_port
	mov dh,00h
	mov al,13H
	out dx,al
	ret
	
P3:
	mov dl,cur_port
	mov dh,00h
	mov al,12H
	out dx,al
	ret
	
P4:
	mov dl,cur_port
	mov dh,00h
	mov al,16H
	out dx,al
	ret
	
P5:
	mov dl,cur_port
	mov dh,00h
	mov al,14H
	out dx,al
	ret
	



;checks for EOC
CONV:
	in al,0ch
	and al,0f0h
	cmp al,10h
	jne conv
	ret	

;update lab of display	
DISPLAY0:
	mov cl,temp0
	mov ch,00h
	mov DI,cx
	LEA BX, TABLE_D
	mov al,CS:[BX+DI]
	not al
	out 00h,al
	ret

;update msb of display
DISPLAY1:
	mov cl,temp1
	mov ch,00h
	mov DI,cx
	LEA BX, TABLE_D
	mov al,CS:[BX+DI]
	not al
	out 02h,al
	ret

;generates debounce delay	
D20MS:    
	mov            cx,20 ; delay generated 
xn:        
	loop           xn
	ret	

	ret 	;**DOUBT - WHY TWO RETURN
	
D1S:    
	mov            cx,4933 ; delay generated is 1s
xs:        
	loop           xs
	ret	

	ret

int_sense:
	;procedure to interrupt sensors
;select sensor 1
	mov al,00h
	out 0AH,al ;At 0Ah we have the PortB of 8255B

;high to low transition on START and ALE
	mov al,00h
	out 0CH,al
	mov al,03h
	out 0CH,al
	mov al,00h
	out 0CH,al
	
;wait for conversion	
	CALL conv
	
;store read temperature
	in al,08h  ;At 08h we have the PortA of 8255B
	mov temp_sense1,al

;select sensor 2
	mov al,01h
	out 0AH,al

;high to low transition
	mov al,00h
	out 0CH,al
	mov al,03h
	out 0CH,al
	mov al,00h
	out 0CH,al
	
;wait for conversion	
	CALL conv
	
;store read temperature
	in al,08h
	mov temp_sense2,al

;select sensor 3
	mov al,02h
	out 0AH,al

;high to low transition
	mov al,00h
	out 0CH,al
	mov al,03h
	out 0CH,al
	mov al,00h
	out 0CH,al
	
;wait for conversion	
	CALL conv
	
;store read temperature
	in al,08h
	mov temp_sense3,al

;select sensor 4
	mov al,03h
	out 0AH,al

;high to low transition
	mov al,00h
	out 0CH,al
	mov al,03h
	out 0CH,al
	mov al,00h
	out 0CH,al
	
;wait for conversion	
	CALL conv
	
;store read temperature
	in al,08h
	mov temp_sense4,al

;select sensor 5
	mov al,04h
	out 0AH,al

;high to low transition
	mov al,00h
	out 0CH,al
	mov al,03h
	out 0CH,al
	mov al,00h
	out 0CH,al
	
;wait for conversion	
	CALL conv
	
;store read temperature
	in al,08h
	mov temp_sense5,al

;select sensor 6
	mov al,05h
	out 0AH,al

;high to low transition
	mov al,00h
	out 0CH,al
	mov al,03h
	out 0CH,al
	mov al,00h
	out 0CH,al
	
;wait for conversion	
	CALL conv
	
	
;store read temperature
	in al,08h
	mov temp_sense6,al
	
	
	mov al,temp_sense1
	mov cur_temp,al
	mov cur_port,10h 
	CALL MOTOR
	
	mov al,temp_sense2
	mov cur_temp,al
	mov cur_port,12h
	CALL MOTOR
	
	mov al,temp_sense3
	mov cur_temp,al
	mov cur_port,14h
	CALL MOTOR
	
	mov al,temp_sense4
	mov cur_temp,al
	mov cur_port,18h
	CALL MOTOR
	
	mov al,temp_sense5
	mov cur_temp,al
	mov cur_port,1Ah
	CALL MOTOR
	
	mov al,temp_sense6
	mov cur_temp,al
	mov cur_port,1Ch
	CALL MOTOR
	
	sti
	jmp X0

	iret

