;
; 1_Led.asm
;
; Created: 3/6/2024 6:23:08 PM
; Author : Maximus
;

#include <m328pdef.inc> ; Incluye las definiciones de los registros 
						;para que se los pueda usar con los nombres en vez del numero que les corresponde

;igualdades, coloca un nombre a un valor numérico
.equ	softversion=0x01
.equ	build=0x04
.equ	centuria=20
.equ	anno=17
.equ	mes=1
.equ	dia=29

;**** GPIOR0 como regsitros de banderas ****
.equ BTNACTUAL			= 0	;GPIOR0<0>: ultimo estado del pulsador
.equ BTNDOWN			= 1 ;GPIOR0<1>:  
;GPIOR0<2>: 
;GPIOR0<3>:
;GPIOR0<4>:  
;.equ F100ms			= 5 ;GPIOR0<5>: flag pongo en 1 cuando pasaron 100ms
.equ FSECUENCIA			= 6 ;GPIOR0<6>:  
.equ F10MS				= 7	;GPIOR0<7>: flag pongo en 1 cuando entra a la interrupcion de 10ms


;definiciones - nombres simbólicos, coloca un nombre a registros
.def	w=r16
.def	w1=r17
.def	saux=r18
.def	flag1=r19
.def	newButton=r21



;Segmento de EEPROM
.eseg
econfig:	.BYTE	1

;constantes
const2:		.DB 1, 2, 3


;segmento de Datos SRAM
.dseg		;sts para cargar --- lds para leer
statboot:		.BYTE	1
addrrx:			.BYTE	2
RXBUF:			.BYTE	24	;Reservo espacio en la RAM
actualstate:	.BYTE	1
tdebounce:		.BYTE	1
tstate:			.BYTE	1
tsecuencia:		.BYTE	1
;aux		.BYTE	1
; No puedo trabajar directamente con la memoria
; Primero tengo que pasar de la SRAM a un registro con					lds r16, aux
; Luego opero con el registro y vuelvo a cargar el valor a la SRAM con	sts aux, r16


;segmento de Código
.cseg
.org	0x00
	jmp	start

;interrupciones	
.org	0x16
	jmp TIMER1_COMPA

;.org	0x16
;	jmp	serv_rx0
;.org	0x26
;	jmp	serv_cmp0

.org	0x34
;constantes
;consts:		.DB 0, 255, 0b01010101, -128, 0xaa
;varlist:	.DD 0, 0xfadebabe, -2147483648, 1 << 30


;Servicio de interrupciones
TIMER1_COMPA:
	push	r2
	in		r2, SREG
	push	r2
	push	r16
	ldi		r16, 0x00

	; Empieza lo que quiero hacer al saltar la interrupción
	sts		TCNT1H, r16
	ldi		r16, 0x00
	sts		TCNT1L, r16
	sbi		GPIOR0, F10MS ; pongo en 1 el bit 7 del GPIOR para indicar que pasaron 10ms
	
	; Termina lo que quiero hacer al saltar la interrupción
out_TIMER1_COMPA:
	pop r16
	pop	r2
	out SREG, r2
	pop r2
	reti


;**** Funciones ****
ini_ports:
	cli
	;PORT B PIN 5
	ldi r16, 0b00100000
	out DDRB, r16
	ldi r16, 0b00010000
	out PORTB, r16
	ret

ini_timer1:
	ldi r16, 0b00000000
	sts TCCR1A, r16
	ldi	r16, 0b00000011
	sts TCCR1B, r16
	ldi r16, high(2500)
	sts OCR1AH, r16
	ldi r16, low(2500)
	sts OCR1AL, r16
	ldi r16, 0b00000010
	sts TIMSK1, r16
	lds r16, TIFR1				;Borra las banderas al cargarlo con 1
	sts	TIFR1, r16
	ret

ini_serie0:
	ret

;====================================== do_10ms
do_10ms:
	cbi		GPIOR0, F10MS
	sbi		GPIOR0, FSECUENCIA

	lds		r16, tdebounce		; Traigo t100 para operar
	dec		r16					; Resto 1 a t100
	breq	RESET_100MS			; Si t100 <> 0 Sigo. Si t100 = 0 voy a la etiqueta
	sts		tdebounce, r16		; Si t100 <> 0 guardo el valor decrementado y sigo

RESET_100MS:
	ldi		r16, 0x0A			; Seteo el valor tdebounce=10
	sts		tdebounce, r16

	sbis	GPIOR0, BTNACTUAL		; Si el btn NO está presionado no hago nada
	rjmp	BTN_BOUNCE				; Salta cuando el botón está en 0

BTN_DEBOUNCE:
	sbic	GPIOR0, BTNDOWN
	jmp		BTN_CHANGE			; Si ya detecté el btn press no cambio
	lds		r16, tdebounce		; Traigo t100 para operar
	dec		r16					; Resto 1 a t100
	breq	BTN_CHANGE			; Si t100 <> 0 Sigo. Si t100 = 0 voy a la etiqueta
	sts		tdebounce, r16		; Si t100 <> 0 guardo el valor decrementado y sigo
	rjmp	do_10ms_OUT

BTN_BOUNCE:
	ldi		r16, 0x0A			; Seteo el valor tdebounce=10
	sts		tdebounce, r16
	rjmp	do_10ms_OUT			; Salgo del do_10ms

BTN_CHANGE:
	sbi		GPIOR0, BTNDOWN
	rjmp	do_10ms_OUT

do_10ms_OUT:
ret

;====================================== do_BTNUP
do_BTNUP:
	lds		r16, actualstate	; Cambio de ESTADO de la SECUENCIA
	inc		r16
	cpi		r16, 0x0B			; Compara si el estado llegó al max para volverlo a 0
	breq	RESET_BUCLE
	sts		actualstate, r16	; Si no se pasó guardo el valor en SRAM
	jmp		do_BTNUP_OUT

RESET_BUCLE:
	ldi		r16, 0x00
	sts		actualstate, r16

do_BTNUP_OUT:
ret

;====================================== do_SECUENCIA
do_SECUENCIA:
	cbi		GPIOR0, FSECUENCIA
	lds		r16, actualstate
	
	cpi		r16, 0x00			; ESTADO 00 = IDLE
	breq	IDLE

	cpi		r16, 0x01			; ESTADO 01 = MODO1
	breq	MODO1
	
	cpi		r16, 0x02			; ESTADO 02 = MODO2
	breq	MODO2

IDLE:
	lds		r16, tsecuencia
	dec		r16
	breq	PC+4
	sts		tsecuencia, r16
	rjmp	do_SECUENCIA_OUT
	
	ldi		r16, 0x0A
	sts		tsecuencia, r16
	rjmp	do_LED

MODO1:
	rjmp	do_SECUENCIA_OUT
MODO2:
	rjmp	do_SECUENCIA_OUT
do_LED:
	ldi		r17, 0b00100000
	in		r16, PORTB
	eor		r16, r17
 	out		PORTB, r16

do_SECUENCIA_OUT:
ret


;Like a main in C
start:
	cli	; Deshabilita todas las interrupciones
	call	ini_ports
	call	ini_serie0
	call	ini_timer1
	ldi		r16, 0x0A	;=10
	sts		tdebounce, r16
	ldi		r16, 0x00
	out		GPIOR0, r16
	sts		actualstate, r16
	ldi		r16, 0x01
	sts		tsecuencia, r16
	sei	; Habilita todas las interrupciones
loop:
								; Pregunto si pasaron los 10ms
	sbic	GPIOR0, F10MS		; Skip if Bit in I/O Register is Cleared
	call	do_10ms

	sbic	GPIOR0, FSECUENCIA
	call	do_SECUENCIA

	sbis	PINB, PB4			; Si el BOTON está Presionado SALTA
	sbi		GPIOR0, BTNACTUAL	; Setea bandera de que el Botón está en 1
	sbic	PINB, PB4			; Si el BOTON NO está Presionado SALTA
	cbi		GPIOR0, BTNACTUAL	; Limpia la bandera de que el Botón está en 0

	sbis	GPIOR0, BTNDOWN		; Si detecté btn press me quedo esperando el cambio de estado
	jmp		loop				; Si no está btn press vuelvo a empezar loop

	sbic	GPIOR0, BTNACTUAL	; Si se soltó el btn está en flanco ascendente
	jmp		loop				; Si sigue press vuelvo a empezar loop

BTN_RISING:
	cbi		GPIOR0, BTNDOWN
	call	do_BTNUP

	jmp	loop
	

