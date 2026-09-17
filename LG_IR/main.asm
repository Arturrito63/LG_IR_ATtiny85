;
; LG_IR.asm
;
; Created: 25/8/2026 12:18:02
; Author : Jorge Albornoz
;
; Programar CKSEL[3:0] = 010 /LFuse = 0xE2 (PLL interno a 16Mhz)
;

.dseg                   ; Cambiar al segmento de datos (SRAM)
.org SRAM_START         ; Iniciar en la primera dirección de la SRAM
mi_var: .byte 1         ; Reservar 1 byte de espacio
old_var: .byte 1        ; Reservar 1 byte de espacio
byte_var: .byte 1       ; Reservar 1 byte de espacio
addr_var: .byte 1       ; Reservar 1 byte de espacio
data_var: .byte 1       ; Reservar 1 byte de espacio

.eseg                   ; Define el inicio del segmento de EEPROM
.org 0x0000
code_1: .db 0x04, 0xFB  ; Código InStart
code_2: .db 0x04, 0xFF  ; Código EzAdjust
code_3: .db 0x04, 0xFE  ; Código PowerOnly

.cseg                   ; Define el inicio del segmento de código
.org 0x0000             ; Vector de Reset
   rjmp RESET

.org PCI0addr
    rjmp PCINT0_ISR     ; Vector de interrupción por cambio de pin (PCINT0)

RESET:
    ; --- Inicialización del puntero de pila (Stack Pointer) ---
    ldi r16, HIGH(RAMEND)
    out SPH, r16
    ldi r16, LOW(RAMEND)
    out SPL, r16

    ; --- Secuencia crítica de cambio de reloj (CLKPR) ---
    cli                     ; Deshabilitar interrupciones por seguridad     

	; almacena la mascara de control en las variables mi_var y old_var
	ldi r16, 0b00011100    ; Cargar mascara en el registro r16
    sts mi_var, r16
	sts old_var, r16

	; --- Define pines de entrada, salida y sus estados 
	ldi r16, 0b00000011 ; all ports set to output   0000 0011 
	out DDRB,R16   ; Set OUTput ports.

    ; Activar resistencia Pull-Up en PB5, PB4 y PB3 y salida PB2 en 1 (alto)
    ldi r16, 0b00011110
	out PORTB, r16

	; Apagar el ADC para ahorrar energía
	cbi ADCSRA, ADEN

	; --- Configura TIMER0 en modo CTC 
	ldi r16,(1<<CS00)  ; clock counter with I/O clock/1
	out TCCR0B,R16
	
	ldi r16,(1<<WGM01)|(1<<COM0A0)  ; WGM[2:0] = 0x2 sets CTC mode. COM0A0 = 1 : toggle pins output with compare match
	out TCCR0A,R16

	;ldi R16,(1<<OCIE0A)  ; Output Compare_0 interrupt enable
	;out TIMSK,R16

	ldi r16, 106 ; cuenta hasta 105-1, unos 13uSeg
	out OCR0A,R16
	
	; --- Habilitar la interrupción por cambio de pin en GIMSK (General Interrupt Mask Register)
    ;in  r16, GIMSK
    ;sbi GIMSK, 5    ; Activa Pin Change Interrupt Enable 0
	ldi r16, (1<<PCIE)
    out GIMSK, r16

    ; 5. Seleccionar qué pin(es) dentro del grupo activan la interrupción en PCMSK (Pin Change Mask Register)
    ldi r16, (1 << PCINT4)|(1 << PCINT3)|(1 << PCINT2)
    out PCMSK, r16      ; Habilita PCINT0 específicamente
	rcall clr_cont

    sei                     ; Reorientar interrupciones
	rjmp main

; ############################################################################################################

main:
   adiw r28, 1
   ;mov r16, r28
   ;mov r17, r29
   ;and r16, r17
   ;cpi r16, 0xff           ; Si R28:R29 = 65.535 ejecuta power_down
   and r28, r29
   cpi r28, 0xff
   brne Q1
   inc r15
   mov r16, r15
   cpi r16, 0xff
   breq to_pd

Q1: lds r16, mi_var
    cpi r16, 0b00011100     ; Si no se presiono ningun botón salta a "main"
    breq main
    ; Si se presiono algún boton...
    rcall delay_100ms
    lds r17, old_var
    cp r16,r17
    breq boton_sel
    sts old_var, r16
    rjmp main

to_pd:
   rcall clr_cont
   rcall power_down
   rjmp main

; ############################################################################################################

clr_cont:
    ldi r28, 0x00
	mov r29, r28
	mov r15, r28
	ret


power_down:
; Configurar bits SM1=1, SM0=0 (Power-down) y SE=1 (Sleep Enable)
    push r16
	ldi r16, (1 << SM1) | (1 << SE)
    out MCUCR, r16

    sleep               ; El ATtiny85 se duerme por completo aquí

    ; Al despertar por el botón, el código continúa desde aquí:
    ldi r16, 0x00
    out MCUCR, r16      ; Deshabilita el modo sleep por seguridad (SE=0)
	pop r16
    ret

boton_sel:
   sbr r16, 0x80  ; Activa bit indicador de interrupción atendida (0b10000000)
   ; Si boton 1 presionado
   sbrs r16, 2
   rjmp boton_1
   ;nop
   ; Si boton 2 presionado
   sbrs r16, 3
   rjmp boton_2
   ;nop
   ; Si boton 3 presionado
   sbrs r16, 4
   rjmp boton_3
   ;nop
   rjmp main

boton_1:
   ori R16, 0b00000100   ; Borra botón 1 presionado
   ldi r25, high(code_1)
   ldi r24, low(code_1)
   rjmp boton_x

boton_2:
   ori R16, 0b00001000   ; Borra botón 2 presionado
   ldi r25, high(code_2)
   ldi r24, low(code_2)
   rjmp boton_x

boton_3:
   ori R16, 0b00010000   ; Borra botón 3 presionado
   ldi r25, high(code_3)
   ldi r24, low(code_3)

boton_x:
   rcall eprom_word_rd
   rcall send_trama
   cbr r16, 0b10000000
   sts mi_var, r16       ; Borra botón presionado en "mi_var"
   rjmp main


eprom_word_rd:
    push r17            ; Guarda el contenido de R17
L1: sbic EECR, EEPE
    rjmp L1
	out EEARH, r25
	out EEARL, r24
	sbi EECR, EERE
	in r17, EEDR
	sts addr_var, r17
	adiw r24,1
L2: sbic EECR, EEPE
    rjmp L2
	out EEARH, r25
	out EEARL, r24
	sbi EECR, EERE
	in r17, EEDR
	sts data_var, r17
	pop r17
	ret


send_trama:
	push r16             ; Guarda el contenido de R16
	rcall IR_long_pulse  ; Pulso de inicio de Trama
	lds r16, addr_var    ; Carga addr
	rcall send_cmp_bytes
	lds r16, data_var    ; Carga data
	rcall send_cmp_bytes
	rcall IR_short_pulse ; Pulso de fin de trama
	pop r16              ; Restaura el contenido de r16
	ret

send_cmp_bytes:         ; Envia un byte seguido de su complento a uno
	sts byte_var, r16
	rcall send_byte
	lds r16, byte_var
	com r16
	rcall send_byte
	ret

send_byte:              ; Envia el contenido de R16
    push r17            ; Guarda el contenido de R17
	ldi r17, 8
T1: lsr r16
    brcs B1
	rcall send_bit_0
	rjmp T2
B1: rcall send_bit_1
T2: dec r17
    brne T1
	pop r17             ; Restaura el contenido de r17
	ret

send_bit_1:
    rcall IR_short_pulse
	rcall delay_560us
	rcall delay_560us
	rcall delay_560us
	ret

send_bit_0:
	rcall IR_short_pulse
	rcall delay_560us
	ret

	IR_long_pulse:
    cbi PORTB, 1 ;Led ON a 38KHz
	rcall delay_4500us
	rcall delay_4500us
	sbi PORTB, 1 ;Led OFF
	rcall delay_4500us
	ret

IR_short_pulse:
    cbi PORTB, 1 ;Led ON a 38KHz
	rcall delay_560us
	sbi PORTB, 1 ;Led OFF
	ret

delay_560us:
    ldi r25, 6              ; Multiplicador externo (1 ciclo)
X1: ldi r24, 250            ; Multiplicador interno (1 ciclo) 248/250
X2: dec r24                 ; 1 ciclo
    brne X2                 ; 2 ciclos si salta, 1 si no
    dec r25                 ; 1 ciclo
    brne X1                 ; 2 ciclos si salta
    ret                     ; Retorno (4 ciclos)


delay_4500us:
    ldi r25, 48             ; Multiplicador externo (1 ciclo)
Y1: ldi r24, 253            ; Multiplicador interno (1 ciclo)
Y2: dec r24                 ; 1 ciclo
    brne Y2                 ; 2 ciclos si salta, 1 si no
    dec r25                 ; 1 ciclo
    brne Y1                 ; 2 ciclos si salta
    ret                     ; Retorno (4 ciclos)

;--- Pausa de 100mSeg
delay_100ms:
    ldi r25, 4
Z0:	push r25
    ldi r25, 200            ; Multiplicador externo (1 ciclo)
Z1: ldi r24, 254            ; Multiplicador interno (1 ciclo)
Z2: dec r24                 ; 1 ciclo
    brne Z2                 ; 2 ciclos si salta, 1 si no
    dec r25                 ; 1 ciclo
    brne Z1                 ; 2 ciclos si salta
	pop r25
	dec r25
	brne Z0
    ret                     ; Retorno (4 ciclos)                    ; Retorno (4 ciclos)

; *******************************************************************************
PCINT0_ISR:
    ; Rutina de servicio de interrupción
	push r16            ; Guarda el contenido de R16

	lds r16, mi_var
	sbrc r16, 7
	rjmp no_salva

    in  r16, SREG       ; Guardar SREG por seguridad
    push r16

    in  r16, PINB
	andi r16, 0b00011100
    sts mi_var, r16     ; 0b000xxx00 -> mi_var

no_salva:
    pop r16             ; Restaurar SREG
    out SREG, r16
	pop r16             ; Restaura el contenido de R16
    reti                ; Retorno de interrupción