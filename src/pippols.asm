; ==========================================================================
; PIPPOLS - Konami (1985) - MSX1 - cartucho RC-729 de 16 KB en la pagina 1
; ==========================================================================
; Generado por tools/mkasm.py a partir del trazado de flujo real.
; Los comentarios provienen de tools/../src/*.notes y estan anclados a
; direccion, de modo que sobreviven a un retrazado.
; ==========================================================================

	org 0x04000


; ----------------------------------------------------------------------
; Etiquetas que no caen en ninguna posicion emitida del listado
; (destinos fuera del binario o dentro de una instruccion).
; ----------------------------------------------------------------------
BAJA_SIN_CONTAR:	equ 0x07181

; ----------------------------------------------------------------------
; DATOS cabecera_del_cartucho: La cabecera que lee la BIOS: "AB", INIT=0x404A
;   y a cero STATEMENT, DEVICE y TEXT. Con la cabecera en 0x4000 la BIOS mapea
;   el cartucho en la PAGINA 1 y salta a INIT al acabar de arrancar
;   0x4000..0x4010  (16 bytes)
DATA_cabecera_del_cartucho:
	defb 041h,042h	; 4000
	defw 0404ah,00000h,00000h,00000h	; 4002  -> INIT 0x0000 0x0000 0x0000
	defb 000h,000h,000h,000h,000h,000h	; 400a

; ======================================================================
; CODIGO 0x4010..0x4095  (133 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LA INTERRUPCION. INIT escribe `jp 0x4010` en el gancho H.KEYI (0xFD9A) y se queda parado en `jr $`: aqui dentro corre el juego entero, un paso por fotograma. Lo primero y lo ultimo es leer el estado del VDP, que es lo que baja la linea de interrupcion.
; ----------------------------------------------------------------------
INTERRUPCION:		; Un paso del juego por fotograma; la BIOS la llama desde el gancho H.KEYI
	call 0013eh		;4010   ; BIOS RDVDP - Reads VDP status register | leer el estado del VDP baja la peticion de interrupcion
	call PASO_DE_SONIDO		;4013   ; un paso del sonido, pase lo que pase
	ld hl,0e005h		;4016   ; el candado: si ya estabamos dentro no se reentra
	bit 0,(hl)		;4019
	jr nz,INTERRUPCION_SALIDA		;401b
	inc (hl)			;401d
	call LEE_MANDOS		;401e   ; lee los mandos
	call PASO		;4021   ; y despacha el estado del juego
	xor a			;4024
	ld (0e005h),a		;4025
INTERRUPCION_SALIDA:		; Vuelve a leer el estado del VDP y, si el bit 7 sigue puesto, mete otro paso de sonido
	call 0013eh		;4028   ; BIOS RDVDP - Reads VDP status register
	or a			;402b
	call m,PASO_DE_SONIDO		;402c   ; bit 7 puesto = ha entrado otra interrupcion mientras: otro paso de sonido
	ret			;402f
ESCRIBE_REG_VDP:		; Escribe B en el registro C del VDP; de paso pone a cero 0x40C5, que esta en la ROM y no cambia nada
	ld hl,00000h		;4030
	ld (040c5h),hl		;4033   ; escribe en la ROM: no hace nada (queda de una version con esta rutina en RAM)
	jp 00047h		;4036   ; BIOS WRTVDP - Writes data in the VDP-register
SUMA_A_HL:		; HL = HL + A, con acarreo al byte alto
	add a,l			;4039
	ld l,a			;403a
	ret nc			;403b
	inc h			;403c
	ret			;403d
SUMA_A_DE:		; DE = DE + A, con acarreo al byte alto
	add a,e			;403e
	ld e,a			;403f
	ret nc			;4040
	inc d			;4041
	ret			;4042

; ----------------------------------------------------------------------
; EL DESPACHADOR DE KONAMI. `call DESPACHA` con el indice en A y la tabla de palabras justo detras del call: el `pop hl` recoge la direccion de la tabla y `jp (hl)` salta a la entrada. Lo usan cuatro sitios (0x4092, 0x7A70, 0x7B99 y 0x7CEB).
; ----------------------------------------------------------------------
DESPACHA:		; Salta a la entrada A de la tabla de palabras que sigue al `call`
	add a,a			;4043   ; el indice va en palabras
	pop hl			;4044   ; la direccion de retorno ES la tabla
	call LEE_PALABRA		;4045   ; DE = la palabra numero A de la tabla
	ex de,hl			;4048
	jp (hl)			;4049

; ----------------------------------------------------------------------
; INIT. Lo llama la BIOS al arrancar, con el cartucho ya mapeado en la pagina 1.
; ----------------------------------------------------------------------
INIT:		; Prepara la maquina, engancha la interrupcion y se queda parado
	di			;404a
	im 1		;404b
	ld sp,0f000h		;404d   ; la pila, arriba del todo de la RAM
	ld a,0c3h		;4050   ; `jp 0x4010` en el gancho H.KEYI de la BIOS
	ld (0fd9ah),a		;4052
	ld hl,INTERRUPCION		;4055
	ld (0fd9bh),hl		;4058
	ld hl,0e000h		;405b   ; borra 0x0EFF+1 bytes de RAM desde 0xE000
	ld bc,00effh		;405e
	call BORRA_RAM		;4061
	ld a,001h		;4064   ; candado puesto: la interrupcion no hara nada mientras se prepara la pantalla
	ld (0e005h),a		;4066
	call PREPARA_PANTALLA		;4069   ; prepara el VDP y borra la VRAM
	xor a			;406c
	ld (0e005h),a		;406d
	call 0013eh		;4070   ; BIOS RDVDP - Reads VDP status register
	ei			;4073
INIT_PARADO:		; Aqui se queda el programa principal para siempre: todo pasa en la interrupcion
	jr INIT_PARADO		;4074
COLOR_DE_FONDO:		; Registro 7 del VDP (tinta y fondo) y de paso apaga el bit 6 de 0xE002
	ld hl,043feh		;4076
	res 6,(hl)		;4079
	jp PIDE_SONIDO		;407b

; ----------------------------------------------------------------------
; EL PASO DE CADA FOTOGRAMA. Los estados 0, 1 y 2 se meten en la pila el retorno 0x4184, que es lo que hace comun el manejo de la pantalla de titulo. En A va el estado (0xE000) y en B el subestado (0xE001), que cada estado va gastando con `djnz`.
; ----------------------------------------------------------------------
PASO:		; Suma un fotograma y despacha el estado de 0xE000
	ld hl,0e003h		;407e
	inc (hl)			;4081   ; 0xE003 es el contador de fotogramas de toda la vida del programa
	ld a,(0e000h)		;4082
	cp 003h		;4085
	jr nc,PASO_DESPACHA		;4087   ; los estados 0, 1 y 2 son la pantalla de titulo
	ld hl,04184h		;4089   ; retorno comun de la pantalla de titulo
	push hl			;408c
PASO_DESPACHA:		; C = estado (0xE000), B = subestado (0xE001)
	ld bc,(0e000h)		;408d
	ld a,c			;4091
	call DESPACHA		;4092

; ----------------------------------------------------------------------
; DATOS tabla_de_estados: Los 8 estados de la pantalla de titulo y de la
;   partida, destino del despachador de 0x4092 (indice 0xE000)
;   0x4095..0x40a5  (16 bytes)
DATA_tabla_de_estados:
	defw 040a5h	; 4095  -> EST_LOGOTIPO
	defw 040d5h	; 4097  -> EST_TITULO_ESPERA
	defw 040ddh	; 4099  -> EST_MENU
	defw 040feh	; 409b  -> EST_PARPADEO
	defw 04121h	; 409d  -> EST_EMPIEZA_FASE
	defw 0413bh	; 409f  -> EST_JUGANDO
	defw 0415ah	; 40a1  -> EST_FIN_DE_PARTIDA
	defw 04161h	; 40a3  -> EST_GAME_OVER

; ======================================================================
; CODIGO 0x40a5..0x41cf  (298 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; ESTADO 0: el logotipo de KONAMI subiendo. El `djnz` de cada estado va comiendo el subestado 0xE001, asi que cada trozo es un paso mas de la secuencia.
; ----------------------------------------------------------------------
EST_LOGOTIPO:		; El logotipo de KONAMI que sube tres filas cada dos fotogramas
	djnz EST_ESPERA_TITULO		;40a5   ; subestado != 1: siguiente trozo
	ld a,(0e003h)		;40a7
	rra			;40aa   ; un fotograma si y otro no
	ret nc			;40ab
	call SUBE_LOGOTIPO		;40ac   ; sube una tanda; devuelve cero cuando ya no quedan
	ret nz			;40af
	ld de,04446h		;40b0
	call RLE_CON_DIRECCION		;40b3
	xor a			;40b6
	jr PON_ESPERA		;40b7
EST_ESPERA_TITULO:		; Espera 0xE004 fotogramas y borra la pantalla para el titulo
	djnz EST_PINTA_TITULO		;40b9   ; subestado distinto de 2: el trozo que pinta el titulo
	ld hl,0e004h		;40bb
	dec (hl)			;40be   ; la cuenta atras que dejo PON_ESPERA
	ret nz			;40bf
	call PINTA_TITULO_Y_ROTULOS		;40c0
	xor a			;40c3   ; A = 0: al estado siguiente sin espera
	jp SIGUIENTE_ESTADO		;40c4
EST_PINTA_TITULO:		; Pone el VDP, borra los nombres, carga los caracteres del panel y monta el titulo grande
	call CARGA_REGISTROS_VDP		;40c7
	call BORRA_PANTALLA		;40ca
	call CARGA_CARACTERES		;40cd
	call PREPARA_LOGOTIPO		;40d0
	jr SIGUIENTE_SUBESTADO		;40d3
EST_TITULO_ESPERA:		; Cuenta atras con el titulo en pantalla
	ld hl,0e004h		;40d5
	dec (hl)			;40d8
	ret nz			;40d9
	jp SIGUIENTE_ESTADO		;40da
EST_MENU:		; El menu: espera a que pulsen espacio y arranca la partida
	djnz EST_ARRANCA_DEMO		;40dd
	call MANDO_DE_LA_DEMO		;40df   ; el mando de la demo
	call PASO_DE_PARTIDA		;40e2
	ld a,(0e054h)		;40e5   ; 0xE054 = 0 quiere decir que la demo ha terminado
	or a			;40e8
	ret nz			;40e9
EST_VUELVE_AL_PRINCIPIO:		; Estado 0, subestado 0
	xor a			;40ea
	ld (0e000h),a		;40eb
	jr SUBESTADO_CERO		;40ee
EST_ARRANCA_DEMO:		; Borra la pantalla y prepara la fase de la demo
	call BORRA_PANTALLA		;40f0
	call DEMO_SIGUIENTE_PANTALLA		;40f3
PON_ESPERA:		; Deja A en 0xE004 y pasa al subestado siguiente
	ld (0e004h),a		;40f6
SIGUIENTE_SUBESTADO:		; Suma uno a 0xE001
	ld hl,0e001h		;40f9
	inc (hl)			;40fc
	ret			;40fd
EST_PARPADEO:		; El "PUSH SPACE KEY" parpadeando mientras se espera
	djnz EST_PARTIDA_NUEVA		;40fe
	ld hl,0e004h		;4100
	dec (hl)			;4103
	jr z,SIGUIENTE_SUBESTADO		;4104
	bit 2,(hl)		;4106   ; el bit 2 del contador enciende y apaga el rotulo
	ld de,044b9h		;4108
	call z,ESCRIBE_ROTULO		;410b
	jp BORRA_ROTULO		;410e
EST_PARTIDA_NUEVA:		; Borra marcadores y prepara una partida
	djnz EST_MUSICA_DE_ARRANQUE		;4111
	call PARTIDA_NUEVA		;4113
	jr SIGUIENTE_ESTADO		;4116
EST_MUSICA_DE_ARRANQUE:		; Suena la musica 0x8F y se esperan 0x50 fotogramas
	ld a,08fh		;4118
	call PIDE_SONIDO		;411a
	ld a,050h		;411d
	jr PON_ESPERA		;411f
EST_EMPIEZA_FASE:		; Borra la pantalla, pinta el marcador y arranca la fase
	call BORRA_PANTALLA		;4121
	call PINTA_PANEL		;4124
	call ARRANCA_FASE		;4127
	ld hl,0e054h		;412a
	ld (hl),001h		;412d
SIGUIENTE_ESTADO:		; Deja A en 0xE004, suma uno a 0xE000 y pone el subestado a cero
	ld (0e004h),a		;412f
	ld hl,0e000h		;4132
	inc (hl)			;4135
SUBESTADO_CERO:		; Pone 0xE001 a cero
	xor a			;4136
	ld (0e001h),a		;4137
	ret			;413a
EST_JUGANDO:		; El estado en el que se juega: un paso de partida por fotograma
	call PASO_DE_PARTIDA		;413b
	ld hl,0e054h		;413e   ; mientras 0xE054 no sea cero, seguimos en la fase
	ld a,(hl)			;4141
	or a			;4142
	ret nz			;4143
	ld (hl),001h		;4144
	ld hl,0e050h		;4146
	ld a,(hl)			;4149   ; sin vidas: se acabo
	and a			;414a
	jr z,SIGUIENTE_ESTADO		;414b
	sub 001h		;414d
	daa			;414f
	ld (hl),a			;4150
	call PREPARA_JUGADOR		;4151   ; vuelve a pintar el marcador con una vida menos
	ld a,0c0h		;4154
	ld (0e11bh),a		;4156
	ret			;4159
EST_FIN_DE_PARTIDA:		; Suena el 0x98 (GAME OVER) y pasa al estado siguiente
	ld a,098h		;415a
	call PIDE_SONIDO		;415c
	jr SIGUIENTE_ESTADO		;415f
EST_GAME_OVER:		; Ensena el rotulo de GAME OVER y vuelve al titulo
	djnz EST_ROTULO_GAME_OVER		;4161   ; subestado distinto de 1: primero el rotulo
	call PARPADEA_PUNTO_MAPA		;4163
	ld a,(0e012h)		;4166   ; +2 del primer canal: no se vuelve al titulo hasta que la musica de GAME OVER se calla
	or a			;4169
	ret nz			;416a
	ld hl,0e002h		;416b
	ld a,(hl)			;416e
	and 0bfh		;416f   ; apaga el bit 6 de 0xE002: ya no hay partida en marcha
	ld (hl),a			;4171
	jp EST_VUELVE_AL_PRINCIPIO		;4172
EST_ROTULO_GAME_OVER:		; Borra el area de juego y escribe GAME OVER
	call BORRA_AREA_DE_JUEGO		;4175
	ld de,044cah		;4178
	call ESCRIBE_ROTULO		;417b
	call PINTA_PANEL		;417e
	jp PON_ESPERA		;4181

; ----------------------------------------------------------------------
; RETORNO DE LA PANTALLA DE TITULO. Es lo que 0x4089 mete en la pila antes de despachar los estados 0 a 2: lee los mandos, y si tocan espacio arranca la partida.
; ----------------------------------------------------------------------
TITULO_MANDOS:		; Si se pulsa espacio, salta a la partida; si no, deja seguir la demo
	call LEE_MANDOS_CRUDO		;4184   ; lee el teclado y el joystick otra vez
	ld hl,0e042h		;4187   ; la pantalla de titulo lleva su propia copia de los mandos, en 0xE041/0xE042
	call MANDOS_FLANCOS		;418a
	or a			;418d   ; nada pulsado: nada que hacer
	ret z			;418e
	ld hl,0e004h		;418f   ; se reinicia la cuenta de espera
	ld (hl),000h		;4192
	ld hl,0e000h		;4194
	ld b,(hl)			;4197
	djnz TITULO_AL_PRINCIPIO		;4198   ; si no estamos en el estado 1, cualquier tecla lleva al titulo
	and 030h		;419a   ; bits 4 y 5: disparo o espacio
	ret z			;419c
	ld a,040h		;419d   ; 0xE002 bit 6: partida de verdad, no demo
	ld (0e002h),a		;419f
	ld (hl),003h		;41a2   ; al estado 3, que es el que prepara la partida
	inc hl			;41a4
	ld (hl),000h		;41a5
	ret			;41a7
TITULO_AL_PRINCIPIO:		; Cualquier tecla durante la demo devuelve a la pantalla de titulo
	ld (hl),001h		;41a8
	ld a,026h		;41aa
	call PIDE_SONIDO		;41ac
	jp PINTA_TITULO_Y_ROTULOS		;41af

; ----------------------------------------------------------------------
; PREPARAR UNA PARTIDA. Deja el marcador a cero, pone dos vidas y coloca la posicion inicial de la fase.
; ----------------------------------------------------------------------
PARTIDA_NUEVA:		; Borra de 0xE046 a 0xE7FF, pone las vidas y arranca el mapa
	ld hl,0e046h		;41b2
	ld bc,007bah		;41b5   ; 0x7BA bytes desde 0xE046: se borra todo menos el record, que vive en 0xE043
	call BORRA_RAM		;41b8
	ld hl,041cfh		;41bb
	ld de,0e050h		;41be
	ld bc,00003h		;41c1
	ldir		;41c4
	ld hl,000c0h		;41c6   ; posicion inicial: 0x00C0 pixeles, o sea la fila 24
	ld (0e100h),hl		;41c9
	jp DESCOMPRIME_PIEZAS		;41cc   ; descomprime las 44 piezas del mapa a 0xE500

; ----------------------------------------------------------------------
; DATOS partida_nueva: Los tres bytes que 0x41B2 copia a 0xE050 al empezar: 2
;   vidas, 1, y 0x20 (la proxima vida extra, en decenas de millar BCD)
;   0x41cf..0x41d2  (3 bytes)
DATA_partida_nueva:
	defb 002h,001h,020h	; 41cf

; ======================================================================
; CODIGO 0x41d2..0x4249  (119 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL MARCADOR. Suma DE (en BCD) a los puntos del jugador que este jugando, mira si toca vida extra y actualiza el record.
; ----------------------------------------------------------------------
SUMA_PUNTOS:		; Suma DE en BCD a los puntos; da vida extra y refresca el record
	ld a,(0e002h)		;41d2   ; bit 6 de 0xE002: sin partida en marcha no se suman puntos
	add a,a			;41d5
	ret p			;41d6
	ld hl,0e046h		;41d7   ; los puntos son tres bytes BCD en 0xE046, y en el panel se pintan con un cero fijo pegado detras: lo que se ve es diez veces esto
	ld a,(hl)			;41da
	add a,e			;41db
	daa			;41dc
	ld (hl),a			;41dd
	inc l			;41de
	ld a,(hl)			;41df
	adc a,d			;41e0
	daa			;41e1
	ld (hl),a			;41e2
	inc hl			;41e3
	ld a,(hl)			;41e4
	adc a,000h		;41e5
	daa			;41e7
	ld (hl),a			;41e8
	jr nc,PUNTOS_VIDA_EXTRA		;41e9
	ld bc,09999h		;41eb   ; tope: 999999 (o sea 9999990 en el panel)
	ld (0e043h),bc		;41ee
	ld (0e044h),bc		;41f2
	jp PINTA_MARCADORES		;41f6
PUNTOS_VIDA_EXTRA:		; Compara las cuatro cifras altas con 0xE052, el proximo escalon de vida extra
	push hl			;41f9
	ld d,(hl)			;41fa
	dec l			;41fb
	ld e,(hl)			;41fc
	ld hl,(0e052h)		;41fd   ; el escalon arranca en 0x0020, o sea 20000 puntos de los que se ven
	ex de,hl			;4200
	and a			;4201
	sbc hl,de		;4202
	ex de,hl			;4204
	jr c,PUNTOS_RECORD		;4205
	ld a,060h		;4207   ; y el siguiente son 0x60 mas: 60000 puntos mas de los que se ven
	add a,l			;4209
	daa			;420a
	ld l,a			;420b
	ld a,000h		;420c
	adc a,h			;420e
	daa			;420f
	ld h,a			;4210
	jr nc,PUNTOS_UNA_MAS		;4211
	ld h,0ffh		;4213
PUNTOS_UNA_MAS:		; Una vida mas (tope 99) y suena el 6
	ld (0e052h),hl		;4215   ; guarda el escalon siguiente de vida extra
	ld hl,0e050h		;4218
	ld a,(hl)			;421b
	cp 099h		;421c   ; 99 vidas es el tope
	jr z,PUNTOS_RECORD		;421e
	add a,001h		;4220
	daa			;4222   ; las vidas tambien van en BCD
	ld (hl),a			;4223
	ld a,006h		;4224   ; el sonido 6 es el de la vida extra
	call PIDE_SONIDO_EN_PARTIDA		;4226
	call PINTA_VIDAS		;4229
PUNTOS_RECORD:		; Compara los puntos con el record de 0xE043
	pop de			;422c
	ld b,003h		;422d
	ld hl,0e045h		;422f
	ex de,hl			;4232
PUNTOS_COMPARA:		; Tres cifras BCD, de la mas alta a la mas baja
	ld a,(de)			;4233   ; la cifra del record, de 0xE045 hacia abajo
	sub (hl)			;4234   ; menos la de los puntos: si el record es menor, hay record nuevo
	jr c,PUNTOS_NUEVO_RECORD		;4235
	jp nz,PINTA_MARCADORES		;4237   ; si el record gana, no hay nada que copiar
	dec l			;423a
	dec e			;423b   ; las dos cuentas bajan a la vez a la cifra siguiente
	djnz PUNTOS_COMPARA		;423c
PUNTOS_NUEVO_RECORD:		; Copia los puntos al record
	ld bc,00003h		;423e
	ld e,045h		;4241
	ld l,048h		;4243
	lddr		;4245
	jr $+104		;4247

; ----------------------------------------------------------------------
; DATOS filas_del_marcador: Una entrada por fila de pantalla (24) y un 0 de
;   cierre: 1, 2 o 3 dice cual de los tres trozos de marco pinta 0x4277 en la
;   columna 23
;   0x4249..0x4262  (25 bytes)
DATA_filas_del_marcador:
	defb 001h,002h,002h,001h,002h,002h,001h,002h,002h,001h,003h,003h,003h,003h,003h,003h,003h,003h,003h,003h,001h,002h,002h,001h,000h	; 4249  .........................

; ----------------------------------------------------------------------
; DATOS marco_borde: El trozo 1: un caracter 0x04 y otro 0x08, comprimidos con
;   el RLE de 0x43B4
;   0x4262..0x4267  (5 bytes)
DATA_marco_borde:
	defb 081h,004h,008h,003h,000h	; 4262

; ----------------------------------------------------------------------
; DATOS marco_medio: El trozo 2: 0x04, 0x07 y otra vez 0x04
;   0x4267..0x426e  (7 bytes)
DATA_marco_medio:
	defb 081h,004h,007h,002h,081h,004h,000h	; 4267

; ----------------------------------------------------------------------
; DATOS marco_doble: El trozo 3: dos veces 0x04, luego 0x05 0x05, y dos veces
;   0x04 0x03
;   0x426e..0x4277  (9 bytes)
DATA_marco_doble:
	defb 082h,004h,005h,005h,002h,082h,004h,003h,000h	; 426e  .........

; ======================================================================
; CODIGO 0x4277..0x42e1  (106 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL MARCO DEL PANEL. Pinta la columna 23 fila a fila con uno de los tres trozos de 0x4249, y encima los rotulos.
; ----------------------------------------------------------------------
PINTA_PANEL:		; El marco de la derecha, los rotulos y el mapa del mundo
	ld hl,03817h		;4277   ; 0x3817 = fila 0, columna 23
	ld de,04249h		;427a
PANEL_FILA:		; Un trozo de marco por fila
	ld a,(de)			;427d   ; 1, 2 o 3: cual de los tres trozos de marco lleva esta fila
	inc de			;427e
	push de			;427f
	push hl			;4280
	ld de,0426eh		;4281   ; el trozo 3 por defecto
	dec a			;4284
	jr nz,PANEL_TROZO_2		;4285
	ld de,04262h		;4287   ; el trozo 1
PANEL_TROZO_2:		; El trozo 2
	dec a			;428a
	jr nz,PANEL_PINTA		;428b
	ld de,04267h		;428d
PANEL_PINTA:		; El RLE deja la fila puesta; se baja una fila y se sigue
	call RLE_A_VRAM		;4290
	pop hl			;4293
	ld de,00020h		;4294   ; una fila mas abajo en la tabla de nombres son 32 bytes
	add hl,de			;4297
	pop de			;4298
	ld a,(de)			;4299
	and a			;429a   ; el 0 de 0x4261 cierra la tabla de filas
	jr nz,PANEL_FILA		;429b
	ld de,04457h		;429d   ; HISCORE, SCORE y REST con sus ceros
	call ESCRIBE_ROTULO		;42a0
	call PINTA_VIDAS		;42a3
	call PARPADEA_PUNTO_MAPA		;42a6
	ld de,04488h		;42a9   ; el copyright y KONAMI 1985
	call ESCRIBE_ROTULO		;42ac
PINTA_MARCADORES:		; El record en la fila 2 y los puntos en la fila 5 del panel
	ld de,0e045h		;42af
	ld hl,03858h		;42b2
	call PINTA_TRES_CIFRAS		;42b5
	ld hl,038b8h		;42b8
	ld de,0e048h		;42bb
PINTA_TRES_CIFRAS:		; Tres bytes BCD (seis cifras) desde DE a la VRAM (HL)
	ld b,003h		;42be
	jr $+77		;42c0
APAGA_PUNTO_MAPA:		; Borra el punto de la pantalla actual en el mapa del mundo
	ld c,000h		;42c2
	jr MAPA_ESCRIBE_PUNTO		;42c4
PARPADEA_PUNTO_MAPA:		; Enciende y apaga, cada 32 fotogramas, el punto de la pantalla actual
	ld a,(0e003h)		;42c6
	and 020h		;42c9   ; el bit 5 del contador de fotogramas
	ld c,0ffh		;42cb
	jr z,MAPA_ESCRIBE_PUNTO		;42cd
	inc c			;42cf
MAPA_ESCRIBE_PUNTO:		; Coge del mapa la direccion del punto de la pantalla y escribe A
	ld a,(0e132h)		;42d0
	add a,a			;42d3
	ld hl,042e1h		;42d4
	call LEE_PALABRA		;42d7
	ex de,hl			;42da
	ld a,009h		;42db   ; 0x09 es el caracter del punto; con C=0 se borra
	and c			;42dd
	jp 0004dh		;42de   ; BIOS WRTVRM - Writes data in VRAM

; ----------------------------------------------------------------------
; DATOS puntos_del_mapamundi: Las 18 direcciones de la VRAM (una por pantalla,
;   indice 0xE132) del punto que parpadea en el mapa del mundo del panel
;   derecho. 0x42C6 escribe alli 0x09 o 0x00 segun el bit 5 del contador de
;   fotogramas
;   0x42e1..0x4305  (36 bytes)
DATA_puntos_del_mapamundi:
	defw 03a3bh	; 42e1
	defw 03a1ch	; 42e3
	defw 03a1ah	; 42e5
	defw 039f9h	; 42e7
	defw 039dah	; 42e9
	defw 039dch	; 42eb
	defw 039bbh	; 42ed
	defw 039fdh	; 42ef
	defw 0399bh	; 42f1
	defw 0399bh	; 42f3
	defw 039bah	; 42f5
	defw 039bch	; 42f7
	defw 039ddh	; 42f9
	defw 039fah	; 42fb
	defw 039fch	; 42fd
	defw 03a1bh	; 42ff
	defw 039d9h	; 4301
	defw 03a3bh	; 4303

; ======================================================================
; CODIGO 0x4305..0x43fd  (248 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LAS CIFRAS DEL MARCADOR. Escribe seis cifras BCD directas por el puerto de datos del VDP, quitando los ceros de delante.
; ----------------------------------------------------------------------
PINTA_VIDAS:		; Las dos cifras de las vidas que quedan (0xE050) en la fila 8 del panel
	ld hl,0391dh		;4305
	ld de,0e050h		;4308
	ld b,001h		;430b
PUNTOS_TRES:		; Prepara la VRAM y saca B bytes BCD, dos cifras por byte
	call PREPARA_ESCRITURA		;430d
	ld c,000h		;4310
PUNTOS_CIFRA:		; El nibble alto
	ld a,(de)			;4312
	rra			;4313
	rra			;4314
	rra			;4315
	rra			;4316
	and 00fh		;4317
	jr z,PUNTOS_ALTA		;4319   ; mientras solo haya ceros, C=0 y la cifra sale en blanco
	ld c,0ffh		;431b
PUNTOS_ALTA:		; Suma la base de las cifras y borra si aun no ha salido ningun dijito
	add a,010h		;431d   ; 0x10 es el caracter del cero
	and c			;431f
	exx			;4320
	out (c),a		;4321
	exx			;4323
	ld a,(de)			;4324
	and 00fh		;4325
	jr z,PUNTOS_ULTIMA		;4327
	ld c,0ffh		;4329
PUNTOS_ULTIMA:		; La ultima cifra siempre se ve, aunque sea un cero
	dec b			;432b
	jr nz,PUNTOS_BAJA		;432c
	ld c,0ffh		;432e
PUNTOS_BAJA:		; El nibble bajo
	inc b			;4330   ; deshace el `dec b` de 0x432B, que solo servia para mirar si era la ultima
	add a,010h		;4331   ; 0x10 es el caracter del cero
	and c			;4333   ; C vale 0 mientras no haya salido ninguna cifra: el cero se borra
	exx			;4334
	out (c),a		;4335
	exx			;4337
	dec de			;4338   ; los bytes BCD se recorren de la cifra mas alta a la mas baja
	djnz PUNTOS_CIFRA		;4339
	ret			;433b

; ----------------------------------------------------------------------
; BORRAR LA PANTALLA. Con C=0x20 borra las 32 columnas; con C=0x17 solo las 23 de la izquierda, que es el area de juego, y deja el panel.
; ----------------------------------------------------------------------
BORRA_PANTALLA:		; Las 24 filas enteras de la tabla de nombres, y los sprites fuera
	ld c,020h		;433c
	jr BORRA_FILAS		;433e
BORRA_AREA_DE_JUEGO:		; Solo las 23 primeras columnas de cada fila
	ld c,017h		;4340
BORRA_FILAS:		; Borra C bytes de cada una de las 24 filas
	ld hl,03800h		;4342
	ld e,018h		;4345
BORRA_UNA_FILA:
	xor a			;4347
	ld b,000h		;4348
	push bc			;434a
	call 00056h		;434b   ; BIOS FILVRM - Fills VRAM with value
	pop bc			;434e
	ld a,020h		;434f
	call SUMA_A_HL		;4351
	dec e			;4354
	jr nz,BORRA_UNA_FILA		;4355
	ld hl,03b00h		;4357   ; los 32 sprites a Y=0xE0, que es "fuera de la pantalla"
	ld bc,00080h		;435a
	ld a,0e0h		;435d
	jp 00056h		;435f   ; BIOS FILVRM - Fills VRAM with value
PREPARA_ESCRITURA:		; Deja el VDP escribiendo en HL y el puerto de datos en C'
	ex af,af'			;4362
	call 00053h		;4363   ; BIOS SETWRT - Enables VDP to write
	exx			;4366
	ld a,(00006h)		;4367   ; el puerto de datos del VDP lo dice la BIOS en 0x0006
	ld c,a			;436a
	exx			;436b
	ex af,af'			;436c
	ret			;436d
COPIA_A_VRAM:		; BC bytes de (DE) a la VRAM (HL)
	ex de,hl			;436e
	jp 0005ch		;436f   ; BIOS LDIRVM - Block transfers to VRAM from memory
RELLENA_TRES_TERCIOS:		; Rellena BC bytes con A en los tres tercios de SCREEN 2
	ld d,003h		;4372
RELLENA_UN_TERCIO:
	push bc			;4374
	push de			;4375
	call 00056h		;4376   ; BIOS FILVRM - Fills VRAM with value
	ld de,00800h		;4379
	add hl,de			;437c
	pop de			;437d
	pop bc			;437e
	dec d			;437f
	jr nz,RELLENA_UN_TERCIO		;4380
	ret			;4382
RLE_TRES_TERCIOS:		; Descomprime (DE) en la VRAM (HL) y repite en los otros dos tercios
	ld b,003h		;4383
RLE_UN_TERCIO:
	push bc			;4385
	push de			;4386
	call RLE_A_VRAM		;4387
	ld de,00800h		;438a   ; 0x800 bytes de un tercio de SCREEN 2 al siguiente
	add hl,de			;438d
	pop de			;438e
	pop bc			;438f
	djnz RLE_UN_TERCIO		;4390
	ret			;4392

; ----------------------------------------------------------------------
; EL ESCRITOR DE ROTULOS. El formato: una palabra con la direccion de la VRAM, luego los caracteres; 0xFE empieza otro renglon con su direccion nueva y 0xFF termina. Con C=0 escribe ceros, o sea que borra el mismo rotulo.
; ----------------------------------------------------------------------
ESCRIBE_ROTULO:		; Escribe el rotulo al que apunta (DE)
	ld c,0ffh		;4393
ROTULO_RENGLON:		; Coge la direccion de VRAM del renglon
	ex de,hl			;4395   ; los dos primeros bytes del renglon son su direccion de la VRAM
	ld e,(hl)			;4396
	inc hl			;4397
	ld d,(hl)			;4398
	ex de,hl			;4399
	inc de			;439a   ; y detras van los caracteres
ROTULO_CARACTER:
	ld a,(de)			;439b
	inc de			;439c
	ld b,a			;439d
	inc b			;439e   ; 0xFF: se acabo
	ret z			;439f
	inc b			;43a0   ; 0xFE: otro renglon
	jr z,ROTULO_RENGLON		;43a1
	and c			;43a3   ; C = 0 borra en vez de escribir
	call 0004dh		;43a4   ; BIOS WRTVRM - Writes data in VRAM
	inc hl			;43a7
	jr ROTULO_CARACTER		;43a8
BORRA_ROTULO:		; El mismo rotulo escrito con ceros
	ld c,000h		;43aa
	jr ROTULO_RENGLON		;43ac

; ----------------------------------------------------------------------
; EL DESCOMPRESOR RLE. Un byte de mando: 0 termina; n con el bit 7 a cero repite n veces el byte siguiente; 0x80 empieza otro bloque con direccion nueva; 0x80+n copia n bytes tal cual. Sale todo por el puerto de datos del VDP.
; ----------------------------------------------------------------------
RLE_CON_DIRECCION:		; Lee la direccion de VRAM de la cabecera y descomprime
	ex de,hl			;43ae   ; la cabecera del bloque dice a que direccion de la VRAM va
	ld e,(hl)			;43af
	inc hl			;43b0
	ld d,(hl)			;43b1
	ex de,hl			;43b2
	inc de			;43b3
RLE_A_VRAM:		; Descomprime (DE) en la VRAM (HL)
	call PREPARA_ESCRITURA		;43b4
	exx			;43b7
	ld a,c			;43b8
	exx			;43b9
	ld c,a			;43ba
RLE_MANDO:
	ld a,(de)			;43bb
	and a			;43bc
	ret z			;43bd
	inc de			;43be
	ld b,a			;43bf
	and 07fh		;43c0   ; el bit 7 distingue "copia tal cual" de "repite"
	cp b			;43c2
	jr z,RLE_REPITE		;43c3
	and a			;43c5
	jr z,RLE_CON_DIRECCION		;43c6   ; 0x80 pelado: bloque nuevo con otra direccion
	ld b,a			;43c8
RLE_COPIA:		; n bytes tal cual
	ld a,(de)			;43c9
	inc de			;43ca
	out (c),a		;43cb
	djnz RLE_COPIA		;43cd
	jr RLE_MANDO		;43cf
RLE_REPITE:		; n veces el mismo byte
	ld a,(de)			;43d1
	out (c),a		;43d2
	djnz RLE_REPITE		;43d4
	inc de			;43d6
	jr RLE_MANDO		;43d7

; ----------------------------------------------------------------------
; PREPARAR LA PANTALLA. Registros del VDP, VRAM a cero y el color de fondo.
; ----------------------------------------------------------------------
PREPARA_PANTALLA:		; Silencia el PSG, pone el fondo, borra los 16 KB de VRAM y carga los registros
	ld a,0b8h		;43d9
	call ESCRIBE_MEZCLA		;43db
	ld a,026h		;43de
	call COLOR_DE_FONDO		;43e0
	xor a			;43e3
	ld h,a			;43e4
	ld l,a			;43e5
	ld bc,04000h		;43e6
	call 00056h		;43e9   ; BIOS FILVRM - Fills VRAM with value
CARGA_REGISTROS_VDP:		; Los ocho registros de 0x43FD
	ld hl,043fdh		;43ec
	ld d,008h		;43ef
	ld c,000h		;43f1
CARGA_UN_REGISTRO:
	ld b,(hl)			;43f3
	call 00047h		;43f4   ; BIOS WRTVDP - Writes data in the VDP-register
	inc hl			;43f7
	inc c			;43f8
	dec d			;43f9
	jr nz,CARGA_UN_REGISTRO		;43fa
	ret			;43fc

; ----------------------------------------------------------------------
; DATOS registros_del_vdp: Los ocho registros que escribe 0x43EC: R0=02
;   (SCREEN 2), R1=E2 (16K, pantalla y interrupcion encendidas, sprites de
;   16x16), R2=0E (nombres en 0x3800), R3=7F (color en 0x0000), R4=07
;   (patrones en 0x2000), R5=76 (atributos de sprite en 0x3B00), R6=03
;   (patrones de sprite en 0x1800), R7=E4 (tinta 14 sobre fondo 4)
;   0x43fd..0x4405  (8 bytes)
DATA_registros_del_vdp:
	defb 002h,0e2h,00eh,07fh,007h,076h,003h,0e4h	; 43fd  .....v..

; ======================================================================
; CODIGO 0x4405..0x4446  (65 bytes)
; ======================================================================


PON_COLOR_DE_FONDO:		; Registro 7 del VDP con el valor de B
	ld c,007h		;4405
	jp ESCRIBE_REG_VDP		;4407

; ----------------------------------------------------------------------
; LOS MANDOS. Junta el joystick (por el PSG) y las teclas de direccion y espacio (fila 8 de la matriz) en un solo byte: bits 0-3 direcciones, bit 4 disparo, bit 5 espacio. Se lee entero cada fotograma, y 0xE008 guarda el de antes para saber que se acaba de pulsar.
; ----------------------------------------------------------------------
LEE_MANDOS:		; Deja en 0xE009 lo que hay pulsado y en 0xE008 lo que se acaba de pulsar
	call LEE_MANDOS_CRUDO		;440a
	ld hl,0e009h		;440d
MANDOS_FLANCOS:		; 0xE008 = lo que esta pulsado ahora y no lo estaba antes
	ld c,(hl)			;4410   ; lo que estaba pulsado en el fotograma anterior
	ld (hl),a			;4411   ; 0xE009 se queda con lo de ahora
	xor c			;4412   ; lo que ha cambiado
	and (hl)			;4413   ; y de eso, solo lo que se acaba de pulsar
	dec hl			;4414
	ld (hl),a			;4415
	ret			;4416
LEE_MANDOS_CRUDO:		; Joystick 1 del PSG mas la fila 8 del teclado
	ld e,08fh		;4417   ; registro 15 del PSG: selecciona el puerto del joystick 1
	ld a,00fh		;4419
	call 00093h		;441b   ; BIOS WRTPSG - Writes data to PSG-register
	ld a,00eh		;441e   ; registro 14: lee las seis lineas del joystick
	call 00096h		;4420   ; BIOS RDPSG - Reads value from PSG-register
	cpl			;4423
	and 03fh		;4424
	push af			;4426
	ld e,000h		;4427
	ld a,008h		;4429
	call 00141h		;442b   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix | fila 8 de la matriz: flechas, espacio y las dos teclas de disparo
	cpl			;442e
	rrca			;442f
	rrca			;4430
	ld b,a			;4431
	and 004h		;4432
	or e			;4434
	ld c,a			;4435
	ld a,b			;4436
	rrca			;4437
	rrca			;4438
	ld b,a			;4439
	and 018h		;443a
	or c			;443c
	ld c,a			;443d
	ld a,b			;443e
	rrca			;443f
	and 003h		;4440
	or c			;4442
	pop bc			;4443
	or b			;4444
	ret			;4445

; ----------------------------------------------------------------------
; DATOS rotulo_software: Para 0x43AE: la barra de doce caracteres 0x5A en la
;   fila 10 y "SOFTWARE" en la 11, comprimidos
;   0x4446..0x4457  (17 bytes)
DATA_rotulo_software:
	defb 04ah,039h,00ch,05ah,080h,06ch,039h,088h,033h,02fh,026h,034h,037h,021h,032h,025h	; 4446  J9.Z.l9.3/&47!2%
	defb 000h	; 4456

; ----------------------------------------------------------------------
; DATOS rotulo_marcadores: Para 0x4393: "HISCORE", "SCORE" y "REST" con sus
;   ceros, en las columnas 24 y siguientes del panel
;   0x4457..0x4488  (49 bytes)
DATA_rotulo_marcadores:
	defb 038h,038h,028h,029h,033h,023h,02fh,032h,025h,0feh,05eh,038h,010h,0feh,098h,038h	; 4457  88()3#/2%.^8...8
	defb 033h,023h,02fh,032h,025h,0feh,0beh,038h,010h,0feh,0f8h,038h,032h,025h,033h,034h	; 4467  3#/2%..8...82%34
	defb 0feh,079h,039h,008h,008h,007h,008h,008h,0feh,059h,03ah,008h,008h,006h,008h,008h	; 4477  .y9......Y:.....
	defb 0ffh	; 4487

; ----------------------------------------------------------------------
; DATOS rotulo_konami_arriba: Para 0x4393: el simbolo de copyright y "KONAMI"
;   en la fila 21, "1985" en la 22
;   0x4488..0x4499  (17 bytes)
DATA_rotulo_konami_arriba:
	defb 0b8h,03ah,01ah,02bh,02fh,02eh,021h,02dh,029h,0feh,0dbh,03ah,011h,019h,018h,015h	; 4488  .:.+/.!-)..:....
	defb 0ffh	; 4498

; ----------------------------------------------------------------------
; DATOS rotulo_pulsa_espacio: Para 0x4393: copyright, "KONAMI 1985" en la fila
;   10 y "PUSH SPACE KEY" en la 17
;   0x4499..0x44b9  (32 bytes)
DATA_rotulo_pulsa_espacio:
	defb 04ah,039h,01ah,02bh,02fh,02eh,021h,02dh,029h,000h,011h,019h,018h,015h,0feh,029h	; 4499  J9.+/.!-)......)
	defb 03ah,030h,035h,033h,028h,000h,033h,030h,021h,023h,025h,000h,02bh,025h,039h,0ffh	; 44a9  :053(.30!#%.+%9.

; ----------------------------------------------------------------------
; DATOS rotulo_empieza_partida: Para 0x4393: "  GAME START  " en la fila 17,
;   encima del anterior
;   0x44b9..0x44ca  (17 bytes)
DATA_rotulo_empieza_partida:
	defb 029h,03ah,000h,000h,027h,021h,02dh,025h,000h,033h,034h,021h,032h,034h,000h,000h	; 44b9  ):..'!-%.34!24..
	defb 0ffh	; 44c9

; ----------------------------------------------------------------------
; DATOS rotulo_fin_de_partida: Para 0x4393: "GAME OVER" en la fila 11
;   0x44ca..0x44d6  (12 bytes)
DATA_rotulo_fin_de_partida:
	defb 068h,039h,027h,021h,02dh,025h,000h,02fh,036h,025h,032h,0ffh	; 44ca  h9'!-%./6%2.

; ======================================================================
; CODIGO 0x44d6..0x4520  (74 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LOS CARACTERES FIJOS. El marco del panel, la fuente y el suelo, cargados en los tres tercios.
; ----------------------------------------------------------------------
CARGA_CARACTERES:		; La fuente en 0x2080, el marco del panel y su color
	ld de,045d8h		;44d6   ; los 42 caracteres de la fuente, del 0x10 al 0x39
	ld hl,02080h		;44d9
	call RLE_TRES_TERCIOS		;44dc
	ld a,0f0h		;44df   ; color 0xF0 -blanco sobre transparente- para los caracteres 0x00 a 0x3A
	ld hl,00000h		;44e1
	ld bc,001d8h		;44e4
	call RELLENA_TRES_TERCIOS		;44e7
	ld hl,02020h		;44ea   ; los cinco caracteres del marco del panel, del 0x04 al 0x08
	ld de,04596h		;44ed
	call RLE_TRES_TERCIOS		;44f0
	ld de,045b2h		;44f3   ; y la tabla de color de esos caracteres
	ld hl,00018h		;44f6
	jp RLE_TRES_TERCIOS		;44f9
CARGA_SUELO:		; Descomprime en el caracter 0x09 el suelo que le toca a la pantalla
	ld a,(0e132h)		;44fc
	ld hl,04520h		;44ff
	call SUMA_A_HL		;4502
	ld a,(hl)			;4505
	add a,a			;4506
	add a,a			;4507
	ld hl,04532h		;4508
	call LEE_PALABRA		;450b
	inc hl			;450e
	push hl			;450f
	ld hl,02048h		;4510   ; patrones en 0x2048 (caracter 0x09) de los tres tercios
	call RLE_TRES_TERCIOS		;4513
	pop hl			;4516
	ld e,(hl)			;4517
	inc hl			;4518
	ld d,(hl)			;4519
	ld hl,00048h		;451a   ; y el color en 0x0048
	jp RLE_TRES_TERCIOS		;451d

; ----------------------------------------------------------------------
; DATOS suelo_por_pantalla: Cual de las siete parejas de 0x4532 lleva cada una
;   de las 18 pantallas del mundo (indice 0xE132)
;   0x4520..0x4532  (18 bytes)
DATA_suelo_por_pantalla:
	defb 000h,003h,001h,005h,002h,004h,006h,001h,000h,000h,005h,003h,001h,004h,006h,002h,004h,000h	; 4520  ..................

; ----------------------------------------------------------------------
; DATOS tabla_de_suelos: Siete parejas (patrones, color) para el caracter
;   0x09, que es el suelo. 0x44FC las descomprime en 0x2048 y 0x0048, en los
;   tres tercios
;   0x4532..0x454e  (28 bytes)
DATA_tabla_de_suelos:
	defw 0454eh,04576h	; 4532  -> DATA_suelo_patron_0 DATA_suelo_color_0
	defw 04558h,04580h	; 4536  -> DATA_suelo_patron_1 DATA_suelo_color_1
	defw 04558h,04585h	; 453a  -> DATA_suelo_patron_1 DATA_suelo_color_2
	defw 04562h,0458ah	; 453e  -> DATA_suelo_patron_2 DATA_suelo_color_3
	defw 04562h,0458dh	; 4542  -> DATA_suelo_patron_2 DATA_suelo_color_4
	defw 0456ch,04590h	; 4546  -> DATA_suelo_patron_3 DATA_suelo_color_5
	defw 0456ch,04593h	; 454a  -> DATA_suelo_patron_3 DATA_suelo_color_6

; ----------------------------------------------------------------------
; DATOS suelo_patron_0: Patrones del suelo, tipo 0 (8 bytes = un caracter),
;   RLE de 0x43B4
;   0x454e..0x4558  (10 bytes)
DATA_suelo_patron_0:
	defb 088h,000h,03ch,07eh,018h,07eh,0d7h,076h,018h,000h	; 454e  ..<~.~.v..

; ----------------------------------------------------------------------
; DATOS suelo_patron_1: Patrones del suelo, tipo 1
;   0x4558..0x4562  (10 bytes)
DATA_suelo_patron_1:
	defb 088h,03ch,07eh,07eh,0ffh,0ffh,072h,018h,018h,000h	; 4558  .<~~..r...

; ----------------------------------------------------------------------
; DATOS suelo_patron_2: Patrones del suelo, tipo 2
;   0x4562..0x456c  (10 bytes)
DATA_suelo_patron_2:
	defb 088h,004h,095h,05ah,034h,0d9h,03ah,01ch,018h,000h	; 4562  ...Z4.:...

; ----------------------------------------------------------------------
; DATOS suelo_patron_3: Patrones del suelo, tipo 3
;   0x456c..0x4576  (10 bytes)
DATA_suelo_patron_3:
	defb 088h,01eh,03fh,013h,03fh,07eh,01eh,07eh,07ch,000h	; 456c  ..?.?~.~|.

; ----------------------------------------------------------------------
; DATOS suelo_color_0: Color del suelo, entrada 0
;   0x4576..0x4580  (10 bytes)
DATA_suelo_color_0:
	defb 088h,061h,061h,061h,0f6h,061h,0c1h,0c1h,0c1h,000h	; 4576  .aaa.a....

; ----------------------------------------------------------------------
; DATOS suelo_color_1: Color del suelo, entrada 1
;   0x4580..0x4585  (5 bytes)
DATA_suelo_color_1:
	defb 006h,0c1h,002h,061h,000h	; 4580

; ----------------------------------------------------------------------
; DATOS suelo_color_2: Color del suelo, entrada 2
;   0x4585..0x458a  (5 bytes)
DATA_suelo_color_2:
	defb 006h,041h,002h,061h,000h	; 4585

; ----------------------------------------------------------------------
; DATOS suelo_color_3: Color del suelo, entrada 3
;   0x458a..0x458d  (3 bytes)
DATA_suelo_color_3:
	defb 008h,051h,000h	; 458a

; ----------------------------------------------------------------------
; DATOS suelo_color_4: Color del suelo, entrada 4
;   0x458d..0x4590  (3 bytes)
DATA_suelo_color_4:
	defb 008h,091h,000h	; 458d

; ----------------------------------------------------------------------
; DATOS suelo_color_5: Color del suelo, entrada 5
;   0x4590..0x4593  (3 bytes)
DATA_suelo_color_5:
	defb 008h,081h,000h	; 4590

; ----------------------------------------------------------------------
; DATOS suelo_color_6: Color del suelo, entrada 6
;   0x4593..0x4596  (3 bytes)
DATA_suelo_color_6:
	defb 008h,021h,000h	; 4593

; ----------------------------------------------------------------------
; DATOS patrones_del_panel: 40 bytes (cinco caracteres, del 0x04 al 0x08) a la
;   VRAM 0x2020 en los tres tercios: los trozos del marco del panel derecho
;   0x4596..0x45b2  (28 bytes)
DATA_patrones_del_panel:
	defb 010h,00fh,098h,000h,03ch,07eh,0ffh,07eh,04ah,04ah,07eh,038h,07ch,0feh,0feh,0feh	; 4596  ....<~.~JJ~8|...
	defb 07ch,038h,000h,006h,00fh,006h,070h,0dah,0ech,078h,02ah,000h	; 45a6  |8....p..x*.

; ----------------------------------------------------------------------
; DATOS colores_del_panel: 48 bytes (los caracteres 0x03 a 0x08) a la VRAM
;   0x0018 en los tres tercios
;   0x45b2..0x45d8  (38 bytes)
DATA_colores_del_panel:
	defb 098h,077h,055h,077h,055h,077h,055h,077h,055h,071h,051h,071h,051h,071h,051h,071h	; 45b2  .wUwUwUwUqQqQqQq
	defb 051h,017h,015h,017h,015h,017h,015h,017h,015h,004h,061h,004h,0f1h,008h,071h,005h	; 45c2  Q.........a...q.
	defb 081h,083h,08ch,081h,0c1h,000h	; 45d2

; ----------------------------------------------------------------------
; DATOS fuente: 264 bytes comprimidos que dan los 336 de la VRAM 0x2080: los
;   42 caracteres del 0x10 al 0x39, o sea las diez cifras y las veintiseis
;   letras. La 'A' es el 0x21 y el 0 el 0x10, asi que un texto se lee restando
;   0x20 a las letras
;   0x45d8..0x46e0  (264 bytes)
DATA_fuente:
	defb 08bh,000h,01ch,022h,063h,063h,063h,022h,01ch,000h,018h,038h,004h,018h,0c9h,07eh	; 45d8  ..."ccc"...8...~
	defb 000h,03eh,063h,003h,00eh,03ch,070h,07fh,000h,03eh,063h,003h,00eh,003h,063h,03eh	; 45e8  .>c..<p..>c...c>
	defb 000h,00eh,01eh,036h,066h,066h,07fh,006h,000h,07fh,060h,07eh,063h,003h,063h,03eh	; 45f8  ...6ff....`~c.c>
	defb 000h,03eh,063h,060h,07eh,063h,063h,03eh,000h,07fh,063h,006h,00ch,018h,018h,018h	; 4608  .>c`~cc>..c.....
	defb 000h,03eh,063h,063h,03eh,063h,063h,03eh,000h,03eh,063h,063h,03fh,003h,063h,03eh	; 4618  .>cc>cc>.>cc?.c>
	defb 03ch,042h,099h,0a1h,0a1h,099h,042h,03ch,028h,000h,004h,000h,001h,07eh,004h,000h	; 4628  <B....B<(....~..
	defb 0c1h,01ch,036h,063h,063h,07fh,063h,063h,000h,07eh,063h,063h,07eh,063h,063h,07eh	; 4638  ..6cc.cc.~cc~cc~
	defb 000h,03eh,063h,060h,060h,060h,063h,03eh,000h,07ch,066h,063h,063h,063h,066h,07ch	; 4648  .>c```c>.|fcccf|
	defb 000h,07fh,060h,060h,07eh,060h,060h,07fh,000h,07fh,060h,060h,07eh,060h,060h,060h	; 4658  ..``~``...``~```
	defb 000h,03eh,063h,060h,067h,063h,063h,03fh,000h,063h,063h,063h,07fh,063h,063h,063h	; 4668  .>c`gcc?.ccc.ccc
	defb 000h,03ch,005h,018h,009h,03ch,089h,000h,063h,066h,06ch,078h,07ch,06eh,067h,000h	; 4678  .<...<..cflx|ng.
	defb 006h,060h,093h,07fh,000h,063h,077h,07fh,07fh,06bh,063h,063h,000h,063h,073h,07bh	; 4688  .`...cw..kcc.cs{
	defb 07fh,06fh,067h,063h,000h,03eh,005h,063h,089h,03eh,000h,07eh,063h,063h,063h,07eh	; 4698  .ogc.>.c.>.~ccc~
	defb 060h,060h,009h,000h,091h,07eh,063h,063h,062h,07ch,066h,063h,000h,03eh,063h,060h	; 46a8  ``...~ccb|fc.>c`
	defb 03eh,003h,063h,03eh,000h,07eh,006h,018h,001h,000h,006h,063h,082h,03eh,000h,004h	; 46b8  >.c>.~.....c.>..
	defb 063h,08bh,036h,01ch,008h,000h,063h,063h,06bh,06bh,07fh,077h,022h,009h,000h,087h	; 46c8  c.6...cckk.w"...
	defb 066h,066h,07eh,03ch,018h,018h,018h,000h	; 46d8  ff~<....

; ======================================================================
; CODIGO 0x46e0..0x4731  (81 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL LOGOTIPO DE KONAMI QUE SUBE. Los caracteres del logotipo se pintan en las filas 21-23 y luego se van subiendo de tres en tres filas.
; ----------------------------------------------------------------------
PREPARA_LOGOTIPO:		; Catorce tandas por subir, y los caracteres del logotipo a la VRAM
	ld a,00eh		;46e0   ; catorce tandas de tres filas por subir
	ld (0e00ah),a		;46e2
	ld hl,03aaah		;46e5   ; 0x3AAA: las filas 21 a 23 de la tabla de nombres, abajo del todo
	ld (0e00eh),hl		;46e8
	ld de,04731h		;46eb
	ld hl,06200h		;46ee   ; los 27 caracteres del logotipo, desde el 0x40
	call RLE_TRES_TERCIOS		;46f1
	ld hl,00200h		;46f4   ; y su color: 0xF0, blanco sobre transparente
	ld bc,000d8h		;46f7
	ld a,0f0h		;46fa
	jp RELLENA_TRES_TERCIOS		;46fc
SUBE_LOGOTIPO:		; Repinta el logotipo una fila mas arriba y borra la de abajo
	ld hl,(0e00eh)		;46ff
	ld de,0ffe0h		;4702   ; una fila menos: -0x20 en la tabla de nombres
	add hl,de			;4705
	ld (0e00eh),hl		;4706
	ld a,040h		;4709
	ld b,003h		;470b
	call PINTA_TIRA		;470d
	ld bc,00b0ch		;4710
	call PINTA_TIRA		;4713
	ld b,c			;4716
	call PINTA_TIRA		;4717
	xor a			;471a
	call 00056h		;471b   ; BIOS FILVRM - Fills VRAM with value
	ld hl,0e00ah		;471e
	dec (hl)			;4721
	ret			;4722
PINTA_TIRA:		; B caracteres consecutivos desde A, y HL a la fila siguiente
	push hl			;4723
PINTA_TIRA_BUCLE:
	call 0004dh		;4724   ; BIOS WRTVRM - Writes data in VRAM
	inc hl			;4727
	inc a			;4728
	djnz PINTA_TIRA_BUCLE		;4729
	pop de			;472b
	ld hl,00020h		;472c
	add hl,de			;472f
	ret			;4730

; ----------------------------------------------------------------------
; DATOS patrones_del_logotipo: 151 bytes comprimidos que dan los 216 de la
;   VRAM 0x2200 (27 caracteres desde el 0x40, en los tres tercios): el
;   logotipo de KONAMI que sube al arrancar
;   0x4731..0x47c8  (151 bytes)
DATA_patrones_del_logotipo:
	defb 00fh,000h,001h,001h,006h,000h,082h,0ffh,0feh,008h,00fh,084h,0c3h,0c7h,0cfh,0dfh	; 4731  ................
	defb 003h,0ffh,089h,0feh,0fch,0f8h,0f0h,0e0h,0c0h,080h,007h,007h,005h,000h,083h,003h	; 4741  ................
	defb 0cfh,0dfh,005h,000h,083h,0e1h,0f9h,07dh,005h,000h,083h,0efh,0ffh,0f7h,005h,000h	; 4751  .......}........
	defb 083h,007h,08fh,09eh,005h,000h,083h,0f0h,0f8h,078h,005h,000h,083h,0f7h,0ffh,0fbh	; 4761  .........x......
	defb 005h,000h,08bh,08fh,0dfh,0f7h,00ch,01eh,01eh,00ch,000h,01eh,09eh,09eh,008h,00fh	; 4771  ................
	defb 090h,0ffh,0ffh,0dfh,0cfh,0c7h,0c3h,0c1h,0c0h,007h,087h,0c7h,0efh,0ffh,0ffh,0ffh	; 4781  ................
	defb 0fch,004h,0deh,084h,09eh,09fh,00fh,003h,005h,03dh,083h,07dh,0f9h,0e1h,008h,0e3h	; 4791  .........=.}....
	defb 090h,0dch,0c0h,0c7h,0deh,0dch,0deh,0cfh,0c3h,03ch,07ch,0fch,03ch,03ch,07ch,0fch	; 47a1  .........<|.<<|.
	defb 0deh,008h,0f1h,008h,0e3h,008h,0deh,088h,038h,044h,0bah,0aah,0b2h,0aah,044h,038h	; 47b1  ........8D....D8
	defb 003h,000h,001h,0ffh,004h,000h,000h	; 47c1

; ======================================================================
; CODIGO 0x47c8..0x47e8  (32 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LA PANTALLA DE TITULO.
; ----------------------------------------------------------------------
PINTA_TITULO:		; Fondo negro, pantalla limpia, caracteres y el dibujo grande de PIPPOLS
	ld b,0e0h		;47c8   ; registro 7 a 0xE0: tinta 14 sobre fondo negro
	call PON_COLOR_DE_FONDO		;47ca
	call BORRA_PANTALLA		;47cd
	call CARGA_CARACTERES		;47d0
	ld de,0481ah		;47d3   ; el dibujo grande de PIPPOLS
	jp RLE_CON_DIRECCION		;47d6
PINTA_TITULO_Y_ROTULOS:		; El titulo mas "KONAMI 1985" y "PUSH SPACE KEY"
	call PINTA_TITULO		;47d9
	ld de,047e8h		;47dc
	call ESCRIBE_ROTULO		;47df
	ld de,04499h		;47e2
	jp ESCRIBE_ROTULO		;47e5

; ----------------------------------------------------------------------
; DATOS nombres_del_logotipo: Para 0x4393: los cuatro renglones de caracteres
;   (0xC0 a 0xD9) que forman el rotulo PIPPOLS en las filas 4 a 7, columnas 10
;   a 21. Lo escribe 0x47DC en cuanto 0x47C8 ha subido el dibujo a la VRAM
;   0x47e8..0x481a  (50 bytes)
DATA_nombres_del_logotipo:
	defb 091h,038h,0c1h,0c2h,0feh,0aah,038h,0c4h,0c5h,0c6h,0c4h,0c5h,0c4h,0c5h,0c0h,0c3h	; 47e8  .8....8.........
	defb 0c7h,0c8h,0c9h,0feh,0cah,038h,0cah,0cbh,0cch,0cah,0cbh,0cah,0cbh,0cdh,0ceh,0cfh	; 47f8  .....8..........
	defb 0d0h,0d1h,0feh,0eah,038h,0d2h,0d3h,0d4h,0d2h,0d3h,0d2h,0d3h,0d5h,0d6h,0d7h,0d8h	; 4808  ....8...........
	defb 0d9h,0ffh	; 4818

; ----------------------------------------------------------------------
; DATOS titulo_pippols: 207 bytes comprimidos: la cabecera manda los patrones
;   a la VRAM 0x2600 y el color a 0x0600, o sea los caracteres 0xC0 en
;   adelante del PRIMER tercio, que es donde caen las filas 4 a 7. Es el
;   dibujo grande del rotulo PIPPOLS
;   0x481a..0x48e9  (207 bytes)
DATA_titulo_pippols:
	defb 000h,066h,088h,00fh,08fh,0fch,03fh,00eh,00fh,03fh,00eh,005h,000h,083h,01eh,03fh	; 481a  .f....?..?.....?
	defb 02fh,006h,000h,08ah,081h,0e6h,0dch,0b8h,070h,0f0h,0e0h,0c0h,0f8h,03ch,003h,000h	; 482a  /.......p....<..
	defb 085h,004h,00ch,03fh,0fch,03ch,003h,000h,085h,030h,0f8h,0fch,03eh,01eh,003h,000h	; 483a  ...?.<...0..>...
	defb 085h,004h,00eh,01eh,07eh,01eh,003h,000h,085h,008h,01ch,03ch,0fch,03ch,005h,000h	; 484a  ....~......<.<..
	defb 083h,001h,003h,006h,004h,000h,084h,07eh,0ffh,00fh,006h,006h,03ch,08ah,03eh,03fh	; 485a  .......~....<.>?
	defb 01fh,00fh,00fh,00eh,00eh,01ch,038h,0e0h,005h,01eh,087h,01ch,03ch,03ch,018h,030h	; 486a  ......8.....<<.0
	defb 070h,060h,004h,0e0h,083h,01eh,00eh,00fh,005h,007h,008h,03ch,091h,006h,00eh,00fh	; 487a  p`.........<....
	defb 00fh,007h,007h,003h,000h,004h,008h,000h,0c0h,0f0h,0fch,0feh,07fh,03fh,003h,03ch	; 488a  .............?.<
	defb 085h,038h,03fh,03fh,07eh,080h,003h,000h,084h,040h,080h,000h,000h,004h,03ch,099h	; 489a  .8??~....@....<.
	defb 03dh,03eh,01ch,008h,0e0h,0f0h,0f0h,078h,07eh,03fh,01fh,007h,007h,006h,00eh,00ch	; 48aa  =>.....x~?......
	defb 038h,0f0h,0c0h,001h,038h,078h,078h,070h,070h,003h,0ffh,090h,001h,002h,006h,02eh	; 48ba  8...8xxpp.......
	defb 0cfh,0cfh,087h,003h,00fh,007h,007h,006h,00ch,0f8h,0f0h,0c0h,080h,000h,046h,002h	; 48ca  ..............F.
	defb 0f0h,086h,08fh,080h,080h,0f0h,0f0h,020h,016h,0f0h,07fh,020h,033h,020h,000h	; 48da  ....... ... 3 .

; ======================================================================
; CODIGO 0x48e9..0x4ac9  (480 bytes)
; ======================================================================


PIDE_SONIDO_EN_PARTIDA:		; Como PIDE_SONIDO, pero solo si hay partida de verdad (bit 6 de 0xE002)
	di			;48e9
	push hl			;48ea
	ld hl,0e002h		;48eb
	bit 6,(hl)		;48ee   ; bit 6 de 0xE002: solo suena si hay partida de verdad
	jr z,PIDE_SONIDO_SALIDA		;48f0
	jr PIDE_SONIDO_GUARDA		;48f2
PIDE_SONIDO:		; Arranca el sonido numero A, guardando los registros
	di			;48f4
	push hl			;48f5
PIDE_SONIDO_GUARDA:
	push de			;48f6   ; se guardan todos los registros, porque lo llama cualquiera
	push bc			;48f7
	push af			;48f8
	call ARRANCA_SONIDO		;48f9
	pop af			;48fc
	pop bc			;48fd
	pop de			;48fe
PIDE_SONIDO_SALIDA:
	pop hl			;48ff
	ei			;4900
	ret			;4901
ARRANCA_SONIDO:		; Reparte la pista del sonido A entre uno, dos o tres canales
	ld c,a			;4902
	and 03fh		;4903   ; el numero pelado, sin los bits de arriba
	ld b,002h		;4905
	ld hl,0e012h		;4907
	cp 007h		;490a   ; menos de 7: un solo canal, el C, que es el de los efectos
	jr c,ARRANCA_UN_CANAL		;490c
	cp 00fh		;490e   ; de 7 a 14: dos canales
	jr c,ARRANCA_COMPARA		;4910
	inc b			;4912   ; de 15 en adelante: los tres
	jr ARRANCA_COMPARA		;4913
ARRANCA_UN_CANAL:		; Un solo canal: el C, en 0xE02E
	dec b			;4915
	ld hl,0e02eh		;4916
ARRANCA_COMPARA:
	ld a,(hl)			;4919
	and 03fh		;491a
	ld e,a			;491c
	ld a,c			;491d   ; el sonido que ya suena en ese canal
	and 03fh		;491e
	cp e			;4920   ; si el que suena vale mas, no se le quita el sitio
	ret c			;4921
	ret z			;4922
	add a,a			;4923
	ld de,04ad6h		;4924   ; la tabla de pistas; el numero de sonido es el indice
	call SUMA_A_DE		;4927
	dec hl			;492a
	dec hl			;492b
ARRANCA_CANAL:		; Deja el canal listo: nota en 1 para que suene ya, y el puntero de la pista
	ld (hl),001h		;492c   ; +0 y +1 a 1: la primera nota entra en el fotograma siguiente
	inc hl			;492e
	ld (hl),001h		;492f
	inc hl			;4931
	ld (hl),c			;4932   ; +2 el numero de sonido, que es el que decide quien manda
	inc hl			;4933
	ld a,(de)			;4934   ; +3/+4 el puntero a la pista, sacado de la tabla
	ld (hl),a			;4935
	inc hl			;4936
	inc de			;4937
	ld a,(de)			;4938
	ld (hl),a			;4939
	ld a,005h		;493a   ; 5 bytes al siguiente campo del canal
	call SUMA_A_HL		;493c
	xor a			;493f   ; +9 a cero: aun no se ha dado ninguna vuelta al bucle
	ld (hl),a			;4940
	ld a,005h		;4941   ; y otros 5 hasta el principio del canal siguiente
	call SUMA_A_HL		;4943
	inc de			;4946   ; la tabla lleva una direccion por canal
	djnz ARRANCA_CANAL		;4947
	ld a,(0e012h)		;4949   ; el 0x89 se queda sin el bit 7 en cuanto arranca
	cp 089h		;494c
	ret nz			;494e
	res 7,a		;494f
	ld (0e012h),a		;4951
	ret			;4954
PISTA_FIN:		; Final de la pista: o vuelve al principio del bucle o para
	inc hl			;4955
	ld a,(ix+009h)		;4956   ; +9 cuenta las vueltas dadas
	inc a			;4959
	cp (hl)			;495a
	jr z,PISTA_ULTIMA_VUELTA		;495b
	jp m,PISTA_SALTA		;495d
	dec a			;4960
PISTA_SALTA:		; Apunta el puntero de la pista al destino del salto
	ld (ix+009h),a		;4961   ; +9 se queda con la vuelta por la que va
	inc hl			;4964   ; detras de la cuenta de vueltas van los dos bytes del destino
	ld a,(hl)			;4965
	ld (ix+003h),a		;4966
	inc hl			;4969
	ld a,(hl)			;496a
	ld (ix+004h),a		;496b
	jr PISTA_SIGUE		;496e
PISTA_ULTIMA_VUELTA:		; Se acabaron las vueltas: sigue detras del salto
	inc hl			;4970
	inc hl			;4971
	xor a			;4972
	ld (ix+009h),a		;4973
	call GUARDA_PUNTERO_PISTA		;4976
PISTA_SIGUE:
	inc (ix+000h)		;4979
	jr PASO_DE_CANAL		;497c
ESCRIBE_MEZCLA:		; Registro 7 del PSG (que canales suenan y cuales llevan ruido)
	ld (0e03ah),a		;497e
	ld e,a			;4981
	ld a,007h		;4982
	jp 00093h		;4984   ; BIOS WRTPSG - Writes data to PSG-register
PASO_DE_SONIDO:		; Un paso de los tres canales; lo llama la interrupcion
	ld a,(0e03ah)		;4987   ; vuelve a poner la mezcla por si la BIOS la ha tocado
	call ESCRIBE_MEZCLA		;498a
	ld c,001h		;498d
	ld ix,0e010h		;498f   ; el primer canal
	exx			;4993
	ld b,003h		;4994
	ld de,0000eh		;4996   ; 14 bytes de un canal al siguiente
SONIDO_CANAL:
	exx			;4999
	ld a,(ix+002h)		;499a   ; si el canal no tiene sonido, no hay nada que hacer
	or a			;499d
	call nz,PASO_DE_CANAL		;499e
	inc c			;49a1   ; dos registros del PSG por canal
	inc c			;49a2
	exx			;49a3
	add ix,de		;49a4
	djnz SONIDO_CANAL		;49a6
	ret			;49a8
PASO_DE_CANAL:		; Un paso del canal al que apunta IX
	bit 7,(ix+002h)		;49a9   ; bit 7: la pista lleva mandos de efecto
	jr nz,PASO_CON_EFECTOS		;49ad
	dec (ix+000h)		;49af   ; mientras la nota no se acabe, no se lee la pista
	ret nz			;49b2
LEE_PISTA:		; Lee el siguiente byte de la pista
	ld l,(ix+003h)		;49b3
	ld h,(ix+004h)		;49b6
	ld a,(hl)			;49b9
	cp 0feh		;49ba   ; 0xFE: fin o salto
	jp z,PISTA_FIN		;49bc
	jr nc,PISTA_CALLA		;49bf   ; 0xFF: callar el canal
	bit 7,(ix+002h)		;49c1
	jp nz,PISTA_MANDOS		;49c5
	and 0f0h		;49c8
	cp 020h		;49ca   ; 0x2n: cambia la duracion de la nota
	ld a,(hl)			;49cc
	jr nz,PISTA_NOTA		;49cd
	and 00fh		;49cf
	ld (ix+001h),a		;49d1
	inc hl			;49d4
	ld a,(hl)			;49d5
PISTA_NOTA:
	and 0f0h		;49d6   ; en las pistas sin efectos el nibble alto es el volumen de la nota
	ld b,a			;49d8
	xor (hl)			;49d9   ; el nibble bajo es el byte alto del periodo
	ld d,a			;49da
	inc hl			;49db
	ld e,(hl)			;49dc   ; y el byte siguiente el bajo: 12 bits de periodo
	call GUARDA_PUNTERO_PISTA		;49dd
	ex de,hl			;49e0
	call ESCRIBE_PERIODO		;49e1
	ld a,b			;49e4   ; el nibble alto, ya suelto, es el volumen
	rrca			;49e5
	rrca			;49e6
	rrca			;49e7
	rrca			;49e8
PISTA_ARRANCA_NOTA:		; Pone la duracion y el volumen de arranque
	ld h,a			;49e9
	ld e,(ix+001h)		;49ea   ; +1 es la duracion, la que dejo el mando 0x2n
	ld (ix+000h),e		;49ed
	ld a,(ix+00ch)		;49f0   ; +C dice cuanto se adelanta la cuenta del apagado
	add a,e			;49f3
	ld (ix+008h),a		;49f4
	jr ESCRIBE_VOLUMEN		;49f7
PISTA_CALLA:		; Deja el canal mudo
	xor a			;49f9
	ld (ix+00bh),a		;49fa
	ld (ix+002h),a		;49fd
	ld h,a			;4a00
	jr ESCRIBE_VOLUMEN		;4a01
PASO_CON_EFECTOS:		; Un paso de una pista con efectos: apaga el volumen segun el perfil
	dec (ix+000h)		;4a03   ; +0 baja cada fotograma; a cero se lee la pista
	jp z,LEE_PISTA		;4a06
	dec (ix+008h)		;4a09   ; +8, la cuenta del apagado, baja al doble de deprisa hasta alcanzar a +0
	ld a,(ix+008h)		;4a0c
	cp (ix+000h)		;4a0f
	jr nz,PASO_APAGA_DOBLE		;4a12
	ld e,a			;4a14
	ld a,(ix+00dh)		;4a15   ; alcanzada, el volumen solo sigue bajando mientras la cuenta no pase de +D
	cp e			;4a18
	ld a,e			;4a19
	jr nc,PASO_BAJA_VOLUMEN		;4a1a
	ret			;4a1c
PASO_APAGA_DOBLE:
	dec (ix+008h)		;4a1d
PASO_BAJA_VOLUMEN:		; Un punto menos de volumen, sin pasar de cero
	ld a,(ix+007h)		;4a20
	dec a			;4a23
	ret m			;4a24
	ld (ix+007h),a		;4a25
	ld h,a			;4a28
ESCRIBE_VOLUMEN:		; Registro 8, 9 o 10 del PSG con el volumen de H
	ld a,c			;4a29
	rrca			;4a2a
	add a,088h		;4a2b
	ld e,h			;4a2d
	jp 00093h		;4a2e   ; BIOS WRTPSG - Writes data to PSG-register
PISTA_MANDOS:		; Los mandos de las pistas con efectos: 0xDn duracion base, 0xFn perfil de apagado, 0xEn ruido u octava
	ld a,(hl)			;4a31
	and 0f0h		;4a32
	cp 0d0h		;4a34   ; 0xDn: duracion base
	ld a,(hl)			;4a36
	jr nz,PISTA_MANDO_F		;4a37
	and 00fh		;4a39
	ld (ix+00ah),a		;4a3b
	inc hl			;4a3e
	ld a,(hl)			;4a3f
PISTA_MANDO_F:
	cp 0f0h		;4a40   ; 0xFn: volumen de arranque y perfil del apagado
	jr c,PISTA_MANDO_E		;4a42
	and 00fh		;4a44
	ld (ix+006h),a		;4a46   ; +6 es el volumen con el que arranca cada nota
	inc hl			;4a49
	ld a,(hl)			;4a4a
	ld (ix+00ch),a		;4a4b   ; +C y +D, el perfil del apagado
	inc hl			;4a4e
	ld a,(hl)			;4a4f
	ld (ix+00dh),a		;4a50
	inc hl			;4a53
	ld a,(hl)			;4a54
PISTA_MANDO_E:
	cp 0e0h		;4a55   ; 0xEn: ruido (bit 3 puesto) u octava
	jr c,PISTA_DURACION		;4a57
	and 00fh		;4a59
	bit 3,a		;4a5b
	jr z,PISTA_OCTAVA		;4a5d
	ld (ix+00bh),a		;4a5f
	inc hl			;4a62
	jr PISTA_MANDOS		;4a63
PISTA_OCTAVA:
	ld (ix+005h),a		;4a65
	inc hl			;4a68
	ld a,(hl)			;4a69
PISTA_DURACION:		; La duracion sale de multiplicar la base por el nibble
	and 00fh		;4a6a
	ld b,a			;4a6c
	ld a,(ix+00ah)		;4a6d
	jr z,PISTA_TOCA_NOTA		;4a70
PISTA_DURACION_MULT:
	add a,(ix+00ah)		;4a72
	djnz PISTA_DURACION_MULT		;4a75
PISTA_TOCA_NOTA:		; Saca el periodo de la nota y lo escribe en el PSG
	ld (ix+001h),a		;4a77   ; +1 la duracion que acaba de calcular PISTA_DURACION
	ld a,(hl)			;4a7a
	call GUARDA_PUNTERO_PISTA		;4a7b
	and 0f0h		;4a7e   ; el nibble alto es la nota
	rrca			;4a80
	rrca			;4a81
	rrca			;4a82
	rrca			;4a83
	ld b,a			;4a84
	sub 00ch		;4a85   ; la nota 12 arranca con volumen cero: es un silencio
	jr z,PISTA_MANTIENE_VOLUMEN		;4a87
	ld a,(ix+006h)		;4a89
PISTA_MANTIENE_VOLUMEN:
	ld (ix+007h),a		;4a8c
	call PISTA_ARRANCA_NOTA		;4a8f
	bit 6,(ix+002h)		;4a92   ; bit 6 del canal: se toca tres semitonos mas grave
	ld hl,04acch		;4a96
	jr z,PISTA_PERIODO		;4a99
	ld hl,04ac9h		;4a9b
PISTA_PERIODO:
	ld a,b			;4a9e
	call SUMA_A_HL		;4a9f
	ld l,(hl)			;4aa2
	ld h,000h		;4aa3
	ld a,(ix+005h)		;4aa5   ; el registro +5 sube o baja octavas doblando el periodo
	or a			;4aa8
	jr z,ESCRIBE_PERIODO		;4aa9
	ld b,a			;4aab
PISTA_OCTAVA_BUCLE:
	add hl,hl			;4aac
	djnz PISTA_OCTAVA_BUCLE		;4aad
ESCRIBE_PERIODO:		; Escribe el periodo HL en los dos registros de tono del canal
	ld a,(ix+00bh)		;4aaf   ; +B distinto de cero: un punto de desafinacion, que es como se hace el vibrato
	or a			;4ab2
	jr z,ESCRIBE_PERIODO_PSG		;4ab3
	inc hl			;4ab5
ESCRIBE_PERIODO_PSG:
	ld a,c			;4ab6
	ld e,h			;4ab7
	call 00093h		;4ab8   ; BIOS WRTPSG - Writes data to PSG-register
	ld a,c			;4abb
	dec a			;4abc
	ld e,l			;4abd
	jp 00093h		;4abe   ; BIOS WRTPSG - Writes data to PSG-register
GUARDA_PUNTERO_PISTA:		; Deja el puntero de la pista, ya avanzado, en +3/+4
	inc hl			;4ac1
	ld (ix+003h),l		;4ac2
	ld (ix+004h),h		;4ac5
	ret			;4ac8

; ----------------------------------------------------------------------
; DATOS periodos_de_las_notas: Quince periodos del PSG, una octava y tres
;   notas de mas: 0x7F 0x78 0x71 0x6B 0x65 0x5F 0x5A 0x55 0x50 0x4C 0x47 0x43
;   0x40 0x3C 0x39. Cada uno es el anterior por 0.944, que es el semitono. La
;   nota se lee desde 0x4ACC, y desde 0x4AC9 -tres bytes antes, o sea tres
;   semitonos mas grave- cuando el canal lleva puesto el bit 6
;   0x4ac9..0x4ad8  (15 bytes)
DATA_periodos_de_las_notas:
	defb 07fh,078h,071h,06bh,065h,05fh,05ah,055h,050h,04ch,047h,043h,040h,03ch,039h	; 4ac9  .xqke_ZUPLGC@<9

; ----------------------------------------------------------------------
; DATOS tabla_de_sonidos: Las 40 pistas por numero de sonido. La lee 0x4924
;   con `de = 0x4AD6 + 2n`, asi que el sonido 1 es la primera entrada. Un
;   sonido de varios canales usa entradas consecutivas
;   0x4ad8..0x4b28  (80 bytes)
DATA_tabla_de_sonidos:
	defw 04b9dh	; 4ad8  -> DATA_pista_9D
	defw 04b83h	; 4ada  -> DATA_pista_83
	defw 04b28h	; 4adc  -> DATA_pista_28
	defw 04bach	; 4ade  -> DATA_4BAC
	defw 04bb9h	; 4ae0  -> DATA_pista_B9
	defw 04bbfh	; 4ae2  -> DATA_pista_BF
	defw 04c56h	; 4ae4  -> DATA_pista_56
	defw 04be9h	; 4ae6  -> DATA_pista_E9
	defw 04b33h	; 4ae8  -> DATA_pista_33
	defw 04b75h	; 4aea  -> DATA_pista_75
	defw 04bcdh	; 4aec  -> DATA_pista_CD
	defw 04f2fh	; 4aee  -> DATA_pista_2F
	defw 04bdch	; 4af0  -> DATA_pista_DC
	defw 04f2fh	; 4af2  -> DATA_pista_2F
	defw 04cc6h	; 4af4  -> DATA_pista_C6
	defw 04cfbh	; 4af6  -> DATA_pista_FB
	defw 04d16h	; 4af8  -> DATA_pista_16
	defw 04d3eh	; 4afa  -> DATA_pista_3E
	defw 04d78h	; 4afc  -> DATA_pista_78
	defw 04db6h	; 4afe  -> DATA_pista_B6
	defw 04dd7h	; 4b00  -> DATA_pista_D7
	defw 04dech	; 4b02  -> DATA_pista_EC
	defw 04dd6h	; 4b04  -> DATA_pista_D6
	defw 04e02h	; 4b06  -> DATA_4E02
	defw 04e1bh	; 4b08  -> DATA_pista_1B
	defw 04e31h	; 4b0a  -> DATA_pista_31
	defw 04e97h	; 4b0c  -> DATA_pista_97
	defw 04each	; 4b0e  -> DATA_4EAC
	defw 04ec1h	; 4b10  -> DATA_pista_C1
	defw 04e4bh	; 4b12  -> DATA_pista_4B
	defw 04e48h	; 4b14  -> DATA_pista_48
	defw 04e71h	; 4b16  -> DATA_pista_71
	defw 04f30h	; 4b18  -> DATA_pista_30
	defw 04f5ch	; 4b1a  -> DATA_pista_5C
	defw 04f85h	; 4b1c  -> DATA_pista_85
	defw 04ed4h	; 4b1e  -> DATA_pista_D4
	defw 04f02h	; 4b20  -> DATA_4F02
	defw 04f2fh	; 4b22  -> DATA_pista_2F
	defw 04f2fh	; 4b24  -> DATA_pista_2F
	defw 04f2fh	; 4b26  -> DATA_pista_2F

; ----------------------------------------------------------------------
; DATOS pista_28: La pista que arranca el sonido 3 (entrada 3 de la tabla de
;   0x4AD8)
;   0x4b28..0x4b33  (11 bytes)
DATA_pista_28:
	defb 0d2h,0feh,002h,002h,0e2h,070h,085h,0cbh	; 4b28  .....p..
	defb 020h,011h,0ffh	; 4b30

; ----------------------------------------------------------------------
; DATOS pista_33: La pista que arranca el sonido 9 (entrada 9 de la tabla de
;   0x4AD8)
;   0x4b33..0x4b75  (66 bytes)
DATA_pista_33:
	defb 024h,063h,080h,062h,080h,073h,080h,072h	; 4b33  $c.b.s.r
	defb 080h,083h,080h,082h,080h,093h,080h,092h	; 4b3b  ........
	defb 080h,0a3h,080h,0a2h,080h,0b3h,080h,0b2h	; 4b43  ........
	defb 080h,0c3h,080h,0c2h,080h,0d3h,080h,0d2h	; 4b4b  ........
	defb 080h,0c3h,080h,0c2h,080h,0b3h,080h,0b2h	; 4b53  ........
	defb 080h,0a3h,080h,0a2h,080h,093h,080h,092h	; 4b5b  ........
	defb 080h,083h,080h,082h,080h,073h,080h,072h	; 4b63  .....s.r
	defb 080h,063h,080h,062h,080h,053h,080h,052h	; 4b6b  .c.b.S.R
	defb 080h,0ffh	; 4b73

; ----------------------------------------------------------------------
; DATOS pista_75: La pista que arranca el sonido 10 (entrada 10 de la tabla de
;   0x4AD8)
;   0x4b75..0x4b83  (14 bytes)
DATA_pista_75:
	defb 0d4h,0fch,002h,002h,0e3h,013h,003h,033h	; 4b75  .......3
	defb 023h,0feh,002h,075h,04bh,0ffh	; 4b7d

; ----------------------------------------------------------------------
; DATOS pista_83: La pista que arranca el sonido 2 (entrada 2 de la tabla de
;   0x4AD8)
;   0x4b83..0x4b9d  (26 bytes)
DATA_pista_83:
	defb 021h,0b0h,055h,0b0h,05fh,0b0h,06bh,0b0h	; 4b83  !.U._.k.
	defb 071h,0a0h,07fh,0a0h,08fh,090h,0a0h,090h	; 4b8b  q.......
	defb 0aah,080h,0beh,080h,0d6h,080h,0e3h,080h	; 4b93  ........
	defb 0feh,0ffh	; 4b9b

; ----------------------------------------------------------------------
; DATOS pista_9D: La pista que arranca el sonido 1 (entrada 1 de la tabla de
;   0x4AD8)
;   0x4b9d..0x4bac  (15 bytes)
DATA_pista_9D:
	defb 021h,0e0h,08fh,0d0h,080h,0c0h,07fh,0b0h	; 4b9d  !.......
	defb 070h,023h,0a0h,06fh,090h,060h,0ffh	; 4ba5

; ----------------------------------------------------------------------
; DATOS pista_AC: La pista que arranca el sonido 4 (entrada 4 de la tabla de
;   0x4AD8)
;   0x4bac..0x4bb9  (13 bytes)
DATA_4BAC:
	defb 0d2h,0fdh,001h,001h,0e0h,041h,061h,0b2h	; 4bac  .....Aa.
	defb 0d1h,001h,041h,071h,0ffh	; 4bb4

; ----------------------------------------------------------------------
; DATOS pista_B9: La pista que arranca el sonido 5 (entrada 5 de la tabla de
;   0x4AD8)
;   0x4bb9..0x4bbf  (6 bytes)
DATA_pista_B9:
	defb 022h,0d0h,044h,0b0h,038h,0ffh	; 4bb9

; ----------------------------------------------------------------------
; DATOS pista_BF: La pista que arranca el sonido 6 (entrada 6 de la tabla de
;   0x4AD8)
;   0x4bbf..0x4bcd  (14 bytes)
DATA_pista_BF:
	defb 024h,0c1h,01dh,0c0h,0d5h,0c0h,0a9h,0c0h	; 4bbf  $.......
	defb 08eh,0feh,002h,0bfh,04bh,0ffh	; 4bc7

; ----------------------------------------------------------------------
; DATOS pista_CD: La pista que arranca el sonido 11 (entrada 11 de la tabla de
;   0x4AD8)
;   0x4bcd..0x4bdc  (15 bytes)
DATA_pista_CD:
	defb 021h,0c0h,017h,0c0h,030h,02fh,000h,000h	; 4bcd  !...0/..
	defb 000h,000h,0feh,0ffh,0cdh,04bh,0ffh	; 4bd5

; ----------------------------------------------------------------------
; DATOS pista_DC: La pista que arranca el sonido 13 (entrada 13 de la tabla de
;   0x4AD8)
;   0x4bdc..0x4be9  (13 bytes)
DATA_pista_DC:
	defb 021h,0c0h,017h,0c0h,030h,02fh,000h,000h	; 4bdc  !...0/..
	defb 0feh,0ffh,0dch,04bh,0ffh	; 4be4

; ----------------------------------------------------------------------
; DATOS pista_E9: La pista que arranca el sonido 8 (entrada 8 de la tabla de
;   0x4AD8)
;   0x4be9..0x4c56  (109 bytes)
DATA_pista_E9:
	defb 0d6h,0fch,004h,002h,0e1h,021h,073h,0e2h	; 4be9  .....!s.
	defb 0b1h,0e1h,023h,0e2h,071h,0b1h,091h,091h	; 4bf1  ..#.q...
	defb 090h,0b0h,0e1h,000h,0e2h,090h,0b1h,0b1h	; 4bf9  ........
	defb 0b0h,0e1h,000h,020h,0e2h,0b0h,0e1h,021h	; 4c01  ... ...!
	defb 073h,0e2h,0b1h,0e1h,023h,041h,021h,0e2h	; 4c09  s...#A!.
	defb 091h,0e1h,021h,020h,010h,0e2h,0b0h,0e1h	; 4c11  ..! ....
	defb 010h,021h,021h,021h,021h,040h,070h,0c0h	; 4c19  .!!!!@p.
	defb 040h,001h,041h,021h,0e2h,071h,0b1h,071h	; 4c21  @.A!.q.q
	defb 020h,030h,040h,050h,060h,070h,080h,090h	; 4c29   0@P`p..
	defb 0a0h,0b0h,0e1h,000h,010h,020h,010h,020h	; 4c31  ..... . 
	defb 030h,040h,070h,0c0h,040h,001h,041h,021h	; 4c39  0@p.@.A!
	defb 0e2h,071h,0b1h,071h,060h,070h,080h,090h	; 4c41  .q.q`p..
	defb 0a0h,0b0h,0e1h,000h,010h,021h,020h,000h	; 4c49  .....! .
	defb 020h,000h,020h,000h,0ffh	; 4c51

; ----------------------------------------------------------------------
; DATOS pista_56: La pista que arranca el sonido 7 (entrada 7 de la tabla de
;   0x4AD8)
;   0x4c56..0x4cc6  (112 bytes)
DATA_pista_56:
	defb 0d6h,0fch,004h,002h,0e3h,071h,0e2h,021h	; 4c56  .....q.!
	defb 0e3h,021h,0e2h,021h,0feh,002h,05ah,04ch	; 4c5e  .!.!..ZL
	defb 0e3h,061h,0e2h,021h,0e3h,021h,0e2h,021h	; 4c66  .a.!.!.!
	defb 0e3h,071h,0e2h,021h,0e3h,021h,0e2h,021h	; 4c6e  .q.!.!.!
	defb 0feh,002h,06eh,04ch,0e3h,071h,0e2h,021h	; 4c76  ..nL.q.!
	defb 0e3h,081h,0e2h,051h,0e3h,091h,0e2h,061h	; 4c7e  ...Q...a
	defb 0e3h,091h,0e2h,071h,060h,090h,060h,0e3h	; 4c86  ...q`.`.
	defb 090h,023h,001h,0e2h,001h,0e3h,041h,0e2h	; 4c8e  .#....A.
	defb 001h,0e3h,071h,0e2h,021h,0e3h,071h,0b1h	; 4c96  ..q.!.q.
	defb 021h,0e2h,001h,0e3h,021h,0e2h,001h,0e3h	; 4c9e  !...!...
	defb 021h,0b1h,021h,0b1h,001h,0e2h,001h,0e3h	; 4ca6  !.!.....
	defb 041h,0e2h,001h,0e3h,071h,0e2h,021h,0e3h	; 4cae  A...q.!.
	defb 071h,0b1h,0e3h,091h,0e2h,021h,0e3h,091h	; 4cb6  q....!..
	defb 0e2h,041h,061h,021h,0e3h,091h,021h,0ffh	; 4cbe  .Aa!..!.

; ----------------------------------------------------------------------
; DATOS pista_C6: La pista que arranca el sonido 15 (entrada 15 de la tabla de
;   0x4AD8)
;   0x4cc6..0x4cfb  (53 bytes)
DATA_pista_C6:
	defb 0d6h,0fch,004h,003h,0e1h,021h,071h,071h	; 4cc6  .....!qq
	defb 021h,001h,090h,080h,090h,070h,060h,040h	; 4cce  !....p`@
	defb 020h,040h,020h,000h,0e2h,0b1h,071h,091h	; 4cd6   @ ...q.
	defb 091h,093h,071h,0b1h,090h,0b0h,0e1h,000h	; 4cde  ..q.....
	defb 0e2h,090h,0b0h,0e1h,000h,021h,000h,020h	; 4ce6  .....!. 
	defb 040h,000h,020h,040h,060h,070h,090h,070h	; 4cee  @. @`p.p
	defb 061h,071h,0b1h,073h,0ffh	; 4cf6

; ----------------------------------------------------------------------
; DATOS pista_FB: La pista que arranca el sonido 16 (entrada 16 de la tabla de
;   0x4AD8)
;   0x4cfb..0x4d16  (27 bytes)
DATA_pista_FB:
	defb 0d6h,0fbh,004h,003h,0e2h,0c1h,021h,0feh	; 4cfb  ......!.
	defb 009h,000h,04dh,0c1h,041h,0c1h,061h,0c1h	; 4d03  ..M.A.a.
	defb 071h,0c1h,091h,0c1h,0e1h,001h,021h,021h	; 4d0b  q.....!!
	defb 0e2h,0b3h,0ffh	; 4d13

; ----------------------------------------------------------------------
; DATOS pista_16: La pista que arranca el sonido 17 (entrada 17 de la tabla de
;   0x4AD8)
;   0x4d16..0x4d3e  (40 bytes)
DATA_pista_16:
	defb 0d6h,0fbh,004h,003h,0e3h,071h,0b1h,021h	; 4d16  .....q.!
	defb 0b1h,061h,0e2h,001h,0e3h,021h,0e2h,001h	; 4d1e  .a...!..
	defb 0feh,002h,01ah,04dh,0e3h,071h,0b1h,091h	; 4d26  ...M.q..
	defb 0e2h,001h,0e3h,0b1h,0e2h,021h,001h,041h	; 4d2e  .....!.A
	defb 021h,061h,021h,091h,071h,071h,073h,0ffh	; 4d36  !a!.qqs.

; ----------------------------------------------------------------------
; DATOS pista_3E: La pista que arranca el sonido 18 (entrada 18 de la tabla de
;   0x4AD8)
;   0x4d3e..0x4d78  (58 bytes)
DATA_pista_3E:
	defb 0d6h,0fch,004h,002h,0e2h,0b0h,0c0h,0e1h	; 4d3e  ........
	defb 020h,0c2h,020h,0c0h,000h,0c0h,040h,0c2h	; 4d46   . ...@.
	defb 070h,0c0h,060h,0c0h,020h,0c0h,020h,040h	; 4d4e  p.`. . @
	defb 060h,0c0h,070h,0c0h,020h,0c0h,0e2h,073h	; 4d56  `.p. ..s
	defb 0b0h,0c0h,0e1h,020h,0c2h,0e2h,0b0h,0c0h	; 4d5e  ... ....
	defb 0e1h,000h,0c0h,040h,0c2h,070h,0c0h,0b0h	; 4d66  ...@.p..
	defb 0c0h,070h,0c0h,090h,0c0h,040h,060h,075h	; 4d6e  .p...@`u
	defb 0c1h,0ffh	; 4d76

; ----------------------------------------------------------------------
; DATOS pista_78: La pista que arranca el sonido 19 (entrada 19 de la tabla de
;   0x4AD8)
;   0x4d78..0x4db6  (62 bytes)
DATA_pista_78:
	defb 0d6h,0fch,004h,002h,0e3h,071h,0b0h,0c0h	; 4d78  .....q..
	defb 0b0h,0c0h,0b0h,0c0h,0e2h,001h,040h,0c0h	; 4d80  ......@.
	defb 040h,0c0h,040h,0c0h,021h,060h,0c0h,060h	; 4d88  @.@.!`.`
	defb 0c0h,060h,0c0h,070h,0c0h,020h,0c0h,0e3h	; 4d90  .`.p. ..
	defb 0b0h,0c0h,070h,0c0h,0b1h,0e2h,020h,0c0h	; 4d98  ..p... .
	defb 020h,0c0h,020h,0c0h,041h,070h,0c0h,070h	; 4da0   . .Ap.p
	defb 0c0h,070h,0c0h,021h,041h,061h,070h,090h	; 4da8  .p.!Aap.
	defb 071h,021h,0e3h,0b1h,071h,0ffh	; 4db0

; ----------------------------------------------------------------------
; DATOS pista_B6: La pista que arranca el sonido 20 (entrada 20 de la tabla de
;   0x4AD8)
;   0x4db6..0x4dd6  (32 bytes)
DATA_pista_B6:
	defb 0d6h,0fdh,004h,002h,0e3h,0cfh,0cfh,021h	; 4db6  .......!
	defb 070h,0c0h,070h,0c0h,070h,0c0h,001h,040h	; 4dbe  p.p.p..@
	defb 0c0h,040h,0c0h,040h,0c0h,061h,091h,021h	; 4dc6  .@.@.a.!
	defb 040h,060h,0b1h,071h,021h,0e4h,0b1h,0ffh	; 4dce  @`.q!...

; ----------------------------------------------------------------------
; DATOS pista_D6: La pista que arranca el sonido 23 (entrada 23 de la tabla de
;   0x4AD8)
;   0x4dd6..0x4dd7  (1 bytes)
DATA_pista_D6:
	defb 0e8h	; 4dd6

; ----------------------------------------------------------------------
; DATOS pista_D7: La pista que arranca el sonido 21 (entrada 21 de la tabla de
;   0x4AD8)
;   0x4dd7..0x4dec  (21 bytes)
DATA_pista_D7:
	defb 0d7h,0fbh,002h,002h,0e0h,020h,0e1h,090h	; 4dd7  ..... ..
	defb 070h,090h,0e0h,020h,010h,0e1h,090h,070h	; 4ddf  p.. ...p
	defb 0feh,0ffh,0d7h,04dh,0ffh	; 4de7

; ----------------------------------------------------------------------
; DATOS pista_EC: La pista que arranca el sonido 22 (entrada 22 de la tabla de
;   0x4AD8)
;   0x4dec..0x4e02  (22 bytes)
DATA_pista_EC:
	defb 0d1h,0fbh,002h,002h,0e0h,0c2h,0d7h,020h	; 4dec  ....... 
	defb 040h,090h,090h,0e1h,020h,040h,090h,0d1h	; 4df4  @... @..
	defb 073h,0feh,0ffh,0ech,04dh,0ffh	; 4dfc

; ----------------------------------------------------------------------
; DATOS pista_02: La pista que arranca el sonido 24 (entrada 24 de la tabla de
;   0x4AD8)
;   0x4e02..0x4e1b  (25 bytes)
DATA_4E02:
	defb 0d6h,0fdh,004h,002h,0e1h,0a1h,0a1h,0a1h	; 4e02  ........
	defb 0e0h,000h,0e1h,0a0h,091h,091h,093h,071h	; 4e0a  .......q
	defb 071h,050h,040h,020h,040h,051h,051h,053h	; 4e12  qP@ @QQS
	defb 0ffh	; 4e1a

; ----------------------------------------------------------------------
; DATOS pista_1B: La pista que arranca el sonido 25 (entrada 25 de la tabla de
;   0x4AD8)
;   0x4e1b..0x4e31  (22 bytes)
DATA_pista_1B:
	defb 0d6h,0fch,004h,002h,0e3h,0c1h,071h,0c1h	; 4e1b  ......q.
	defb 0e2h,001h,0c1h,001h,0c1h,001h,0c1h,021h	; 4e23  .......!
	defb 0c1h,001h,001h,001h,003h,0ffh	; 4e2b

; ----------------------------------------------------------------------
; DATOS pista_31: La pista que arranca el sonido 26 (entrada 26 de la tabla de
;   0x4AD8)
;   0x4e31..0x4e48  (23 bytes)
DATA_pista_31:
	defb 0d6h,0fch,004h,002h,0e3h,001h,041h,041h	; 4e31  ......AA
	defb 071h,051h,091h,051h,091h,0e4h,0a1h,0e3h	; 4e39  qQ.Q....
	defb 0a1h,001h,0a1h,091h,091h,093h,0ffh	; 4e41

; ----------------------------------------------------------------------
; DATOS pista_48: La pista que arranca el sonido 31 (entrada 31 de la tabla de
;   0x4AD8)
;   0x4e48..0x4e4b  (3 bytes)
DATA_pista_48:
	defb 023h,000h,000h	; 4e48

; ----------------------------------------------------------------------
; DATOS pista_4B: La pista que arranca el sonido 30 (entrada 30 de la tabla de
;   0x4AD8)
;   0x4e4b..0x4e71  (38 bytes)
DATA_pista_4B:
	defb 023h,0d0h,060h,0d0h,040h,0d0h,050h,0d0h	; 4e4b  #.`.@.P.
	defb 030h,0feh,002h,04ch,04eh,0b0h,060h,0b0h	; 4e53  0..LN.`.
	defb 040h,0a0h,050h,0a0h,030h,090h,060h,090h	; 4e5b  @.P.0.`.
	defb 040h,080h,050h,080h,030h,070h,060h,070h	; 4e63  @.P.0p`p
	defb 040h,060h,050h,060h,030h,0ffh	; 4e6b

; ----------------------------------------------------------------------
; DATOS pista_71: La pista que arranca el sonido 32 (entrada 32 de la tabla de
;   0x4AD8)
;   0x4e71..0x4e97  (38 bytes)
DATA_pista_71:
	defb 022h,0d0h,0d0h,0d0h,0b0h,0d0h,0c0h,0d0h	; 4e71  ".......
	defb 0a0h,0feh,002h,071h,04eh,0b0h,0d0h,0b0h	; 4e79  ...qN...
	defb 0b0h,0a0h,0c0h,0a0h,0a0h,090h,0d0h,090h	; 4e81  ........
	defb 0b0h,080h,0c0h,080h,0a0h,070h,0d0h,070h	; 4e89  .....p.p
	defb 0b0h,060h,0c0h,060h,0a0h,0ffh	; 4e91

; ----------------------------------------------------------------------
; DATOS pista_97: La pista que arranca el sonido 27 (entrada 27 de la tabla de
;   0x4AD8)
;   0x4e97..0x4eac  (21 bytes)
DATA_pista_97:
	defb 0d2h,0fch,001h,001h,0e3h,000h,020h,040h	; 4e97  ...... @
	defb 050h,070h,090h,0b0h,0e2h,000h,020h,040h	; 4e9f  Pp.... @
	defb 050h,070h,090h,0b7h,0ffh	; 4ea7

; ----------------------------------------------------------------------
; DATOS pista_AC: La pista que arranca el sonido 28 (entrada 28 de la tabla de
;   0x4AD8)
;   0x4eac..0x4ec1  (21 bytes)
DATA_4EAC:
	defb 0d2h,0fch,001h,001h,0e2h,0c0h,000h,020h	; 4eac  ....... 
	defb 040h,050h,070h,090h,0b0h,0e1h,000h,020h	; 4eb4  @Pp.... 
	defb 040h,050h,070h,097h,0ffh	; 4ebc

; ----------------------------------------------------------------------
; DATOS pista_C1: La pista que arranca el sonido 29 (entrada 29 de la tabla de
;   0x4AD8)
;   0x4ec1..0x4ed4  (19 bytes)
DATA_pista_C1:
	defb 0d2h,0fch,001h,001h,0e1h,000h,020h,040h	; 4ec1  ...... @
	defb 050h,070h,090h,0b0h,0e0h,000h,020h,040h	; 4ec9  Pp.... @
	defb 050h,079h,0ffh	; 4ed1

; ----------------------------------------------------------------------
; DATOS pista_D4: La pista que arranca el sonido 36 (entrada 36 de la tabla de
;   0x4AD8)
;   0x4ed4..0x4f02  (46 bytes)
DATA_pista_D4:
	defb 022h,0c0h,058h,0c0h,078h,0c0h,070h,0c0h	; 4ed4  ".X.x.p.
	defb 090h,0c0h,088h,0c0h,0a8h,0c0h,0a0h,0c0h	; 4edc  ........
	defb 0c0h,0c0h,0b8h,0c0h,0c8h,0c0h,0c0h,0c0h	; 4ee4  ........
	defb 0f0h,0c0h,0e8h,0c1h,008h,0c1h,000h,0c1h	; 4eec  ........
	defb 020h,0c1h,018h,0c1h,038h,0c1h,030h,0c1h	; 4ef4   ...8.0.
	defb 050h,000h,000h,000h,000h,0ffh	; 4efc

; ----------------------------------------------------------------------
; DATOS pista_02: La pista que arranca el sonido 37 (entrada 37 de la tabla de
;   0x4AD8)
;   0x4f02..0x4f2f  (45 bytes)
DATA_4F02:
	defb 022h,0d1h,008h,0d1h,028h,0d1h,020h,0d1h	; 4f02  "...(. .
	defb 040h,0d1h,038h,0d1h,058h,0d1h,050h,0d1h	; 4f0a  @.8.X.P.
	defb 070h,0d1h,068h,0d1h,088h,0d1h,080h,0d1h	; 4f12  p.h.....
	defb 0a0h,0d1h,098h,0d1h,0b8h,0d1h,0b0h,0d1h	; 4f1a  ........
	defb 0d0h,0d2h,028h,0d2h,048h,0d2h,040h,0d2h	; 4f22  ..(.H.@.
	defb 060h,000h,000h,000h,000h	; 4f2a

; ----------------------------------------------------------------------
; DATOS pista_2F: La pista que arranca el sonido 12,14,38,39,40 (entradas
;   12,14,38,39,40 de la tabla de 0x4AD8)
;   0x4f2f..0x4f30  (1 bytes)
DATA_pista_2F:
	defb 0ffh	; 4f2f

; ----------------------------------------------------------------------
; DATOS pista_30: La pista que arranca el sonido 33 (entrada 33 de la tabla de
;   0x4AD8)
;   0x4f30..0x4f5c  (44 bytes)
DATA_pista_30:
	defb 0d9h,0fch,003h,003h,0e1h,093h,060h,070h	; 4f30  ......`p
	defb 096h,090h,090h,090h,0b0h,0e0h,000h,0e1h	; 4f38  ........
	defb 0b2h,0b0h,090h,070h,093h,060h,090h,061h	; 4f40  ...p.`.a
	defb 041h,061h,022h,0e2h,0b0h,0e1h,010h,020h	; 4f48  Aa".... 
	defb 040h,060h,040h,070h,060h,040h,02bh,0feh	; 4f50  @`@p`@+.
	defb 002h,030h,04fh,0ffh	; 4f58

; ----------------------------------------------------------------------
; DATOS pista_5C: La pista que arranca el sonido 34 (entrada 34 de la tabla de
;   0x4AD8)
;   0x4f5c..0x4f85  (41 bytes)
DATA_pista_5C:
	defb 0d9h,0fch,003h,003h,0e1h,063h,020h,040h	; 4f5c  .....c @
	defb 066h,060h,060h,060h,070h,090h,072h,070h	; 4f64  f```p.rp
	defb 060h,040h,063h,020h,060h,015h,0e2h,0b2h	; 4f6c  `@c `...
	defb 0b2h,0b2h,0e1h,012h,0e2h,0b2h,0b0h,090h	; 4f74  ........
	defb 070h,091h,070h,062h,0feh,002h,05ch,04fh	; 4f7c  p.pb..\O
	defb 0ffh	; 4f84

; ----------------------------------------------------------------------
; DATOS pista_85: La pista que arranca el sonido 35 (entrada 35 de la tabla de
;   0x4AD8)
;   0x4f85..0x4fd9  (84 bytes)
DATA_pista_85:
	defb 0d9h,0fbh,004h,004h,0e0h,020h,060h,090h	; 4f85  ..... `.
	defb 090h,060h,020h,010h,020h,060h,090h,060h	; 4f8d  .` . `.`
	defb 020h,000h,020h,060h,090h,060h,020h,0e1h	; 4f95   . `.` .
	defb 0b0h,0e0h,020h,070h,0b0h,070h,020h,020h	; 4f9d  .. p.p  
	defb 060h,090h,090h,060h,020h,0e1h,090h,0e0h	; 4fa5  `..` ...
	defb 010h,060h,090h,060h,010h,0e1h,0b0h,0e0h	; 4fad  .`.`....
	defb 020h,060h,0e1h,090h,0e0h,020h,060h,0e1h	; 4fb5   `... `.
	defb 080h,0e0h,040h,080h,0e1h,090h,0e0h,070h	; 4fbd  ..@....p
	defb 090h,0e1h,070h,0e0h,020h,070h,070h,060h	; 4fc5  ..p. pp`
	defb 040h,060h,0e1h,090h,0e0h,040h,022h,0feh	; 4fcd  @`...@".
	defb 002h,085h,04fh,0ffh	; 4fd5

; ======================================================================
; CODIGO 0x4fd9..0x5005  (44 bytes)
; ======================================================================


BORRA_RAM:		; Pone a cero BC+1 bytes desde HL
	xor a			;4fd9
	ld (hl),a			;4fda   ; el truco de siempre: se pone el primer byte y el LDIR lo va arrastrando
	ld d,h			;4fdb
	ld e,l			;4fdc
	inc de			;4fdd
	ldir		;4fde
	ret			;4fe0

; ----------------------------------------------------------------------
; ARRANCAR UNA FASE. Borra la RAM del juego, coloca al jugador, arma las 24 filas del fondo y carga los sprites.
; ----------------------------------------------------------------------
ARRANCA_FASE:		; Deja la fase lista y pinta la primera pantalla
	ld hl,0e180h		;4fe1
	ld bc,0037fh		;4fe4   ; 0x380 bytes: de 0xE180 a 0xE4FF, o sea enemigos, disparos y objetos
	call BORRA_RAM		;4fe7
	call PREPARA_JUGADOR		;4fea
	call ARMA_PANTALLA		;4fed   ; arma las 24 filas del buffer de nombres
	call BORRA_ACTORES		;4ff0
	call CARGA_SPRITES		;4ff3   ; los patrones de sprite comunes
ARRANCA_PANTALLA:		; El suelo, los caracteres del fondo y la primera volcada de nombres
	call CARGA_SUELO		;4ff6   ; el suelo que le toca a esta pantalla del mundo
	call BORRA_ACTORES		;4ff9
	call GENERA_FONDO		;4ffc   ; genera los 192 caracteres del fondo
	call ARMA_PANTALLA		;4fff   ; vuelve a armar las filas con el fondo ya generado
	jp PASO_DE_SCROLL		;5002

; ----------------------------------------------------------------------
; DATOS jugador_nuevo: Los once bytes que 0x5050 copia a 0xE120 al empezar la
;   fase: estado 0, sentido 0, espera 8, Y=0x58, X=0x58, juego de sprites 0,
;   velocidad 15, 8, 11
;   0x5005..0x500f  (10 bytes)
DATA_jugador_nuevo:
	defb 000h,000h,008h,058h,058h,000h,005h,00fh,008h,00bh	; 5005  ...XX.....

; ======================================================================
; CODIGO 0x500f..0x5229  (538 bytes)
; ======================================================================


BORRA_ACTORES:		; Manda fuera de la pantalla los disparos, los enemigos y los objetos
	ld a,0e0h		;500f   ; 0xE0 en la Y es "este sprite no se ve"
	ld (0e1e3h),a		;5011
	ld (0e1ebh),a		;5014
	ld (0e390h),a		;5017
	ld hl,0e1b0h		;501a   ; 0xE0 en los 32 bytes de 0xE1B0: los disparos enemigos, fuera
	ld b,020h		;501d
BORRA_SPRITES_SUELTOS:
	ld (hl),a			;501f
	inc l			;5020
	djnz BORRA_SPRITES_SUELTOS		;5021
	ld hl,0e204h		;5023   ; la Y de las fichas de enemigo, de 16 en 16 bytes (once, una mas de las diez que hay)
	ld b,00bh		;5026
	ld e,010h		;5028
	call BORRA_LISTA		;502a
	ld hl,0e402h		;502d   ; y la Y de los siete objetos, de 8 en 8
	ld b,007h		;5030
	ld e,008h		;5032
BORRA_LISTA:		; Pone A en el primer byte de B fichas separadas E bytes
	ld d,000h		;5034
BORRA_LISTA_BUCLE:
	ld (hl),a			;5036
	add hl,de			;5037
	djnz BORRA_LISTA_BUCLE		;5038
	ret			;503a

; ----------------------------------------------------------------------
; COLOCAR AL JUGADOR. Copia el estado inicial y busca hacia arriba la primera fila del mapa que este libre.
; ----------------------------------------------------------------------
PREPARA_JUGADOR:		; Marcador, estado inicial y una casilla libre donde ponerse
	call PINTA_VIDAS		;503b
	xor a			;503e
	ld (0e187h),a		;503f   ; 0xE187 a cero: el jugador no se esta muriendo
	ld h,a			;5042
	ld l,a			;5043
	ld (0e1a8h),hl		;5044   ; 0xE1A8 y 0xE1A9 a cero: sin bota y sin escudo
	ld hl,0e19ah		;5047   ; y los doce contadores de 0xE19A, lo recogido en la fase
	ld b,00ch		;504a
PREPARA_JUGADOR_BORRA:		; El bucle que borra los doce bytes de 0xE19A
	ld (hl),a			;504c
	inc hl			;504d
	djnz PREPARA_JUGADOR_BORRA		;504e
	ld hl,05005h		;5050   ; los once bytes de 0x5005 a 0xE120
	ld de,0e120h		;5053
	ld bc,0000bh		;5056
	ldir		;5059
	ld hl,(0e123h)		;505b   ; mira la casilla del mapa donde va a caer
	ld b,005h		;505e
BUSCA_CASILLA_LIBRE:		; Prueba hasta cinco veces: si hay algo pintado, se corre una fila
	push hl			;5060
	call DIRECCION_DE_NOMBRE		;5061
	call 0004ah		;5064   ; BIOS RDVRM - Reads the content of VRAM | lee de la VRAM el caracter que hay ahi
	pop hl			;5067
	and a			;5068
	jr z,CASILLA_ELEGIDA		;5069
	ld a,(0e102h)		;506b
	and a			;506e
	ld a,010h		;506f   ; subiendo se corre +0x10 y bajando -0x10
	jr z,BUSCA_CASILLA_SIGUE		;5071
	ld a,0f0h		;5073
BUSCA_CASILLA_SIGUE:
	add a,l			;5075
	ld l,a			;5076
	djnz BUSCA_CASILLA_LIBRE		;5077
CASILLA_ELEGIDA:
	ld (0e123h),hl		;5079
PON_SENTIDO:		; 0xE121 (el sentido del disparo) segun se suba o se baje
	ld a,(0e102h)		;507c
	and a			;507f
	jr z,PON_SENTIDO_GUARDA		;5080
	inc a			;5082
PON_SENTIDO_GUARDA:
	ld (0e121h),a		;5083
	ret			;5086

; ----------------------------------------------------------------------
; EL PASO DE LA PARTIDA. Es lo que corre en cada fotograma mientras se juega: sprites, mando, jugador, enemigos, disparos, objetos y scroll.
; ----------------------------------------------------------------------
PASO_DE_PARTIDA:		; Un fotograma de juego entero
	ld hl,0e11bh		;5087   ; 0xE11B es la invulnerabilidad, que va bajando sola
	ld a,(hl)			;508a
	and a			;508b
	jr z,PASO_DE_PARTIDA_CUERPO		;508c
	dec (hl)			;508e
PASO_DE_PARTIDA_CUERPO:		; El cuerpo del paso, ya con la invulnerabilidad descontada
	call VUELCA_SPRITES		;508f   ; vuelca la tabla de sprites a la VRAM
	call DIBUJA_JUGADOR		;5092   ; dibuja al jugador
	call PARPADEA_PUNTO_MAPA		;5095   ; el punto que parpadea en el mapa del mundo
	ld a,(0e111h)		;5098   ; 0xE111 distinto de cero: estamos en el final de la fase
	and a			;509b
	jp nz,PASO_FINAL		;509c
	call ELIGE_MUSICA		;509f   ; elige la musica que toca
	call MIRA_LA_META		;50a2   ; mira si el jugador ha llegado a la meta
	call MUEVE_CON_EL_MANDO		;50a5   ; lee el mando y mueve al jugador
	call ANIMA_JUGADOR		;50a8   ; anima al jugador
	ld a,(0e1a7h)		;50ab
	and a			;50ae
	jr nz,PASO_CADA_CUATRO		;50af
	call MUEVE_DISPAROS		;50b1   ; mueve y dispara
	call DISPARA		;50b4
PASO_CADA_CUATRO:		; Lo que solo se hace un fotograma de cada cuatro
	ld a,(0e003h)		;50b7
	and 003h		;50ba   ; un fotograma de cada cuatro
	jr nz,PASO_FIN_DE_FASE		;50bc
	ld a,(0e171h)		;50be   ; 0xE171: si quedan encargos por soltar no se toca el escudo
	and a			;50c1
	jr nz,PASO_QUITA_ESCUDO		;50c2
	ld a,(0e1d0h)		;50c4   ; el escudo aguanta mientras uno de los dos encargos sea del tipo 5
	cp 005h		;50c7
	jr z,PASO_TRONO		;50c9
	ld a,(0e1d3h)		;50cb
	cp 005h		;50ce
	jr z,PASO_TRONO		;50d0
PASO_QUITA_ESCUDO:
	xor a			;50d2
	ld (0e11ah),a		;50d3
PASO_TRONO:		; La cuenta atras de estar en el trono
	ld hl,0e1a7h		;50d6
	ld a,(hl)			;50d9   ; 0xE1A7 es la cuenta atras de estar sentado en el trono
	and a			;50da
	jr z,PASO_OBJETOS		;50db
	dec (hl)			;50dd
	jr nz,PASO_OBJETOS		;50de
	xor a			;50e0
	ld (0e113h),a		;50e1
	ld a,026h		;50e4   ; al levantarse suena la 0x26
	call PIDE_SONIDO_EN_PARTIDA		;50e6
PASO_OBJETOS:		; Mueve los objetos, suelta enemigos y da el paso de scroll
	call MUEVE_OBJETOS		;50e9
	ld a,(0e113h)		;50ec
	and a			;50ef
	ret nz			;50f0
	call ENCARGA_ENEMIGO		;50f1   ; mira si toca soltar un enemigo
	call PASO_DE_SCROLL		;50f4   ; EL PASO DE SCROLL
	ld hl,(0e100h)		;50f7   ; a mitad de la fase (0x480 subiendo, 0x540 bajando) se prepara el jefe
	ld de,00480h		;50fa
	ld a,(0e102h)		;50fd
	and a			;5100
	jr z,PASO_MITAD		;5101
	ld de,00540h		;5103
PASO_MITAD:
	sbc hl,de		;5106   ; justo en ese pixel se encarga el jefe
	ld a,002h		;5108
	jr nz,PASO_SUELTA_OBJETOS		;510a
	ld (0e171h),a		;510c   ; 0xE171 = 2: dos encargos pendientes
	xor a			;510f
	ld (0e11eh),a		;5110   ; 0xE11E a cero: la pantalla del jefe vuelve a tener fondo
PASO_SUELTA_OBJETOS:
	jp SUELTA_OBJETOS		;5113
PASO_FIN_DE_FASE:		; El paso cuando la fase ya se ha acabado: solo enemigos y disparos
	ld hl,0e180h		;5116
	inc (hl)			;5119   ; 0xE180 es el contador de fotogramas de la fase
	ld a,(0e1a7h)		;511a   ; sentado en el trono no se suelta nada
	and a			;511d
	jr nz,PASO_CHOQUES		;511e
	call SUELTA_ENEMIGO		;5120
	call PASO_DE_ENEMIGOS		;5123
	call MUEVE_DISPAROS_ENEMIGOS		;5126
PASO_CHOQUES:		; Mira los choques del jugador con enemigos y objetos
	call MIRA_DISPAROS_CONTRA_DISPAROS		;5129
	call MIRA_DISPAROS		;512c
	call PISA_OBJETOS		;512f
	ld a,(0e120h)		;5132
	and a			;5135
	ret m			;5136
	ld de,(0e123h)		;5137
	call MIRA_OBJETO		;513b   ; mira si el jugador pisa un objeto
	jr nc,PASO_CHOQUE_ENEMIGO		;513e
	cp 00ah		;5140
	jr z,PASO_CHOQUE_ENEMIGO		;5142
	cp 005h		;5144
	call nz,COGE_OBJETO		;5146   ; el 5 y el 0x0A no se recogen
PASO_CHOQUE_ENEMIGO:
	ld hl,0e11bh		;5149   ; 0xE11B es la invulnerabilidad
	ld a,(0e1a7h)		;514c   ; en el trono los choques se miran igual, aunque sea invulnerable
	and a			;514f
	jr nz,PASO_CHOQUE_2		;5150
	or (hl)			;5152
	ret nz			;5153
PASO_CHOQUE_2:
	call MIRA_CHOQUE_CON_ENEMIGO		;5154
	ld a,(0e1a7h)		;5157
	and a			;515a
	ret nz			;515b
	jp MIRA_DISPARO_ENEMIGO		;515c
PASO_FINAL:		; Los pasos de la pantalla del trono y del final
	call PASO_DE_FIN_DE_FASE		;515f
	call ANIMA_JUGADOR		;5162
	jp PASO_DE_ENEMIGOS		;5165

; ----------------------------------------------------------------------
; LA MUSICA QUE TOCA. La elige mirando en que anda el jugador; como manda el numero mas alto, basta con pedirla cada fotograma.
; ----------------------------------------------------------------------
ELIGE_MUSICA:		; Pide la musica o el sonido continuo que corresponde
	ld hl,0e11fh		;5168   ; 0xE11F: acaba de morir, y suena la 0x92 en cuanto se calle lo que hubiera
	ld a,(hl)			;516b
	and a			;516c
	jr z,MUSICA_NORMAL		;516d
	ld a,(0e012h)		;516f
	and a			;5172
	ret nz			;5173
	dec (hl)			;5174
	ld a,092h		;5175
	jp PIDE_SONIDO_EN_PARTIDA		;5177
MUSICA_NORMAL:
	ld a,(0e120h)		;517a   ; 0xE120 = 0xFF quiere decir muriendose: no se pide musica
	add a,a			;517d
	ret c			;517e
	ld c,000h		;517f
	ld a,(0e1a7h)		;5181   ; 0xE1A7: en el trono suena la 0x0B, y si ya queda poco la 0x0D
	and a			;5184
	jr z,MUSICA_COMPARA		;5185
	ld c,00bh		;5187
	cp 030h		;5189
	jr nc,MUSICA_COMPARA		;518b
	ld c,00dh		;518d
MUSICA_COMPARA:
	ld hl,0e012h		;518f   ; +2 del primer canal: lo que esta sonando ahora
	ld a,(hl)			;5192
	cp 09bh		;5193   ; la 0x9B y la 0x1E no se interrumpen
	ret z			;5195
	cp 01eh		;5196
	ret z			;5198
	ld a,c			;5199
	and a			;519a
	jr z,MUSICA_DEL_PASEO		;519b
	cp (hl)			;519d   ; si ya suena la que toca, no se vuelve a pedir
	ret z			;519e
	ld a,(hl)			;519f
	and a			;51a0
	jr z,MUSICA_PIDE		;51a1
	ld c,026h		;51a3   ; y si suena otra cosa, se pide la 0x26 en su lugar
MUSICA_PIDE:
	ld a,c			;51a5
	jp PIDE_SONIDO_EN_PARTIDA		;51a6
MUSICA_DEL_PASEO:		; La musica de andar, o la del escudo si lo lleva
	ld a,(0e11ah)		;51a9   ; 0xE11A: con un enemigo de tipo 5 encargado suena la 0x89
	and a			;51ac
	ld a,089h		;51ad
	jp nz,PIDE_SONIDO_EN_PARTIDA		;51af
	ld c,0c7h		;51b2
	ld a,(0e117h)		;51b4   ; el bit 1 de la fila del tramo alterna entre la 0xC7 y la 0x87
	and 002h		;51b7
	jr z,MUSICA_PIDE_2		;51b9
	ld c,087h		;51bb
MUSICA_PIDE_2:
	ld a,c			;51bd
	jp PIDE_SONIDO_EN_PARTIDA		;51be

; ----------------------------------------------------------------------
; LA DEMO. Va pasando por las nueve pantallas del mundo, una detras de otra.
; ----------------------------------------------------------------------
DEMO_SIGUIENTE_PANTALLA:		; Pasa a la pantalla siguiente de la demo y la arranca
	ld hl,0e00dh		;51c1   ; 0xE00D: las nueve pantallas de la demo, en rueda
	ld a,(hl)			;51c4
	inc a			;51c5
	cp 009h		;51c6
	jr c,DEMO_PANTALLA		;51c8
	xor a			;51ca
DEMO_PANTALLA:
	ld (hl),a			;51cb
	ld (0e132h),a		;51cc   ; 0xE132 es la pantalla del mundo
	ld hl,07b84h		;51cf   ; que fase le toca a esa pantalla
	call SUMA_A_HL		;51d2
	ld a,(hl)			;51d5
	ld (0e103h),a		;51d6
	ld a,001h		;51d9   ; 0xE054: la fase queda en marcha
	ld (0e054h),a		;51db
	call DESCOMPRIME_PIEZAS		;51de
	ld h,000h		;51e1
	ld a,r		;51e3   ; la X de salida se sortea con el registro R
	and 00fh		;51e5
	add a,0b0h		;51e7   ; la posicion de salida cae entre 0xB0 y 0xBF
	ld l,a			;51e9
	ld (0e100h),hl		;51ea
	call CARGA_SUELO		;51ed
	call PINTA_PANEL		;51f0
	call ARRANCA_FASE		;51f3
	xor a			;51f6
	ld (0e102h),a		;51f7   ; subiendo (0xE102 = 0), sin dificultad acumulada y sin encargos
	ld (0e105h),a		;51fa
	ld (0e170h),a		;51fd
	dec a			;5200   ; 0xFF en 0xE11B: en la demo no se puede morir
	ld (0e11bh),a		;5201
	ret			;5204
MANDO_DE_LA_DEMO:		; Mete en 0xE009 el paso que toca del guion de 0x5229
	ld a,(0e003h)		;5205
	ld c,a			;5208
	ld hl,0e004h		;5209
	and 01fh		;520c   ; un paso del guion cada 32 fotogramas
	jr nz,MANDO_DEMO_PASO		;520e
	inc (hl)			;5210
MANDO_DEMO_PASO:
	ld a,(hl)			;5211   ; los 16 pasos del guion, en rueda
	and 00fh		;5212
	ld hl,05229h		;5214
	call SUMA_A_HL		;5217
	ld a,(hl)			;521a
	ld hl,0e009h		;521b   ; 0xE009 es lo que cuenta como pulsado
	ld (hl),a			;521e
	dec l			;521f
	ld (hl),010h		;5220   ; y 0xE008 el flanco: el disparo, un fotograma de cada 16
	ld a,c			;5222
	and 00fh		;5223
	ret z			;5225
	ld (hl),000h		;5226
	ret			;5228

; ----------------------------------------------------------------------
; DATOS mando_de_la_demo: Los 16 pasos del mando fingido de la demo. 0x5205
;   avanza uno cada 32 fotogramas y lo mete en 0xE009 como si fuera el
;   joystick
;   0x5229..0x5239  (16 bytes)
DATA_mando_de_la_demo:
	defb 001h,002h,001h,002h,002h,009h,002h,001h,001h,000h,002h,001h,006h,001h,002h,000h	; 5229  ................

; ======================================================================
; CODIGO 0x5239..0x53a2  (361 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL PASO DE SCROLL. Suma (o resta) un pixel a la posicion de la fase, y cada ocho pixeles corre el buffer de filas y arma la fila nueva.
;
; EL SCROLL AL PIXEL, EN CORTO. SCREEN 2 no tiene registro de
; desplazamiento, asi que hay que fabricarlo:
;
; 1. Los caracteres del fondo estan OCHO VECES en la VRAM, del 0x40 al
; 0xFF, en bloques de 24: el bloque p lleva el mismo dibujo bajado p
; pixeles. Los genera 0x566D al empezar la pantalla.
;
; 2. Desplazar la pantalla un pixel es sumarle 24 * (posicion y 7) a todos
; los numeros de caracter. Por eso 0x5312 reescribe las 24 filas x 22
; columnas de la tabla de nombres ENTERA en cada fotograma: 528 escrituras
; por el puerto de datos del VDP.
;
; 3. Cada ocho pixeles el buffer de filas de 0xE060 se corre seis bytes y
; 0x5293 arma la fila que entra por el borde. En ese momento la fase
; vuelve a 0, asi que la cuenta encaja sin costura.
;
; Medido en openMSX sobre un Philips VG-8020 (71591 ciclos por fotograma):
; 0x5312 se lleva 32557 ciclos de media, el 45,5 % del fotograma y el 62 %
; de lo que dura la interrupcion, que son 52533 ciclos (73,4 %). Todo el
; detalle esta en EL-SCROLL-AL-PIXEL.md.
; ----------------------------------------------------------------------
PASO_DE_SCROLL:		; Un pixel de scroll y la tabla de nombres entera repintada
	ld a,(0e102h)		;5239   ; 0xE102: 0 se sube por la fase, distinto de 0 se baja
	and a			;523c
	jr nz,SCROLL_HACIA_ATRAS		;523d
	ld hl,(0e100h)		;523f
	inc hl			;5242   ; un pixel mas
	ld (0e100h),hl		;5243
	ld a,l			;5246
	and 007h		;5247   ; la fase de 0 a 7 dentro del caracter
	ld (0e11ch),a		;5249
	jp nz,FASE_DEL_SCROLL		;524c   ; mientras no se cruce un caracter, solo hay que repintar
	ld hl,0e0e9h		;524f   ; cruzamos caracter: el buffer entero baja una fila (6 bytes)
	ld de,0e0efh		;5252
	ld bc,0008ah		;5255
	lddr		;5258
	ld hl,(0e100h)		;525a   ; la fila que entra es la de 0xB8 pixeles mas arriba (23 filas)
	ld c,0b8h		;525d
	add hl,bc			;525f
	ex de,hl			;5260
	ld hl,0e060h		;5261   ; y se arma en 0xE060, que es la fila de arriba de la pantalla
	call ARMA_FILA		;5264
	jp VUELCA_NOMBRES		;5267
SCROLL_HACIA_ATRAS:		; Lo mismo al reves: la fila nueva entra por abajo
	call FASE_DEL_SCROLL		;526a   ; al bajar se repinta antes de mover, para no perder un fotograma
	ld hl,(0e100h)		;526d
	dec hl			;5270
	ld (0e100h),hl		;5271
	ld a,l			;5274
	inc a			;5275
	and 007h		;5276
	ld (0e11ch),a		;5278
	ld a,l			;527b
	and 007h		;527c
	cp 007h		;527e
	ret nz			;5280
	ld hl,0e066h		;5281   ; el buffer sube una fila
	ld de,0e060h		;5284
	ld bc,0008ah		;5287
	ldir		;528a
	ld de,(0e100h)		;528c
	ld hl,0e0eah		;5290

; ----------------------------------------------------------------------
; ARMAR UNA FILA. Traduce una posicion en pixeles a los 6 bytes de la fila: divide por 192 para saber el tramo, por 8 para saber la fila dentro del tramo, y saca las 6 piezas de la tabla del plano.
; ----------------------------------------------------------------------
ARMA_FILA:		; Deja en (HL) los 6 bytes de la fila que hay en la posicion DE
	push hl			;5293
	ld bc,000c0h		;5294   ; 192 pixeles = 24 filas = un tramo
	call DIVIDE		;5297   ; E = tramo, HL = lo que sobra
	ld a,l			;529a   ; la fila dentro del tramo, de 0 a 23
	rra			;529b
	rra			;529c
	rra			;529d
	and 01fh		;529e
	exx			;52a0
	ld c,a			;52a1
	exx			;52a2
	pop hl			;52a3
	ld a,e			;52a4
	ld (0e117h),a		;52a5   ; 0xE117 guarda el tramo, que otras rutinas miran
	ld a,(0e132h)		;52a8   ; las pantallas 8 y 0x11 (los jefes) llevan plano propio
	cp 008h		;52ab
	ld c,008h		;52ad
	jr z,FILA_INDICE		;52af
	inc c			;52b1
	cp 011h		;52b2
	jr z,FILA_INDICE		;52b4
	cp 009h		;52b6
	jr z,FILA_PLANO_DE_LA_FASE		;52b8
	ld a,(0e11eh)		;52ba
	and a			;52bd
	jr nz,FILA_INDICE		;52be
FILA_PLANO_DE_LA_FASE:
	ld a,(0e103h)		;52c0
	ld c,a			;52c3
FILA_INDICE:
	ld a,c			;52c4   ; A = 13 * plano + tramo: cada fase son trece tramos
	add a,a			;52c5
	add a,a			;52c6
	ld b,a			;52c7
	add a,a			;52c8
	add a,b			;52c9
	add a,c			;52ca
	add a,e			;52cb
	ld de,053a2h		;52cc
	call SUMA_A_DE		;52cf
	ld a,(de)			;52d2   ; el byte que sale es el numero de tramo de la tabla de 0x5424
	ld e,a			;52d3
	add a,a			;52d4
	add a,a			;52d5
	add a,e			;52d6
	add a,e			;52d7
	ld de,05424h		;52d8   ; seis piezas por tramo
	call SUMA_A_DE		;52db
	exx			;52de
	ld b,006h		;52df
FILA_PIEZA:		; Saca de cada una de las seis piezas la fila que toca
	exx			;52e1
	ld a,(de)			;52e2
	exx			;52e3
	ld h,000h		;52e4   ; cada pieza son 24 filas
	ld l,a			;52e6
	add hl,hl			;52e7
	add hl,hl			;52e8
	add hl,hl			;52e9
	ld e,l			;52ea
	ld d,h			;52eb
	add hl,hl			;52ec
	add hl,de			;52ed
	ex de,hl			;52ee
	ld a,c			;52ef
	call SUMA_A_DE		;52f0
	ld ix,0e500h		;52f3   ; las piezas viven en 0xE500
	add ix,de		;52f7
	exx			;52f9
	ld a,(ix+000h)		;52fa
	ld (hl),a			;52fd
	inc l			;52fe
	inc de			;52ff
	exx			;5300
	djnz FILA_PIEZA		;5301
	ld l,000h		;5303   ; L = 0 para VUELCA_NOMBRES: al cruzar caracter la fase es 0
	ret			;5305
FASE_DEL_SCROLL:		; Calcula L = 24 * (posicion y 7), que es lo que se le suma a cada caracter
	ld a,(0e100h)		;5306   ; la fase, de 0 a 7 pixeles
	and 007h		;5309
	add a,a			;530b   ; x8
	add a,a			;530c
	add a,a			;530d
	ld c,a			;530e
	add a,a			;530f   ; ...y x3: 24 caracteres por bloque de desplazamiento
	add a,c			;5310
	ld l,a			;5311

; ----------------------------------------------------------------------
; VOLCAR LA TABLA DE NOMBRES. 24 filas de 22 caracteres, sacadas por el puerto de datos del VDP. Cada byte del buffer describe CUATRO columnas: dos parejas de caracteres, y una pareja son un caracter y el que esta 12 mas alla, que es su mitad derecha. El desplazamiento en pixeles entra sumando L.
; ----------------------------------------------------------------------
VUELCA_NOMBRES:		; Repinta el area de juego con el desplazamiento L
	ld a,(00006h)		;5312   ; el puerto de datos del VDP
	exx			;5315
	ld c,a			;5316
	ld hl,03801h		;5317   ; columna 1 de la fila 0: la columna 0 no se toca
	exx			;531a
	ld de,0e060h		;531b
	ld c,018h		;531e   ; 24 filas
NOMBRES_FILA:
	exx			;5320
	call 00053h		;5321   ; BIOS SETWRT - Enables VDP to write
	ld de,00020h		;5324   ; la fila siguiente esta 32 bytes mas alla
	add hl,de			;5327
	exx			;5328
	ld b,006h		;5329   ; seis bytes por fila
NOMBRES_BYTE:		; Traduce un byte del buffer a dos parejas de caracteres
	ld a,(de)			;532b
	inc e			;532c
	ld h,000h		;532d
	cp 080h		;532f   ; menos de 0x80: una pareja de fondo y una pareja vacia
	jr c,NOMBRES_FONDO		;5331
	and 07fh		;5333
	cp 060h		;5335   ; de 0x80 a 0xDF: la misma pareja dos veces
	jr c,NOMBRES_REPETIDA		;5337
	and 007h		;5339   ; de 0xE0 en adelante: una costura y una tapa, elegidas por los tres bits de abajo
	exx			;533b
	ld b,a			;533c
	exx			;533d
	rra			;533e   ; bit 0: tapa de abajo (0x43 o 0x47) en vez de tapa de arriba
	jr nc,NOMBRES_TAPA_PAR		;533f
	bit 1,a		;5341
	ld a,043h		;5343
	jr z,NOMBRES_TAPA		;5345
	ld a,047h		;5347
NOMBRES_TAPA:
	jr NOMBRES_COSTURA		;5349
NOMBRES_TAPA_PAR:
	rra			;534b
	ld a,040h		;534c
	jr nc,NOMBRES_COSTURA		;534e
	ld a,044h		;5350
NOMBRES_COSTURA:
	add a,l			;5352   ; H = la segunda pareja, con su desplazamiento
	ld h,a			;5353
	exx			;5354
	ld a,b			;5355
	exx			;5356
	rra			;5357
	add a,048h		;5358   ; A = la costura: 0x48, 0x49, 0x4A o 0x4B, mas el desplazamiento
	add a,l			;535a
	jr NOMBRES_SACA		;535b
NOMBRES_REPETIDA:		; La misma pareja en las cuatro columnas
	add a,l			;535d
	ld h,a			;535e
	jr NOMBRES_SACA		;535f
NOMBRES_FONDO:
	cp 00fh		;5361   ; los caracteres por debajo del 0x0F no llevan desplazamiento: son iguales en los ocho
	jr c,NOMBRES_SACA		;5363
	add a,l			;5365
NOMBRES_SACA:		; Saca las cuatro columnas: pareja A (n, n+12) y pareja H (n, n+12)
	exx			;5366
	out (c),a		;5367
	exx			;5369
	add a,00ch		;536a   ; la mitad derecha de la pareja esta 12 caracteres mas alla
	exx			;536c
	out (c),a		;536d
	exx			;536f
	dec b			;5370   ; al sexto byte solo le caben dos columnas: 5*4 + 2 = 22
	jr z,NOMBRES_FIN_DE_FILA		;5371
	ld a,h			;5373
	exx			;5374
	out (c),a		;5375
	exx			;5377
	add a,00ch		;5378
	exx			;537a
	out (c),a		;537b
	exx			;537d
	jr NOMBRES_BYTE		;537e
NOMBRES_FIN_DE_FILA:
	dec c			;5380
	jr nz,NOMBRES_FILA		;5381
	ret			;5383

; ----------------------------------------------------------------------
; ARMAR LA PANTALLA ENTERA. Las 24 filas de golpe, de abajo arriba: la de abajo es la posicion actual y cada una que sube son 8 pixeles mas.
; ----------------------------------------------------------------------
ARMA_PANTALLA:		; Rellena las 24 filas del buffer de nombres
	ld de,(0e100h)		;5384
	ld hl,0e0eah		;5388   ; 0xE0EA es la ultima fila del buffer, la de abajo de la pantalla
	ld b,018h		;538b
ARMA_PANTALLA_FILA:
	push bc			;538d
	push de			;538e
	push hl			;538f
	call ARMA_FILA		;5390
	pop hl			;5393
	ld de,0fffah		;5394   ; una fila menos en el buffer (6 bytes)
	add hl,de			;5397
	pop de			;5398
	pop bc			;5399
	ld a,008h		;539a   ; ...y 8 pixeles mas arriba en la fase
	call SUMA_A_DE		;539c
	djnz ARMA_PANTALLA_FILA		;539f
	ret			;53a1

; ----------------------------------------------------------------------
; DATOS planos_por_fase: Diez fases de trece tramos. Cada byte dice que tramo
;   de 0x5424 se usa; un tramo son 24 filas, o sea 192 pixeles, asi que una
;   fase mide 2496 pixeles
;   0x53a2..0x5424  (130 bytes)
DATA_planos_por_fase:
	defb 011h,00bh,00bh,00bh,001h,001h,004h,007h,00bh,001h,001h,00ah,010h	; 53a2  .............
	defb 011h,00bh,00bh,00bh,001h,001h,00bh,003h,00ch,00dh,001h,00ah,010h	; 53af  .............
	defb 011h,001h,001h,001h,005h,005h,006h,004h,004h,001h,001h,00ah,010h	; 53bc  .............
	defb 011h,00ch,00dh,00bh,00ch,00dh,00bh,00bh,00ch,00dh,00bh,00ah,010h	; 53c9  .............
	defb 011h,00bh,00bh,00bh,001h,001h,003h,003h,003h,001h,001h,00ah,010h	; 53d6  .............
	defb 011h,001h,005h,005h,005h,005h,001h,001h,005h,001h,001h,00ah,010h	; 53e3  .............
	defb 011h,008h,008h,001h,00ch,00dh,001h,001h,00ch,00dh,001h,00ah,010h	; 53f0  .............
	defb 011h,000h,000h,002h,008h,000h,000h,009h,00ch,00dh,001h,00ah,010h	; 53fd  .............
	defb 011h,000h,000h,002h,008h,000h,000h,009h,00ch,00dh,001h,00ah,00fh	; 540a  .............
	defb 00eh,012h,00bh,00bh,001h,001h,004h,007h,00bh,001h,001h,00ah,010h	; 5417  .............

; ----------------------------------------------------------------------
; DATOS tramos: Diecinueve tramos de seis piezas. Cada byte es una pieza de
;   las 44 de 0xE500, y las seis se ponen una al lado de otra: cuatro columnas
;   cada una. La primera y la ultima suelen ser la pieza 2, que es el borde
;   0x5424..0x5496  (114 bytes)
DATA_tramos:
	defb 002h,003h,003h,003h,003h,002h	; 5424
	defb 002h,003h,004h,003h,004h,002h	; 542a
	defb 002h,005h,006h,006h,007h,002h	; 5430
	defb 008h,006h,009h,00ah,006h,002h	; 5436
	defb 002h,00bh,00bh,00bh,00bh,002h	; 543c
	defb 00dh,00dh,002h,00eh,00dh,002h	; 5442
	defb 002h,012h,013h,013h,014h,002h	; 5448
	defb 002h,00fh,010h,011h,00ch,002h	; 544e
	defb 002h,015h,015h,015h,015h,002h	; 5454
	defb 008h,00fh,003h,011h,005h,002h	; 545a
	defb 016h,017h,018h,019h,01ah,002h	; 5460
	defb 002h,00bh,00eh,00bh,00eh,002h	; 5466
	defb 002h,021h,021h,021h,021h,002h	; 546c
	defb 002h,022h,022h,022h,022h,002h	; 5472
	defb 01bh,01bh,01bh,01bh,01bh,01bh	; 5478
	defb 01ch,01dh,01eh,01fh,020h,002h	; 547e
	defb 024h,024h,025h,024h,024h,024h	; 5484
	defb 023h,023h,026h,023h,023h,023h	; 548a
	defb 027h,027h,028h,027h,027h,027h	; 5490

; ======================================================================
; CODIGO 0x5496..0x54c0  (42 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LAS PIEZAS DEL MAPA. Cada pieza son 24 filas de un byte. Se guardan comprimidas como una lista de indices a un diccionario de 25 grupos de tres filas: ocho indices por pieza.
; ----------------------------------------------------------------------
DESCOMPRIME_PIEZAS:		; Monta las 44 piezas del mapa en 0xE500
	ld de,0e500h		;5496
	ld bc,00160h		;5499   ; 352 grupos de tres bytes = 1056 bytes = 44 piezas
	ld hl,0550bh		;549c   ; la lista de indices; se le acaba en 0x5653 y las tres ultimas piezas salen de leer codigo (nadie las usa)
PIEZAS_GRUPO:
	ld a,(hl)			;549f   ; el byte del mapa es el numero de entrada del diccionario
	add a,a			;54a0   ; por tres, que es lo que ocupa cada entrada
	add a,(hl)			;54a1
	inc hl			;54a2
	exx			;54a3
	ld hl,054c0h		;54a4   ; el diccionario, tres filas por entrada
	call SUMA_A_HL		;54a7
	ld a,(hl)			;54aa
	inc hl			;54ab
	exx			;54ac
	ld (de),a			;54ad   ; las tres filas de la pieza, seguidas, en (DE)
	inc de			;54ae
	exx			;54af
	ld a,(hl)			;54b0
	inc hl			;54b1
	exx			;54b2
	ld (de),a			;54b3
	inc de			;54b4
	exx			;54b5
	ld a,(hl)			;54b6
	exx			;54b7
	ld (de),a			;54b8
	inc de			;54b9
	dec bc			;54ba   ; BC son los grupos que quedan por descomprimir
	ld a,b			;54bb
	or c			;54bc
	jr nz,PIEZAS_GRUPO		;54bd
	ret			;54bf

; ----------------------------------------------------------------------
; DATOS diccionario_del_mapa: Veinticinco grupos de tres filas. 0x5496 arma
;   las piezas de 0xE500 pegando 352 de estos grupos, uno por byte de 0x550B
;   0x54c0..0x550b  (75 bytes)
DATA_diccionario_del_mapa:
	defb 042h,041h,048h	; 54c0
	defb 042h,041h,04ah	; 54c3
	defb 042h,041h,0e1h	; 54c6
	defb 042h,041h,0e5h	; 54c9
	defb 0c2h,0c1h,0e0h	; 54cc
	defb 0c2h,0c1h,0e4h	; 54cf
	defb 0c2h,0c1h,0c8h	; 54d2
	defb 0c2h,0c1h,0cah	; 54d5
	defb 046h,045h,049h	; 54d8
	defb 046h,045h,04bh	; 54db
	defb 046h,045h,0e3h	; 54de
	defb 046h,045h,0e7h	; 54e1
	defb 0c6h,0c5h,0e2h	; 54e4
	defb 0c6h,0c5h,0e6h	; 54e7
	defb 0c6h,0c5h,0c9h	; 54ea
	defb 0c6h,0c5h,0cbh	; 54ed
	defb 042h,041h,040h	; 54f0
	defb 0c2h,0c1h,0c0h	; 54f3
	defb 046h,045h,044h	; 54f6
	defb 0c6h,0c5h,0c4h	; 54f9
	defb 000h,001h,043h	; 54fc
	defb 000h,001h,0c3h	; 54ff
	defb 000h,001h,047h	; 5502
	defb 000h,001h,0c7h	; 5505
	defb 000h,000h,000h	; 5508

; ----------------------------------------------------------------------
; DATOS secuencia_del_mapa: Los indices del diccionario, ocho por pieza (8 x 3
;   = 24 filas). Son 328 bytes para 352 lecturas: las 24 ultimas caen ya en el
;   codigo de 0x5653, y de ahi salen tres piezas de basura -la 41, la 42 y la
;   43- a las que 0x5424 no apunta nunca
;   0x550b..0x5653  (328 bytes)
DATA_secuencia_del_mapa:
	defb 015h,006h,007h,00fh,00fh,00eh,006h,004h	; 550b  ........
	defb 014h,000h,001h,009h,009h,008h,000h,000h	; 5513  ........
	defb 001h,009h,009h,009h,008h,000h,000h,000h	; 551b  ........
	defb 000h,010h,016h,012h,016h,012h,014h,000h	; 5523  ........
	defb 010h,016h,012h,016h,012h,014h,000h,000h	; 552b  ........
	defb 000h,010h,016h,00bh,00dh,012h,014h,000h	; 5533  ........
	defb 010h,016h,012h,017h,013h,014h,000h,000h	; 553b  ........
	defb 000h,010h,016h,009h,009h,012h,014h,000h	; 5543  ........
	defb 000h,001h,009h,00bh,00dh,008h,000h,000h	; 554b  ........
	defb 000h,010h,016h,009h,009h,012h,014h,000h	; 5553  ........
	defb 000h,010h,016h,00bh,00dh,012h,014h,000h	; 555b  ........
	defb 000h,010h,016h,009h,012h,014h,000h,000h	; 5563  ........
	defb 010h,016h,012h,016h,009h,012h,014h,000h	; 556b  ........
	defb 002h,007h,00fh,00fh,00fh,00eh,004h,000h	; 5573  ........
	defb 010h,016h,009h,009h,009h,012h,014h,000h	; 557b  ........
	defb 010h,014h,010h,016h,00bh,013h,014h,000h	; 5583  ........
	defb 010h,014h,003h,013h,016h,012h,014h,000h	; 558b  ........
	defb 010h,014h,001h,012h,017h,013h,014h,000h	; 5593  ........
	defb 000h,001h,012h,017h,013h,014h,000h,000h	; 559b  ........
	defb 010h,016h,009h,00bh,00dh,012h,014h,000h	; 55a3  ........
	defb 000h,000h,010h,016h,012h,014h,000h,000h	; 55ab  ........
	defb 010h,018h,018h,018h,018h,018h,014h,000h	; 55b3  ........
	defb 000h,001h,009h,009h,009h,008h,002h,006h	; 55bb  ........
	defb 000h,010h,017h,013h,016h,012h,015h,006h	; 55c3  ........
	defb 000h,010h,016h,012h,017h,013h,014h,000h	; 55cb  ........
	defb 000h,010h,017h,013h,016h,012h,015h,006h	; 55d3  ........
	defb 000h,010h,016h,012h,016h,012h,015h,006h	; 55db  ........
	defb 018h,018h,018h,018h,018h,018h,018h,018h	; 55e3  ........
	defb 007h,00dh,009h,009h,008h,002h,006h,006h	; 55eb  ........
	defb 004h,010h,018h,018h,018h,016h,00bh,00eh	; 55f3  ........
	defb 010h,018h,018h,018h,018h,018h,015h,006h	; 55fb  ........
	defb 011h,018h,018h,018h,018h,018h,017h,00eh	; 5603  ........
	defb 006h,011h,018h,018h,018h,017h,00eh,006h	; 560b  ........
	defb 010h,018h,018h,018h,018h,018h,018h,018h	; 5613  ........
	defb 018h,018h,018h,018h,018h,018h,018h,014h	; 561b  ........
	defb 006h,007h,00fh,013h,017h,00eh,006h,004h	; 5623  ........
	defb 007h,00fh,013h,017h,00fh,00eh,006h,006h	; 562b  ........
	defb 001h,009h,012h,016h,00bh,00eh,006h,006h	; 5633  ........
	defb 006h,007h,00dh,012h,016h,008h,000h,000h	; 563b  ........
	defb 015h,006h,007h,00fh,00fh,00eh,006h,004h	; 5643  ........
	defb 014h,000h,001h,009h,009h,008h,000h,000h	; 564b  ........

; ======================================================================
; CODIGO 0x5653..0x57cd  (378 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; DIVISION. HL:DE / BC, por restas y desplazamientos: al salir DE es el cociente y HL el resto.
; ----------------------------------------------------------------------
DIVIDE:		; DE = DE / BC, HL = el resto
	ld hl,00000h		;5653
	exx			;5656
	ld b,010h		;5657
DIVIDE_BIT:
	exx			;5659
	sla e		;565a   ; division a restas: un bit por vuelta, y el cociente entra por abajo en DE
	rl d		;565c
	adc hl,hl		;565e
	sbc hl,bc		;5660   ; si el resto se va negativo, se deshace la resta
	jr c,DIVIDE_RESTAURA		;5662
	inc e			;5664
	jr DIVIDE_SIGUE		;5665
DIVIDE_RESTAURA:
	add hl,bc			;5667
DIVIDE_SIGUE:
	exx			;5668
	djnz DIVIDE_BIT		;5669
	exx			;566b
	ret			;566c

; ----------------------------------------------------------------------
; GENERAR EL FONDO. Trae las tiras a 0xEA00, les cambia las tintas y sube a la VRAM los 192 caracteres y sus 192 colores, en los tres tercios.
;
; LOS 192 CARACTERES DEL FONDO. Lo que hay comprimido en el cartucho son
; CUATRO TIRAS de 24 bytes, o sea cuatro columnas de tres caracteres en
; vertical. De ahi salen ocho bloques de 24 caracteres, uno por
; desplazamiento.
;
; Cada bloque son dos mitades de 12: la izquierda de las tiras 1 y 2 y la
; derecha de las 3 y 4. Por eso el volcado escribe siempre un caracter y
; el que esta 12 mas alla: son las dos columnas de la misma pareja.
;
; Y los 12 de cada mitad, llamando A a la tira de arriba y B a la de
; abajo: 0-3 la tira A bajada p pixeles, con relleno arriba y abajo; 4-7
; la tira B igual; y 8-11 las CUATRO COSTURAS (A sobre A, A sobre B, B
; sobre A, B sobre B), que son las que hacen que el dibujo siga siendo
; continuo cuando el desplazamiento deja media fila de un caracter y media
; del de encima.
;
; El relleno es el byte 0x11, que en la tabla de color es negro sobre
; negro.
; ----------------------------------------------------------------------
GENERA_FONDO:		; Los 192 caracteres del fondo y su color, en los tres tercios
	call CARGA_TIRAS		;566d   ; las cuatro tiras de patron y de color a 0xEA00 y 0xEA60
	call CAMBIA_TINTAS		;5670   ; el cambio de tinta de esta pantalla
	ld a,(00006h)		;5673
	ld c,a			;5676
	exx			;5677
	ld hl,0ea00h		;5678   ; patrones: 96 bytes de RAM -> 1536 bytes en la VRAM 0x2200 (caracter 0x40)
	ld de,02200h		;567b
	call VUELCA_TRES_TERCIOS		;567e
	ld hl,0ea60h		;5681   ; color: los mismos 96 bytes -> la VRAM 0x0200
	ld de,00200h		;5684
VUELCA_TRES_TERCIOS:		; El mismo bloque en los tres tercios de SCREEN 2
	ld b,003h		;5687
VUELCA_UN_TERCIO:
	push bc			;5689
	push de			;568a
	push hl			;568b
	ex de,hl			;568c
	call 00053h		;568d   ; BIOS SETWRT - Enables VDP to write
	ex de,hl			;5690
	call OCHO_DESPLAZAMIENTOS		;5691
	pop hl			;5694
	pop de			;5695
	pop bc			;5696
	ld a,008h		;5697   ; el tercio siguiente, 0x800 mas alla
	add a,d			;5699
	ld d,a			;569a
	djnz VUELCA_UN_TERCIO		;569b
	ret			;569d
OCHO_DESPLAZAMIENTOS:		; Los ocho bloques, de 0 a 7 pixeles, de 24 caracteres cada uno
	ld c,000h		;569e
DESPLAZAMIENTO:
	push hl			;56a0
	call DOCE_CARACTERES		;56a1   ; la mitad izquierda: tiras 1 y 2
	pop hl			;56a4
	push hl			;56a5
	ld de,00030h		;56a6   ; la mitad derecha: tiras 3 y 4, 0x30 bytes mas alla
	add hl,de			;56a9
	call DOCE_CARACTERES		;56aa
	pop hl			;56ad
	inc c			;56ae
	ld a,c			;56af
	cp 008h		;56b0   ; ocho desplazamientos
	jr nz,DESPLAZAMIENTO		;56b2
	ret			;56b4
DOCE_CARACTERES:		; Los 12 caracteres de media pareja para el desplazamiento C
	ld (0e300h),hl		;56b5
	ld b,c			;56b8   ; C bytes de relleno: es lo que baja el dibujo
	call SACA_RELLENO		;56b9
	ld b,018h		;56bc   ; la tira A entera, 24 bytes = tres caracteres
	call SACA_BYTES		;56be
	ld a,008h		;56c1   ; y (8-C) de relleno para cerrar el cuarto caracter
	sub c			;56c3
	ld b,a			;56c4
	call SACA_RELLENO		;56c5
	ld b,c			;56c8
	call SACA_RELLENO		;56c9   ; lo mismo con la tira B
	ld b,018h		;56cc
	call SACA_BYTES		;56ce
	ld a,008h		;56d1
	sub c			;56d3
	ld b,a			;56d4
	call SACA_RELLENO		;56d5
	ld de,01000h		;56d8   ; los cuatro caracteres de costura
	call CARACTER_DE_COSTURA		;56db
	ld de,01018h		;56de
	call CARACTER_DE_COSTURA		;56e1
	ld de,02800h		;56e4
	call CARACTER_DE_COSTURA		;56e7
	ld de,02818h		;56ea
CARACTER_DE_COSTURA:		; Un caracter con el final de una tira arriba y el principio de otra abajo
	ld hl,(0e300h)		;56ed   ; D dice de que tira sale la parte de arriba (0x10 = A, 0x28 = B)
	ld a,008h		;56f0
	sub c			;56f2
	add a,d			;56f3
	call SUMA_A_HL		;56f4
	ld b,c			;56f7   ; los C ultimos bytes de esa tira
	call SACA_BYTES		;56f8
	ld hl,(0e300h)		;56fb   ; E dice de que tira sale la parte de abajo (0 = A, 0x18 = B)
	ld d,000h		;56fe
	add hl,de			;5700
	ld a,008h		;5701
	sub c			;5703
	ld b,a			;5704
SACA_BYTES:		; B bytes de (HL) por el puerto de datos del VDP
	inc b			;5705
	dec b			;5706
	ret z			;5707
SACA_BYTES_BUCLE:
	ld a,(hl)			;5708
	inc hl			;5709
	exx			;570a   ; el puerto de datos del VDP esta en C del juego alterno
	out (c),a		;570b
	exx			;570d
	djnz SACA_BYTES_BUCLE		;570e
	ret			;5710
SACA_RELLENO:		; B veces el byte 0x11 (que en la tabla de color es negro sobre negro)
	ld a,011h		;5711
	inc b			;5713
	dec b			;5714
	ret z			;5715
SACA_RELLENO_BUCLE:
	exx			;5716
	out (c),a		;5717
	nop			;5719   ; el nop le deja tiempo al VDP entre byte y byte
	exx			;571a
	djnz SACA_RELLENO_BUCLE		;571b
	ret			;571d

; ----------------------------------------------------------------------
; LAS TIRAS. Cada fase tiene su juego: cuatro punteros a tiras de 24 bytes de patron y cuatro a tiras de color comprimidas.
; ----------------------------------------------------------------------
CARGA_TIRAS:		; Trae a 0xEA00 los patrones y a 0xEA60 el color del fondo de la fase
	ld a,(0e103h)		;571e
	ld hl,057e8h		;5721   ; que juego de fondo lleva esta fase
	call SUMA_A_HL		;5724
	ld a,(hl)			;5727
	add a,a			;5728   ; 16 bytes por juego
	add a,a			;5729
	add a,a			;572a
	add a,a			;572b
	ld hl,057f0h		;572c
	call SUMA_A_HL		;572f
	exx			;5732
	ld de,0ea00h		;5733
	exx			;5736
	ld b,004h		;5737   ; cuatro tiras de patron, 24 bytes cada una
CARGA_TIRAS_BUCLE:
	push bc			;5739
	call COPIA_TIRA		;573a
	pop bc			;573d
	djnz CARGA_TIRAS_BUCLE		;573e
	call DESCOMPRIME_COLOR		;5740   ; y cuatro de color, comprimidas
	call DESCOMPRIME_COLOR		;5743
	call DESCOMPRIME_COLOR		;5746
DESCOMPRIME_COLOR:		; Descomprime en (DE) el bloque de color al que apunta la lista
	ld a,(hl)			;5749   ; los dos bytes de la lista son la direccion del bloque comprimido
	inc hl			;574a
	exx			;574b
	ld l,a			;574c   ; el puntero se arma en el juego alterno, que es donde esta el destino
	exx			;574d
	ld a,(hl)			;574e
	inc hl			;574f
	exx			;5750
	ld h,a			;5751
COLOR_MANDO:
	ld a,(hl)			;5752
	and 07fh		;5753   ; bit 7 puesto: copia n bytes tal cual
	cp (hl)			;5755
	inc hl			;5756
	jr z,COLOR_REPITE		;5757
	ld c,a			;5759
	ld b,000h		;575a
	ldir		;575c
	jr COLOR_MANDO		;575e
COLOR_REPITE:
	and a			;5760   ; un 0 termina el bloque
	exx			;5761
	ret z			;5762
	exx			;5763
	ld b,a			;5764
	ld a,(hl)			;5765
	inc hl			;5766
COLOR_REPITE_BUCLE:
	ld (de),a			;5767
	inc de			;5768
	djnz COLOR_REPITE_BUCLE		;5769
	jr COLOR_MANDO		;576b
COPIA_TIRA:		; Copia a (DE) los 24 bytes de la tira a la que apunta la lista
	ld a,(hl)			;576d   ; los dos bytes de la lista son la direccion de la tira
	inc hl			;576e
	exx			;576f
	ld l,a			;5770
	exx			;5771
	ld a,(hl)			;5772
	inc hl			;5773
	exx			;5774
	ld h,a			;5775
	ld bc,00018h		;5776   ; 24 bytes: una columna de tres caracteres
	ldir		;5779
	exx			;577b
	ret			;577c

; ----------------------------------------------------------------------
; EL CAMBIO DE TINTA. El mismo dibujo sale de otro color en cada pantalla del mundo: se recorren los 96 bytes de color y se cambian tres parejas de tintas.
; ----------------------------------------------------------------------
CAMBIA_TINTAS:		; Cambia tres parejas de tintas en las tiras de color
	ld a,(0e132h)		;577d
	ld hl,057d6h		;5780   ; que cambio lleva esta pantalla (0 = ninguno)
	call SUMA_A_HL		;5783
	ld a,(hl)			;5786
	add a,a			;5787
	ret z			;5788
	add a,(hl)			;5789   ; tres bytes por cambio
	ld hl,TINTA_BUCLE		;578a
	call SUMA_A_HL		;578d
	ld b,003h		;5790
TINTA_UNA:
	push bc			;5792
	ld a,(hl)			;5793
	and 0f0h		;5794   ; nibble alto: la tinta del dibujo
	ld d,a			;5796
	rrca			;5797
	rrca			;5798
	rrca			;5799
	rrca			;579a
	ld e,a			;579b
	ld a,(hl)			;579c
	and 00fh		;579d   ; nibble bajo: la del fondo
	ld c,a			;579f
	rrca			;57a0
	rrca			;57a1
	rrca			;57a2
	rrca			;57a3
	ld b,a			;57a4
	inc hl			;57a5
	push hl			;57a6
	ld hl,0ea60h		;57a7
	exx			;57aa
	ld b,060h		;57ab   ; los 96 bytes de color
TINTA_BYTE:
	exx			;57ad
	ld a,(hl)			;57ae
	and 0f0h		;57af
	cp d			;57b1   ; si el dibujo lleva la tinta vieja, se cambia por la nueva
	jr nz,TINTA_FONDO		;57b2
	ld a,(hl)			;57b4
	and 00fh		;57b5
	or b			;57b7
	ld (hl),a			;57b8
TINTA_FONDO:
	ld a,(hl)			;57b9
	and 00fh		;57ba
	cp e			;57bc   ; y lo mismo con la tinta del fondo
	jr nz,TINTA_SIGUIENTE		;57bd
	ld a,(hl)			;57bf
	and 0f0h		;57c0
	or c			;57c2
	ld (hl),a			;57c3
TINTA_SIGUIENTE:
	inc hl			;57c4
	exx			;57c5
	djnz TINTA_BYTE		;57c6
	pop hl			;57c8
	pop bc			;57c9
TINTA_BUCLE:		; El `djnz` de las tres parejas; los tres bytes que le siguen son el primer cambio de tinta
	djnz TINTA_UNA		;57ca
	ret			;57cc

; ----------------------------------------------------------------------
; DATOS cambios_de_tinta: Tres entradas de tres bytes (la 0 no existe: la base
;   es 0x57CA, que cae dentro del codigo). Cada byte es un par de tintas que
;   0x577D intercambia en las tiras de color, y con eso el mismo dibujo sale
;   de otro color en cada pantalla
;   0x57cd..0x57d6  (9 bytes)
DATA_cambios_de_tinta:
	defb 035h,025h,0c4h	; 57cd
	defb 07bh,059h,048h	; 57d0
	defb 093h,082h,06ch	; 57d3

; ----------------------------------------------------------------------
; DATOS tinta_por_pantalla: Que cambio de tinta lleva cada una de las 18
;   pantallas del mundo (0 = ninguno)
;   0x57d6..0x57e8  (18 bytes)
DATA_tinta_por_pantalla:
	defb 000h,000h,000h,000h,001h,002h,003h,002h,000h,000h,000h,000h,000h,002h,003h,001h,002h,000h	; 57d6  ..................

; ----------------------------------------------------------------------
; DATOS fondo_por_fase: Que juego de fondo usa cada una de las 8 fases (indice
;   0xE103): 0, 2, 3, 4, 2, 3, 4, 1
;   0x57e8..0x57f0  (8 bytes)
DATA_fondo_por_fase:
	defb 000h,002h,003h,004h,002h,003h,004h,001h	; 57e8  ........

; ----------------------------------------------------------------------
; DATOS juegos_de_fondo: Cinco juegos de dieciseis bytes: cuatro punteros a
;   tiras de patrones de 24 bytes y cuatro a tiras de color comprimidas. Los
;   lee 0x571E
;   0x57f0..0x5840  (80 bytes)
DATA_juegos_de_fondo:
	defw 05840h,05840h,05858h,05858h,058a0h,058a0h,058adh,058adh	; 57f0
	defw 05840h,05870h,05858h,05888h,058a0h,058b8h,058adh,058c5h	; 5800
	defw 058d0h,058d0h,058e8h,058e8h,05900h,05900h,05912h,05912h	; 5810
	defw 05922h,05922h,0593ah,0593ah,05952h,05952h,05957h,05957h	; 5820
	defw 0595ch,05974h,0598ch,059a4h,059bch,059c6h,059c9h,059d0h	; 5830

; ----------------------------------------------------------------------
; DATOS tiras_verde: Las cuatro tiras de patrones de los juegos 0 y 1 (las
;   flores). Cada tira son 24 bytes = tres caracteres en columna, y el juego 0
;   repite la misma dos veces
;   0x5840..0x58a0  (96 bytes)
DATA_tiras_verde:
	defb 000h,001h,001h,078h,03eh,01eh,00fh,01eh	; 5840  ...x>...
	defb 07fh,07fh,0f5h,0f2h,0f1h,0f9h,07fh,03fh	; 5848  .......?
	defb 00eh,03dh,07bh,07bh,0f3h,0e3h,0c1h,080h	; 5850  .={{....
	defb 0f0h,0fch,0feh,0c7h,0e3h,0ffh,0ffh,07eh	; 5858  .......~
	defb 080h,0c2h,0c6h,0eeh,0ech,0e0h,0c0h,03eh	; 5860  .......>
	defb 0dch,070h,078h,0bch,0dch,0deh,0ceh,082h	; 5868  .px.....
	defb 00ch,03eh,07fh,018h,034h,018h,0feh,078h	; 5870  .>..4..x
	defb 01dh,07bh,01ch,078h,0f8h,007h,003h,07ch	; 5878  .{.x...|
	defb 01eh,043h,07ch,03eh,01eh,007h,003h,001h	; 5880  .C|>....
	defb 00ch,038h,038h,078h,078h,078h,0f0h,0b8h	; 5888  .88xxx..
	defb 0feh,0feh,050h,0d0h,060h,080h,0feh,0fch	; 5890  ..P.`...
	defb 070h,04fh,0deh,0beh,0bch,07ch,038h,020h	; 5898  pO...|8 

; ----------------------------------------------------------------------
; DATOS tiras_verde_color_0: Color de la tira 1, comprimido (24 bytes)
;   0x58a0..0x58ad  (13 bytes)
DATA_tiras_verde_color_0:
	defb 003h,080h,004h,0c0h,003h,080h,004h,08fh,003h,080h,007h,020h,000h	; 58a0  ........... .

; ----------------------------------------------------------------------
; DATOS tiras_verde_color_1: Color de la tira 2
;   0x58ad..0x58b8  (11 bytes)
DATA_tiras_verde_color_1:
	defb 003h,080h,002h,08fh,008h,080h,002h,082h,009h,020h,000h	; 58ad  ......... .

; ----------------------------------------------------------------------
; DATOS tiras_verde_color_2: Color de la tira 3
;   0x58b8..0x58c5  (13 bytes)
DATA_tiras_verde_color_2:
	defb 003h,050h,003h,0f5h,004h,050h,003h,0c5h,002h,050h,009h,0c0h,000h	; 58b8  .P...P...P...

; ----------------------------------------------------------------------
; DATOS tiras_verde_color_3: Color de la tira 4
;   0x58c5..0x58d0  (11 bytes)
DATA_tiras_verde_color_3:
	defb 007h,0c0h,003h,050h,004h,0f5h,003h,050h,007h,0c0h,000h	; 58c5  ...P...P...

; ----------------------------------------------------------------------
; DATOS tiras_juego_2: Las dos tiras de patrones del juego 2
;   0x58d0..0x5900  (48 bytes)
DATA_tiras_juego_2:
	defb 001h,007h,01fh,03fh,03fh,07fh,07fh,074h	; 58d0  ...??..t
	defb 0efh,0bdh,01bh,0bfh,03fh,0ffh,077h,0feh	; 58d8  ....?.w.
	defb 06fh,07fh,037h,019h,004h,001h,001h,003h	; 58e0  o.7.....
	defb 0c0h,0e0h,0f8h,0f8h,0fch,0feh,0feh,03fh	; 58e8  .......?
	defb 0e0h,0f8h,0feh,0fbh,0fbh,0b7h,0bfh,07fh	; 58f0  ........
	defb 0feh,0eeh,0ech,0d8h,050h,0c0h,0c0h,0e0h	; 58f8  ....P...

; ----------------------------------------------------------------------
; DATOS tiras_juego_2_color_0: Color de la tira 1 del juego 2
;   0x5900..0x5912  (18 bytes)
DATA_tiras_juego_2_color_0:
	defb 007h,030h,085h,02ch,0cfh,0cfh,0c3h,0cfh,003h,0c3h,005h,0c0h,084h,030h,090h,090h	; 5900  .0.,.........0..
	defb 090h,000h	; 5910

; ----------------------------------------------------------------------
; DATOS tiras_juego_2_color_1: Color de la tira 2 del juego 2
;   0x5912..0x5922  (16 bytes)
DATA_tiras_juego_2_color_1:
	defb 005h,030h,083h,020h,020h,02ch,003h,0c2h,009h,0c0h,084h,060h,090h,080h,060h,000h	; 5912  .0.  ,.....`..`.

; ----------------------------------------------------------------------
; DATOS tiras_juego_3: Las dos tiras de patrones del juego 3
;   0x5922..0x5952  (48 bytes)
DATA_tiras_juego_3:
	defb 009h,005h,055h,033h,009h,025h,093h,053h	; 5922  ..U3.%.S
	defb 069h,01dh,005h,017h,093h,051h,039h,00dh	; 592a  i....Q9.
	defb 0a5h,067h,023h,069h,01dh,007h,003h,003h	; 5932  .g#i....
	defb 000h,040h,048h,090h,02ah,04ch,092h,0a4h	; 593a  .@H.*L..
	defb 0b4h,0e6h,0c8h,08ah,092h,0bch,0e1h,0c6h	; 5942  ........
	defb 0cch,0f1h,0e6h,0c8h,0dch,0e0h,0c0h,0c0h	; 594a  ........

; ----------------------------------------------------------------------
; DATOS tiras_juego_3_color_0: Color de la tira 1 del juego 3
;   0x5952..0x5957  (5 bytes)
DATA_tiras_juego_3_color_0:
	defb 001h,070h,017h,050h,000h	; 5952

; ----------------------------------------------------------------------
; DATOS tiras_juego_3_color_1: Color de la tira 2 del juego 3
;   0x5957..0x595c  (5 bytes)
DATA_tiras_juego_3_color_1:
	defb 002h,050h,016h,040h,000h	; 5957

; ----------------------------------------------------------------------
; DATOS tiras_juego_4: Las cuatro tiras de patrones del juego 4 (los moais),
;   todas distintas
;   0x595c..0x59bc  (96 bytes)
DATA_tiras_juego_4:
	defb 007h,00fh,01fh,01fh,020h,002h,017h,02fh	; 595c  .... ../
	defb 01fh,03fh,07fh,07fh,00fh,047h,07fh,01fh	; 5964  .?...G..
	defb 06fh,07fh,0ffh,0ffh,0feh,078h,007h,01fh	; 596c  o....x..
	defb 00eh,03fh,07fh,0feh,0ffh,0ffh,0ffh,07eh	; 5974  .?.....~
	defb 0dch,0dch,06fh,06fh,06fh,06fh,037h,037h	; 597c  ..oooo77
	defb 02fh,01eh,03eh,03fh,03fh,07fh,03fh,000h	; 5984  /.>??.?.
	defb 0e0h,0f8h,0fch,0feh,03eh,01eh,098h,0f6h	; 598c  ....>...
	defb 0feh,0f6h,0f6h,0f6h,0ech,0ech,0ech,0d8h	; 5994  ........
	defb 0d8h,0d8h,0c0h,018h,038h,078h,0f8h,0f8h	; 599c  ....8x..
	defb 000h,000h,080h,0c0h,060h,0c0h,000h,060h	; 59a4  ....`..`
	defb 070h,0f8h,0fch,0fch,0f0h,0e4h,0feh,0fch	; 59ac  p.......
	defb 0fah,0feh,0ffh,03fh,00fh,092h,0e0h,000h	; 59b4  ...?....

; ----------------------------------------------------------------------
; DATOS tiras_juego_4_color_0: Color de la tira 1 del juego 4
;   0x59bc..0x59c6  (10 bytes)
DATA_tiras_juego_4_color_0:
	defb 086h,090h,090h,080h,080h,090h,060h,012h,080h,000h	; 59bc  ......`...

; ----------------------------------------------------------------------
; DATOS tiras_juego_4_color_1: Color de la tira 2 del juego 4
;   0x59c6..0x59c9  (3 bytes)
DATA_tiras_juego_4_color_1:
	defb 018h,090h,000h	; 59c6

; ----------------------------------------------------------------------
; DATOS tiras_juego_4_color_2: Color de la tira 3 del juego 4
;   0x59c9..0x59d0  (7 bytes)
DATA_tiras_juego_4_color_2:
	defb 001h,090h,012h,080h,005h,060h,000h	; 59c9

; ----------------------------------------------------------------------
; DATOS tiras_juego_4_color_3: Color de la tira 4 del juego 4
;   0x59d0..0x59d9  (9 bytes)
DATA_tiras_juego_4_color_3:
	defb 007h,090h,001h,080h,00dh,090h,003h,080h,000h	; 59d0  .........

; ======================================================================
; CODIGO 0x59d9..0x5acf  (246 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; ANIMAR Y MOVER AL JUGADOR. El estado (0xE120) manda: 0 quieto, 1 sube, 2 baja, 3 va a la derecha, 4 a la izquierda, 5 sentado en el trono y 0xFF muriendose.
; ----------------------------------------------------------------------
ANIMA_JUGADOR:		; Un paso de la animacion y del movimiento del jugador
	xor a			;59d9
	ld (0e1f2h),a		;59da
	ld a,(0e11bh)		;59dd   ; con invulnerabilidad va mas deprisa a ratos
	and a			;59e0
	ld c,005h		;59e1
	jr z,ANIMA_VELOCIDAD		;59e3
	ld a,(0e003h)		;59e5
	and 008h		;59e8
	jr z,ANIMA_VELOCIDAD		;59ea
	ld c,007h		;59ec
ANIMA_VELOCIDAD:		; 0xE126 se escribe aqui y no la lee nadie en todo el cartucho
	ld a,c			;59ee
	ld (0e126h),a		;59ef
	ld hl,0e120h		;59f2   ; 0xE120 es el estado del jugador
	ld a,(hl)			;59f5
	and a			;59f6
	jp m,JUGADOR_MURIENDO		;59f7   ; estado negativo: se esta muriendo
	jr nz,ANIMA_POR_ESTADO		;59fa
	inc l			;59fc
	ld c,000h		;59fd   ; parado: el juego de sprites 0 mirando arriba y el 3 mirando abajo
	ld a,(hl)			;59ff
	and a			;5a00
	jr z,ANIMA_ESPERA		;5a01
	ld c,003h		;5a03
ANIMA_ESPERA:
	inc l			;5a05
ANIMA_CUENTA:		; Cuenta atras del fotograma; mientras no llegue a cero no se mueve
	dec (hl)			;5a06
	jr z,ANIMA_SIGUIENTE_PASO		;5a07
	ld a,001h		;5a09
	ld (0e1f2h),a		;5a0b
	ret			;5a0e
ANIMA_SIGUIENTE_PASO:		; Recarga la espera y pasa al fotograma siguiente
	call ANIMA_RECARGA_ESPERA		;5a0f
	inc l			;5a12
	inc l			;5a13
	inc l			;5a14
	ld de,0e130h		;5a15   ; 0xE130 es la cuenta de la animacion de andar
	ld a,(de)			;5a18
	inc a			;5a19
	ld (de),a			;5a1a
	and 003h		;5a1b   ; la animacion es 0, 1, 2, 1, 0...
	cp 003h		;5a1d
	jr nz,ANIMA_PON_SPRITE		;5a1f
	ld a,001h		;5a21
ANIMA_PON_SPRITE:
	add a,c			;5a23
	ld (hl),a			;5a24
	ret			;5a25
ANIMA_POR_ESTADO:		; Se reparte por estados: 1 sube, 2 baja, 3/4 a los lados
	ld de,0e12ah		;5a26   ; 0xE12A es la fraccion de la Y; 0xE123, la parte entera
	inc l			;5a29
	inc l			;5a2a
	inc l			;5a2b
	dec a			;5a2c
	jr nz,ANIMA_BAJA		;5a2d
	ld bc,0ff00h		;5a2f   ; un pixel por paso, y con la bota pixel y medio
	ld a,(0e1a8h)		;5a32   ; 0xE1A8 es la bota: se anda mas rapido
	and a			;5a35
	jr z,ANIMA_SUBE		;5a36
	ld bc,0fe80h		;5a38
ANIMA_SUBE:		; Resta 0x0100 (o 0x0180 con la bota) a la Y del jugador
	ld a,(de)			;5a3b
	add a,c			;5a3c
	ld (de),a			;5a3d
	ld a,b			;5a3e
	adc a,(hl)			;5a3f
	cp 00fh		;5a40   ; tope de arriba: la fila 15
	jr c,ANIMA_SUBE_FIN		;5a42
	ld (hl),a			;5a44
ANIMA_SUBE_FIN:
	ld c,000h		;5a45
	dec l			;5a47
	jr ANIMA_CUENTA		;5a48
ANIMA_BAJA:		; Suma 0x0100 (o 0x0180) a la Y
	dec a			;5a4a
	jr nz,ANIMA_DERECHA		;5a4b
	ld bc,00100h		;5a4d
	ld a,(0e1a8h)		;5a50
	and a			;5a53
	jr z,ANIMA_BAJA_PASO		;5a54
	ld c,080h		;5a56   ; con la bota, tambien pixel y medio hacia abajo
ANIMA_BAJA_PASO:
	ld a,(de)			;5a58
	add a,c			;5a59
	ld (de),a			;5a5a
	ld a,b			;5a5b
	adc a,(hl)			;5a5c
	cp 0aah		;5a5d   ; tope de abajo: 0xAA
	jr nc,ANIMA_BAJA_FIN		;5a5f
	ld (hl),a			;5a61
ANIMA_BAJA_FIN:
	ld c,003h		;5a62
	dec l			;5a64
	jr ANIMA_CUENTA		;5a65
ANIMA_DERECHA:		; Un paso hacia la derecha
	dec a			;5a67
	jr nz,ANIMA_IZQUIERDA		;5a68
	ld bc,00106h		;5a6a
ANIMA_LADO:		; El movimiento lateral, con la curva de empuje que corresponda
	dec l			;5a6d
	dec (hl)			;5a6e
	jr z,ANIMA_PARA		;5a6f
	ld de,05ad4h		;5a71   ; la curva de cuando la pantalla sube
	ld a,(0e102h)		;5a74
	and a			;5a77
	jr z,ANIMA_LADO_PARADO		;5a78
	ld de,05af4h		;5a7a   ; la de cuando baja
ANIMA_LADO_PARADO:
	ld a,(0e113h)		;5a7d
	and a			;5a80
	jr z,ANIMA_LADO_PASO		;5a81
	ld de,05b14h		;5a83   ; y la de cuando el fondo esta parado
ANIMA_LADO_PASO:
	ld a,020h		;5a86   ; la curva se recorre al reves: 0x20 menos lo que queda
	sub (hl)			;5a88
	inc l			;5a89
	call SUMA_A_DE		;5a8a
	ld a,(de)			;5a8d
	add a,(hl)			;5a8e   ; la correccion de la Y del paso lateral, sumada a 0xE123
	ld e,a			;5a8f
	sub 00ah		;5a90   ; topes de la Y: de 0x0A a 0xAA
	cp 0a1h		;5a92
	jr nc,ANIMA_LADO_SPRITE		;5a94
	ld (hl),e			;5a96
ANIMA_LADO_SPRITE:
	inc l			;5a97   ; y la X, que sube o baja de uno en uno
	ld a,(hl)			;5a98
	add a,b			;5a99
	ld (hl),a			;5a9a
	inc l			;5a9b
	ld a,c			;5a9c   ; el juego de sprites: 6 andando a la derecha, 7 a la izquierda
	cp (hl)			;5a9d
	ld (hl),a			;5a9e
	jr nz,ANIMA_LADO_SONIDO		;5a9f
	ld a,001h		;5aa1
	ld (0e1f2h),a		;5aa3
ANIMA_LADO_SONIDO:
	ld a,(0e122h)		;5aa6
	cp 020h		;5aa9   ; al llegar al fotograma 0x20 suena el paso
	ret nz			;5aab
	ld a,001h		;5aac
	jp PIDE_SONIDO		;5aae
ANIMA_IZQUIERDA:		; Un paso hacia la izquierda
	dec a			;5ab1
	jr nz,ANIMA_TRONO		;5ab2
	ld bc,0ff07h		;5ab4
	jr ANIMA_LADO		;5ab7
ANIMA_PARA:		; Vuelve al estado 0
	xor a			;5ab9
	ld (0e120h),a		;5aba
ANIMA_RECARGA_ESPERA:		; Deja en (HL) los fotogramas que dura el paso, segun el estado
	ld de,05acfh		;5abd   ; la tabla de 0x5ACF: 8, 4, 4, 0x21 y 0x21 fotogramas segun el estado
	ld a,(0e120h)		;5ac0
	call SUMA_A_DE		;5ac3
	ld a,(de)			;5ac6
	ld (hl),a			;5ac7
	ret			;5ac8
ANIMA_TRONO:		; Sentado: el juego de sprites 0x0A
	ld a,00ah		;5ac9
	ld (0e125h),a		;5acb
	ret			;5ace

; ----------------------------------------------------------------------
; DATOS espera_por_estado: Los fotogramas que dura cada paso de la animacion
;   segun el estado del jugador (0xE120): 8, 4, 4, 0x21, 0x21
;   0x5acf..0x5ad4  (5 bytes)
DATA_espera_por_estado:
	defb 008h,004h,004h,021h,021h	; 5acf

; ----------------------------------------------------------------------
; DATOS empuje_subiendo: 32 correcciones de la Y, una por fotograma del paso
;   lateral (0x5A8E las suma a 0xE123). Suman +8, que son justo los ocho
;   pixeles que el fondo sube en esos 32 fotogramas: el jugador se queda
;   pegado al mismo sitio del dibujo mientras anda de lado
;   0x5ad4..0x5af4  (32 bytes)
DATA_empuje_subiendo:
	defb 0ffh,0feh,0ffh,0ffh,0ffh,0ffh,0ffh,000h,000h,0ffh,000h,0ffh,000h,000h,000h,001h	; 5ad4  ................
	defb 000h,000h,001h,001h,000h,001h,001h,001h,001h,001h,002h,001h,001h,002h,002h,002h	; 5ae4  ................

; ----------------------------------------------------------------------
; DATOS empuje_bajando: La misma curva para cuando la pantalla baja; esta suma
;   -8
;   0x5af4..0x5b14  (32 bytes)
DATA_empuje_bajando:
	defb 0fch,0feh,0feh,0feh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,000h,0ffh,000h,000h,0ffh,000h	; 5af4  ................
	defb 000h,000h,000h,000h,001h,000h,001h,000h,001h,000h,001h,001h,001h,001h,001h,002h	; 5b04  ................

; ----------------------------------------------------------------------
; DATOS empuje_parado: La curva de cuando el fondo no se mueve; suma 0
;   0x5b14..0x5b34  (32 bytes)
DATA_empuje_parado:
	defb 0fdh,0feh,0feh,0feh,0ffh,0ffh,0ffh,0ffh,0ffh,000h,0ffh,000h,000h,0ffh,000h,000h	; 5b14  ................
	defb 000h,000h,001h,000h,000h,001h,000h,001h,001h,001h,001h,001h,002h,002h,002h,003h	; 5b24  ................

; ======================================================================
; CODIGO 0x5b34..0x5b62  (46 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; MORIRSE. Tres pasos: el sonido y el sprite de muerte, la caida, y avisar de que la fase se ha acabado.
; ----------------------------------------------------------------------
JUGADOR_MURIENDO:		; El jugador se esta muriendo
	ld hl,0e122h		;5b34   ; 0xE122 es la cuenta atras de la animacion
	ld a,(0e187h)		;5b37
	dec a			;5b3a
	jr z,MUERTE_CAE		;5b3b
	dec a			;5b3d
	jr z,MUERTE_FIN		;5b3e
	ld (hl),080h		;5b40   ; 0x80 fotogramas de caida, y el sonido 0x24
	ld a,024h		;5b42
	call PIDE_SONIDO_EN_PARTIDA		;5b44
MUERTE_SIGUIENTE_PASO:
	ld hl,0e187h		;5b47
	inc (hl)			;5b4a
	ret			;5b4b
MUERTE_CAE:		; La animacion de la caida, parpadeando entre dos sprites
	dec (hl)			;5b4c
	jr z,MUERTE_SIGUIENTE_PASO		;5b4d
	ld a,(0e003h)		;5b4f   ; el bit 3 del contador de fotogramas: parpadea entre el juego 8 y el 9
	and 008h		;5b52
	ld a,008h		;5b54
	jr nz,MUERTE_SPRITE		;5b56
	inc a			;5b58
MUERTE_SPRITE:
	ld (0e125h),a		;5b59
	ret			;5b5c
MUERTE_FIN:		; Pone 0xE054 a cero, que es lo que le dice al estado 5 que se acabo
	xor a			;5b5d
	ld (0e054h),a		;5b5e
	ret			;5b61

; ----------------------------------------------------------------------
; DATOS sondas_de_choque: Cuatro desplazamientos (Y, X) que 0x5B6A suma a la
;   posicion del jugador para mirar que caracter hay delante. La base es
;   0x5B60, o sea que el indice empieza en 1
;   0x5b62..0x5b6a  (8 bytes)
DATA_sondas_de_choque:
	defw 000f8h	; 5b62
	defw 0000eh	; 5b64
	defw 02000h	; 5b66
	defw 0e000h	; 5b68

; ======================================================================
; CODIGO 0x5b6a..0x5d32  (456 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL CHOQUE CON EL FONDO. Mira el caracter que hay en la tabla de nombres delante del jugador. Como los caracteres del fondo cambian de numero con el desplazamiento, la comparacion se hace contra 0x40 + 24 * fase, que es donde empieza el bloque que se esta usando ahora mismo.
; ----------------------------------------------------------------------
MIRA_CHOQUE:		; Devuelve carry si el jugador no puede ir en la direccion A
	ld (0e300h),a		;5b6a   ; 0xE300 guarda la direccion que se esta probando
	ld c,a			;5b6d
	ld a,(0e101h)		;5b6e   ; en las primeras filas de las fases 1 y 3 hay que mirar tambien los objetos
	dec a			;5b71
	cp 007h		;5b72
	jr nc,CHOQUE_CON_OBJETO		;5b74
	ld a,(0e103h)		;5b76   ; y ahi dentro, solo las fases 1 y 3 miran el objeto
	dec a			;5b79
	jr z,CHOQUE_CON_OBJETO		;5b7a
	cp 003h		;5b7c
	jr nz,CHOQUE_LATERAL		;5b7e
CHOQUE_CON_OBJETO:
	ld hl,05b60h		;5b80   ; la sonda: cuatro desplazamientos (Y, X) desde el jugador
	ld a,c			;5b83
	and a			;5b84
	jr nz,CHOQUE_SONDA		;5b85
	ld a,(0e102h)		;5b87
	inc a			;5b8a
CHOQUE_SONDA:
	add a,a			;5b8b   ; dos bytes por entrada de la sonda
	call LEE_PALABRA		;5b8c
	ld hl,(0e123h)		;5b8f   ; Y y X del jugador de una vez: L = Y, H = X
	add hl,de			;5b92
	ex de,hl			;5b93
	call MIRA_OBJETO		;5b94   ; y si en ese punto hay un objeto de tipo 5 o 10, tampoco se pasa
	jr nc,CHOQUE_LATERAL		;5b97
	cp 005h		;5b99
	jr nz,CHOQUE_OBJETO_10		;5b9b
	scf			;5b9d
	ret			;5b9e
CHOQUE_OBJETO_10:
	cp 00ah		;5b9f
	scf			;5ba1
	ret z			;5ba2
CHOQUE_LATERAL:		; Al ir a los lados, los bordes de la pantalla son pared
	ld a,(0e300h)		;5ba3   ; la direccion que se guardo al entrar
	ld c,a			;5ba6
	cp 003h		;5ba7   ; solo los estados 3 y 4, que son los lados, miran los bordes
	jr c,CHOQUE_MIRA_CARACTER		;5ba9
	ex af,af'			;5bab
	ld a,(0e1f1h)		;5bac   ; 0xE1F1: el jugador esta llegando a la meta
	and a			;5baf
	ld hl,0e124h		;5bb0
	jr z,CHOQUE_TOPE		;5bb3
	ld a,(0e11eh)		;5bb5
	and a			;5bb8
	jr nz,CHOQUE_TOPE		;5bb9
	ld a,(hl)			;5bbb
	cp 018h		;5bbc   ; topes laterales: 0x18 y 0x98
	ret z			;5bbe
	cp 098h		;5bbf
	ret z			;5bc1
CHOQUE_TOPE:
	ex af,af'			;5bc2
	ld a,098h		;5bc3
	jr z,CHOQUE_TOPE_COMPARA		;5bc5
	ld a,018h		;5bc7
CHOQUE_TOPE_COMPARA:
	cp (hl)			;5bc9
	scf			;5bca
	ret z			;5bcb
CHOQUE_MIRA_CARACTER:		; Lee de la VRAM el caracter que hay en el punto y lo compara con el bloque de esta fase
	ld a,(0e11ch)		;5bcc   ; la fase de 0 a 7...
	add a,a			;5bcf
	add a,a			;5bd0
	add a,a			;5bd1
	ld d,a			;5bd2
	add a,a			;5bd3
	add a,d			;5bd4
	add a,040h		;5bd5   ; ...por 24, mas 0x40: el primer caracter del bloque que se ve ahora
	ld e,a			;5bd7
	ld hl,(0e123h)		;5bd8
	ld a,(0e300h)		;5bdb
	cp 003h		;5bde
	jr c,CHOQUE_CALCULA		;5be0
	ld a,l			;5be2
	sub 004h		;5be3
	ld l,a			;5be5
CHOQUE_CALCULA:
	ld a,l			;5be6   ; B guarda los tres bits de abajo de la Y, que dicen si se esta a caballo de dos filas
	and 007h		;5be7
	ld b,a			;5be9
	call DIRECCION_DE_NOMBRE		;5bea   ; de (Y, X) a la direccion de la tabla de nombres
	ld a,(0e11ch)		;5bed   ; 0xE11C es el desplazamiento de 0 a 7 pixeles del scroll
	ld d,a			;5bf0
	ld a,c			;5bf1
	and a			;5bf2
	jr nz,CHOQUE_POR_SENTIDO		;5bf3
	ld a,(0e102h)		;5bf5
	and a			;5bf8
	jr z,CHOQUE_ARRIBA		;5bf9
	jr CHOQUE_ABAJO_LEE		;5bfb
CHOQUE_MUERTO:		; `xor a / ret` al que no salta nadie: los tres `jr` de 0x5BF3 a 0x5BFB lo pasan de largo
	xor a			;5bfd
	ret			;5bfe
CHOQUE_POR_SENTIDO:		; Reparte por la direccion en la que se quiere andar
	dec a			;5bff
	jr nz,CHOQUE_ABAJO		;5c00
CHOQUE_ARRIBA:		; La casilla de arriba (0x20 filas menos)
	ld a,0e0h		;5c02
	add a,l			;5c04
	ld l,a			;5c05
	jr c,CHOQUE_ARRIBA_LEE		;5c06
	dec h			;5c08
CHOQUE_ARRIBA_LEE:
	call 0004ah		;5c09   ; BIOS RDVRM - Reads the content of VRAM
	and a			;5c0c
	ret z			;5c0d
	sub 003h		;5c0e
	cp e			;5c10
	jr z,CHOQUE_ARRIBA_BORDE		;5c11
	sub 004h		;5c13
	cp e			;5c15
	jr nz,CHOQUE_PARED		;5c16
CHOQUE_ARRIBA_BORDE:
	ld a,d			;5c18
	cp b			;5c19
	ccf			;5c1a
	ret			;5c1b
CHOQUE_PARED:		; Hay pared: carry
	scf			;5c1c
	ret			;5c1d
CHOQUE_ABAJO:		; La casilla de abajo
	dec a			;5c1e
	jr nz,CHOQUE_DERECHA		;5c1f
CHOQUE_ABAJO_LEE:
	ld a,040h		;5c21
	call SUMA_A_HL		;5c23
	call 0004ah		;5c26   ; BIOS RDVRM - Reads the content of VRAM
	and a			;5c29
	ret z			;5c2a
	cp e			;5c2b
	jr z,CHOQUE_ABAJO_BORDE		;5c2c
	sub 004h		;5c2e
	cp e			;5c30
	jr nz,CHOQUE_PARED		;5c31
CHOQUE_ABAJO_BORDE:
	ld a,d			;5c33
	ld a,d			;5c34
	cp b			;5c35
	ret			;5c36
CHOQUE_DERECHA:		; La casilla de la derecha (dos columnas, o cuatro con el escudo)
	dec a			;5c37
	jr nz,CHOQUE_IZQUIERDA		;5c38
	ld c,042h		;5c3a   ; 0x42: dos filas mas abajo y dos columnas a la derecha
	ld a,(0e1a9h)		;5c3c
	and a			;5c3f
	jr z,CHOQUE_LADO_LEE		;5c40
	ld c,044h		;5c42   ; con el escudo (0xE1A9), dos columnas mas alla
CHOQUE_LADO_LEE:
	ld a,c			;5c44
	push bc			;5c45
	and a			;5c46   ; el desplazamiento lleva signo: se extiende a 16 bits
	ld b,000h		;5c47
	jp p,CHOQUE_LADO_SUMA		;5c49
	dec b			;5c4c
CHOQUE_LADO_SUMA:
	add hl,bc			;5c4d
	pop bc			;5c4e
	call 0004ah		;5c4f   ; BIOS RDVRM - Reads the content of VRAM
	and a			;5c52
	ret z			;5c53
	cp e			;5c54
	jr z,CHOQUE_LADO_BORDE		;5c55
	sub 004h		;5c57
	cp e			;5c59
	jr nz,CHOQUE_PARED		;5c5a
CHOQUE_LADO_BORDE:
	inc d			;5c5c
	ld a,d			;5c5d
	cp b			;5c5e
	ret			;5c5f
CHOQUE_IZQUIERDA:		; La casilla de la izquierda
	ld c,03eh		;5c60   ; 0x3E: dos filas mas abajo y dos columnas a la izquierda
	ld a,(0e1a9h)		;5c62
	and a			;5c65
	jr z,CHOQUE_LADO_LEE		;5c66
	ld c,03ch		;5c68   ; con el escudo, otras dos columnas
	jr CHOQUE_LADO_LEE		;5c6a

; ----------------------------------------------------------------------
; DE COORDENADAS A LA TABLA DE NOMBRES. L = Y, H = X; sale la direccion de VRAM 0x3800 + (Y/8)*32 + X/8.
; ----------------------------------------------------------------------
DIRECCION_DE_NOMBRE:		; Direccion de la tabla de nombres del punto (X=H, Y=L)
	ld a,l			;5c6c
	and 0f8h		;5c6d   ; la fila: Y sin los tres bits de abajo
	ld l,a			;5c6f
	ld a,h			;5c70
	ld h,00eh		;5c71   ; 0x0E00 x 4 = 0x3800, que es donde empieza la tabla de nombres
	add hl,hl			;5c73
	add hl,hl			;5c74
	rra			;5c75   ; la columna: X / 8
	rra			;5c76
	rra			;5c77
	and 01fh		;5c78
	or l			;5c7a
	ld l,a			;5c7b
	ret			;5c7c
SENTIDO_POR_MANDO:		; Si solo se pulsa arriba o abajo, cambia el sentido del disparo
	ld a,(0e009h)		;5c7d
	and 003h		;5c80   ; bits 0 y 1 del mando: arriba y abajo
	ret pe			;5c82   ; paridad par quiere decir las dos o ninguna: no se toca el sentido
	rra			;5c83
	ld a,000h		;5c84
	jr c,SENTIDO_GUARDA		;5c86
	inc a			;5c88
SENTIDO_GUARDA:
	ld (0e121h),a		;5c89
	ret			;5c8c

; ----------------------------------------------------------------------
; EL MANDO DEL JUGADOR. Traduce el joystick a estado, mira si se puede ir por ahi y, si no, prueba solo una de las dos direcciones.
; ----------------------------------------------------------------------
MUEVE_CON_EL_MANDO:		; Lee el mando y decide el estado del jugador
	ld a,(0e114h)		;5c8d
	and a			;5c90
	ret nz			;5c91
	ld a,(0e120h)		;5c92   ; con el estado 5 (trono) o mas no se atiende al mando
	cp 005h		;5c95
	ret nc			;5c97
	sub 003h		;5c98
	cp 002h		;5c9a
	jr c,SENTIDO_POR_MANDO		;5c9c
	call ESTADO_DEL_MANDO		;5c9e   ; el estado que pide el mando
	call MIRA_CHOQUE		;5ca1   ; y si se puede ir por ahi
	jr nc,MANDO_LIBRE		;5ca4
	ld a,(0e120h)		;5ca6
	ld c,a			;5ca9
	ld a,(0e009h)		;5caa
	and 003h		;5cad
	jp pe,MANDO_PRUEBA_OTRA		;5caf
	ld c,000h		;5cb2
	rra			;5cb4
	jr nc,MANDO_UNA_SOLA		;5cb5
	inc c			;5cb7
MANDO_UNA_SOLA:
	rra			;5cb8
	jr nc,MANDO_PRUEBA_OTRA		;5cb9
	ld c,002h		;5cbb
MANDO_PRUEBA_OTRA:		; Con dos direcciones a la vez, prueba una sola
	ld a,c			;5cbd
	push bc			;5cbe
	call MIRA_CHOQUE		;5cbf
	pop bc			;5cc2
	jr nc,MANDO_NO_SE_PUEDE		;5cc3
	ld a,(0e003h)		;5cc5   ; un fotograma de cada cuatro, que es cuando el fondo se mueve
	and 003h		;5cc8
	jr nz,MANDO_PARA		;5cca
	ld a,(0e113h)		;5ccc
	and a			;5ccf
	jr nz,MANDO_PARA		;5cd0
	ld a,(0e102h)		;5cd2   ; 0xE102: el empujon va en el sentido de la marcha
	ld d,a			;5cd5
	ld e,0ffh		;5cd6
	and a			;5cd8
	jr nz,MANDO_EMPUJA		;5cd9
	ld e,001h		;5cdb
MANDO_EMPUJA:		; Contra la pared en el sentido del scroll, el jugador se deja empujar un pixel
	ld hl,0e123h		;5cdd
	ld a,(hl)			;5ce0
	add a,e			;5ce1
	ld e,a			;5ce2
	sub 00dh		;5ce3   ; fuera de 0x0D..0xAE se muere: le ha pillado el borde
	cp 0a1h		;5ce5
	jr c,MANDO_MUEVE		;5ce7
	ld a,d			;5ce9
	dec c			;5cea   ; estado menos uno contra 0xE102: iba en el mismo sentido que el scroll
	jp m,MANDO_APLASTADO		;5ceb
	xor c			;5cee
	jr nz,MANDO_PARA		;5cef
MANDO_APLASTADO:		; El scroll le ha aplastado contra el borde: estado 0xFF
	ld a,0ffh		;5cf1
	ld (0e120h),a		;5cf3
	ret			;5cf6
MANDO_MUEVE:
	ld (hl),e			;5cf7
MANDO_PARA:
	xor a			;5cf8
MANDO_PON_ESTADO:
	ld hl,0e120h		;5cf9
	cp (hl)			;5cfc   ; si el estado no cambia, solo se mira el sentido del disparo
	jp z,SENTIDO_POR_MANDO		;5cfd
	ld (hl),a			;5d00
	inc l			;5d01
	dec a			;5d02   ; los estados 1 y 2 dejan tambien el sentido en 0xE121
	cp 002h		;5d03
	jr nc,MANDO_PON_ESPERA		;5d05
	ld (hl),a			;5d07
MANDO_PON_ESPERA:
	inc l			;5d08
	jp ANIMA_RECARGA_ESPERA		;5d09
MANDO_NO_SE_PUEDE:
	ld a,c			;5d0c
	and a			;5d0d
	ret z			;5d0e
	jr MANDO_PON_ESTADO		;5d0f
MANDO_LIBRE:		; Se puede ir: se pone el estado nuevo
	call ESTADO_DEL_MANDO		;5d11
	ld hl,0e120h		;5d14
	cp (hl)			;5d17   ; el mismo estado no reinicia la animacion
	ret z			;5d18
	ld (hl),a			;5d19
	inc l			;5d1a
	dec a			;5d1b   ; estados 1 y 2: sube o baja, y eso es el sentido del disparo
	cp 002h		;5d1c
	jr nc,MANDO_LIBRE_ESPERA		;5d1e
	ld (hl),a			;5d20
MANDO_LIBRE_ESPERA:
	inc l			;5d21
	jp ANIMA_RECARGA_ESPERA		;5d22
ESTADO_DEL_MANDO:		; Traduce el nibble del joystick a estado, con la tabla de 0x5D32
	ld a,(0e009h)		;5d25
	and 00fh		;5d28   ; los cuatro bits de las direcciones
	ld de,05d32h		;5d2a
	call SUMA_A_DE		;5d2d
	ld a,(de)			;5d30
	ret			;5d31

; ----------------------------------------------------------------------
; DATOS mando_a_estado: Los dieciseis valores del nibble del joystick pasados
;   a estado del jugador: 1 arriba, 2 abajo, 3 derecha, 4 izquierda, 0 quieto
;   0x5d32..0x5d42  (16 bytes)
DATA_mando_a_estado:
	defb 000h,001h,002h,000h,004h,004h,004h,004h,003h,003h,003h,003h,000h,001h,002h,000h	; 5d32  ................

; ======================================================================
; CODIGO 0x5d42..0x5db6  (116 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; DIBUJAR AL JUGADOR. Cuatro sprites de 16x16 en 0x3B04, y los patrones cargados a mano en 0x1800 segun el juego que toque.
; ----------------------------------------------------------------------
DIBUJA_JUGADOR:		; Los cuatro sprites del jugador y sus patrones
	ld hl,03b04h		;5d42   ; el sprite 1 de la tabla de atributos; el 0 es para otra cosa
	call PREPARA_ESCRITURA		;5d45
	ld a,(0e125h)		;5d48   ; sentado en el trono los sprites van pegados de otra manera
	ld de,05db6h		;5d4b
	cp 003h		;5d4e
	jr nc,DIBUJA_JUGADOR_POS		;5d50
	ld de,05dbah		;5d52
DIBUJA_JUGADOR_POS:
	ld hl,0e123h		;5d55
	ld c,(hl)			;5d58
	dec a			;5d59
	jr nz,DIBUJA_JUGADOR_POS2		;5d5a
	dec c			;5d5c
DIBUJA_JUGADOR_POS2:
	cp 003h		;5d5d
	jr nz,DIBUJA_JUGADOR_2		;5d5f
	dec c			;5d61
DIBUJA_JUGADOR_2:
	inc l			;5d62
	ld b,(hl)			;5d63   ; la X va justo detras de la Y
	inc l			;5d64
	inc l			;5d65
	exx			;5d66
	ld b,004h		;5d67   ; los cuatro sprites que forman el muneco
DIBUJA_JUGADOR_SPRITE:		; Y, X, numero de patron y color de cada uno de los cuatro
	exx			;5d69
	ld a,(de)			;5d6a
	add a,c			;5d6b
	exx			;5d6c
	out (c),a		;5d6d
	exx			;5d6f
	inc de			;5d70
	ld a,b			;5d71
	exx			;5d72
	out (c),a		;5d73
	exx			;5d75
	exx			;5d76
	ld a,004h		;5d77   ; los patrones van de cuatro en cuatro: 0, 4, 8 y 12
	sub b			;5d79
	add a,a			;5d7a
	add a,a			;5d7b
	out (c),a		;5d7c
	exx			;5d7e
	ld a,(hl)			;5d7f
	inc hl			;5d80
	exx			;5d81
	out (c),a		;5d82
	djnz DIBUJA_JUGADOR_SPRITE		;5d84
	ld a,(0e1f2h)		;5d86   ; 0xE1F2 puesto: el jugador no se dibuja (esta apareciendo o desapareciendo)
	and a			;5d89
	ret nz			;5d8a
	exx			;5d8b
	ld hl,01800h		;5d8c   ; los patrones del jugador se cargan enteros en 0x1800 cada fotograma
	call 00053h		;5d8f   ; BIOS SETWRT - Enables VDP to write
	ld a,(00006h)		;5d92
	ld c,a			;5d95
	ld a,(0e125h)		;5d96
	ld e,a			;5d99
	add a,a			;5d9a
	add a,a			;5d9b
	add a,e			;5d9c
	ld de,05dbeh		;5d9d
	call SUMA_A_DE		;5da0
CARGA_SPRITES_JUGADOR:		; Descomprime los bloques de la lista de 0x5DBE en 0x1800
	ld a,(de)			;5da3
	cp 0ffh		;5da4   ; 0xFF cierra la lista de bloques del juego de sprites
	ret z			;5da6
	inc de			;5da7
	exx			;5da8
	ld hl,0643ah		;5da9   ; 0x643A es la tabla de los 26 bloques de patrones del jugador
	add a,a			;5dac
	call LEE_PALABRA		;5dad
	call RLE_MANDO		;5db0
	exx			;5db3
	jr CARGA_SPRITES_JUGADOR		;5db4

; ----------------------------------------------------------------------
; DATOS sprites_del_trono: Los cuatro desplazamientos en Y de los cuatro
;   sprites del jugador cuando esta sentado
;   0x5db6..0x5dba  (4 bytes)
DATA_sprites_del_trono:
	defb 004h,0f1h,0edh,0fdh	; 5db6

; ----------------------------------------------------------------------
; DATOS sprites_andando: Los cuatro desplazamientos en Y de los cuatro sprites
;   del jugador andando: 0, 1, 2 y otra vez 0
;   0x5dba..0x5dbe  (4 bytes)
DATA_sprites_andando:
	defb 004h,0f1h,0f4h,004h	; 5dba

; ----------------------------------------------------------------------
; DATOS sprites_por_estado: Once filas de cinco: que bloque de la tabla de
;   0x643A carga cada uno de los cuatro cuartos del jugador, y 0xFF donde no
;   hay
;   0x5dbe..0x5df5  (55 bytes)
DATA_sprites_por_estado:
	defb 000h,001h,002h,0ffh,0ffh	; 5dbe
	defb 018h,001h,019h,0ffh,0ffh	; 5dc3
	defb 003h,001h,004h,0ffh,0ffh	; 5dc8
	defb 005h,006h,007h,008h,0ffh	; 5dcd
	defb 016h,006h,007h,017h,0ffh	; 5dd2
	defb 009h,006h,007h,00ah,0ffh	; 5dd7
	defb 00bh,0ffh,0ffh,0ffh,0ffh	; 5ddc
	defb 00ch,0ffh,0ffh,0ffh,0ffh	; 5de1
	defb 00dh,00eh,00fh,010h,0ffh	; 5de6
	defb 011h,012h,00fh,013h,0ffh	; 5deb
	defb 011h,014h,007h,015h,0ffh	; 5df0

; ======================================================================
; CODIGO 0x5df5..0x5e6d  (120 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; DISPARAR. Dos disparos a la vez como mucho; salen hacia arriba o hacia abajo segun 0xE121.
; ----------------------------------------------------------------------
DISPARA:		; Si se pulsa disparo y hay hueco, saca un disparo
	ld a,(0e120h)		;5df5
	and a			;5df8
	ret m			;5df9
	ld a,(0e11fh)		;5dfa
	and a			;5dfd
	ret nz			;5dfe
	ld a,(0e012h)		;5dff
	cp 092h		;5e02
	ret z			;5e04
	ld a,(0e008h)		;5e05   ; bits 4 y 5: las dos teclas de disparo
	and 030h		;5e08
	ret z			;5e0a
	ld b,002h		;5e0b   ; dos huecos de 8 bytes en 0xE1E0
	ld hl,0e1e0h		;5e0d
	ld e,008h		;5e10
	call BUSCA_HUECO		;5e12
	ret c			;5e15
	ld (hl),001h		;5e16
	inc l			;5e18
	ld (hl),014h		;5e19   ; 0xE121: hacia arriba (-4) o hacia abajo (+4)
	ld a,(0e121h)		;5e1b
	and a			;5e1e
	ld a,004h		;5e1f
	jr nz,DISPARA_SENTIDO		;5e21
	ld a,0fch		;5e23
DISPARA_SENTIDO:
	inc hl			;5e25
	ld (hl),a			;5e26
	ld a,0eeh		;5e27
	jr z,DISPARA_POSICION		;5e29
	ld a,00ah		;5e2b
DISPARA_POSICION:
	ld de,(0e123h)		;5e2d   ; Y y X del jugador de una vez: E = Y, D = X
	inc l			;5e31   ; sale 18 pixeles por encima (0xEE) o 10 por debajo
	add a,e			;5e32
	ld (hl),a			;5e33
	inc l			;5e34
	ld (hl),d			;5e35   ; y en la misma X
	inc l			;5e36
	ld (hl),040h		;5e37   ; patron 0x40 y color 15
	inc l			;5e39
	ld (hl),00fh		;5e3a
	ld a,002h		;5e3c
	jp PIDE_SONIDO_EN_PARTIDA		;5e3e
MUEVE_DISPAROS:		; Mueve los dos disparos y los quita cuando se acaba su tiempo o se salen
	ld hl,0e1e0h		;5e41
	call MUEVE_UN_DISPARO		;5e44
	ld l,0e8h		;5e47
MUEVE_UN_DISPARO:
	ld a,(hl)			;5e49
	and a			;5e4a
	ret z			;5e4b
	inc l			;5e4c
	dec (hl)			;5e4d   ; el disparo dura lo que dice su contador
	jr z,MUEVE_DISPARO_FUERA		;5e4e
	inc l			;5e50
	ld a,(hl)			;5e51
	inc l			;5e52
	add a,(hl)			;5e53
	ld c,a			;5e54
	sub 0c0h		;5e55   ; de 0xC0 a 0xFA la Y ya esta fuera de la pantalla: se apaga
	cp 03bh		;5e57
	jr c,MUEVE_DISPARO_APAGA		;5e59
	ld (hl),c			;5e5b
	ret			;5e5c
MUEVE_DISPARO_FUERA:
	inc l			;5e5d
	inc l			;5e5e
MUEVE_DISPARO_APAGA:
	ld (hl),0e0h		;5e5f   ; 0xE0 en la Y: fuera de la pantalla
	dec l			;5e61
	dec l			;5e62
	dec l			;5e63
	ld (hl),000h		;5e64   ; y el tipo a cero: el hueco vuelve a estar libre
	ret			;5e66
CARGA_SPRITES:		; Descomprime en la VRAM 0x1880 los 52 patrones de sprite comunes
	ld de,05e6dh		;5e67
	jp RLE_CON_DIRECCION		;5e6a

; ----------------------------------------------------------------------
; DATOS patrones_de_sprite: 1664 bytes a la VRAM 0x1880, o sea 52 patrones de
;   sprite de 16x16 desde el numero 4: los enemigos, los disparos y los
;   objetos
;   0x5e6d..0x643a  (1485 bytes)
DATA_patrones_de_sprite:
	defb 080h,018h,085h,007h,01fh,033h,06dh,05dh,003h,051h,08dh,06dh,073h,03eh,01eh,0ceh	; 5e6d  .....3m].Q.ms>..
	defb 07bh,0e1h,023h,0c0h,0f0h,098h,06ch,074h,003h,044h,08dh,06ch,09ch,0f8h,0f0h,0ebh	; 5e7d  {.#...lt.D.l....
	defb 0deh,087h,004h,007h,01fh,033h,06dh,05dh,003h,045h,08dh,06dh,073h,03eh,01eh,0ceh	; 5e8d  .....3m].E.ms>..
	defb 07bh,0e1h,020h,0c0h,0f0h,098h,06ch,074h,003h,014h,0e0h,06ch,09ch,0f8h,0f0h,0ebh	; 5e9d  {. ...lt...l....
	defb 0deh,087h,0c4h,01eh,027h,01fh,039h,076h,06ch,0e8h,0a4h,064h,071h,07fh,05fh,017h	; 5ead  ....'.9vl..dq._.
	defb 005h,01bh,07fh,038h,076h,0fch,0ceh,0b7h,095h,086h,0a7h,0a5h,0ceh,0fdh,0fch,0fbh	; 5ebd  ...8v...........
	defb 04eh,078h,060h,01eh,06fh,03fh,079h,036h,06ch,0e8h,0a2h,062h,071h,07fh,02fh,073h	; 5ecd  Nx`.o?y6l..bq./s
	defb 03dh,00fh,003h,030h,07ch,0f0h,0cch,0b6h,096h,087h,095h,095h,0ceh,0feh,0fah,0f8h	; 5edd  =..0|...........
	defb 050h,06ch,07eh,00ch,03eh,00fh,03fh,07fh,07fh,0ffh,0bfh,0bfh,07fh,07fh,05fh,01fh	; 5eed  Pl~.>.?......._.
	defb 00ah,036h,07eh,078h,0f6h,0fch,0feh,0fch,0feh,0ffh,0fdh,003h,0feh,09dh,0f4h,0ceh	; 5efd  .6~x............
	defb 0bch,0f0h,0c0h,01ch,06eh,03fh,07fh,0ffh,0bfh,07fh,0ffh,0bfh,07fh,0bfh,03fh,0dfh	; 5f0d  ....n?........?.
	defb 072h,01eh,006h,078h,0e4h,0f8h,0fch,0feh,0feh,0ffh,0fdh,003h,0feh,08fh,0fah,0e8h	; 5f1d  r..x............
	defb 0a0h,0d8h,0feh,00eh,017h,00fh,039h,036h,06ch,06ah,062h,060h,071h,003h,03fh,08dh	; 5f2d  ......96ljb`q.?.
	defb 01bh,00dh,030h,038h,070h,0f8h,0cch,0b4h,096h,0a6h,0a6h,086h,0ceh,003h,0fch,088h	; 5f3d  ..08p...........
	defb 068h,058h,006h,01ch,00eh,01fh,03fh,03fh,005h,07fh,003h,03fh,088h,016h,01ah,060h	; 5f4d  hX....??...?...`
	defb 070h,0e8h,0f0h,0fch,0fch,005h,0feh,003h,0fch,0dfh,0d8h,0b0h,00ch,000h,000h,03ch	; 5f5d  p..............<
	defb 04fh,03fh,071h,0eeh,059h,0d6h,0c6h,061h,07fh,0bfh,02dh,01ah,07fh,000h,000h,01ch	; 5f6d  O?q.Y..a..-.....
	defb 07ah,0fch,08fh,076h,07bh,01bh,062h,087h,0fdh,0feh,0dah,0ach,07fh,000h,000h,038h	; 5f7d  z..v{.b........8
	defb 05eh,03fh,0ffh,07fh,0ffh,0ffh,07fh,0ffh,0bfh,07fh,06bh,035h,0feh,000h,03ch,0f2h	; 5f8d  ^?........k5..<.
	defb 0fch,0feh,0ffh,0feh,0feh,0ffh,0ffh,0feh,0feh,0fdh,0b4h,058h,0feh,01fh,017h,017h	; 5f9d  ...........X....
	defb 013h,051h,051h,0d1h,0d9h,0dfh,0efh,0efh,0a7h,0a3h,001h,000h,000h,0f8h,0d0h,0d0h	; 5fad  .QQ.............
	defb 090h,014h,016h,037h,077h,0f7h,0efh,0e5h,0e5h,003h,0c0h,09fh,060h,01fh,017h,017h	; 5fbd  ...7w.......`...
	defb 013h,011h,051h,051h,059h,05fh,06fh,04fh,067h,023h,003h,003h,006h,0f8h,0d0h,0d0h	; 5fcd  ..QQY_oOg#......
	defb 090h,014h,014h,036h,076h,0f6h,0eeh,0e4h,0e8h,0c0h,080h,007h,000h,086h,004h,00eh	; 5fdd  ...6v...........
	defb 00fh,007h,003h,001h,00ah,000h,085h,040h,0e0h,0e0h,0c0h,080h,008h,000h,083h,001h	; 5fed  .......@........
	defb 003h,003h,005h,007h,002h,003h,081h,001h,006h,000h,002h,080h,005h,0c0h,002h,080h	; 5ffd  ................
	defb 004h,000h,0a8h,001h,011h,009h,044h,020h,010h,000h,0e0h,000h,010h,020h,044h,009h	; 600d  ......D ..... D.
	defb 011h,001h,000h,000h,010h,020h,044h,008h,010h,000h,00eh,000h,010h,008h,044h,020h	; 601d  ..... D.......D 
	defb 010h,000h,000h,003h,00fh,03fh,03fh,033h,06fh,07fh,07fh,004h,0ffh,08bh,077h,039h	; 602d  .....??3o.....w9
	defb 01fh,003h,000h,040h,0b0h,0d0h,0c8h,0dch,0e6h,003h,0fbh,002h,0fdh,0a9h,0fah,0e6h	; 603d  ...@............
	defb 09ch,070h,000h,003h,00fh,00fh,03fh,07fh,0ffh,0ffh,0feh,0eeh,0efh,077h,01fh,01fh	; 604d  .p....?......w..
	defb 001h,000h,000h,0e0h,0e8h,0d8h,0dch,0dch,09eh,06fh,0f3h,0ffh,03fh,0deh,0e6h,0ech	; 605d  .........o..?...
	defb 0f0h,000h,000h,003h,01fh,037h,07ah,004h,0fdh,003h,07eh,089h,03dh,01eh,007h,000h	; 606d  .....7z...~.=...
	defb 000h,0f0h,0cch,032h,0feh,004h,0ffh,086h,0dfh,0e6h,0f8h,0f0h,0f0h,040h,006h,000h	; 607d  ...2.........@..
	defb 081h,032h,005h,015h,081h,012h,009h,000h,081h,020h,005h,050h,081h,020h,009h,000h	; 608d  .2....... .P. ..
	defb 087h,039h,022h,022h,03ah,00ah,00ah,039h,009h,000h,081h,010h,005h,0a8h,081h,010h	; 609d  .9"":..9........
	defb 009h,000h,081h,064h,005h,02ah,081h,024h,009h,000h,081h,044h,005h,0aah,081h,044h	; 60ad  ...d.*.$...D...D
	defb 009h,000h,087h,022h,055h,015h,025h,045h,045h,072h,009h,000h,081h,022h,005h,055h	; 60bd  ..."U.%EEr...".U
	defb 081h,022h,009h,000h,087h,022h,055h,015h,025h,015h,055h,022h,009h,000h,081h,022h	; 60cd  ."..."U.%.U"..."
	defb 005h,055h,081h,022h,009h,000h,087h,072h,045h,065h,015h,015h,055h,022h,009h,000h	; 60dd  .U."...rEe..U"..
	defb 081h,022h,005h,055h,081h,022h,006h,000h,08dh,007h,019h,031h,025h,025h,023h,039h	; 60ed  .".U.".....1%%#9
	defb 03fh,055h,054h,02ah,02ah,03fh,003h,000h,098h,0e0h,098h,00ch,04eh,04eh,012h,0e8h	; 60fd  ?UT**?......NN..
	defb 058h,058h,090h,0b0h,060h,0c0h,000h,007h,019h,011h,025h,025h,023h,039h,07fh,055h	; 610d  XX..`.....%%#9.U
	defb 055h,003h,000h,002h,02ah,09bh,03fh,0e0h,098h,00ch,04eh,04eh,016h,0eah,04ah,048h	; 611d  U...*.?...NN..JH
	defb 018h,018h,010h,0b0h,0b0h,0e0h,0c0h,000h,030h,034h,03ah,01ah,01dh,00dh,005h,002h	; 612d  ........04:.....
	defb 00eh,003h,01dh,08dh,009h,019h,010h,000h,018h,058h,0b8h,0b0h,070h,060h,040h,080h	; 613d  .........X..p`@.
	defb 0e0h,003h,070h,0ffh,020h,030h,010h,000h,060h,0f4h,0fah,0fah,0f9h,07dh,03dh,01eh	; 614d  ..p. 0..`....}=.
	defb 006h,03dh,07dh,079h,039h,0e1h,0c0h,000h,00ch,05eh,0beh,0beh,03eh,07ch,078h,0f0h	; 615d  .=}y9....^..>|x.
	defb 0c0h,078h,07ch,03ch,038h,01eh,00eh,038h,07ch,06ch,077h,03fh,00bh,00bh,00fh,004h	; 616d  .x|<8..8|lw?....
	defb 003h,007h,00fh,01bh,01bh,002h,03eh,038h,07ch,05ch,0bch,0d8h,040h,040h,0c0h,086h	; 617d  ......>8|\..@@..
	defb 009h,0c8h,0f0h,0b0h,0c8h,0b8h,0e0h,038h,07ch,06ch,077h,03fh,00bh,00bh,00fh,004h	; 618d  .......8|lw?....
	defb 003h,007h,01fh,01bh,023h,03ah,00eh,038h,07ch,05ch,0bch,0d8h,040h,040h,0c0h,086h	; 619d  ....#:.8|\..@@..
	defb 009h,088h,0e8h,0b0h,0b0h,080h,0f8h,000h,001h,039h,07ch,06dh,07fh,036h,006h,007h	; 61ad  .........9|m.6..
	defb 003h,001h,007h,01dh,01bh,007h,03eh,0e0h,0f0h,0b0h,070h,0a0h,0c0h,0ach,0ach,0f0h	; 61bd  ......>...p.....
	defb 0e6h,089h,0f0h,0ffh,0dch,0ech,070h,03eh,007h,00fh,00dh,00eh,005h,003h,035h,035h	; 61cd  ......p>......55
	defb 00fh,007h,001h,007h,01dh,01bh,007h,03eh,000h,080h,09ch,03eh,0b6h,0feh,06ch,060h	; 61dd  .......>...>..l`
	defb 0e0h,0c6h,089h,0f0h,0dch,0ech,070h,03eh,000h,003h,017h,027h,02fh,02fh,097h,0cdh	; 61ed  ......p>...'//..
	defb 07dh,07fh,03fh,00dh,022h,01ch,001h,003h,0c0h,080h,038h,044h,0b0h,0fch,0feh,0beh	; 61fd  }.?.".....8D....
	defb 0b3h,0e9h,0f4h,0f4h,0e4h,0e8h,0c0h,000h,004h,008h,018h,01dh,05fh,05fh,04fh,025h	; 620d  ............__O%
	defb 01dh,00fh,09fh,07eh,038h,001h,00eh,000h,000h,070h,080h,03ch,07eh,0f2h,0f1h,0b8h	; 621d  ...~8....p.<~...
	defb 0a4h,0f2h,0f2h,0fah,0b8h,018h,010h,020h,003h,004h,028h,049h,065h,073h,07fh,03dh	; 622d  ....... ..(Ies.=
	defb 09dh,087h,04fh,037h,007h,02fh,01eh,000h,000h,078h,0e4h,0c0h,0cch,0d2h,0e1h,0b9h	; 623d  ..O7./...x......
	defb 0bch,0feh,0feh,0fdh,0a6h,092h,014h,020h,0c0h,000h,000h,001h,007h,00fh,01fh,03fh	; 624d  ....... .......?
	defb 031h,061h,06dh,0cdh,0c1h,0c3h,0ffh,0f7h,063h,000h,000h,0f0h,0d8h,0e8h,0f0h,018h	; 625d  1am.....c.......
	defb 00ch,006h,066h,067h,007h,08fh,0ffh,0beh,01ch,000h,00fh,01fh,01fh,00eh,010h,03fh	; 626d  ..fg...........?
	defb 071h,061h,061h,0cdh,0cdh,0c3h,0ffh,0deh,08ch,000h,080h,0c0h,060h,078h,0f8h,01ch	; 627d  qaa.........`x..
	defb 00ch,006h,006h,067h,067h,08fh,0ffh,0f7h,062h,003h,00ch,013h,02dh,058h,055h,0b5h	; 628d  ...gg...b...-XU.
	defb 0b8h,0bdh,0b5h,055h,058h,02dh,013h,00ch,003h,0c0h,030h,0c8h,0b4h,01ah,0aah,0bdh	; 629d  ...UX-....0.....
	defb 01dh,0adh,0adh,0aah,01ah,0b4h,0c8h,030h,0c0h,001h,006h,00bh,00dh,018h,015h,015h	; 62ad  .......0........
	defb 018h,01dh,015h,015h,018h,00dh,00bh,006h,001h,0c0h,030h,0d8h,068h,02ch,054h,074h	; 62bd  ..........0.h,Tt
	defb 034h,003h,054h,085h,02ch,068h,0d8h,030h,0c0h,010h,001h,010h,080h,008h,000h,0b5h	; 62cd  4.T.,h.0........
	defb 001h,007h,01fh,07eh,039h,007h,03fh,01eh,030h,018h,00eh,008h,018h,03ch,06eh,0deh	; 62dd  ...~9.?.0....<n.
	defb 0deh,0bch,07ch,0f8h,0f0h,0e0h,080h,000h,006h,003h,01ah,03ch,03dh,01bh,023h,071h	; 62ed  ..|........<=.#q
	defb 076h,02fh,00fh,036h,078h,036h,046h,070h,060h,040h,0dch,036h,0bah,0c7h,0d8h,0bch	; 62fd  v/.6x6Fp`@.6....
	defb 03ch,058h,060h,0e0h,0c0h,003h,000h,09dh,004h,00eh,007h,00bh,005h,002h,001h,003h	; 630d  <X`.............
	defb 007h,00eh,01dh,03ah,074h,028h,010h,000h,004h,00eh,01ch,0bah,0f4h,0e8h,0f0h,0b8h	; 631d  ...:t(..........
	defb 05ch,0aeh,014h,00ah,004h,003h,000h,0e6h,003h,019h,03dh,02eh,072h,04dh,07bh,07dh	; 632d  \.........=.rM{}
	defb 0efh,0d3h,0f8h,04eh,015h,039h,017h,003h,000h,040h,0b0h,050h,0c8h,090h,0e4h,052h	; 633d  ...N.9...@.P...R
	defb 0bbh,0bbh,07dh,0bdh,0cah,0e6h,09ch,070h,003h,006h,004h,00fh,00ah,030h,07eh,0ffh	; 634d  ..}....p.....0~.
	defb 0feh,079h,007h,007h,00fh,00fh,007h,000h,0e0h,010h,030h,0e0h,0deh,0a1h,041h,063h	; 635d  .y........0...Ac
	defb 07fh,01ah,0e5h,0ffh,0feh,0f4h,0e0h,000h,059h,033h,06ch,051h,027h,02eh,04eh,05eh	; 636d  ........Y3lQ'.N^
	defb 05eh,04fh,02fh,027h,011h,00ch,013h,030h,01ah,0cch,036h,08ah,0e4h,0f4h,0f2h,0fah	; 637d  ^O/'...0..6.....
	defb 01ah,0f2h,0f4h,0e4h,088h,030h,0c8h,00ch,000h,000h,003h,00fh,01fh,01fh,003h,03fh	; 638d  .....0.........?
	defb 002h,01fh,082h,00fh,003h,005h,000h,08bh,080h,0e0h,0f0h,0d0h,0f8h,0e8h,0f8h,0d0h	; 639d  ................
	defb 0b0h,0e0h,080h,003h,000h,081h,003h,003h,0ffh,002h,0c0h,092h,0ffh,003h,0ffh,0fdh	; 63ad  ................
	defb 0f9h,0f0h,0c0h,0ffh,003h,003h,0c0h,0ffh,0bfh,09fh,00fh,003h,0ffh,0c0h,003h,0ffh	; 63bd  ................
	defb 002h,003h,0e3h,0ffh,0c0h,0c0h,003h,003h,0ffh,0cfh,08fh,0ceh,0cch,0c9h,0f3h,0e7h	; 63cd  ................
	defb 0cfh,0ffh,000h,002h,003h,003h,080h,080h,0feh,09eh,03eh,07eh,0c6h,086h,026h,002h	; 63dd  ..........>~..&.
	defb 0e6h,0feh,000h,000h,080h,080h,003h,003h,0ffh,0efh,0cfh,0eeh,0ech,0e9h,0f3h,0e7h	; 63ed  ................
	defb 0cfh,0ffh,000h,002h,003h,003h,080h,080h,0feh,09eh,03eh,07eh,0c6h,092h,0e6h,0ceh	; 63fd  ..........>~....
	defb 082h,0feh,000h,000h,080h,080h,003h,003h,0ffh,083h,0f3h,0c7h,0f3h,0b2h,0c4h,0f9h	; 640d  ................
	defb 0f3h,0ffh,000h,002h,003h,003h,0c0h,0c0h,0ffh,0e7h,0cfh,09fh,023h,043h,093h,081h	; 641d  ............#C..
	defb 0f3h,0ffh,000h,000h,0c0h,0c0h,008h,000h,081h,001h,017h,000h,000h	; 642d  .............

; ----------------------------------------------------------------------
; DATOS tabla_de_sprites_del_jugador: Los 26 bloques de patrones que 0x5DA3
;   puede cargar en 0x1800 para el jugador
;   0x643a..0x646e  (52 bytes)
DATA_tabla_de_sprites_del_jugador:
	defw 0646eh	; 643a  -> DATA_sprite_00
	defw 0648dh	; 643c  -> DATA_sprite_01
	defw 064beh	; 643e  -> DATA_sprite_02
	defw 064d1h	; 6440  -> DATA_sprite_03
	defw 064f0h	; 6442  -> DATA_sprite_04
	defw 06503h	; 6444  -> DATA_sprite_05
	defw 06521h	; 6446  -> DATA_sprite_06
	defw 0653bh	; 6448  -> DATA_sprite_07
	defw 0654dh	; 644a  -> DATA_sprite_08
	defw 0656fh	; 644c  -> DATA_sprite_09
	defw 0658dh	; 644e  -> DATA_sprite_10
	defw 065afh	; 6450  -> DATA_sprite_11
	defw 0660fh	; 6452  -> DATA_sprite_12
	defw 0666fh	; 6454  -> DATA_sprite_13
	defw 0668dh	; 6456  -> DATA_sprite_14
	defw 066a7h	; 6458  -> DATA_sprite_15
	defw 066b9h	; 645a  -> DATA_sprite_16
	defw 066d9h	; 645c  -> DATA_sprite_17
	defw 066f7h	; 645e  -> DATA_sprite_18
	defw 06712h	; 6460  -> DATA_sprite_19
	defw 06734h	; 6462  -> DATA_sprite_20
	defw 0674eh	; 6464  -> DATA_sprite_21
	defw 06770h	; 6466  -> DATA_sprite_22
	defw 06790h	; 6468  -> DATA_sprite_23
	defw 067b2h	; 646a  -> DATA_sprite_24
	defw 067ceh	; 646c  -> DATA_sprite_25

; ----------------------------------------------------------------------
; DATOS sprite_00: El bloque 0 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x646e..0x648d  (31 bytes)
DATA_sprite_00:
	defb 08ch,004h,007h,007h,00fh,000h,00fh,00eh	; 646e  ........
	defb 00eh,00eh,00eh,01eh,03eh,004h,000h,08ch	; 6476  ....>...
	defb 040h,0c0h,0c0h,0e0h,000h,0e0h,0e0h,080h	; 647e  @.......
	defb 060h,0f0h,0f0h,070h,004h,000h,000h	; 6486

; ----------------------------------------------------------------------
; DATOS sprite_01: El bloque 1 de la tabla de 0x643A: 64 bytes de patron (2
;   sprites de 16x16) a la VRAM 0x1800
;   0x648d..0x64be  (49 bytes)
DATA_sprite_01:
	defb 006h,000h,08ah,007h,00fh,00fh,016h,059h	; 648d  .......Y
	defb 05fh,05fh,02fh,01ch,00fh,006h,000h,08ah	; 6495  __/.....
	defb 080h,0c0h,0e0h,0f4h,0fch,0f4h,0e8h,0d8h	; 649d  ........
	defb 070h,0c0h,004h,000h,08ch,0c0h,040h,020h	; 64a5  p.....@ 
	defb 020h,000h,000h,000h,020h,030h,018h,00fh	; 64ad   ... 0..
	defb 005h,00ch,000h,084h,010h,060h,0e0h,040h	; 64b5  .....`.@
	defb 000h	; 64bd

; ----------------------------------------------------------------------
; DATOS sprite_02: El bloque 2 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x64be..0x64d1  (19 bytes)
DATA_sprite_02:
	defb 086h,003h,018h,038h,0f0h,0efh,040h,00ah	; 64be  ...8..@.
	defb 000h,086h,080h,020h,030h,010h,0f0h,010h	; 64c6  ... 0...
	defb 00ah,000h,000h	; 64ce

; ----------------------------------------------------------------------
; DATOS sprite_03: El bloque 3 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x64d1..0x64f0  (31 bytes)
DATA_sprite_03:
	defb 08ch,004h,007h,007h,00fh,000h,00fh,00eh	; 64d1  ........
	defb 002h,00ch,01eh,01eh,01ch,004h,000h,08ch	; 64d9  ........
	defb 040h,0c0h,0c0h,0e0h,000h,0e0h,0e0h,0e0h	; 64e1  @.......
	defb 0e0h,0e0h,0f0h,0f8h,004h,000h,000h	; 64e9

; ----------------------------------------------------------------------
; DATOS sprite_04: El bloque 4 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x64f0..0x6503  (19 bytes)
DATA_sprite_04:
	defb 086h,003h,008h,018h,010h,01fh,010h,00ah	; 64f0  ........
	defb 000h,086h,080h,030h,038h,01eh,0eeh,004h	; 64f8  ...08...
	defb 00ah,000h,000h	; 6500

; ----------------------------------------------------------------------
; DATOS sprite_05: El bloque 5 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x6503..0x6521  (30 bytes)
DATA_sprite_05:
	defb 08ch,000h,004h,007h,007h,00fh,000h,003h	; 6503  ........
	defb 00eh,00eh,00eh,01eh,03eh,005h,000h,08bh	; 650b  ....>...
	defb 040h,0c0h,0c0h,0e0h,000h,0e0h,0e0h,098h	; 6513  @.......
	defb 078h,0f8h,070h,004h,000h,000h	; 651b

; ----------------------------------------------------------------------
; DATOS sprite_06: El bloque 6 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x6521..0x653b  (26 bytes)
DATA_sprite_06:
	defb 006h,000h,089h,00ch,003h,000h,000h,000h	; 6521  ........
	defb 006h,00eh,008h,008h,007h,000h,08ah,0f0h	; 6529  ........
	defb 0d8h,068h,01ah,00eh,0c4h,0e0h,020h,020h	; 6531  .h....  
	defb 000h,000h	; 6539

; ----------------------------------------------------------------------
; DATOS sprite_07: El bloque 7 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x653b..0x654d  (18 bytes)
DATA_sprite_07:
	defb 00bh,000h,085h,03ch,05fh,03fh,07bh,040h	; 653b  ...<_?{@
	defb 00ah,000h,086h,001h,002h,086h,0e4h,050h	; 6543  .......P
	defb 018h,000h	; 654b

; ----------------------------------------------------------------------
; DATOS sprite_08: El bloque 8 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x654d..0x656f  (34 bytes)
DATA_sprite_08:
	defb 0a0h,011h,011h,031h,03bh,03bh,03fh,01bh	; 654d  ...1;;?.
	defb 00ch,003h,008h,018h,030h,03fh,01ch,000h	; 6555  ....0?..
	defb 000h,000h,016h,016h,0feh,0fch,0b0h,070h	; 655d  .......p
	defb 0e0h,080h,030h,038h,01eh,0eeh,004h,000h	; 6565  ..08....
	defb 000h,000h	; 656d

; ----------------------------------------------------------------------
; DATOS sprite_09: El bloque 9 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x656f..0x658d  (30 bytes)
DATA_sprite_09:
	defb 08ch,000h,004h,007h,007h,00fh,000h,00fh	; 656f  ........
	defb 00eh,032h,03ch,03eh,01ch,005h,000h,08bh	; 6577  .2<>....
	defb 040h,0c0h,0c0h,0e0h,000h,080h,0e0h,0e0h	; 657f  @.......
	defb 0e0h,0f0h,0f8h,004h,000h,000h	; 6587

; ----------------------------------------------------------------------
; DATOS sprite_10: El bloque 10 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x658d..0x65af  (34 bytes)
DATA_sprite_10:
	defb 0a0h,011h,011h,031h,03bh,03bh,03fh,01bh	; 658d  ...1;;?.
	defb 00ch,003h,018h,038h,0f0h,0efh,000h,000h	; 6595  ...8....
	defb 000h,000h,016h,016h,0feh,0fch,0b0h,070h	; 659d  .......p
	defb 0e0h,080h,020h,030h,018h,0f8h,070h,000h	; 65a5  .. 0..p.
	defb 000h,000h	; 65ad

; ----------------------------------------------------------------------
; DATOS sprite_11: El bloque 11 de la tabla de 0x643A: 128 bytes de patron (4
;   sprites de 16x16) a la VRAM 0x1800
;   0x65af..0x660f  (96 bytes)
DATA_sprite_11:
	defb 08ch,000h,000h,003h,003h,007h,000h,00fh	; 65af  ........
	defb 07fh,0deh,0f8h,0c0h,080h,006h,000h,086h	; 65b7  ........
	defb 0c0h,0c1h,0c3h,01fh,0fdh,0ffh,00eh,000h	; 65bf  ........
	defb 089h,01ch,03fh,01fh,04ah,074h,07ch,0f9h	; 65c7  ..?.Jt|.
	defb 0c1h,080h,006h,000h,089h,020h,080h,080h	; 65cf  ..... ..
	defb 080h,000h,000h,0c0h,080h,080h,00ch,000h	; 65d7  ........
	defb 085h,080h,0c0h,060h,031h,003h,00bh,000h	; 65df  ...`1...
	defb 0a6h,048h,024h,06ch,0f8h,074h,018h,000h	; 65e7  .H$l.t..
	defb 012h,03fh,02fh,03fh,01fh,00fh,007h,01bh	; 65ef  .?/?....
	defb 0bch,0fch,060h,007h,000h,000h,000h,020h	; 65f7  ..`.... 
	defb 020h,0f8h,0f8h,0f8h,072h,0b6h,0e6h,08eh	; 65ff   ...r...
	defb 03ch,038h,000h,080h,000h,000h,000h,000h	; 6607  <8......

; ----------------------------------------------------------------------
; DATOS sprite_12: El bloque 12 de la tabla de 0x643A: 128 bytes de patron (4
;   sprites de 16x16) a la VRAM 0x1800
;   0x660f..0x666f  (96 bytes)
DATA_sprite_12:
	defb 088h,000h,000h,003h,083h,0c3h,0f8h,0bfh	; 660f  ........
	defb 0ffh,00ah,000h,08ah,0c0h,0c0h,0e0h,000h	; 6617  ........
	defb 0f0h,0feh,07bh,01fh,003h,001h,009h,000h	; 661f  ..{.....
	defb 089h,004h,001h,001h,001h,000h,000h,003h	; 6627  ........
	defb 001h,001h,008h,000h,089h,038h,0fch,0feh	; 662f  .....8..
	defb 05eh,02eh,03eh,01fh,003h,001h,00bh,000h	; 6637  ^.>.....
	defb 086h,012h,024h,036h,01fh,02eh,018h,00ah	; 663f  ..$6....
	defb 000h,093h,001h,003h,000h,080h,0c0h,000h	; 6647  ........
	defb 004h,004h,01fh,01fh,01fh,04eh,06dh,067h	; 664f  .....Nmg
	defb 071h,03ch,01ch,000h,001h,004h,000h,08fh	; 6657  q<......
	defb 048h,0fch,0f4h,0fch,0f8h,0f0h,0e0h,0d8h	; 665f  H.......
	defb 03dh,03fh,006h,0e0h,000h,000h,000h,000h	; 6667  =?......

; ----------------------------------------------------------------------
; DATOS sprite_13: El bloque 13 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x666f..0x668d  (30 bytes)
DATA_sprite_13:
	defb 08ch,000h,004h,007h,007h,008h,00fh,00fh	; 666f  ........
	defb 09eh,0dch,0f8h,078h,030h,005h,000h,08bh	; 6677  ...x0...
	defb 040h,0c0h,0c0h,020h,0e0h,0e0h,0f2h,076h	; 667f  @.. ...v
	defb 03eh,03ch,018h,004h,000h,000h	; 6687

; ----------------------------------------------------------------------
; DATOS sprite_14: El bloque 14 de la tabla de 0x643A: 31 bytes de patron (0
;   sprites de 16x16) a la VRAM 0x1800
;   0x668d..0x66a7  (26 bytes)
DATA_sprite_14:
	defb 006h,000h,089h,003h,004h,001h,010h,040h	; 668d  .......@
	defb 00dh,019h,019h,01dh,006h,000h,08ah,0c0h	; 6695  ........
	defb 000h,0f0h,018h,0c8h,0ech,034h,030h,0f0h	; 669d  .....40.
	defb 0e0h,000h	; 66a5

; ----------------------------------------------------------------------
; DATOS sprite_15: El bloque 15 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x66a7..0x66b9  (18 bytes)
DATA_sprite_15:
	defb 00ah,000h,085h,028h,051h,05ah,06fh,038h	; 66a7  ...(QZo8
	defb 00bh,000h,086h,002h,004h,004h,040h,020h	; 66af  ......@ 
	defb 000h,000h	; 66b7

; ----------------------------------------------------------------------
; DATOS sprite_16: El bloque 16 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x66b9..0x66d9  (32 bytes)
DATA_sprite_16:
	defb 08dh,022h,0a2h,0e2h,07fh,078h,030h,0d0h	; 66b9  ."...x0.
	defb 0cfh,0e3h,078h,038h,00fh,00fh,005h,000h	; 66c1  ..x8....
	defb 08eh,004h,01ch,078h,038h,036h,0e6h,08eh	; 66c9  ...x86..
	defb 03ch,038h,0e0h,0e0h,000h,000h,000h,000h	; 66d1  <8......

; ----------------------------------------------------------------------
; DATOS sprite_17: El bloque 17 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x66d9..0x66f7  (30 bytes)
DATA_sprite_17:
	defb 08ch,000h,004h,007h,007h,00fh,000h,00fh	; 66d9  ........
	defb 00eh,00eh,00eh,03ch,07ch,005h,000h,08bh	; 66e1  ...<|...
	defb 040h,0c0h,0c0h,0e0h,000h,0e0h,0e0h,0e0h	; 66e9  @.......
	defb 0e0h,078h,07ch,004h,000h,000h	; 66f1

; ----------------------------------------------------------------------
; DATOS sprite_18: El bloque 18 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x66f7..0x6712  (27 bytes)
DATA_sprite_18:
	defb 006h,000h,08ah,003h,004h,001h,010h,040h	; 66f7  .......@
	defb 01eh,032h,032h,03eh,01ch,006h,000h,08ah	; 66ff  .22>....
	defb 0c0h,000h,0f0h,018h,008h,0cch,064h,060h	; 6707  ......d`
	defb 0e0h,000h,000h	; 670f

; ----------------------------------------------------------------------
; DATOS sprite_19: El bloque 19 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x6712..0x6734  (34 bytes)
DATA_sprite_19:
	defb 0a0h,001h,081h,0c1h,063h,078h,030h,010h	; 6712  ....cx0.
	defb 00fh,003h,018h,078h,0efh,0cfh,0cfh,000h	; 671a  ...x....
	defb 000h,010h,010h,014h,0fch,078h,038h,030h	; 6722  .....x80
	defb 0e0h,080h,030h,03ch,0eeh,0e6h,0e6h,000h	; 672a  ..0<....
	defb 000h,000h	; 6732

; ----------------------------------------------------------------------
; DATOS sprite_20: El bloque 20 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x6734..0x674e  (26 bytes)
DATA_sprite_20:
	defb 006h,000h,089h,00ch,003h,000h,000h,000h	; 6734  ........
	defb 006h,008h,008h,00eh,007h,000h,08ah,0f0h	; 673c  ........
	defb 0d8h,068h,01ah,00eh,0c4h,020h,020h,0e0h	; 6744  .h...  .
	defb 000h,000h	; 674c

; ----------------------------------------------------------------------
; DATOS sprite_21: El bloque 21 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x674e..0x6770  (34 bytes)
DATA_sprite_21:
	defb 0a0h,011h,011h,031h,03dh,03fh,030h,018h	; 674e  ...1=?0.
	defb 00ch,003h,008h,018h,03fh,07fh,06fh,0e0h	; 6756  ....?.o.
	defb 000h,000h,016h,016h,0feh,0fch,010h,030h	; 675e  .......0
	defb 060h,080h,020h,030h,0f8h,0fch,0fch,00eh	; 6766  `. 0....
	defb 000h,000h	; 676e

; ----------------------------------------------------------------------
; DATOS sprite_22: El bloque 22 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x6770..0x6790  (32 bytes)
DATA_sprite_22:
	defb 09ch,000h,004h,007h,007h,00fh,000h,007h	; 6770  ........
	defb 006h,00eh,00eh,01eh,01eh,000h,000h,000h	; 6778  ........
	defb 000h,000h,040h,0c0h,0c0h,0e0h,000h,0c0h	; 6780  ..@.....
	defb 0c0h,0e0h,0e0h,0f0h,0f0h,004h,000h,000h	; 6788  ........

; ----------------------------------------------------------------------
; DATOS sprite_23: El bloque 23 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x6790..0x67b2  (34 bytes)
DATA_sprite_23:
	defb 0a0h,011h,011h,031h,03bh,03bh,03fh,01bh	; 6790  ...1;;?.
	defb 00ch,003h,008h,018h,030h,03fh,038h,018h	; 6798  ....0?8.
	defb 000h,000h,016h,016h,0feh,0fch,0b0h,070h	; 67a0  .......p
	defb 0e0h,080h,020h,030h,018h,0f8h,038h,030h	; 67a8  .. 0..80
	defb 000h,000h	; 67b0

; ----------------------------------------------------------------------
; DATOS sprite_24: El bloque 24 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x67b2..0x67ce  (28 bytes)
DATA_sprite_24:
	defb 086h,004h,007h,007h,00fh,000h,00fh,004h	; 67b2  ........
	defb 00eh,082h,01eh,01eh,004h,000h,085h,040h	; 67ba  .......@
	defb 0c0h,0c0h,0e0h,000h,005h,0e0h,082h,0f0h	; 67c2  ........
	defb 0f0h,004h,000h,000h	; 67ca

; ----------------------------------------------------------------------
; DATOS sprite_25: El bloque 25 de la tabla de 0x643A: 32 bytes de patron (1
;   sprites de 16x16) a la VRAM 0x1800
;   0x67ce..0x67e1  (19 bytes)
DATA_sprite_25:
	defb 086h,003h,008h,018h,030h,03fh,010h,00ah	; 67ce  ....0?..
	defb 000h,086h,080h,020h,030h,018h,0f8h,010h	; 67d6  ... 0...
	defb 00ah,000h,000h	; 67de

; ======================================================================
; CODIGO 0x67e1..0x6863  (130 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; SOLTAR UN ENEMIGO. Busca una ficha libre en 0xE200 y la rellena. No suelta nada mientras suene uno de los tres sonidos que se comen la partida.
; ----------------------------------------------------------------------
SUELTA_ENEMIGO:		; Suelta el enemigo que hay encargado, si hay sitio y toca
	ld a,(0e012h)		;67e1   ; con la musica de morir, de la meta o del final no se suelta nada
	cp 01eh		;67e4
	ret z			;67e6
	cp 092h		;67e7
	ret z			;67e9
	cp 08fh		;67ea
	ret z			;67ec
SUELTA_ENEMIGO_YA:		; El cuerpo: cada cuantos fotogramas segun el tipo
	ld hl,0e180h		;67ed
	ld c,(hl)			;67f0   ; C = el contador de fotogramas de la fase
	inc l			;67f1
	inc l			;67f2
	ld a,(hl)			;67f3
	cp 00ah		;67f4   ; los tipos por debajo del 10 salen cada 32 fotogramas...
	ld b,01fh		;67f6
	jr c,SUELTA_RITMO_2		;67f8
	ld b,00fh		;67fa   ; ...y los demas cada 16
SUELTA_RITMO_2:
	cp 007h		;67fc
	jr nz,SUELTA_RITMO_3		;67fe
	ld b,00fh		;6800
SUELTA_RITMO_3:
	cp 00ch		;6802   ; el tipo 12 sale en cuanto se le encarga
	jr nz,SUELTA_COMPRUEBA		;6804
	ld b,000h		;6806
SUELTA_COMPRUEBA:
	ld a,b			;6808
	and c			;6809
	ret nz			;680a
	ld a,(hl)			;680b   ; el tipo 5 pone ademas la marca de 0xE11A
	sub 005h		;680c
	jr nz,SUELTA_HAY_ENCARGO		;680e
	inc a			;6810
	ld (0e11ah),a		;6811
SUELTA_HAY_ENCARGO:
	dec l			;6814
	ld a,(hl)			;6815
	and a			;6816
	ret z			;6817
	ld hl,0e200h		;6818   ; diez fichas de 16 bytes
	ld b,00ah		;681b
	ld e,010h		;681d
	call BUSCA_HUECO		;681f
	ret c			;6822
	push hl			;6823
	pop ix		;6824
	ex de,hl			;6826
	ld hl,0e185h		;6827   ; una mas en la cuenta de enemigos vivos
	inc (hl)			;682a
	ld hl,0e181h		;682b
	dec (hl)			;682e
	inc hl			;682f
	ld a,(hl)			;6830   ; +0 de la ficha: el tipo
	ld (de),a			;6831
	ex de,hl			;6832
	inc l			;6833
	xor a			;6834
	ld (hl),a			;6835
	inc l			;6836
	ld (hl),0a0h		;6837   ; la ficha nueva: subestado 0, cuenta 0xA0, contador 0x20
	inc l			;6839
	ld (hl),020h		;683a
	inc l			;683c
	call COLOCA_ENEMIGO		;683d   ; por donde entra
	inc l			;6840
	call PON_SPRITE_ENEMIGO		;6841   ; patron de sprite y color
	inc l			;6844
	ld a,(0e181h)		;6845   ; si era el ultimo, una tanda mas en 0xE184
	ex de,hl			;6848
	ld hl,0e184h		;6849
	and a			;684c
	jr nz,SUELTA_REMATA		;684d
	inc (hl)			;684f
SUELTA_REMATA:
	ex de,hl			;6850
	ld a,(0e182h)		;6851   ; y lo que le falte, segun el tipo
	ld de,SALTA_POR_TABLA_YA		;6854
	inc l			;6857
SALTA_POR_TABLA:		; Coge de la tabla (DE) la palabra numero A y salta ahi
	ex de,hl			;6858
	add a,a			;6859   ; dos bytes por entrada de la tabla
	call SUMA_A_HL		;685a
	ld c,(hl)			;685d   ; el destino se mete en la pila y se vuelve a el
	inc hl			;685e
	ld b,(hl)			;685f
	ex de,hl			;6860
SALTA_POR_TABLA_YA:		; El `push bc / ret`; los 24 bytes que siguen son la tabla del tipo
	push bc			;6861
	ret			;6862

; ----------------------------------------------------------------------
; DATOS enemigo_al_soltar: Doce rutinas, una por tipo de enemigo (base 0x6861,
;   indice desde 1): la que remata la ficha en el momento de soltarlo. 0x6859
;   salta a ella con `push bc / ret`
;   0x6863..0x687b  (24 bytes)
DATA_enemigo_al_soltar:
	defw 06997h	; 6863  -> NACE_PERSEGUIDOR
	defw 069b3h	; 6865  -> NACE_PERSEGUIDOR_2
	defw 069bdh	; 6867  -> NACE_CON_VUELTAS
	defw 069d1h	; 6869  -> NACE_CON_ESPERA
	defw 069e6h	; 686b  -> NACE_SIN_NADA
	defw 069e6h	; 686d  -> NACE_SIN_NADA
	defw 069dah	; 686f  -> NACE_RAPIDO
	defw 069deh	; 6871  -> NACE_ALTERNO
	defw 069e7h	; 6873  -> NACE_LENTO
	defw 069ebh	; 6875  -> NACE_CON_TIEMPO
	defw 06a02h	; 6877  -> NACE_CAYENDO
	defw 06a1ah	; 6879  -> NACE_EN_CIRCULO

; ======================================================================
; CODIGO 0x687b..0x6896  (27 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; BUSCAR UN HUECO. Recorre B fichas separadas E bytes y para en la primera cuyo primer byte valga A. Con carry, no hay sitio.
; ----------------------------------------------------------------------
BUSCA_HUECO:		; Busca una ficha libre (primer byte 0)
	xor a			;687b
BUSCA_VALOR:		; Busca la primera ficha cuyo primer byte valga A
	ld d,000h		;687c
BUSCA_BUCLE:
	cp (hl)			;687e   ; para en la primera ficha cuyo primer byte valga A
	ret z			;687f
	add hl,de			;6880
	djnz BUSCA_BUCLE		;6881
	scf			;6883   ; sin sitio: vuelve con carry
	ret			;6884
PON_SPRITE_ENEMIGO:		; Patron y color del tipo, de la tabla de 0x6894
	ld a,(0e182h)		;6885
	ld de,PON_DOS_BYTES_FIN		;6888
PON_DOS_BYTES:		; Copia a (HL) y (HL+1) los dos bytes de la entrada A de la tabla (DE)
	add a,a			;688b   ; dos bytes por entrada
	call SUMA_A_DE		;688c
	ld a,(de)			;688f
	ld (hl),a			;6890
	inc de			;6891
	inc l			;6892
	ld a,(de)			;6893
PON_DOS_BYTES_FIN:		; El `ld (hl),a`; los 24 bytes que siguen son la tabla de patrones
	ld (hl),a			;6894
	ret			;6895

; ----------------------------------------------------------------------
; DATOS patron_y_color_de_enemigo: Doce parejas (patron de sprite, color), una
;   por tipo. Base 0x6894, indice desde 1. El patron partido por cuatro es el
;   numero de sprite de 16x16, y su dibujo esta en la VRAM 0x1800 + patron *
;   8, que es lo que sube 0x5E67. Mirando los dibujos: tipo 1 patron 0x18
;   color 10, un bicho redondo con dos orejas y dos ojos grandes, con cuatro
;   vistas (0x18 de frente, 0x20 de espaldas, 0x28 de lado y 0x30 girando);
;   tipo 2 patron 0x9C color 7, una figura con la cabeza arriba a la izquierda
;   y el cuerpo ancho abajo, con dos patas; tipo 3 patron 0x90 color 7, una
;   forma con brazos radiales que da vueltas en tres fotogramas (0x90, 0x94 y
;   0x98); tipo 4 patron 0x80 color 14, UN RATON: dos orejas redondas y un
;   rabo enroscado; tipo 5 patron 0x38 color 15, una forma con una visera
;   rayada arriba, alas a los lados y una cola fina abajo; tipo 6 patron 0x10
;   color 10, una cara con dos ojos redondos enormes y patas; tipo 7 patron
;   0x4C color 8, un bulto redondo irregular en tres fotogramas (0x4C, 0x50 y
;   0x54); tipo 8 patron 0x10 color 6, el mismo dibujo que el 6, en rojo
;   oscuro; tipo 9 patron 0x70 color 15, UNA CALAVERA; tipo 10 patron 0x78
;   color 0, UNA MARIPOSA (el color de verdad sale de 0x69FC); tipo 11 patron
;   0x10 color 10, otra vez el dibujo del 6; tipo 12 patron 0xDC color 15, y
;   ese patron (VRAM 0x1EE0) es UN SOLO PIXEL: de los 32 bytes, 31 son cero.
;   Los tipos 1, 2, 3, 5 y 7 no se han podido poner nombre con seguridad
;   0x6896..0x68ae  (24 bytes)
DATA_patron_y_color_de_enemigo:
	defb 018h,00ah	; 6896
	defb 09ch,007h	; 6898
	defb 090h,007h	; 689a
	defb 080h,00eh	; 689c
	defb 038h,00fh	; 689e
	defb 010h,00ah	; 68a0
	defb 04ch,008h	; 68a2
	defb 010h,006h	; 68a4
	defb 070h,00fh	; 68a6
	defb 078h,000h	; 68a8
	defb 010h,00ah	; 68aa
	defb 0dch,00fh	; 68ac

; ======================================================================
; CODIGO 0x68ae..0x68b6  (8 bytes)
; ======================================================================


COLOCA_ENEMIGO:		; Salta a la rutina de colocacion del tipo, tabla de 0x68B4
	ld a,(0e182h)		;68ae
	ld de,COLOCA_ENEMIGO_SALTO		;68b1
COLOCA_ENEMIGO_SALTO:		; El `jr` a SALTA_POR_TABLA_YA; detras va la tabla
	jr $-92		;68b4

; ----------------------------------------------------------------------
; DATOS enemigo_al_colocar: Doce rutinas, una por tipo: la que decide por
;   donde entra. Base 0x68B4, indice desde 1
;   0x68b6..0x68ce  (24 bytes)
DATA_enemigo_al_colocar:
	defw 068ceh	; 68b6  -> COLOCA_ARRIBA_O_ABAJO
	defw 06915h	; 68b8  -> COLOCA_POR_CUENTA
	defw 06915h	; 68ba  -> COLOCA_POR_CUENTA
	defw 06915h	; 68bc  -> COLOCA_POR_CUENTA
	defw 0691ah	; 68be  -> COLOCA_EN_ESQUINA
	defw 0691ah	; 68c0  -> COLOCA_EN_ESQUINA
	defw 06957h	; 68c2  -> COLOCA_JUNTO_AL_JUGADOR
	defw 0697fh	; 68c4  -> COLOCA_POR_SENTIDO
	defw 06932h	; 68c6  -> COLOCA_AL_AZAR
	defw 06946h	; 68c8  -> COLOCA_EN_ESQUINA_2
	defw 06946h	; 68ca  -> COLOCA_EN_ESQUINA_2
	defw 0698fh	; 68cc  -> COLOCA_EL_JEFE

; ======================================================================
; CODIGO 0x68ce..0x6910  (66 bytes)
; ======================================================================


COLOCA_ARRIBA_O_ABAJO:		; Entra por arriba (Y=0xF0) o por abajo (Y=0xC0), alternando
	ld a,(0e184h)		;68ce
COLOCA_POR_BIT:
	rra			;68d1   ; el bit 0 de 0xE184 va alternando arriba y abajo
	ld c,0f0h		;68d2
	jr nc,COLOCA_MIRA_TRAMO		;68d4
	ld c,0c0h		;68d6
COLOCA_MIRA_TRAMO:
	ld a,(0e105h)		;68d8   ; 0xE105 es la dificultad: sin ella se entra siempre por arriba
	and a			;68db
	jr nz,COLOCA_POR_POSICION		;68dc
	ld a,(0e117h)		;68de   ; y en las seis primeras filas del tramo, tambien
	cp 006h		;68e1
	jr nc,COLOCA_POR_POSICION		;68e3
	ld c,0f0h		;68e5
	jr COLOCA_PON_Y		;68e7
COLOCA_POR_POSICION:
	ld a,(0e101h)		;68e9   ; 0xE101 es la fila de la fase: la posicion en pixeles partida por 256
	sub 002h		;68ec
	cp 006h		;68ee
	jr c,COLOCA_PON_Y		;68f0
	ld c,0f0h		;68f2
	jp m,COLOCA_PON_Y		;68f4
	ld c,0c0h		;68f7
COLOCA_PON_Y:
	ld a,c			;68f9
COLOCA_PON_COLUMNA:		; Deja la Y y elige una de las cinco columnas de 0x6910
	ld (hl),a			;68fa
	inc l			;68fb
	ld a,(0e181h)		;68fc   ; 0xE181, los que quedan por soltar, elige la columna
COLOCA_COLUMNA_MOD:		; Cinco columnas, en circulo
	cp 005h		;68ff
	jr c,COLOCA_COLUMNA_LEE		;6901
	sub 005h		;6903
	jr COLOCA_COLUMNA_MOD		;6905
COLOCA_COLUMNA_LEE:
	ld de,06910h		;6907
	call SUMA_A_DE		;690a
	ld a,(de)			;690d
	ld (hl),a			;690e
	ret			;690f

; ----------------------------------------------------------------------
; DATOS columnas_de_entrada: Las cinco X por las que puede entrar un enemigo:
;   0x98, 0x78, 0x18, 0x58 y 0x38
;   0x6910..0x6915  (5 bytes)
DATA_columnas_de_entrada:
	defb 098h,078h,018h,058h,038h	; 6910

; ======================================================================
; CODIGO 0x6915..0x692a  (21 bytes)
; ======================================================================


COLOCA_POR_CUENTA:		; Igual que 0x68CE, pero el lado lo decide cuantos van sueltos
	ld a,(0e181h)		;6915
	jr $-71		;6918
COLOCA_EN_ESQUINA:		; Una de las cuatro esquinas de 0x692A
	ld de,0692ah		;691a
	ld a,(0e184h)		;691d
	ld c,a			;6920
	ld a,(0e181h)		;6921
	add a,c			;6924
COLOCA_ESQUINA_PON:
	and 003h		;6925
	jp PON_DOS_BYTES		;6927

; ----------------------------------------------------------------------
; DATOS esquinas_de_entrada: Cuatro parejas (Y, X): las cuatro esquinas por
;   las que entra el enemigo de tipo 4 y 5
;   0x692a..0x6932  (8 bytes)
DATA_esquinas_de_entrada:
	defb 008h,018h	; 692a
	defb 0b0h,018h	; 692c
	defb 008h,098h	; 692e
	defb 0b0h,098h	; 6930

; ======================================================================
; CODIGO 0x6932..0x694f  (29 bytes)
; ======================================================================


COLOCA_AL_AZAR:		; Arriba o abajo con el registro R, y a la altura del jugador
	ld a,r		;6932
	rra			;6934
	ld a,0f0h		;6935
	jr nc,COLOCA_AZAR_PON		;6937
	ld a,0c0h		;6939
COLOCA_AZAR_PON:
	ld (hl),a			;693b
	inc l			;693c
	ld a,(0e124h)		;693d   ; la X del jugador redondeada a 32 pixeles, mas 0x18
	and 0e0h		;6940
	or 018h		;6942
	ld (hl),a			;6944
	ret			;6945
COLOCA_EN_ESQUINA_2:		; Una de las cuatro esquinas de 0x694F
	ld a,(0e184h)		;6946
	ld de,0694fh		;6949
	jp COLOCA_ESQUINA_PON		;694c

; ----------------------------------------------------------------------
; DATOS esquinas_de_entrada_2: Las mismas cuatro esquinas en otro orden, para
;   los tipos 9 y 10
;   0x694f..0x6957  (8 bytes)
DATA_esquinas_de_entrada_2:
	defb 0f0h,018h	; 694f
	defb 0c0h,098h	; 6951
	defb 0f0h,098h	; 6953
	defb 0c0h,018h	; 6955

; ======================================================================
; CODIGO 0x6957..0x697b  (36 bytes)
; ======================================================================


COLOCA_JUNTO_AL_JUGADOR:		; Al lado del jugador, con uno de los cuatro desvios de 0x697B
	call BORDE_DE_ENTRADA		;6957
	ld (hl),a			;695a
	inc l			;695b
	ld a,(0e184h)		;695c   ; uno de los cuatro desvios de 0x697B, en rueda
	and 003h		;695f
	ld de,0697bh		;6961
	call SUMA_A_DE		;6964
	ex de,hl			;6967
	ld a,(0e124h)		;6968   ; la X del jugador mas el desvio
	add a,(hl)			;696b
	ex de,hl			;696c
	cp 098h		;696d   ; sin pasarse de 0x98 ni bajar de 0x18
	jr c,COLOCA_JUNTO_TOPE		;696f
	ld a,098h		;6971
COLOCA_JUNTO_TOPE:
	cp 018h		;6973
	jr nc,COLOCA_JUNTO_PON		;6975
	ld a,018h		;6977
COLOCA_JUNTO_PON:
	ld (hl),a			;6979
	ret			;697a

; ----------------------------------------------------------------------
; DATOS desvios_en_x: Cuatro desvios que 0x6957 suma a la X del jugador para
;   colocar al enemigo: 0x20, 0, 0xE0 (o sea -32) y 0
;   0x697b..0x697f  (4 bytes)
DATA_desvios_en_x:
	defb 020h,000h,0e0h,000h	; 697b

; ======================================================================
; CODIGO 0x697f..0x69fc  (125 bytes)
; ======================================================================


COLOCA_POR_SENTIDO:		; Por delante segun se suba o se baje
	call BORDE_DE_ENTRADA		;697f
	jp COLOCA_PON_COLUMNA		;6982
BORDE_DE_ENTRADA:		; Y = 0xF0 subiendo, 0xC0 bajando
	ld a,(0e102h)		;6985   ; 0xE102: subiendo se entra por arriba, bajando por abajo
	and a			;6988
	ld a,0f0h		;6989
	ret z			;698b
	ld a,0c0h		;698c
	ret			;698e
COLOCA_EL_JEFE:		; La posicion que lleve guardada 0xE390
	ld de,(0e390h)		;698f
	ld (hl),e			;6993
	inc l			;6994
	ld (hl),d			;6995
	ret			;6996

; ----------------------------------------------------------------------
; LO QUE LE FALTA A CADA TIPO AL SOLTARLO. Doce rutinas, tabla de 0x6863: velocidad, contadores y comprobacion de que la casilla esta libre.
; ----------------------------------------------------------------------
NACE_PERSEGUIDOR:		; Velocidad hacia el jugador y contador 0x20
	call VELOCIDAD_AL_JUGADOR		;6997
	ld (hl),020h		;699a
NACE_COMPRUEBA:		; Si la casilla donde va a salir esta pintada, el enemigo se muere antes de nacer
	call POSICION_ENEMIGO		;699c
	ld a,l			;699f   ; entrando por arriba se mira la fila 0; por abajo, la 0xB8
	ld l,000h		;69a0
	cp 0e0h		;69a2
	jr nc,NACE_LEE_CASILLA		;69a4
	ld l,0b8h		;69a6
NACE_LEE_CASILLA:		; Lee de la tabla de nombres el caracter de la casilla donde va a nacer
	call DIRECCION_DE_NOMBRE		;69a8   ; lee la tabla de nombres en ese punto
	call 0004ah		;69ab   ; BIOS RDVRM - Reads the content of VRAM
	and a			;69ae
	ret z			;69af
	jp MATA_ENEMIGO		;69b0   ; hay algo pintado: se anula
NACE_PERSEGUIDOR_2:		; Como el anterior con dos contadores
	call VELOCIDAD_AL_JUGADOR		;69b3
	ld (hl),020h		;69b6
	inc l			;69b8
	ld (hl),020h		;69b9
	jr NACE_COMPRUEBA		;69bb
NACE_CON_VUELTAS:		; Velocidad de 0x10 y de una a cuatro vueltas
	ld a,010h		;69bd
	call VELOCIDAD_AL_JUGADOR_MAS		;69bf
	ld a,(0e181h)		;69c2   ; de una a cuatro vueltas, segun cuantos van sueltos
	and 003h		;69c5
	inc a			;69c7
	ld (ix+002h),a		;69c8
	ld (ix+003h),000h		;69cb
	jr NACE_COMPRUEBA		;69cf
NACE_CON_ESPERA:		; Velocidad de 0x0C y contador a 0xFF
	ld a,00ch		;69d1
	call VELOCIDAD_AL_JUGADOR_MAS		;69d3
	ld (hl),0ffh		;69d6
	jr NACE_COMPRUEBA		;69d8
NACE_RAPIDO:		; Velocidad de 0x10, sin mas
	ld a,010h		;69da
	jr $+109		;69dc
NACE_ALTERNO:		; Subestado 0 o 1 segun cuantos lleve sueltos
	ld a,(0e181h)		;69de
	and 001h		;69e1
	ld (ix+002h),a		;69e3
NACE_SIN_NADA:		; Los tipos que no necesitan nada mas
	ret			;69e6
NACE_LENTO:		; Velocidad de 8
	ld a,008h		;69e7
	jr $+96		;69e9
NACE_CON_TIEMPO:		; Velocidad hacia abajo y un tiempo de vida de la tabla de 0x69FC
	call NACE_CAYENDO		;69eb
	ld a,(0e181h)		;69ee   ; +7 es el color: el tipo 10 lo saca de la tabla de 0x69FC
	ld hl,069fch		;69f1
	call SUMA_A_HL		;69f4
	ld a,(hl)			;69f7
	ld (ix+007h),a		;69f8
	ret			;69fb

; ----------------------------------------------------------------------
; DATOS colores_del_enemigo_10: Seis colores del MSX (6, 10, 4, 7, 15 y 13)
;   que 0x69F8 escribe en el +7 del enemigo de tipo 10, elegidos por cuantos
;   van soltados. En la tabla de 0x6894 ese tipo lleva color 0, asi que el
;   color de verdad sale siempre de aqui
;   0x69fc..0x6a02  (6 bytes)
DATA_colores_del_enemigo_10:
	defb 006h,00ah,004h,007h,00fh,00dh	; 69fc

; ======================================================================
; CODIGO 0x6a02..0x6a8a  (136 bytes)
; ======================================================================


NACE_CAYENDO:		; Dos pixeles por fotograma hacia dentro de la pantalla, sin velocidad en X, y el objetivo en (0x60, 0x60)
	inc l			;6a02   ; los tipos que se mueven con AVANZA llevan la velocidad en +A/+B, uno mas alla que los de AVANZA_EN_Y
	ld de,00200h		;6a03
	call VELOCIDAD_SIGNO		;6a06
	xor a			;6a09   ; sin velocidad en X
	ld (hl),a			;6a0a
	inc l			;6a0b
	ld (hl),a			;6a0c
	inc l			;6a0d
	ld de,06060h		;6a0e   ; y el objetivo (+E/+F) en (0x60, 0x60)
	jr VELOCIDAD_PON		;6a11
LEE_PALABRA:		; Deja en DE la palabra numero A de la tabla (HL); HL queda en el byte alto
	call SUMA_A_HL		;6a13
	ld e,(hl)			;6a16
	inc hl			;6a17
	ld d,(hl)			;6a18
	ret			;6a19
NACE_EN_CIRCULO:		; Una de las ocho direcciones de 0x6A96, sorteada con el registro R
	ld a,r		;6a1a   ; el registro R del Z80 hace de dado
	ld c,a			;6a1c
	ld a,(0e003h)		;6a1d
	add a,c			;6a20
	and 01ch		;6a21
	ld hl,06a96h		;6a23
	call LEE_PALABRA		;6a26
	inc hl			;6a29
	ld a,(0e181h)		;6a2a   ; 0xE181 decide si la velocidad se invierte
	push af			;6a2d
	and 003h		;6a2e
	call pe,NIEGA_DE		;6a30   ; segun el sorteo, la velocidad se invierte
	ld (ix+00ah),e		;6a33   ; +A/+B es la velocidad en Y, en 8.8
	ld (ix+00bh),d		;6a36
	ld e,(hl)			;6a39
	inc hl			;6a3a
	ld d,(hl)			;6a3b
	pop af			;6a3c
	rra			;6a3d
	call c,NIEGA_DE		;6a3e
	ld (ix+00ch),e		;6a41   ; y +C/+D la de X
	ld (ix+00dh),d		;6a44
	ret			;6a47
VELOCIDAD_AL_JUGADOR:		; Velocidad hacia el jugador, con la escala de la dificultad
	xor a			;6a48
VELOCIDAD_AL_JUGADOR_MAS:		; Lo mismo sumandole A a la escala
	call ESCALA_DE_VELOCIDAD		;6a49
	ld a,(ix+000h)		;6a4c   ; el tipo de la ficha
	cp 009h		;6a4f
	jr z,VELOCIDAD_DOBLE		;6a51
	cp 007h		;6a53
	jr nz,VELOCIDAD_GUARDA		;6a55
VELOCIDAD_DOBLE:		; Los tipos 7 y 9 van al doble
	add hl,hl			;6a57
VELOCIDAD_GUARDA:
	ex de,hl			;6a58
VELOCIDAD_SIGNO:		; Le da el signo segun por donde haya entrado el enemigo: con Y >= 0xE0 (por arriba) va hacia abajo, y al reves
	ld a,(ix+004h)		;6a59
	cp 0e0h		;6a5c
	call c,NIEGA_DE		;6a5e
VELOCIDAD_PON:
	ld (hl),e			;6a61
	inc l			;6a62
	ld (hl),d			;6a63
	inc l			;6a64
	ret			;6a65
ESCALA_DE_VELOCIDAD:		; Saca de 0x6A8A la velocidad que toca por dificultad, en 8.8
	ld c,a			;6a66
	ex de,hl			;6a67
	call SUMA_A_HL		;6a68
	ld a,(0e105h)		;6a6b   ; 0xE105 sube con las fases: es la dificultad
	sra a		;6a6e
	add a,c			;6a70
	cp 017h		;6a71   ; tope: 0x17
	jr c,ESCALA_LEE		;6a73
	ld a,017h		;6a75
ESCALA_LEE:
	sra a		;6a77   ; la escala va de dos en dos
	ld hl,06a8ah		;6a79   ; la tabla de velocidades de 0x6A8A
	call SUMA_A_HL		;6a7c
	ld l,(hl)			;6a7f
	ld h,000h		;6a80
	ld b,h			;6a82
	ld c,l			;6a83
	add hl,hl			;6a84   ; por 17, que es como se pasa a 8.8 sin multiplicar
	add hl,hl			;6a85
	add hl,hl			;6a86
	add hl,hl			;6a87
	add hl,bc			;6a88
	ret			;6a89

; ----------------------------------------------------------------------
; DATOS escala_de_velocidad: Doce valores que 0x6A66 usa para sacar la
;   velocidad de persecucion segun la dificultad: van de 0x0C a 0x1E de dos en
;   dos
;   0x6a8a..0x6a96  (12 bytes)
DATA_escala_de_velocidad:
	defb 00ch,00dh,00eh,00fh,010h,012h,014h,016h,018h,01ah,01ch,01eh	; 6a8a  ............

; ----------------------------------------------------------------------
; DATOS vueltas_del_rebote: Ocho parejas de velocidades (Y, X) en coma fija
;   8.8, que 0x6A1A elige con el registro R y el contador de fotogramas.
;   Recorridas en orden dan las ocho direcciones de un circulo
;   0x6a96..0x6ab6  (32 bytes)
DATA_vueltas_del_rebote:
	defw 000c8h,007f6h	; 6a96
	defw 00252h,007a7h	; 6a9a
	defw 003c5h,0070eh	; 6a9e
	defw 00513h,0062fh	; 6aa2
	defw 0062fh,00513h	; 6aa6
	defw 0070eh,003c5h	; 6aaa
	defw 007a7h,00252h	; 6aae
	defw 007f6h,000c8h	; 6ab2

; ======================================================================
; CODIGO 0x6ab6..0x6b5a  (164 bytes)
; ======================================================================


SUELTA_DISPARO_ENEMIGO:		; Cada cierto tiempo, el enemigo tira un disparo hacia el jugador
	dec (ix+00ch)		;6ab6
	ret nz			;6ab9
	ld a,(0e105h)		;6aba   ; con dificultad alta dispara el doble de seguido
	cp 003h		;6abd
	ld c,040h		;6abf
	jr c,DISPARO_PON_ESPERA		;6ac1
	ld c,020h		;6ac3
DISPARO_PON_ESPERA:
	ld (ix+00ch),c		;6ac5   ; +C es la cuenta atras hasta el disparo siguiente
	ld b,003h		;6ac8   ; tres huecos de disparo enemigo en 0xE1B0
	ld hl,0e1b0h		;6aca
	ld e,008h		;6acd
	ld a,0e0h		;6acf
	call BUSCA_VALOR		;6ad1
	ret c			;6ad4
	ld a,(ix+004h)		;6ad5   ; el disparo sale donde esta el enemigo
	ld (hl),a			;6ad8
	ld c,a			;6ad9
	inc l			;6ada
	ld a,(ix+005h)		;6adb
	ld (hl),a			;6ade
	inc l			;6adf
	ld (hl),044h		;6ae0   ; patron 0x44 y color 15
	inc l			;6ae2
	ld (hl),00fh		;6ae3
	inc l			;6ae5
	ld a,(0e123h)		;6ae6   ; con el jugador mas abajo el disparo baja (+2); si no, sube (0xFE)
	sub c			;6ae9
	ld c,002h		;6aea
	jr nc,DISPARO_PON_SENTIDO		;6aec
	ld c,0feh		;6aee
DISPARO_PON_SENTIDO:
	ld (hl),c			;6af0
	ret			;6af1

; ----------------------------------------------------------------------
; LOS DISPAROS ENEMIGOS. Tres, de 8 bytes; se mueven en Y y se paran al tocar el fondo.
; ----------------------------------------------------------------------
MUEVE_DISPAROS_ENEMIGOS:		; Mueve los tres disparos enemigos
	ld b,003h		;6af2
	ld ix,0e1b0h		;6af4
	ld de,00008h		;6af8
MUEVE_DISPARO_ENEMIGO:
	ld a,(ix+000h)		;6afb
	cp 0e0h		;6afe
	jr z,MUEVE_DISPARO_SIGUIENTE		;6b00
	add a,(ix+004h)		;6b02
	ld (ix+000h),a		;6b05
	cp 0c0h		;6b08
	jr nc,MUEVE_DISPARO_QUITA		;6b0a
	ld l,a			;6b0c
	ld h,(ix+001h)		;6b0d
	call DIRECCION_DE_NOMBRE		;6b10   ; si el caracter de esa casilla no es fondo, el disparo se apaga
	call 0004ah		;6b13   ; BIOS RDVRM - Reads the content of VRAM
	and a			;6b16
	jr nz,MUEVE_DISPARO_QUITA		;6b17
MUEVE_DISPARO_SIGUIENTE:
	add ix,de		;6b19
	djnz MUEVE_DISPARO_ENEMIGO		;6b1b
	ret			;6b1d
MUEVE_DISPARO_QUITA:
	ld (ix+000h),0e0h		;6b1e
	jr MUEVE_DISPARO_SIGUIENTE		;6b22

; ----------------------------------------------------------------------
; EL PASO DE LOS ENEMIGOS. Recorre las diez fichas y llama a la rutina del tipo. Un tipo negativo quiere decir que el enemigo se esta muriendo.
; ----------------------------------------------------------------------
PASO_DE_ENEMIGOS:		; Un paso de cada uno de los diez enemigos
	ld b,00ah		;6b24
	ld hl,0e200h		;6b26
	push hl			;6b29
	pop ix		;6b2a
PASO_ENEMIGO:
	push bc			;6b2c
	ld (0e300h),hl		;6b2d
	ld a,(hl)			;6b30
	and a			;6b31
	jp m,PASO_ENEMIGO_MURIENDO		;6b32   ; tipo negativo: se esta muriendo
	call nz,PASO_ENEMIGO_SALTA		;6b35
PASO_ENEMIGO_SIGUIENTE:
	ld hl,(0e300h)		;6b38   ; la ficha siguiente: 16 bytes mas alla
	ld de,00010h		;6b3b
	add hl,de			;6b3e
	add ix,de		;6b3f
	pop bc			;6b41
	djnz PASO_ENEMIGO		;6b42
	ret			;6b44
PASO_ENEMIGO_MURIENDO:		; Cuenta atras de la explosion y, al acabar, la ficha se libera
	inc l			;6b45   ; +1 es la cuenta atras de la explosion
	dec (hl)			;6b46
	jr nz,PASO_ENEMIGO_SIGUIENTE		;6b47
	inc l			;6b49
	ld a,(hl)			;6b4a   ; +2 guardo el tipo: vuelve a +0 para que MATA_ENEMIGO sepa de quien era
	dec l			;6b4b
	dec l			;6b4c
	ld (hl),a			;6b4d
	call MATA_ENEMIGO		;6b4e
	jr PASO_ENEMIGO_SIGUIENTE		;6b51
PASO_ENEMIGO_SALTA:		; Salta a la rutina del tipo por la tabla de 0x6B58
	inc l			;6b53   ; HL en +1, que es donde lo espera la rutina del tipo
	ld de,06b58h		;6b54
	jp SALTA_POR_TABLA		;6b57

; ----------------------------------------------------------------------
; DATOS tabla_de_actores: Las doce rutinas de cada fotograma, una por tipo de
;   enemigo. Base 0x6B58, indice desde 1; 0x6B53 salta con `push bc / ret`
;   0x6b5a..0x6b72  (24 bytes)
DATA_tabla_de_actores:
	defw 06ce6h	; 6b5a  -> ENEMIGO_PERSIGUE
	defw 06f3ch	; 6b5c  -> ENEMIGO_VA_Y_VIENE
	defw 0701eh	; 6b5e  -> ENEMIGO_RECTO
	defw 06e9fh	; 6b60  -> ENEMIGO_RATON
	defw 06c1ah	; 6b62  -> ENEMIGO_ACECHA
	defw 071b2h	; 6b64  -> ENEMIGO_EN_CIRCULO
	defw 07269h	; 6b66  -> ENEMIGO_PLANEA
	defw 07285h	; 6b68  -> ENEMIGO_JEFE
	defw 07137h	; 6b6a  -> ENEMIGO_CALAVERA
	defw 071a1h	; 6b6c  -> ENEMIGO_MARIPOSA
	defw 07159h	; 6b6e  -> ENEMIGO_BAJA
	defw 07c9ah	; 6b70  -> ENEMIGO_DEL_TRONO

; ======================================================================
; CODIGO 0x6b72..0x712b  (1465 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL MOTOR DE PERSECUCION. Acerca la velocidad del enemigo a la que le llevaria al objetivo (+E, +F): es una persecucion suave, no un giro seco.
; ----------------------------------------------------------------------
PERSIGUE_LENTO:		; Acerca la velocidad al objetivo, a la mitad de fuerza
	ld c,001h		;6b72
PERSIGUE:		; Acerca la velocidad al objetivo con la fuerza que diga C
	ld a,(ix+004h)		;6b74   ; diferencia entre donde esta y donde quiere estar, en Y
	sub (ix+00eh)		;6b77
	ld e,a			;6b7a
	ld d,000h		;6b7b
	add a,a			;6b7d
	jr nc,PERSIGUE_Y		;6b7e
	dec d			;6b80
PERSIGUE_Y:
	ld a,c			;6b81
	and a			;6b82
	jr z,PERSIGUE_Y_APLICA		;6b83
PERSIGUE_Y_DIVIDE:
	sra e		;6b85   ; C dice cuantas veces se parte por dos
	dec a			;6b87
	jr nz,PERSIGUE_Y_DIVIDE		;6b88
PERSIGUE_Y_APLICA:
	ld l,(ix+00ah)		;6b8a   ; +A/+B: la velocidad en Y se acerca a la que hace falta
	ld h,(ix+00bh)		;6b8d
	and a			;6b90
	sbc hl,de		;6b91
	ld (ix+00ah),l		;6b93
	ld (ix+00bh),h		;6b96
	ld a,(ix+005h)		;6b99   ; y lo mismo en X
	sub (ix+00fh)		;6b9c
	ld e,a			;6b9f
	ld d,000h		;6ba0
	add a,a			;6ba2
	jr nc,PERSIGUE_X		;6ba3
	dec d			;6ba5
PERSIGUE_X:
	ld a,c			;6ba6
	and a			;6ba7
	jr z,PERSIGUE_X_APLICA		;6ba8
PERSIGUE_X_DIVIDE:
	sra e		;6baa
	dec a			;6bac
	jr nz,PERSIGUE_X_DIVIDE		;6bad
PERSIGUE_X_APLICA:
	ld l,(ix+00ch)		;6baf   ; y +C/+D la de X
	ld h,(ix+00dh)		;6bb2
	and a			;6bb5
	sbc hl,de		;6bb6
	ld (ix+00ch),l		;6bb8
	ld (ix+00dh),h		;6bbb
	jr AVANZA		;6bbe
LEE_OBJETIVO:		; Devuelve en DE el objetivo (+E,+F) por 16, y en A la parte alta
	ld e,(hl)			;6bc0   ; +E/+F, el objetivo
	inc l			;6bc1
	ld d,(hl)			;6bc2
	inc l			;6bc3
	ex de,hl			;6bc4
	add hl,hl			;6bc5   ; el objetivo por 16
	add hl,hl			;6bc6
	add hl,hl			;6bc7
	add hl,hl			;6bc8
	ex de,hl			;6bc9
	ld a,d			;6bca
	ret			;6bcb
MUERE_SI_SE_SALE:		; Si el enemigo se sale por abajo o por la derecha, se le quita
	ld a,(ix+004h)		;6bcc   ; por debajo de la fila 0xC0 ya no esta en la pantalla
	cp 0c0h		;6bcf
	jp nc,MATA_ENEMIGO		;6bd1
	ld a,(ix+005h)		;6bd4   ; ni pasada la columna 0xB8
	cp 0b8h		;6bd7
	jp nc,MATA_ENEMIGO		;6bd9
	ret			;6bdc
FOTOGRAMA_0x78:		; Fotograma 0x78 del sprite (o 0x7C, alternando)
	ld c,078h		;6bdd
	jr FOTOGRAMA_ALTERNO		;6bdf
FOTOGRAMA_0x38:		; Fotograma 0x38 del sprite
	ld c,038h		;6be1
	jr FOTOGRAMA_ALTERNO		;6be3
FOTOGRAMA_0x10:		; Fotograma 0x10 del sprite
	ld c,010h		;6be5
FOTOGRAMA_ALTERNO:		; Suma 4 al fotograma un rato si y otro no, que es como se anima
	ld a,(0e180h)		;6be7   ; el bit 4 del contador de la fase da los dos fotogramas
	and 010h		;6bea
	ld a,c			;6bec
	jr z,FOTOGRAMA_PON		;6bed
	add a,004h		;6bef
FOTOGRAMA_PON:
	ld (ix+006h),a		;6bf1
	ret			;6bf4
AVANZA:		; Suma la velocidad (8.8) a la posicion del enemigo, en Y y en X
	ld a,(ix+00ah)		;6bf5   ; la fraccion de la Y (+8) mas la velocidad (+A/+B)
	add a,(ix+008h)		;6bf8
	ld (ix+008h),a		;6bfb
	ld a,(ix+00bh)		;6bfe
	adc a,(ix+004h)		;6c01
	ld (ix+004h),a		;6c04
	ld a,(ix+00ch)		;6c07   ; y lo mismo con la X: +9 con +C/+D
	add a,(ix+009h)		;6c0a
	ld (ix+009h),a		;6c0d
	ld a,(ix+00dh)		;6c10
	adc a,(ix+005h)		;6c13
	ld (ix+005h),a		;6c16
	ret			;6c19

; ----------------------------------------------------------------------
; ENEMIGO 5: el que se queda quieto parpadeando y luego sale disparado hacia el jugador.
; ----------------------------------------------------------------------
ENEMIGO_ACECHA:		; Se queda quieto, parpadea, y al final se lanza
	call FOTOGRAMA_0x38		;6c1a
	ld a,(hl)			;6c1d   ; subestado 1 = esperando, 2 = lanzado
	dec a			;6c1e
	jr z,ACECHA_ESPERA		;6c1f
	dec a			;6c21
	jp z,ACECHA_FIN		;6c22
	inc l			;6c25
	inc l			;6c26
	dec (hl)			;6c27   ; la cuenta del parpadeo
	ld c,00fh		;6c28
	jr z,ACECHA_LANZA		;6c2a
ACECHA_PARPADEO:
	bit 1,(hl)		;6c2c   ; con el color 0 el sprite no se ve: asi parpadea
	jr nz,ACECHA_PON_COLOR		;6c2e
	ld c,000h		;6c30
ACECHA_PON_COLOR:
	ld (ix+007h),c		;6c32
	ret			;6c35
ACECHA_LANZA:		; Se lanza a izquierda o derecha segun donde este
	ld (hl),070h		;6c36   ; recarga la cuenta y pasa al subestado 1
	ld (ix+001h),001h		;6c38
	ld (ix+007h),00fh		;6c3c
	ld de,00100h		;6c40
	ld a,(ix+005h)		;6c43   ; se lanza hacia la izquierda o hacia la derecha segun de que lado este
	cp 060h		;6c46
	jr c,ACECHA_PON_VELOCIDAD		;6c48
	ld de,0ff00h		;6c4a
ACECHA_PON_VELOCIDAD:
	ld (ix+00ch),e		;6c4d
	ld (ix+00dh),d		;6c50
	xor a			;6c53   ; y sin velocidad vertical
	ld (ix+00ah),a		;6c54
	ld (ix+00bh),a		;6c57
	ret			;6c5a
ACECHA_ESPERA:		; La espera de antes de lanzarse, con su sonido
	call AVANZA		;6c5b
	ld a,(0e180h)		;6c5e   ; el bit 5 del contador de la fase decide hacia donde va
	and 020h		;6c61
	ld de,00040h		;6c63
	jr z,ACECHA_CUENTA		;6c66
	ld de,0ffc0h		;6c68
ACECHA_CUENTA:
	ld (ix+00ah),e		;6c6b
	ld (ix+00bh),d		;6c6e
	inc l			;6c71
	ld a,(hl)			;6c72
	and a			;6c73
	jr z,ACECHA_SIGUE		;6c74
	ld a,(0e180h)		;6c76   ; la cuenta baja un fotograma de cada cuatro
	and 003h		;6c79
	jr nz,ACECHA_APUNTA		;6c7b
	dec (hl)			;6c7d
ACECHA_APUNTA:		; Apunta 0x10 arriba o abajo del jugador
	inc l			;6c7e
	dec (hl)			;6c7f
	ld a,089h		;6c80   ; mientras dura, suena el 0x89
	jp nz,PIDE_SONIDO_EN_PARTIDA		;6c82
	ld (hl),030h		;6c85
	ld (ix+001h),002h		;6c87
	ld a,(0e123h)		;6c8b   ; compara la Y del jugador con la del enemigo
	ld b,a			;6c8e
	ld c,(ix+004h)		;6c8f
	sub c			;6c92
	sub 020h		;6c93   ; si estan a menos de 0x20, se apunta 0x10 mas alla
	cp 020h		;6c95
	ld e,010h		;6c97
	jr z,ACECHA_APUNTA_ALTERNO		;6c99
	ld a,c			;6c9b
	sub b			;6c9c
	jr c,ACECHA_PON_OBJETIVO		;6c9d
ACECHA_APUNTA_ABAJO:
	ld e,0f0h		;6c9f
ACECHA_PON_OBJETIVO:
	ld a,(ix+004h)		;6ca1   ; el objetivo en Y: 0x10 por encima o por debajo del enemigo
	add a,e			;6ca4
	ld (ix+00eh),a		;6ca5
	ld a,(ix+005h)		;6ca8   ; y en su misma X
	ld (ix+00fh),a		;6cab
	ret			;6cae
ACECHA_APUNTA_ALTERNO:
	ld a,(0e180h)		;6caf
	bit 1,a		;6cb2
	jr z,ACECHA_PON_OBJETIVO		;6cb4
	jr ACECHA_APUNTA_ABAJO		;6cb6
ACECHA_FIN:
	inc l			;6cb8
	inc l			;6cb9
	dec (hl)			;6cba   ; cuando se acaba el tiempo, vuelta a lanzarse
	jp z,ACECHA_LANZA		;6cbb
	jp PERSIGUE_LENTO		;6cbe
ACECHA_SIGUE:
	inc l			;6cc1
	dec (hl)			;6cc2
	jp MUERE_SI_SE_SALE		;6cc3
GIRA_SPRITE:		; Va girando el fotograma del sprite y suena al dar la vuelta
	dec (ix+003h)		;6cc6   ; el fotograma solo cambia cuando se acaba el contador
	jr nz,GIRA_SPRITE_LADO		;6cc9
	ld a,002h		;6ccb
	add a,(hl)			;6ccd
	ld (hl),a			;6cce
	ld (ix+003h),021h		;6ccf
	ld a,083h		;6cd3   ; y al cambiar suena el 0x83
	jp PIDE_SONIDO		;6cd5
GIRA_SPRITE_LADO:
	bit 7,(ix+00ah)		;6cd8
	ld a,030h		;6cdc
	jr z,GIRA_SPRITE_PON		;6cde
	ld a,034h		;6ce0
GIRA_SPRITE_PON:
	ld (ix+006h),a		;6ce2
	ret			;6ce5

; ----------------------------------------------------------------------
; ENEMIGO 1: el que persigue al jugador de frente y le sigue por la pantalla.
; ----------------------------------------------------------------------
ENEMIGO_PERSIGUE:		; Persigue al jugador y mira el fondo por delante
	ld a,(hl)			;6ce6
	and a			;6ce7   ; subestado 0 = andando, 3 y 4 = muriendose
	jr z,PERSIGUE_ANDANDO		;6ce8
	sub 003h		;6cea
	jr c,GIRA_SPRITE		;6cec
	jp z,MUERE_A_LA_DERECHA		;6cee
	dec a			;6cf1
	jp z,MUERE_A_LA_IZQUIERDA		;6cf2
PERSIGUE_ANDANDO:
	ld a,(ix+004h)		;6cf5
	cp 0c0h		;6cf8   ; por debajo de la fila 0xC0 esta fuera de la pantalla
	jr nc,PERSIGUE_PARADO		;6cfa
	inc l			;6cfc
	ld a,(hl)			;6cfd
	and a			;6cfe
	jr z,PERSIGUE_PARADO		;6cff
	ld a,(0e180h)		;6d01   ; la cuenta baja un fotograma si y otro no
	rra			;6d04
	jr c,PERSIGUE_PASO		;6d05
	dec (hl)			;6d07
PERSIGUE_PASO:
	call AVANZA_EN_Y		;6d08   ; mueve, rebota y mira si se ha salido
	call REBOTA_ARRIBA_ABAJO		;6d0b
	call CHOCA_CON_EL_FONDO		;6d0e
	jp c,MATA_ENEMIGO		;6d11
	call FOTOGRAMA_0x18		;6d14
	ld a,(0e180h)		;6d17
	and 07fh		;6d1a
	ret nz			;6d1c
	call LADO_DEL_JUGADOR		;6d1d   ; cada 128 fotogramas se replantea el rumbo
	push bc			;6d20
	call POSICION_ENEMIGO		;6d21   ; mira que caracter hay dos columnas al lado
	call DIRECCION_DE_NOMBRE		;6d24
	dec c			;6d27
	ld a,004h		;6d28
	jr z,PERSIGUE_MIRA_CASILLA		;6d2a
	ld a,0fch		;6d2c
PERSIGUE_MIRA_CASILLA:
	add a,l			;6d2e
	ld l,a			;6d2f
	call 0004ah		;6d30   ; BIOS RDVRM - Reads the content of VRAM
	pop bc			;6d33
	ld b,010h		;6d34   ; si hay fondo, se le da la vuelta al rumbo
	and a			;6d36
	jr z,PERSIGUE_PON_RUMBO		;6d37
	ld bc,09000h		;6d39
PERSIGUE_PON_RUMBO:
	ld (ix+003h),b		;6d3c
	ld (ix+001h),c		;6d3f
	ret			;6d42
LADO_DEL_JUGADOR:		; Devuelve en C de que lado esta el jugador (0, 1 o 2)
	ld a,(0e124h)		;6d43
	sub (ix+005h)		;6d46   ; compara la X del jugador con la del enemigo
	ld c,002h		;6d49
	ret c			;6d4b
	dec c			;6d4c
	ld a,(ix+005h)		;6d4d
	cp 097h		;6d50   ; pegado al borde de abajo, siempre para el mismo lado
	ret c			;6d52
	inc c			;6d53
	ret			;6d54
PERSIGUE_PARADO:
	call CHOCA_CON_EL_FONDO		;6d55
	jp c,MATA_ENEMIGO		;6d58
	call SALE_DE_LA_PANTALLA		;6d5b
	ret c			;6d5e
	call AVANZA_EN_Y		;6d5f
FOTOGRAMA_0x18:		; Fotograma 0x18 o 0x20, segun el signo de la velocidad, alternando
	ld a,(ix+00ah)		;6d62
	add a,a			;6d65   ; el bit 7 de la velocidad dice hacia donde mira
	ld c,018h		;6d66
	jr nc,FOTOGRAMA_0x18_ALTERNO		;6d68
	ld c,020h		;6d6a
FOTOGRAMA_0x18_ALTERNO:
	ld a,(0e180h)		;6d6c
	and 004h		;6d6f   ; y el bit 2 del contador anima
	ld a,c			;6d71
	jr nz,FOTOGRAMA_0x18_PON		;6d72
	add a,004h		;6d74
FOTOGRAMA_0x18_PON:
	ld (ix+006h),a		;6d76
	ret			;6d79
MUERE_A_LA_IZQUIERDA:
	ld c,0ffh		;6d7a
	jr MUERE_EMPUJADO		;6d7c
MUERE_A_LA_DERECHA:
	ld c,001h		;6d7e
MUERE_EMPUJADO:
	ld b,028h		;6d80
MUERE_CUENTA:		; La animacion de morir: se va de lado con la curva del empuje
	dec (ix+003h)		;6d82
	jr z,EMPUJA_FIN		;6d85
EMPUJA_CON_CURVA:		; Mueve la ficha con la misma curva de empuje que usa el jugador
	ld a,l			;6d87
	and 0f0h		;6d88
	add a,003h		;6d8a
	ld l,a			;6d8c
	ld de,05ad4h		;6d8d   ; la misma curva de empuje que el jugador
	ld a,(0e102h)		;6d90
	and a			;6d93
	jr z,EMPUJA_PARADO		;6d94
	ld de,05af4h		;6d96
EMPUJA_PARADO:
	ld a,(0e113h)		;6d99
	and a			;6d9c
	jr z,EMPUJA_PASO		;6d9d
	ld de,05b14h		;6d9f
EMPUJA_PASO:
	ld a,020h		;6da2   ; la curva se recorre al reves
	sub (hl)			;6da4
	inc l			;6da5
	call SUMA_A_DE		;6da6
	ld a,(de)			;6da9
	add a,(hl)			;6daa
	ld (hl),a			;6dab
	inc l			;6dac
	ld a,c			;6dad
	add a,(hl)			;6dae
	ld (hl),a			;6daf
	inc l			;6db0
	bit 7,(ix+00ah)		;6db1   ; el bit 7 de la velocidad elige el fotograma
	ld a,b			;6db5
	jr z,EMPUJA_PON		;6db6
	add a,004h		;6db8
EMPUJA_PON:
	ld (hl),a			;6dba
	ret			;6dbb
EMPUJA_FIN:		; Al acabar, la ficha vuelve a perseguir
	xor a			;6dbc
	ld (ix+001h),a		;6dbd   ; subestado 0: la ficha vuelve a lo suyo
	call ESCALA_DE_VELOCIDAD		;6dc0   ; al acabar la caida, velocidad nueva hacia el jugador
	ex de,hl			;6dc3
	ld a,(0e123h)		;6dc4   ; la Y del jugador decide el signo de la velocidad nueva
	sub (ix+004h)		;6dc7
	call c,NIEGA_DE		;6dca
	ld (ix+009h),e		;6dcd
	ld (ix+00ah),d		;6dd0
	ld (ix+00bh),080h		;6dd3
	ret			;6dd7
POSICION_ENEMIGO:		; L = Y, H = X del enemigo
	ld l,(ix+004h)		;6dd8
	ld h,(ix+005h)		;6ddb
	ret			;6dde
CARACTER_DELANTE:		; Lee el caracter del fondo que hay una fila por delante del enemigo
	call POSICION_ENEMIGO		;6ddf
	call DIRECCION_DE_NOMBRE		;6de2
	ld a,(ix+00ah)		;6de5   ; con velocidad negativa mira 0x20 arriba, con positiva 0x40 abajo
	add a,a			;6de8
	ld de,0ffe0h		;6de9
	jr c,CARACTER_DELANTE_LEE		;6dec
	ld de,00040h		;6dee
CARACTER_DELANTE_LEE:
	add hl,de			;6df1
	jp 0004ah		;6df2   ; BIOS RDVRM - Reads the content of VRAM
AVANZA_EN_Y:		; Suma la velocidad en Y (8.8) a la posicion
	ld a,(ix+009h)		;6df5   ; aqui la velocidad en Y va en +9/+A, no en +A/+B como en AVANZA
	add a,(ix+008h)		;6df8
	ld (ix+008h),a		;6dfb
	ld a,(ix+00ah)		;6dfe
	adc a,(ix+004h)		;6e01
	ld (ix+004h),a		;6e04
	ret			;6e07
REBOTA_ARRIBA_ABAJO:		; Invierte la velocidad si se sale por arriba o por abajo
	ld a,(ix+004h)		;6e08
	sub 00ch		;6e0b   ; fuera de 0x0C..0xB6 hay que rebotar
	cp 0aah		;6e0d
	ccf			;6e0f
	ret nc			;6e10
	ld a,(ix+004h)		;6e11
	sub 00ch		;6e14
	cp 0e3h		;6e16   ; por debajo de 0xEF ya se ha salido del todo
	ld a,(ix+00ah)		;6e18
	jr nc,REBOTA_POR_ABAJO		;6e1b
	and a			;6e1d
	ret m			;6e1e
INVIERTE_VELOCIDAD_Y:		; Le da la vuelta a la velocidad en Y del enemigo
	push de			;6e1f
	ld d,(ix+00ah)		;6e20   ; la velocidad en Y esta en +9/+A
	ld e,(ix+009h)		;6e23
	call NIEGA_DE		;6e26
	ld (ix+00ah),d		;6e29
	ld (ix+009h),e		;6e2c
	pop de			;6e2f
	scf			;6e30
	ret			;6e31
REBOTA_POR_ABAJO:
	and a			;6e32
	ret p			;6e33
	jr INVIERTE_VELOCIDAD_Y		;6e34
CHOCA_CON_EL_FONDO:		; Devuelve carry si el enemigo se ha ido fuera; rebota si toca fondo
	ld a,(ix+004h)		;6e36
	sub 00ch		;6e39   ; fuera del alto util no hay nada que mirar
	cp 0aah		;6e3b
	ret nc			;6e3d
	call CARACTER_DELANTE		;6e3e
	cp 00fh		;6e41   ; caracteres por debajo del 0x0F son fondo liso: se puede pasar
	ccf			;6e43
	ret nc			;6e44
	ld a,(0e102h)		;6e45
	and a			;6e48
	ld a,(ix+004h)		;6e49
	jr nz,CHOCA_BAJANDO		;6e4c
	cp 0b0h		;6e4e   ; subiendo, el tope es la fila 0xB0
	ccf			;6e50
	ret c			;6e51
	call INVIERTE_VELOCIDAD_Y		;6e52
	xor a			;6e55
	ret			;6e56
CHOCA_BAJANDO:
	cp 010h		;6e57
	ret c			;6e59
	call nc,INVIERTE_VELOCIDAD_Y		;6e5a
	xor a			;6e5d
	ret			;6e5e
NIEGA_DE:		; DE = -DE
	ld a,e			;6e5f   ; la vuelta al complemento a dos
	cpl			;6e60
	ld e,a			;6e61
	ld a,d			;6e62
	cpl			;6e63
	ld d,a			;6e64
	inc de			;6e65
	ret			;6e66

; ----------------------------------------------------------------------
; MATAR UN ENEMIGO. Libera la ficha, descuenta del encargo correspondiente y de la cuenta de vivos.
; ----------------------------------------------------------------------
MATA_ENEMIGO:		; Quita el enemigo al que apunta IX y descuenta las cuentas
	ld a,(ix+000h)		;6e67
	and a			;6e6a
	ret z			;6e6b
	ld c,a			;6e6c
	ld (ix+000h),000h		;6e6d   ; la ficha queda libre
	ld (ix+004h),0e0h		;6e71   ; y 0xE0 en la Y: fuera de la pantalla
	cp 00ah		;6e75   ; los tipos de 10 en adelante van por la cuenta de 0xE18C
	jr c,MATA_BUSCA_ENCARGO		;6e77
	ld hl,0e18ch		;6e79
	dec (hl)			;6e7c
	jr MATA_CUENTA_VIVOS		;6e7d
MATA_BUSCA_ENCARGO:
	ld hl,0e1d1h		;6e7f
	ld b,002h		;6e82
MATA_ENCARGO_BUCLE:
	ld a,(hl)			;6e84   ; +1 del encargo: cuantos quedan de esa clase
	dec l			;6e85
	and a			;6e86
	jr z,MATA_ENCARGO_SIGUIENTE		;6e87
	ld a,(hl)			;6e89
	cp c			;6e8a
	jr z,MATA_DESCUENTA		;6e8b
MATA_ENCARGO_SIGUIENTE:
	inc l			;6e8d   ; los encargos van de tres en tres bytes
	inc l			;6e8e
	inc l			;6e8f
	inc l			;6e90
	djnz MATA_ENCARGO_BUCLE		;6e91
	jr MATA_CUENTA_VIVOS		;6e93
MATA_DESCUENTA:
	inc l			;6e95
	dec (hl)			;6e96
MATA_CUENTA_VIVOS:
	ld hl,0e185h		;6e97   ; 0xE185 son los enemigos vivos
	ld a,(hl)			;6e9a
	and a			;6e9b
	ret z			;6e9c
	dec (hl)			;6e9d
	ret			;6e9e

; ----------------------------------------------------------------------
; ENEMIGO 4, EL RATON. El dibujo es el sprite 32 (patron 0x80, en 0x1A00 de la VRAM): dos orejas redondas, cabeza, patas y un rabo enroscado a la derecha. En el suelo alterna los patrones 0x80 y 0x84 (0x6EE5) y en el aire el 0x88 y el 0x8C (0x6F24). Va a saltos, apuntando al jugador.
; ----------------------------------------------------------------------
ENEMIGO_RATON:		; El raton que se mueve a saltos, apuntando al jugador
	ld a,(hl)			;6e9f
	dec a			;6ea0   ; subestado 1 y 2: muriendose
	jr z,SALTA_MUERE_DERECHA		;6ea1
	dec a			;6ea3
	jr z,SALTA_MUERE_IZQUIERDA		;6ea4
	jp p,SALTA_EN_EL_AIRE		;6ea6
	ld a,(ix+00bh)		;6ea9
	and a			;6eac
	jr z,SALTA_SUELO		;6ead
	dec (ix+00bh)		;6eaf   ; la cuenta del salto
	inc l			;6eb2
	ld a,(hl)			;6eb3
	and a			;6eb4
	jr z,SALTA_SIGUE		;6eb5
	dec (hl)			;6eb7
SALTA_SIGUE:
	inc hl			;6eb8
	jr nz,SALTA_MIRA_JUGADOR		;6eb9
	ld (hl),000h		;6ebb
SALTA_MIRA_JUGADOR:
	ld a,(0e124h)		;6ebd
	cp (ix+005h)		;6ec0   ; mira si el jugador esta a la izquierda o a la derecha
	jr z,SALTA_REBOTA		;6ec3
	ld a,000h		;6ec5
	jr nc,SALTA_COMPARA		;6ec7
	inc a			;6ec9
SALTA_COMPARA:
	ld c,a			;6eca
	push bc			;6ecb
	call CASILLA_LIBRE		;6ecc   ; y si la casilla de ese lado esta libre
	pop bc			;6ecf
	jr c,SALTA_REBOTA		;6ed0
	dec c			;6ed2
	jr z,SALTA_ARRANCA		;6ed3
	ld c,003h		;6ed5
	jr SALTA_PON_SUBESTADO		;6ed7
SALTA_REBOTA:
	call REBOTA_ARRIBA_ABAJO		;6ed9
SALTA_AVANZA:
	call AVANZA_EN_Y		;6edc
	call CHOCA_CON_EL_FONDO		;6edf
	jp c,MATA_ENEMIGO		;6ee2
	ld a,(0e180h)		;6ee5
	bit 1,a		;6ee8   ; el bit 1 del contador anima el salto
	ld a,080h		;6eea
	jr z,SALTA_PON_FOTOGRAMA		;6eec
	ld a,084h		;6eee
SALTA_PON_FOTOGRAMA:
	ld (ix+006h),a		;6ef0
	ret			;6ef3
SALTA_SUELO:
	call SALTA_AVANZA		;6ef4
	jp SALE_DE_LA_PANTALLA		;6ef7
SALTA_ARRANCA:
	ld c,004h		;6efa
SALTA_PON_SUBESTADO:
	ld (ix+001h),c		;6efc
	ld (ix+003h),018h		;6eff   ; 0x18 fotogramas de salto
	ret			;6f03
SALTA_MUERE_IZQUIERDA:
	ld c,0ffh		;6f04
	jr SALTA_MURIENDO		;6f06
SALTA_MUERE_DERECHA:
	ld c,001h		;6f08
SALTA_MURIENDO:
	inc l			;6f0a
	inc l			;6f0b
	dec (hl)			;6f0c   ; la cuenta de la caida al morir
	jr z,SALTA_MUERTO		;6f0d
	ld b,084h		;6f0f
	jp EMPUJA_CON_CURVA		;6f11
SALTA_MUERTO:
	dec l			;6f14
	ld (hl),011h		;6f15   ; al acabar, se queda con el subestado guardado
	dec l			;6f17
	ld a,(hl)			;6f18
	ld (hl),000h		;6f19
	inc l			;6f1b
	inc l			;6f1c
	ld (hl),a			;6f1d
	ret			;6f1e
SALTA_EN_EL_AIRE:
	inc l			;6f1f
	inc l			;6f20
	dec (hl)			;6f21
	jr z,SALTA_CAE		;6f22
	ld a,(0e180h)		;6f24
	bit 3,a		;6f27   ; en el aire cambia de fotograma cada ocho
	ld a,088h		;6f29
	jr z,SALTA_FOTOGRAMA_AIRE		;6f2b
	ld a,08ch		;6f2d
SALTA_FOTOGRAMA_AIRE:
	ld (ix+006h),a		;6f2f
	jp ARRASTRA_CON_EL_SCROLL		;6f32
SALTA_CAE:
	ld (hl),021h		;6f35   ; 0x21 fotogramas para la caida
	dec l			;6f37
	dec l			;6f38
	dec (hl)			;6f39   ; dos menos en el subestado: del 3 y el 4 se pasa al 1 y al 2
	dec (hl)			;6f3a
	ret			;6f3b

; ----------------------------------------------------------------------
; ENEMIGO 2: el que va y viene por la pantalla.
; ----------------------------------------------------------------------
ENEMIGO_VA_Y_VIENE:
	ld a,(hl)			;6f3c
	dec a			;6f3d   ; subestado 1 y 2: muriendose
	jp z,SALE_COMPARA		;6f3e
	dec a			;6f41
	jp z,SALE_SI		;6f42
	inc l			;6f45
	ld a,(hl)			;6f46
	and a			;6f47
	jp z,MIRA_SI_LE_DAN_3		;6f48
	ld a,(0e120h)		;6f4b   ; con el jugador muerto o invulnerable, este no ataca
	and a			;6f4e
	jp m,MIRA_SI_LE_DAN_3		;6f4f
	ld a,(0e11bh)		;6f52
	and a			;6f55
	jp nz,MIRA_SI_LE_DAN_3		;6f56
	ld a,(0e180h)		;6f59
	rra			;6f5c   ; la cuenta baja un fotograma si y otro no
	jr c,VA_Y_VIENE_PASO		;6f5d
	dec (hl)			;6f5f
VA_Y_VIENE_PASO:
	inc l			;6f60
	inc l			;6f61
	ld a,(hl)			;6f62
	inc l			;6f63
	cp 0c0h		;6f64   ; por debajo de 0xC0 esta fuera
	jp nc,MIRA_SI_LE_DAN_3		;6f66
	ld a,(0e124h)		;6f69   ; compara la X del jugador con la del enemigo
	sub (hl)			;6f6c
	jr z,VA_Y_VIENE_FOTOGRAMA		;6f6d
	ld a,000h		;6f6f
	jr nc,VA_Y_VIENE_GIRA		;6f71
	inc a			;6f73
VA_Y_VIENE_GIRA:
	call CASILLA_LIBRE		;6f74   ; mira si puede ir hacia ese lado
	jr c,VA_Y_VIENE_FIN		;6f77
	call LADO_DEL_JUGADOR		;6f79
	ld (ix+003h),021h		;6f7c   ; 0x21 fotogramas andando en esa direccion
	ld (ix+001h),c		;6f80
	ret			;6f83
VA_Y_VIENE_FOTOGRAMA:
	ld a,(0e123h)		;6f84   ; y si esta en la misma columna, se compara la Y
	sub (ix+004h)		;6f87
	ld c,000h		;6f8a
	jr nc,VA_Y_VIENE_MIRA		;6f8c
	inc c			;6f8e
VA_Y_VIENE_MIRA:
	ld a,(ix+00ah)		;6f8f   ; si mira al lado contrario del jugador, se da la vuelta
	rlca			;6f92
	and 001h		;6f93
	xor c			;6f95
	call nz,INVIERTE_VELOCIDAD_Y		;6f96
	ld a,(ix+004h)		;6f99
	cp 0c0h		;6f9c
	jr nc,VA_Y_VIENE_FIN		;6f9e
	ld a,(0e105h)		;6fa0   ; sin dificultad acumulada no dispara
	and a			;6fa3
	jr z,VA_Y_VIENE_FIN		;6fa4
	ld hl,0e123h		;6fa6
	sub (hl)			;6fa9
	add a,020h		;6faa   ; solo dispara si el jugador esta a menos de 0x20 en Y
	cp 040h		;6fac
	call nc,SUELTA_DISPARO_ENEMIGO		;6fae
	ld a,(ix+00ch)		;6fb1
	cp 010h		;6fb4
	jr nc,VA_Y_VIENE_FIN		;6fb6
	call ARRASTRA_CON_EL_SCROLL		;6fb8   ; y se deja arrastrar por el scroll
	jr MIRA_SI_LE_DAN		;6fbb
VA_Y_VIENE_FIN:
	call CHOCA_CON_EL_FONDO		;6fbd
	jp c,MATA_ENEMIGO		;6fc0
	call AVANZA_EN_Y		;6fc3
	call REBOTA_ARRIBA_ABAJO		;6fc6
MIRA_SI_LE_DAN:		; Si el jugador esta encima del enemigo, le mata
	ld a,(0e180h)		;6fc9
	and 008h		;6fcc   ; el bit 3 del contador anima
	ld a,09ch		;6fce
	jr z,MIRA_SI_LE_DAN_2		;6fd0
	ld a,0a0h		;6fd2
MIRA_SI_LE_DAN_2:
	ld (ix+006h),a		;6fd4
	ret			;6fd7
MIRA_SI_LE_DAN_3:
	call MIRA_SI_LE_DAN		;6fd8
	call AVANZA_EN_Y		;6fdb
	call CHOCA_CON_EL_FONDO		;6fde
	jp c,MATA_ENEMIGO		;6fe1
SALE_DE_LA_PANTALLA:		; Devuelve carry si el enemigo ya no esta en la pantalla
	ld a,(ix+004h)		;6fe4
	sub 0c1h		;6fe7   ; fuera de 0xC1..0xEE ya no esta en la pantalla
	cp 02eh		;6fe9
	ret nc			;6feb
	call MATA_ENEMIGO		;6fec
	scf			;6fef
	ret			;6ff0
SALE_COMPARA:
	ld c,001h		;6ff1
	jr SALE_NO		;6ff3
SALE_SI:
	ld c,0ffh		;6ff5
SALE_NO:
	ld b,09ch		;6ff7
	jp MUERE_CUENTA		;6ff9
CASILLA_LIBRE:		; Mira si la casilla de al lado esta libre de fondo
	ex de,hl			;6ffc
	call POSICION_ENEMIGO		;6ffd
	ex de,hl			;7000
CASILLA_LIBRE_2:
	ex af,af'			;7001
	ld a,e			;7002
	cp 0c0h		;7003   ; por debajo de 0xC0 no hay pantalla que mirar
	ccf			;7005
	ret c			;7006
	ex de,hl			;7007
	call DIRECCION_DE_NOMBRE		;7008
	ex af,af'			;700b
	and a			;700c
	ld a,002h		;700d   ; dos columnas a un lado o al otro
	jr z,CASILLA_LIBRE_FIN		;700f
	ld a,0feh		;7011
CASILLA_LIBRE_FIN:
	add a,l			;7013
	ld l,a			;7014
	call 0004ah		;7015   ; BIOS RDVRM - Reads the content of VRAM
	ex de,hl			;7018
	and a			;7019
	dec a			;701a   ; solo el caracter 1 deja pasar
	ret z			;701b
	scf			;701c
	ret			;701d

; ----------------------------------------------------------------------
; ENEMIGO 3: el que se mueve en linea recta y rebota.
; ----------------------------------------------------------------------
ENEMIGO_RECTO:
	ld a,(ix+00ch)		;701e
	and a			;7021   ; mientras la cuenta no llegue a cero no se puede volver a girar
	jr z,RECTO_PASO		;7022
	dec (ix+00ch)		;7024
RECTO_PASO:
	ld a,(0e180h)		;7027
	and 003h		;702a   ; gira cada cuatro fotogramas
	jr nz,RECTO_FOTOGRAMA		;702c
	ld a,(ix+00bh)		;702e
	inc a			;7031   ; tres fotogramas en circulo, del 0x90 al 0x98
	cp 003h		;7032
	jr c,RECTO_GIRA		;7034
	xor a			;7036
RECTO_GIRA:
	ld (ix+00bh),a		;7037
	add a,a			;703a
	add a,a			;703b
	add a,090h		;703c
	ld (ix+006h),a		;703e
RECTO_FOTOGRAMA:
	ld a,(hl)			;7041
	and a			;7042
	jp nz,SALTO_PARABOLA		;7043   ; con subestado, es que esta saltando
	inc l			;7046
	ld a,(hl)			;7047
	and a			;7048
	jr z,RECTO_FIN		;7049
	ld a,(ix+00ch)		;704b
	and a			;704e
	jr nz,RECTO_FIN		;704f
	ex de,hl			;7051
	call POSICION_ENEMIGO		;7052
	ex de,hl			;7055
	bit 7,(ix+00ah)		;7056   ; el bit 7 de la velocidad dice a que lado mirar
	ld a,010h		;705a
	jr nz,RECTO_MIRA		;705c
	add a,e			;705e
	ld e,a			;705f
RECTO_MIRA:
	push de			;7060
	xor a			;7061
	call CASILLA_LIBRE_2		;7062   ; mira dos columnas a un lado
	pop de			;7065
	jr nc,MUERE_A_UN_LADO		;7066
	ld a,001h		;7068
	call CASILLA_LIBRE_2		;706a   ; y dos al otro
	jr nc,MUERE_AL_OTRO		;706d
RECTO_FIN:
	call AVANZA_EN_Y		;706f
	call SALE_DE_LA_PANTALLA		;7072
	call POSICION_ENEMIGO		;7075
	ld a,l			;7078
	cp 0c0h		;7079
	ret nc			;707b
	call DIRECCION_DE_NOMBRE		;707c   ; el caracter que hay justo donde esta
	call 0004ah		;707f   ; BIOS RDVRM - Reads the content of VRAM
	cp 010h		;7082   ; del 0x10 para arriba es fondo: se muere
	ret c			;7084
	ld c,048h		;7085
EMPIEZA_A_MORIR:		; Deja la ficha en "muriendo": tipo 0xFF, contador 0x10 y el fotograma de la explosion
	ld (ix+006h),c		;7087
	ld (ix+007h),00fh		;708a
	ld a,(ix+000h)		;708e
	ld (ix+002h),a		;7091   ; el tipo se guarda en +2 para poder deshacer la muerte
	ld (ix+000h),0ffh		;7094   ; tipo 0xFF: muriendose, con 0x10 fotogramas de explosion
	ld (ix+001h),010h		;7098
	ret			;709c
MUERE_A_UN_LADO:
	ld c,001h		;709d
	jr MUERE_CUENTA_ATRAS		;709f
MUERE_AL_OTRO:
	ld c,002h		;70a1
MUERE_CUENTA_ATRAS:
	dec (ix+002h)		;70a3
	ld (ix+00ch),00ah		;70a6   ; y 0x0A fotogramas de espera entre pasos
	jr nz,RECTO_FIN		;70aa
	ld (ix+003h),019h		;70ac   ; 0x19 pasos de salto
	ld (ix+001h),c		;70b0
	ret			;70b3
SALTO_PARABOLA:		; El salto del enemigo 4, con la tabla de pasos de 0x712B
	ld a,(0e180h)		;70b4   ; con el bit 0 del contador el salto va a mitad de velocidad
	rra			;70b7
	ret c			;70b8
	ld c,(ix+001h)		;70b9
	dec (ix+003h)		;70bc
	jr z,SALTO_ATERRIZA		;70bf   ; al acabar los pasos, aterriza
	ld a,(ix+003h)		;70c1
	ld e,a			;70c4
	ld d,000h		;70c5
	cp 00dh		;70c7   ; la primera mitad del salto sube y la segunda baja
	jr nc,SALTO_SENTIDO		;70c9
	set 7,d		;70cb
SALTO_SENTIDO:
	bit 7,(ix+00ah)		;70cd   ; el bit 7 de la velocidad invierte el lado
	jr z,SALTO_LADO		;70d1
	ld a,d			;70d3
	xor 080h		;70d4
	ld d,a			;70d6
SALTO_LADO:
	dec c			;70d7
	jr z,SALTO_PASO		;70d8
	set 6,d		;70da
SALTO_PASO:
	ld a,(ix+003h)		;70dc
	sub 00dh		;70df
	jr c,SALTO_PASO_NEGATIVO		;70e1
	ld hl,0712bh		;70e3   ; la tabla de pasos: nibble alto en Y, nibble bajo en X
	ld c,a			;70e6
	ld a,00bh		;70e7   ; la tabla se recorre al reves en la segunda mitad
	sub c			;70e9
	call SUMA_A_HL		;70ea
SALTO_LEE:
	ld a,(hl)			;70ed
	rra			;70ee
	rra			;70ef
	rra			;70f0
	rra			;70f1
	and 00fh		;70f2   ; nibble bajo: lo que avanza en Y
	bit 7,d		;70f4
	jr z,SALTO_APLICA_Y		;70f6
	neg		;70f8
SALTO_APLICA_Y:
	add a,(ix+004h)		;70fa
	ld (ix+004h),a		;70fd
	ld a,(hl)			;7100
	and 00fh		;7101   ; nibble alto: lo que avanza en X
	bit 6,d		;7103
	jr z,SALTO_APLICA_X		;7105
	neg		;7107
SALTO_APLICA_X:
	add a,(ix+005h)		;7109
	ld (ix+005h),a		;710c
	ret			;710f
SALTO_PASO_NEGATIVO:		; La otra mitad del salto: el mismo paso con el indice negativo
	ld hl,07137h		;7110
	ld c,a			;7113
	ld b,0ffh		;7114
	add hl,bc			;7116
	jr SALTO_LEE		;7117
SALTO_ATERRIZA:
	ld (hl),000h		;7119
	ld e,(ix+009h)		;711b
	ld d,(ix+00ah)		;711e
	call NIEGA_DE		;7121   ; al aterrizar se le da la vuelta a la velocidad
	ld (ix+009h),e		;7124
	ld (ix+00ah),d		;7127
	ret			;712a

; ----------------------------------------------------------------------
; DATOS pasos_del_salto: Doce bytes con dos nibbles cada uno: el de arriba es
;   lo que avanza en Y y el de abajo lo que avanza en X en cada paso del
;   salto. 0x70E3 los lee de frente y 0x7110 al reves (con el indice negativo)
;   0x712b..0x7137  (12 bytes)
DATA_pasos_del_salto:
	defb 020h,021h,020h,021h,011h,011h,022h,012h,012h,012h,002h,002h	; 712b   ! !..".....

; ======================================================================
; CODIGO 0x7137..0x7259  (290 bytes)
; ======================================================================


ENEMIGO_CALAVERA:		; La calavera: patrones 0x70 y 0x74 (sprites 28 y 29), craneo con dos cuencas y dentadura. Se queda en el sitio y solo la arrastra el scroll
	ld a,(0e180h)		;7137
	and 004h		;713a   ; el bit 2 del contador anima
	ld a,070h		;713c
	jr z,QUIETO_FOTOGRAMA		;713e
	ld a,074h		;7140
QUIETO_FOTOGRAMA:
	ld (ix+006h),a		;7142
	call AVANZA_EN_Y		;7145
	jp SALE_DE_LA_PANTALLA		;7148
FOTOGRAMA_SUELTO:		; Elige el fotograma como 0x6D62 y 0x7137, pero no lo llama nadie
	ld a,(0e180h)		;714b
	and 008h		;714e
	ld a,c			;7150
	jr z,FOTOGRAMA_SUELTO_PON		;7151
	add a,004h		;7153
FOTOGRAMA_SUELTO_PON:
	ld (ix+006h),a		;7155
	ret			;7158
ENEMIGO_BAJA:		; El que baja hasta la fila 0x60 y alli se queda
	call FOTOGRAMA_0x10		;7159
BAJA_PASO:
	ld a,(hl)			;715c
	dec a			;715d   ; subestado 1 y 2
	jr z,BAJA_ESPERA		;715e
	dec a			;7160
	jr z,BAJA_MIRA		;7161
	call AVANZA		;7163
	ld a,(ix+004h)		;7166   ; al llegar a la fila 0x60 se para
	cp 060h		;7169
	ret nz			;716b
	ld (ix+001h),001h		;716c
	ret			;7170
BAJA_MIRA:
	call AVANZA		;7171
	jp MUERE_SI_SE_SALE		;7174
BAJA_ESPERA:
	inc l			;7177
	ld a,(0e180h)		;7178   ; la cuenta baja un fotograma si y otro no
	and 001h		;717b
	jr nz,$+4		;717d   ; salta a 0x7181, que es el segundo byte del `jr z` de la linea siguiente
	dec (hl)			;717f
	jr z,BAJA_FIN		;7180
	ld c,002h		;7182
	jp PERSIGUE		;7184
BAJA_FIN:
	dec l			;7187
	ld (hl),002h		;7188
	ret			;718a
ARRASTRA_CON_EL_SCROLL:		; Un pixel arriba o abajo cada cuatro fotogramas, para que el enemigo no se quede clavado en la pantalla
	ld a,(0e003h)		;718b   ; un pixel cada cuatro fotogramas
	and 003h		;718e
	cp 003h		;7190
	ret nz			;7192
	ld a,(0e102h)		;7193
	and a			;7196
	jr nz,ARRASTRA_ABAJO		;7197
	inc (ix+004h)		;7199
	ret			;719c
ARRASTRA_ABAJO:
	dec (ix+004h)		;719d
	ret			;71a0
ENEMIGO_MARIPOSA:		; La mariposa: patrones 0x78 y 0x7C (sprites 30 y 31), dos alas arriba y dos abajo con el cuerpo en medio. Baja igual que el tipo 11 y su color sale de la tabla de 0x69FC
	call FOTOGRAMA_0x78		;71a1
	jr BAJA_PASO		;71a4
ENEMIGO_HASTA_0xD0:		; Persigue y se muere al llegar a la fila 0xD0
	call PERSIGUE_LENTO		;71a6
	ld a,(ix+004h)		;71a9
	cp 0d0h		;71ac   ; al llegar a la fila 0xD0 se le quita
	jp z,MATA_ENEMIGO		;71ae
	ret			;71b1
ENEMIGO_EN_CIRCULO:		; El que da vueltas alrededor del jugador
	ld a,(ix+005h)		;71b2
	cp 0c0h		;71b5   ; pasada la columna 0xC0 se le quita
	jp nc,MATA_ENEMIGO		;71b7
	call FOTOGRAMA_0x10		;71ba   ; fotogramas 0x10 y 0x14
	ld a,(hl)			;71bd
	dec a			;71be
	jr z,CIRCULO_MIRA		;71bf
	dec a			;71c1
	jr nz,CIRCULO_PASO		;71c2
	inc l			;71c4
	inc l			;71c5
	dec (hl)			;71c6
	jr nz,ENEMIGO_HASTA_0xD0		;71c7
	jr CIRCULO_GIRA		;71c9
CIRCULO_PASO:
	inc l			;71cb
	inc l			;71cc
	dec (hl)			;71cd   ; +3 es la cuenta de la vuelta
	jr z,CIRCULO_GIRA		;71ce
	ld c,00ah		;71d0   ; con color 10, parpadeando
	jp ACECHA_PARPADEO		;71d2
CIRCULO_GIRA:
	ld (ix+007h),00ah		;71d5   ; color 10 fijo: deja de parpadear
	ld (hl),0ffh		;71d9
	call PON_OBJETIVO_JUGADOR		;71db
	ld (ix+001h),001h		;71de
	ld (ix+003h),060h		;71e2   ; 0x60 fotogramas dando vueltas
	ret			;71e6
CIRCULO_MIRA:
	call AVANZA		;71e7
	ld a,(ix+004h)		;71ea   ; al llegar a la fila 0xD0 se le quita
	cp 0d0h		;71ed
	jp z,MATA_ENEMIGO		;71ef
	inc l			;71f2
	ld a,(hl)			;71f3
	and a			;71f4
	jp z,MUERE_SI_SE_SALE		;71f5
	ld a,(0e180h)		;71f8   ; la cuenta baja un fotograma de cada cuatro
	and 003h		;71fb
	jr nz,CIRCULO_FIN		;71fd
	dec (hl)			;71ff
CIRCULO_FIN:
	inc l			;7200
	dec (hl)			;7201
	ret nz			;7202
	ld (ix+001h),002h		;7203   ; subestado 2 y 0x68 fotogramas mas
	ld (hl),068h		;7207
	ld de,00007h		;7209
	add hl,de			;720c
	call LEE_OBJETIVO		;720d   ; el objetivo por 16, para repartir la vuelta
	ld a,(ix+005h)		;7210
	sub d			;7213
	ld (ix+00fh),a		;7214
	call LEE_OBJETIVO		;7217
	add a,(ix+004h)		;721a
	ld (ix+00eh),a		;721d
	ret			;7220
PON_OBJETIVO_JUGADOR:		; Deja como objetivo del enemigo la posicion del jugador
	ld de,(0e123h)		;7221   ; D = X del jugador, E = Y
	ld bc,00000h		;7225
	ld a,d			;7228   ; B y C se quedan con de que lado esta
	sub (ix+005h)		;7229
	jr nc,OBJETIVO_PASO		;722c
	inc b			;722e
OBJETIVO_PASO:
	ld a,e			;722f
	sub (ix+004h)		;7230
	jr nc,PLANEA		;7233
	inc c			;7235
PLANEA:		; Coge una de las cuatro velocidades de 0x7259, sorteada con el registro R
	ld a,r		;7236   ; el registro R del Z80 hace de dado
	and 00ch		;7238
	ld hl,07259h		;723a
	call LEE_PALABRA		;723d
	inc hl			;7240
	dec c			;7241
	call z,NIEGA_DE		;7242   ; y una de cada dos veces la velocidad se invierte
	ld (ix+00ah),e		;7245
	ld (ix+00bh),d		;7248
	ld e,(hl)			;724b
	inc hl			;724c
	ld d,(hl)			;724d
	dec b			;724e
	call z,NIEGA_DE		;724f
	ld (ix+00ch),e		;7252
	ld (ix+00dh),d		;7255
	ret			;7258

; ----------------------------------------------------------------------
; DATOS velocidades_del_planeo: Cuatro parejas de velocidades (Y, X) en 8.8
;   que 0x723A sortea con el registro R
;   0x7259..0x7269  (16 bytes)
DATA_velocidades_del_planeo:
	defw 000b5h,000b5h	; 7259
	defw 00061h,000ech	; 725d
	defw 000b5h,000b5h	; 7261
	defw 000ech,00061h	; 7265

; ======================================================================
; CODIGO 0x7269..0x730e  (165 bytes)
; ======================================================================


ENEMIGO_PLANEA:		; El que planea cambiando de rumbo al azar
	ld a,(0e003h)		;7269
	and 006h		;726c   ; dos fotogramas de cada ocho
	jr nz,PLANEA_FIN		;726e
	ld a,(hl)			;7270
	inc a			;7271
	cp 003h		;7272
	jr c,PLANEA_PASO		;7274
	xor a			;7276
PLANEA_PASO:
	ld (hl),a			;7277
	add a,a			;7278
	add a,a			;7279
	add a,04ch		;727a   ; tres fotogramas: 0x4C, 0x50 y 0x54
	ld (ix+006h),a		;727c
PLANEA_FIN:
	call AVANZA_EN_Y		;727f
	jp SALE_DE_LA_PANTALLA		;7282
ENEMIGO_JEFE:		; El del tramo 6 de las fases 1 y 3, que van ocho o diez de golpe: cruza la pantalla de un lado a otro. Lleva el mismo dibujo que los tipos 6 y 11 (patron 0x10), en rojo oscuro
	ld a,(hl)			;7285
	inc l			;7286
	and a			;7287
	jr nz,JEFE_FOTOGRAMA		;7288
	call SALE_DE_LA_PANTALLA		;728a
	ret c			;728d
	ld (ix+003h),021h		;728e
	ld a,(hl)			;7292
	and a			;7293
	ld a,(ix+005h)		;7294   ; +5 es la X del jefe
	jr nz,JEFE_MIRA		;7297
	cp 098h		;7299   ; pasada la columna 0x98 se da la vuelta
	jr c,JEFE_PASO		;729b
	inc (hl)			;729d
JEFE_PASO:
	dec l			;729e
	inc (hl)			;729f
	ret			;72a0
JEFE_MIRA:
	cp 019h		;72a1   ; y por debajo de la 0x19, tambien
	jr nc,JEFE_GIRA		;72a3
	dec (hl)			;72a5
JEFE_GIRA:
	dec l			;72a6
	inc (hl)			;72a7
	ret			;72a8
JEFE_FOTOGRAMA:
	ld e,(hl)			;72a9
	inc l			;72aa
	dec (hl)			;72ab   ; +3 es la cuenta de la embestida
	jr nz,JEFE_AVANZA		;72ac
	dec l			;72ae
	dec l			;72af
	dec (hl)			;72b0
	ret			;72b1
JEFE_AVANZA:
	ld a,(0e102h)		;72b2
	and a			;72b5
	ld bc,00040h		;72b6
	jr z,JEFE_FIN		;72b9
	ld bc,0ffc0h		;72bb
JEFE_FIN:
	ld (ix+00ah),b		;72be   ; +9/+A: la velocidad en Y del jefe, en el sentido del scroll
	ld (ix+009h),c		;72c1
	ld c,001h		;72c4
	dec e			;72c6
	jr nz,JEFE_MUERE		;72c7
	ld c,0ffh		;72c9
JEFE_MUERE:
	ld b,028h		;72cb   ; la misma curva de empuje que usa el jugador
	call EMPUJA_CON_CURVA		;72cd
	call AVANZA_EN_Y		;72d0
	ld a,(ix+004h)		;72d3
	cp 0d0h		;72d6   ; al llegar a la fila 0xD0 se le quita
	ret nz			;72d8
	jp MATA_ENEMIGO		;72d9

; ----------------------------------------------------------------------
; ENCARGAR ENEMIGOS. 0xE171 lleva los encargos pendientes; cada uno pone en marcha un enemigo del tipo que dice la tabla de 0x730E.
; ----------------------------------------------------------------------
ENCARGA_ENEMIGO:		; Si toca, encarga un enemigo del tipo de esta fase
	ld a,(0e181h)		;72dc
	and a			;72df
	ret nz			;72e0
	ld hl,0e171h		;72e1   ; 0xE171 son los encargos pendientes
	ld a,(hl)			;72e4
	and a			;72e5
	jr z,$+48		;72e6
	ld a,(0e185h)		;72e8   ; con cuatro o mas vivos no se encarga nada
	cp 004h		;72eb
	ret nc			;72ed
	ld a,(0e18ch)		;72ee
	and a			;72f1
	ret nz			;72f2
	dec (hl)			;72f3
	ld hl,0e103h		;72f4   ; el tipo depende de la fase
	ld a,(hl)			;72f7
	ld de,0730eh		;72f8
	call SUMA_A_DE		;72fb
	ld a,(de)			;72fe
	ld hl,0e182h		;72ff
	ld (hl),a			;7302
	ld a,006h		;7303   ; seis enemigos de esa clase
	dec l			;7305
	ld (hl),a			;7306
	ld hl,0e18ch		;7307
	ld (hl),a			;730a
	inc l			;730b
	ld (hl),a			;730c
	ret			;730d

; ----------------------------------------------------------------------
; DATOS enemigo_por_fase: El tipo de enemigo que suelta 0x72DC en cada una de
;   las ocho fases: 0x0A o 0x0B
;   0x730e..0x7316  (8 bytes)
DATA_enemigo_por_fase:
	defb 00ah,00ah,00bh,00ah,00bh,00ah,00bh,00ah	; 730e  ........

; ======================================================================
; CODIGO 0x7316..0x73ae  (152 bytes)
; ======================================================================


ENCARGA_POR_TRAMO:		; Mira la tabla de 0x73AE y encarga la tanda que toque en este tramo
	ld a,(0e103h)		;7316
	cp 006h		;7319   ; antes de la fase 6 no hay jefe
	jr c,ENCARGA_TRAMO		;731b
	ld hl,(0e100h)		;731d   ; en las fases de la 6 en adelante, pasado cierto punto se encarga el jefe
	ld a,h			;7320
	ld de,0061dh		;7321   ; el jefe sale pasada la posicion 0x061D
	sbc hl,de		;7324
	and a			;7326
	ld de,000c0h		;7327
	sbc hl,de		;732a
	jr nc,ENCARGA_JEFE		;732c
	ld hl,0e181h		;732e
	ld (hl),001h		;7331   ; un enemigo del tipo 7, que es el jefe
	inc l			;7333
	ld (hl),007h		;7334
	ret			;7336
ENCARGA_JEFE:
	sub 006h		;7337   ; con A = 6 no se encarga nada
	ret z			;7339
	dec a			;733a
	jr nz,ENCARGA_TRAMO		;733b
	ld a,l			;733d
	cp 030h		;733e   ; y con 7, solo pasada la fila 0x30
	ret c			;7340
ENCARGA_TRAMO:
	ld a,(0e117h)		;7341
	sub 002h		;7344   ; el tramo, de dos en dos
	jp p,ENCARGA_TOPE		;7346
	xor a			;7349
ENCARGA_TOPE:
	cp 008h		;734a
	jr c,ENCARGA_INDICE		;734c
	ld a,008h		;734e
ENCARGA_INDICE:
	and 0feh		;7350   ; diez parejas por fase, elegidas por el tramo
	add a,a			;7352
	ld c,a			;7353
	ld a,(0e103h)		;7354   ; veinte bytes por fase
	ld l,a			;7357
	ld h,000h		;7358
	add hl,hl			;735a
	add hl,hl			;735b
	ld e,l			;735c
	ld d,h			;735d
	add hl,hl			;735e
	add hl,hl			;735f
	add hl,de			;7360
	ld de,073aeh		;7361
	add hl,de			;7364
	ld b,000h		;7365
	add hl,bc			;7367
	ex de,hl			;7368
	ld hl,0e1d1h		;7369
	push de			;736c   ; la primera pareja libre de las dos de 0xE1D0
	call ENCARGA_TANDA		;736d
	pop de			;7370
	ret c			;7371
	ld hl,0e1d4h		;7372
	inc de			;7375
	inc de			;7376
ENCARGA_TANDA:		; Apunta la tanda en 0xE1D0 (tipo, cuantos, cuantos quedan)
	ld a,(0e105h)		;7377
	sra a		;737a
	ld c,a			;737c
	ld a,(hl)			;737d   ; si la pareja esta ocupada no se encarga nada
	and a			;737e
	ret nz			;737f
	dec l			;7380
	ld a,(de)			;7381   ; un 0 en el tipo quiere decir "en este tramo no sale nada"
	and a			;7382
	ret z			;7383
	ld b,a			;7384
	inc de			;7385
	ld a,(de)			;7386
	exx			;7387
	ld c,a			;7388
	ld a,(0e115h)		;7389   ; 0xE115 elige el nibble alto o el bajo del byte de cantidad
	and a			;738c
	ld a,c			;738d
	jr nz,ENCARGA_CUANTOS		;738e
	rra			;7390
	rra			;7391
	rra			;7392
	rra			;7393
ENCARGA_CUANTOS:
	and 00fh		;7394
	exx			;7396
	and a			;7397
	ret z			;7398
	add a,c			;7399
	cp 00ah		;739a   ; tope de diez a la vez
	jr c,ENCARGA_APUNTA		;739c
	ld a,00ah		;739e
ENCARGA_APUNTA:
	ld (hl),b			;73a0   ; el encargo: tipo, cuantos y cuantos quedan
	inc l			;73a1
	ld (hl),a			;73a2
	inc l			;73a3
	ld (hl),a			;73a4
	ld (0e181h),a		;73a5   ; 0xE181 y 0xE182: los que faltan por soltar y de que tipo
	ld a,b			;73a8
	ld (0e182h),a		;73a9
	scf			;73ac
	ret			;73ad

; ----------------------------------------------------------------------
; DATOS encargos_por_fase: Ocho fases de veinte bytes: diez parejas (tipo de
;   enemigo, cuantos). 0x7316 elige la pareja por la fila del tramo, y 0xE1D0
;   lleva la cuenta de los que van saliendo
;   0x73ae..0x744e  (160 bytes)
DATA_encargos_por_fase:
	defb 002h,048h,001h,008h,002h,006h,003h,056h,002h,005h,001h,055h,002h,045h,001h,044h,002h,052h,001h,052h	; 73ae  .H.....V...U.E.D.R.R
	defb 004h,044h,003h,045h,006h,022h,002h,045h,004h,054h,001h,045h,008h,088h,000h,000h,004h,063h,002h,044h	; 73c2  .D.E.".E.T.E.....c.D
	defb 001h,055h,002h,035h,009h,056h,005h,042h,003h,056h,001h,055h,009h,055h,005h,042h,001h,073h,002h,072h	; 73d6  .U.5.V.B.V.U.U.B.s.r
	defb 001h,065h,006h,032h,009h,065h,001h,052h,009h,065h,002h,032h,008h,08ah,000h,000h,002h,073h,001h,072h	; 73ea  .e.2.e.R.e.2.....s.r
	defb 004h,053h,002h,045h,006h,033h,002h,054h,004h,074h,001h,054h,005h,041h,001h,054h,004h,072h,002h,064h	; 73fe  .S.E.3.T.t.T.A.T.r.d
	defb 009h,055h,005h,041h,009h,055h,005h,041h,001h,054h,002h,054h,009h,08ah,005h,041h,001h,073h,002h,083h	; 7412  .U.A.U.A.T.T...A.s..
	defb 001h,055h,002h,036h,006h,022h,001h,045h,005h,074h,001h,055h,000h,000h,000h,000h,006h,073h,001h,055h	; 7426  .U.6.".E.t.U.....s.U
	defb 001h,067h,002h,047h,001h,066h,006h,023h,003h,074h,002h,045h,000h,000h,000h,000h,001h,084h,002h,072h	; 743a  .g.G.f.#.t.E.......r

; ======================================================================
; CODIGO 0x744e..0x751a  (204 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LOS DISPAROS CONTRA LOS ENEMIGOS. Los dos disparos del jugador se cruzan con las diez fichas de enemigo.
; ----------------------------------------------------------------------
HAY_DISPARO_1:		; Deja en DE la posicion del primer disparo y la Z si no esta vivo
	ld de,(0e1e3h)		;744e
	ld c,000h		;7452
	ld a,(0e1e0h)		;7454
	and a			;7457
	ret			;7458
HAY_DISPARO_2:		; Lo mismo con el segundo
	ld de,(0e1ebh)		;7459
	ld c,008h		;745d
	ld a,(0e1e8h)		;745f
	and a			;7462
	ret			;7463
MIRA_DISPAROS:		; Cruza los dos disparos con los enemigos
	call HAY_DISPARO_1		;7464
	call nz,DISPARO_CONTRA_ENEMIGOS		;7467
	call HAY_DISPARO_2		;746a
	ret z			;746d
DISPARO_CONTRA_ENEMIGOS:		; Recorre los diez enemigos buscando uno a menos de 10 pixeles
	ld hl,0e200h		;746e
	ld b,00ah		;7471
DISPARO_UNA_FICHA:
	ld a,(hl)			;7473
	inc l			;7474
	inc l			;7475
	inc l			;7476   ; la Y del enemigo esta en el byte 4 de la ficha
	inc l			;7477
	dec a			;7478
	jp m,DISPARO_SIGUIENTE		;7479
	ld a,(hl)			;747c
	sub e			;747d
	add a,00ah		;747e   ; a menos de 10 pixeles en Y...
	cp 014h		;7480
	jr nc,DISPARO_SIGUIENTE		;7482
	inc l			;7484
	ld a,(hl)			;7485
	dec l			;7486
	sub d			;7487
	add a,00ah		;7488   ; ...y a menos de 10 en X: tocado
	cp 014h		;748a
	jr c,ENEMIGO_TOCADO_YA		;748c
DISPARO_SIGUIENTE:
	ld a,00ch		;748e
	add a,l			;7490   ; la ficha siguiente, 16 bytes mas alla
	ld l,a			;7491
	djnz DISPARO_UNA_FICHA		;7492
	ret			;7494
ENEMIGO_TOCADO:		; Un enemigo tocado: si aguanta, solo baja su resistencia
	ld hl,0e18dh		;7495
	dec (hl)			;7498   ; 0xE18D es la resistencia del que aguanta varios tiros
	jr z,TOCADO_MUERE		;7499
	jr TOCADO_MUERE_2		;749b
ENEMIGO_TOCADO_YA:		; Apunta cual es y decide si muere
	ld a,c			;749d
	ld (0e302h),a		;749e
	ld a,l			;74a1
	and 0f0h		;74a2   ; la ficha empieza en un multiplo de 16
	ld l,a			;74a4
	ld a,(hl)			;74a5
	ld (0e303h),a		;74a6
	push hl			;74a9
	pop ix		;74aa
	cp 00ah		;74ac   ; los tipos de 10 en adelante son los duros
	jr nc,ENEMIGO_TOCADO		;74ae
	cp 007h		;74b0
	jr z,TOCADO_FIN		;74b2
	ld b,002h		;74b4   ; busca el encargo al que pertenece para descontarlo
	ld hl,0e1d0h		;74b6
TOCADO_BUSCA_ENCARGO:
	cp (hl)			;74b9   ; busca el encargo de ese tipo, de tres en tres bytes
	jr z,TOCADO_RESISTE		;74ba
	inc l			;74bc
	inc l			;74bd
	inc l			;74be
	djnz TOCADO_BUSCA_ENCARGO		;74bf
TOCADO_RESISTE:
	inc l			;74c1
	inc l			;74c2
	dec (hl)			;74c3   ; un tiro menos de aguante
	jr nz,TOCADO_MUERE_2		;74c4
TOCADO_MUERE:		; Explosion, puntos y sonido
	ld a,(0e1a7h)		;74c6
	and a			;74c9
	jr nz,TOCADO_MUERE_2		;74ca
	ld a,(0e303h)		;74cc
	cp 00ah		;74cf
	push af			;74d1
	ld c,05ch		;74d2   ; el fotograma de la explosion: 0x5C o 0x60
	jr c,TOCADO_EXPLOTA		;74d4
	ld c,060h		;74d6
TOCADO_EXPLOTA:
	call EMPIEZA_A_MORIR		;74d8
	ld de,00050h		;74db
	pop af			;74de
	jr c,TOCADO_PUNTOS		;74df
	ld de,00100h		;74e1
TOCADO_PUNTOS:
	jr TOCADO_SUMA_PUNTOS		;74e4
TOCADO_MUERE_2:
	ld a,(0e1a7h)		;74e6   ; en el final de fase la explosion es otra
	and a			;74e9
	push af			;74ea
	ld c,048h		;74eb
	jr z,TOCADO_EXPLOTA_2		;74ed
	ld c,060h		;74ef
TOCADO_EXPLOTA_2:
	call EMPIEZA_A_MORIR		;74f1
	ld a,(0e303h)		;74f4   ; los puntos del tipo, de la tabla de 0x751A
	ld hl,07519h		;74f7
	call SUMA_A_HL		;74fa
	ld e,(hl)			;74fd
	ld d,000h		;74fe
	pop af			;7500
	jr z,TOCADO_SUMA_PUNTOS		;7501
	ld de,00100h		;7503
TOCADO_SUMA_PUNTOS:		; Suma los puntos del tipo y hace sonar el 5
	call SUMA_PUNTOS		;7506
	ld a,005h		;7509   ; y el sonido 5
	call PIDE_SONIDO		;750b
TOCADO_FIN:
	ld a,(0e1a7h)		;750e   ; en el trono el disparo no se apaga
	and a			;7511
	ret nz			;7512
	ld a,(0e302h)		;7513
	ld c,a			;7516
	jp APAGA_DISPARO		;7517

; ----------------------------------------------------------------------
; DATOS puntos_por_enemigo: Once valores, uno por tipo de enemigo: 0x7506 los
;   multiplica por 16 y los suma en BCD. Con el cero fijo del panel salen 600,
;   800, 500, 500, 700, 1000, 0, 800, 500, 600 y 600 puntos
;   0x751a..0x7525  (11 bytes)
DATA_puntos_por_enemigo:
	defb 006h,008h,005h,005h,007h,010h,000h,008h,005h,006h,006h	; 751a  ...........

; ======================================================================
; CODIGO 0x7525..0x7654  (303 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL CHOQUE DEL JUGADOR CON UN ENEMIGO. Rectangulo de 12x8 (o 18x13 en el final de fase) alrededor del jugador.
; ----------------------------------------------------------------------
MIRA_CHOQUE_CON_ENEMIGO:		; Si un enemigo toca al jugador, el jugador se muere
	ld a,(0e1a7h)		;7525
	ld de,00c18h		;7528   ; rectangulo de 12 x 8 alrededor del jugador
	ld bc,00810h		;752b
	and a			;752e
	jr z,CHOQUE_ENEMIGO_POSICION		;752f
	ld de,01224h		;7531   ; y de 18 x 13 en el final de fase
	ld bc,00d1ah		;7534
CHOQUE_ENEMIGO_POSICION:
	exx			;7537
	ld de,(0e123h)		;7538   ; E = Y, D = X del jugador
	jr nz,CHOQUE_ENEMIGO_BUCLE		;753c
	ld a,e			;753e   ; de pie se mira cuatro pixeles mas arriba
	sub 004h		;753f
	ld e,a			;7541
CHOQUE_ENEMIGO_BUCLE:
	ld hl,0e200h		;7542
	ld b,00ah		;7545
CHOQUE_ENEMIGO_FICHA:
	ld a,(hl)			;7547
	inc l			;7548   ; hasta +4, que es la Y del enemigo
	inc l			;7549
	inc l			;754a
	inc l			;754b
	dec a			;754c   ; tipo 0 o negativo: no hay enemigo que valga
	jp m,CHOQUE_ENEMIGO_SIGUIENTE		;754d
	ld a,(hl)			;7550
	inc l			;7551
	sub e			;7552   ; la Y del enemigo menos la del jugador, contra el alto del rectangulo
	exx			;7553
	add a,d			;7554
	cp e			;7555
	exx			;7556
	jr nc,CHOQUE_ENEMIGO_NO		;7557
	ld a,(hl)			;7559   ; y lo mismo con la X
	sub d			;755a
	exx			;755b
	add a,b			;755c
	cp c			;755d
	exx			;755e
	jr c,JUGADOR_TOCADO		;755f
CHOQUE_ENEMIGO_NO:
	dec l			;7561
CHOQUE_ENEMIGO_SIGUIENTE:
	ld a,00ch		;7562   ; la ficha siguiente
	add a,l			;7564
	ld l,a			;7565
	djnz CHOQUE_ENEMIGO_FICHA		;7566
	ret			;7568
JUGADOR_TOCADO:		; Estado 0xFF y el sonido de morir
	ld a,(0e1a7h)		;7569   ; en el trono el que se lleva el golpe es el enemigo
	and a			;756c
	jp nz,ENEMIGO_TOCADO_YA		;756d
	xor a			;7570
	ld (0e187h),a		;7571
	dec a			;7574   ; estado 0xFF: muriendose
	ld (0e120h),a		;7575
	ld a,026h		;7578
	jp PIDE_SONIDO		;757a

; ----------------------------------------------------------------------
; LOS OBJETOS. Siete fichas de 8 bytes en 0xE400 (el paso de 8 sale de 0x77E4 y de 0x502D); este bucle recorre ocho. El choque es un cuadrado de 24x24.
; ----------------------------------------------------------------------
MIRA_OBJETO:		; Devuelve carry y el tipo si el jugador esta encima de un objeto
	ld a,e			;757d
	sub 006h		;757e   ; el objeto se compara con el jugador desplazado 6 pixeles
	ld e,a			;7580
	ld b,008h		;7581   ; ocho fichas de objeto
	ld hl,0e400h		;7583
MIRA_OBJETO_BUCLE:
	ld a,(hl)			;7586
	inc l			;7587
	inc l			;7588
	dec a			;7589
	jp m,MIRA_OBJETO_SIGUIENTE		;758a
	ld a,(hl)			;758d
	sub e			;758e
	add a,00ch		;758f   ; cuadrado de 24 pixeles en Y...
	cp 018h		;7591
	jr nc,MIRA_OBJETO_SIGUIENTE		;7593
	inc l			;7595
	ld a,(hl)			;7596
	dec l			;7597
	sub d			;7598   ; ...y en X
	add a,00ch		;7599
	cp 018h		;759b
	jr nc,MIRA_OBJETO_SIGUIENTE		;759d
	dec l			;759f
	dec l			;75a0
	ld (0e304h),hl		;75a1   ; se guarda cual es, para que 0x75AF lo recoja
	ld a,(hl)			;75a4
	scf			;75a5
	ret			;75a6
MIRA_OBJETO_SIGUIENTE:
	ld a,006h		;75a7   ; seis, mas los dos que ya se subieron: fichas de 8 bytes
	add a,l			;75a9
	ld l,a			;75aa
	djnz MIRA_OBJETO_BUCLE		;75ab
	xor a			;75ad
	ret			;75ae
COGE_OBJETO:		; Recoge el objeto: puntos, escudo, bota o lo que sea
	ld hl,(0e304h)		;75af
	ld a,(hl)			;75b2
	ld (hl),0ffh		;75b3   ; la ficha se marca como "recogida" y se le da 0x10 fotogramas de rotulo
	inc l			;75b5
	ld c,a			;75b6
	ld (hl),010h		;75b7
	inc l			;75b9
	inc l			;75ba
	inc l			;75bb
	ex de,hl			;75bc
	cp 006h		;75bd   ; el objeto 6 arranca el final de la fase
	jp z,COGE_META		;75bf
	cp 007h		;75c2   ; el 7 sienta al jugador en el trono
	jr z,COGE_TRONO		;75c4
	cp 008h		;75c6   ; el 8 es la bota
	jr z,COGE_BOTA		;75c8
	cp 009h		;75ca   ; el 9 es el escudo
	jr z,COGE_ESCUDO		;75cc
	cp 00bh		;75ce
	jr nc,COGE_OBJETO_RARO		;75d0
	ld hl,0e198h		;75d2   ; los demas se acumulan por clases: a los cuatro iguales, premio
	add a,a			;75d5
	add a,l			;75d6
	ld l,a			;75d7
	inc (hl)			;75d8   ; cuatro de la misma clase hacen premio
	ld a,(hl)			;75d9
	cp 004h		;75da
	jr z,COGE_CUARTO		;75dc
	inc l			;75de
	inc (hl)			;75df
	ld a,(hl)			;75e0
	cp 004h		;75e1
	jr c,COGE_PUNTOS		;75e3
	ld a,004h		;75e5
	ld (hl),a			;75e7
	jr COGE_PUNTOS		;75e8
COGE_CUARTO:		; Al cuarto objeto de la misma clase, el premio gordo
	ld (hl),000h		;75ea   ; la cuenta de esa clase vuelve a cero y la de al lado se queda en cuatro
	inc l			;75ec
	ld (hl),004h		;75ed
	ld hl,0e1a1h		;75ef   ; y el premio de cada clase solo se da una vez
	ld a,c			;75f2
	add a,l			;75f3
	ld l,a			;75f4
	ld a,(hl)			;75f5
	and a			;75f6
	jr nz,COGE_PREMIO		;75f7
	inc (hl)			;75f9
COGE_PREMIO:
	ld a,004h		;75fa
COGE_PUNTOS:		; Coge la pareja (puntos, sprite) de 0x7652 y la aplica
	ld hl,TABLA_DE_PREMIOS		;75fc   ; parejas (puntos, sprite del rotulo)
	add a,a			;75ff
	call SUMA_A_HL		;7600
	ld b,(hl)			;7603
	inc hl			;7604
	ld c,(hl)			;7605
COGE_PON_ROTULO:		; Deja el numero flotando y suma los puntos
	ex de,hl			;7606
	ld (hl),c			;7607   ; +4 y +5 de la ficha: el sprite del numero, en blanco
	inc l			;7608
	ld (hl),00fh		;7609
	ld l,b			;760b
	ld h,000h		;760c
	add hl,hl			;760e   ; los puntos de la tabla, por 16
	add hl,hl			;760f
	add hl,hl			;7610
	add hl,hl			;7611
	ex de,hl			;7612
	call SUMA_PUNTOS		;7613
	ld a,084h		;7616   ; sonido 0x84
	call PIDE_SONIDO		;7618
	xor a			;761b
	ret			;761c
COGE_OBJETO_RARO:
	ld a,084h		;761d
	ld bc,03068h		;761f
	jr COGE_SUENA		;7622
COGE_TRONO:		; El objeto 7: al trono, con 0x80 fotogramas de premio
	ld a,080h		;7624
	ld (0e1a7h),a		;7626
	ld (0e113h),a		;7629
	ld a,09bh		;762c
COGE_SONIDO:
	ld bc,03068h		;762e
	jr COGE_SUENA		;7631
COGE_BOTA:		; El objeto 8: se anda mas rapido
	ld a,001h		;7633
	ld (0e1a8h),a		;7635
	ld a,09bh		;7638
COGE_SONIDO_2:
	ld bc,0506ch		;763a
COGE_SUENA:
	call PIDE_SONIDO_EN_PARTIDA		;763d
	jr COGE_PON_ROTULO		;7640
COGE_ESCUDO:		; El objeto 9: escudo
	ld a,001h		;7642
	ld (0e1a9h),a		;7644
	ld a,09bh		;7647
	jr COGE_SONIDO_2		;7649
COGE_META:		; El objeto 6: la meta de la fase
	push de			;764b
	call MATA_A_TODOS		;764c
	pop de			;764f
	ld a,01eh		;7650
TABLA_DE_PREMIOS:		; El `jr` final; los ocho bytes que siguen son la tabla de premios
	jr COGE_SONIDO		;7652

; ----------------------------------------------------------------------
; DATOS objetos_puntuables: Cuatro parejas (puntos por 16, patron de sprite)
;   para lo que se recoge: 100, 500, 1000 y 2000 puntos de los que se ven, y
;   el sprite que los ensena es justo ese numero dibujado. La base es 0x7652,
;   que cae dentro del codigo
;   0x7654..0x765c  (8 bytes)
DATA_objetos_puntuables:
	defb 001h,058h	; 7654
	defb 005h,05ch	; 7656
	defb 010h,060h	; 7658
	defb 020h,064h	; 765a

; ======================================================================
; CODIGO 0x765c..0x785c  (512 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LIMPIAR LA PANTALLA DE ENEMIGOS. Los mata a todos, que es lo que pasa al llegar a la meta.
; ----------------------------------------------------------------------
MATA_A_TODOS:		; Manda a explotar los diez enemigos y borra los disparos enemigos
	ld b,00ah		;765c
	ld ix,0e200h		;765e   ; las diez fichas de enemigo
MATA_A_TODOS_FICHA:
	push bc			;7662
	ld a,(ix+000h)		;7663
	dec a			;7666
	jp m,MATA_A_TODOS_SIGUIENTE		;7667   ; tipo 0 o negativo: nada que matar
	ld c,060h		;766a
	call EMPIEZA_A_MORIR		;766c
	ld de,00100h		;766f
	call SUMA_PUNTOS		;7672
MATA_A_TODOS_SIGUIENTE:
	ld de,00010h		;7675
	add ix,de		;7678
	pop bc			;767a
	djnz MATA_A_TODOS_FICHA		;767b
	ld b,018h		;767d   ; y los 24 sprites de 0xE1B0 fuera de la pantalla
	ld hl,0e1b0h		;767f
MATA_A_TODOS_DISPAROS:
	ld (hl),0e0h		;7682
	inc l			;7684
	djnz MATA_A_TODOS_DISPAROS		;7685
	ret			;7687
MIRA_DISPARO_ENEMIGO:		; Si un disparo enemigo toca al jugador, le mata
	ld de,(0e123h)		;7688
	ld hl,0e1b0h		;768c
	ld b,003h		;768f
DISPARO_ENEMIGO_FICHA:
	ld a,(hl)			;7691
	cp 0e0h		;7692   ; 0xE0 en la Y: el disparo no existe
	jr z,DISPARO_ENEMIGO_SIGUIENTE		;7694
	sub e			;7696
	add a,008h		;7697
	cp 010h		;7699
	jr nc,DISPARO_ENEMIGO_SIGUIENTE		;769b   ; rectangulo de 16 x 26 alrededor del jugador
	inc l			;769d
	ld a,(hl)			;769e
	dec l			;769f
	sub d			;76a0
	add a,00dh		;76a1
	cp 01ah		;76a3
	jr c,DISPARO_ENEMIGO_ACIERTA		;76a5
DISPARO_ENEMIGO_SIGUIENTE:
	ld a,008h		;76a7
	add a,l			;76a9
	ld l,a			;76aa
	djnz DISPARO_ENEMIGO_FICHA		;76ab
	ret			;76ad
DISPARO_ENEMIGO_ACIERTA:
	ld (hl),0e0h		;76ae
	jp JUGADOR_TOCADO		;76b0
MIRA_DISPAROS_CONTRA_DISPAROS:		; Los disparos del jugador tumban los disparos enemigos
	ld de,(0e1e3h)		;76b3   ; Y y X del primer disparo del jugador
	ld c,000h		;76b7
	ld a,(0e1e0h)		;76b9   ; +0 a cero quiere decir que ese disparo no esta
	and a			;76bc
	call nz,DISPARO_CONTRA_DISPARO		;76bd
	ld de,(0e1ebh)		;76c0   ; y el segundo, ocho bytes mas alla
	ld c,008h		;76c4
	ld a,(0e1e8h)		;76c6
	and a			;76c9
	ret z			;76ca
DISPARO_CONTRA_DISPARO:
	ld hl,0e1b0h		;76cb
	ld b,003h		;76ce
DISPARO_CONTRA_DISPARO_FICHA:
	ld a,(hl)			;76d0
	cp 0e0h		;76d1   ; 0xE0 en la Y: ese disparo enemigo no esta
	jr z,DISPARO_CONTRA_DISPARO_SIGUIENTE		;76d3
	sub e			;76d5
	add a,010h		;76d6   ; aqui el rectangulo es de 32 x 16
	cp 020h		;76d8
	jr nc,DISPARO_CONTRA_DISPARO_SIGUIENTE		;76da
	inc l			;76dc
	ld a,(hl)			;76dd
	dec l			;76de
	sub d			;76df
	add a,008h		;76e0
	cp 010h		;76e2
	jr c,DISPARO_CONTRA_DISPARO_ACIERTA		;76e4
DISPARO_CONTRA_DISPARO_SIGUIENTE:
	ld a,008h		;76e6   ; los disparos enemigos van de ocho en ocho bytes
	add a,l			;76e8
	ld l,a			;76e9
	djnz DISPARO_CONTRA_DISPARO_FICHA		;76ea
	ret			;76ec
DISPARO_CONTRA_DISPARO_ACIERTA:
	ld (hl),0e0h		;76ed
APAGA_DISPARO:		; Apaga el disparo del jugador numero C
	ld hl,0e1e0h		;76ef   ; C vale 0 o 8: cual de los dos disparos del jugador
	ld b,000h		;76f2
	add hl,bc			;76f4
	ld (hl),000h		;76f5
	inc l			;76f7
	inc l			;76f8
	inc l			;76f9
	ld (hl),0e0h		;76fa   ; y la Y a 0xE0 para que no se vea
	ret			;76fc

; ----------------------------------------------------------------------
; LOS OBJETOS QUE HAY QUE PISAR. En las fases 1 y 3, los del tipo 5 se rompen a pisotones.
; ----------------------------------------------------------------------
PISA_OBJETOS:		; Solo en las fases 1 y 3
	ld a,(0e103h)		;76fd
	dec a			;7700   ; solo en las fases 1 y 3
	jr z,PISA_COMPRUEBA		;7701
	cp 003h		;7703
	ret nz			;7705
PISA_COMPRUEBA:
	call HAY_DISPARO_1		;7706
	call nz,PISA_BUSCA		;7709
	call HAY_DISPARO_2		;770c
	ret z			;770f
PISA_BUSCA:		; Busca un objeto de tipo 5 debajo del disparo
	ld hl,0e400h		;7710
	ld b,00ch		;7713
PISA_FICHA:
	ld a,(hl)			;7715
	inc l			;7716
	inc l			;7717
	cp 005h		;7718   ; los objetos de tipo 5 son los que se rompen
	jr nz,PISA_SIGUIENTE		;771a
	ld a,(hl)			;771c
	sub e			;771d
	add a,010h		;771e   ; cuadrado de 32 pixeles
	cp 020h		;7720
	jr nc,PISA_SIGUIENTE		;7722
	inc l			;7724
	ld a,(hl)			;7725
	sub d			;7726
	dec l			;7727
	add a,010h		;7728
	cp 020h		;772a
	jr c,PISA_ACIERTA		;772c
PISA_SIGUIENTE:
	ld a,006h		;772e
	add a,l			;7730
	ld l,a			;7731
	djnz PISA_FICHA		;7732
	ret			;7734
PISA_ACIERTA:		; Un golpe mas; al cuarto se rompe y da 500 puntos
	push hl			;7735
	call APAGA_DISPARO		;7736
	pop hl			;7739
	dec l			;773a
	inc (hl)			;773b   ; tres golpes y al cuarto se rompe
	ld a,(hl)			;773c
	cp 004h		;773d
	jr c,PISA_CAMBIA_SPRITE		;773f
	dec l			;7741
	ld (hl),0ffh		;7742
	inc l			;7744
	ld (hl),010h		;7745
	inc l			;7747
	inc l			;7748
	inc l			;7749
	ld (hl),05ch		;774a
	inc l			;774c
	ld (hl),00fh		;774d
	ld de,00050h		;774f   ; y da 500 puntos de los que se ven
	jp SUMA_PUNTOS		;7752
PISA_CAMBIA_SPRITE:
	inc l			;7755
	inc l			;7756
	inc l			;7757
	cp 002h		;7758
	ret c			;775a
	ld (hl),0bch		;775b   ; a partir del segundo golpe cambia de dibujo
	ret			;775d

; ----------------------------------------------------------------------
; SOLTAR LOS OBJETOS DE LA FASE. Cada 16 pixeles de scroll se mira la lista de la fase, y si toca, se pone un objeto.
; ----------------------------------------------------------------------
SUELTA_OBJETOS:		; Coloca el objeto que le toque a esta posicion de la fase
	ld hl,(0e100h)		;775e
	ld a,l			;7761   ; solo cada 16 pixeles
	and 00fh		;7762
	ret nz			;7764
	ld (0e1afh),a		;7765
	ld a,(0e103h)		;7768
	add a,a			;776b
	ld hl,07876h		;776c   ; la lista de objetos de la fase
	call LEE_PALABRA		;776f
	ld a,(0e170h)		;7772
	add a,a			;7775
	call SUMA_A_DE		;7776
	ld hl,(0e100h)		;7779   ; la posicion por 16, que es como esta escrita en la lista
	add hl,hl			;777c
	add hl,hl			;777d
	add hl,hl			;777e
	add hl,hl			;777f
	ex de,hl			;7780
	ld a,d			;7781
	ld c,02ah		;7782
	cp 08ah		;7784   ; los tramos 0x8A y 0x06 son la meta y el arranque
	jr z,OBJETO_META_SUBIENDO		;7786
	cp 006h		;7788
	jr z,OBJETO_META_BAJANDO		;778a
	ld a,(0e102h)		;778c
	and a			;778f
	ld a,(hl)			;7790
	jr z,OBJETO_SENTIDO		;7791
	add a,00dh		;7793
OBJETO_SENTIDO:
	ld c,a			;7795
	ld a,d			;7796
	jr z,OBJETO_ESPECIAL		;7797
	sub 00dh		;7799
OBJETO_ESPECIAL:
	cp 024h		;779b   ; en 0x24, 0x48 y 0x60 va un objeto especial
	jr z,OBJETO_ESPECIAL_PON		;779d
	cp 048h		;779f
	jr z,OBJETO_ESPECIAL_PON		;77a1
	cp 060h		;77a3
	jr nz,OBJETO_DE_LA_LISTA		;77a5
OBJETO_ESPECIAL_PON:
	rlca			;77a7   ; los tres bits altos del tramo eligen uno de cuatro
	rlca			;77a8
	rlca			;77a9
	and 003h		;77aa
	ld hl,0e102h		;77ac
	bit 0,(hl)		;77af
	ld b,02ah		;77b1
	jr z,OBJETO_ESPECIAL_TIPO		;77b3
	ld b,02eh		;77b5
	neg		;77b7
OBJETO_ESPECIAL_TIPO:
	add a,b			;77b9
	ld c,a			;77ba
	ld a,001h		;77bb
	ld (0e1afh),a		;77bd   ; 0xE1AF: ya hay objeto puesto en esta X
	jr PON_OBJETO		;77c0
OBJETO_DE_LA_LISTA:
	ld a,c			;77c2
	cp d			;77c3   ; solo cuando el tramo cae justo donde dice la lista
	ret nz			;77c4
	inc hl			;77c5
	ld c,(hl)			;77c6
	jr PON_OBJETO		;77c7
OBJETO_META_SUBIENDO:
	ld a,(0e102h)		;77c9
	and a			;77cc
	ret nz			;77cd
	ld a,(0e132h)		;77ce   ; la meta solo sale en la pantalla 8
	cp 008h		;77d1
	jr nz,PON_OBJETO		;77d3
	ret			;77d5
OBJETO_META_BAJANDO:
	ld a,(0e102h)		;77d6
	and a			;77d9
	ret z			;77da
	ld a,(0e132h)		;77db   ; y bajando, en la 0x11 no hay meta
	cp 011h		;77de
	ret z			;77e0
PON_OBJETO:		; Busca hueco en 0xE400 y deja el objeto con su sprite
	ld hl,0e400h		;77e1   ; siete fichas de 6 bytes
	ld e,008h		;77e4
	ld b,007h		;77e6
	call BUSCA_HUECO		;77e8
	jp c,OBJETO_AVANZA_LISTA		;77eb
	ld a,c			;77ee
	and 00fh		;77ef   ; el nibble bajo del byte de la lista es el tipo
	cp 005h		;77f1
	jr nc,OBJETO_RELLENA		;77f3
	ld de,0e1a2h		;77f5   ; si ya se cogio la bota o el escudo, sale otro objeto en su lugar
	ld a,(de)			;77f8
	and a			;77f9
	jr nz,OBJETO_SUSTITUYE_BOTA		;77fa
	ld e,0a5h		;77fc
	ld a,(de)			;77fe
	and a			;77ff
	jr z,OBJETO_RELLENA		;7800
	ld a,(0e1a9h)		;7802
	and a			;7805
	jr nz,OBJETO_RELLENA		;7806
	ld b,009h		;7808
	jr OBJETO_SUSTITUYE		;780a
OBJETO_SUSTITUYE_BOTA:
	ld a,(0e1a8h)		;780c
	and a			;780f
	jr nz,OBJETO_RELLENA		;7810
	ld b,008h		;7812
OBJETO_SUSTITUYE:
	ld a,c			;7814
	and 0f0h		;7815   ; se dejan los tres bits altos, que son la X, y se cambia el tipo
	add a,b			;7817
	ld c,a			;7818
	xor a			;7819
	ld (de),a			;781a
OBJETO_RELLENA:
	ld a,c			;781b   ; el nibble bajo es el tipo
	and 00fh		;781c
	ld (hl),a			;781e
	inc l			;781f   ; +1 a cero: la cuenta del rotulo
	ld (hl),000h		;7820
	inc l			;7822
	ld a,(0e102h)		;7823   ; la Y: 0xEF subiendo, 0xC8 bajando
	and a			;7826
	ld a,0efh		;7827
	jr z,OBJETO_PON_X		;7829
	ld a,0c8h		;782b
OBJETO_PON_X:
	ld (hl),a			;782d
	inc l			;782e
	ld a,c			;782f
	add a,a			;7830   ; la X sale de los tres bits altos del tipo
	and 0e0h		;7831
	add a,018h		;7833
	ld (hl),a			;7835
	inc l			;7836
	ld a,c			;7837
	and 00fh		;7838
	add a,a			;783a
	ld de,OBJETO_RETROCEDE		;783b   ; patron y color del tipo
	call SUMA_A_DE		;783e
	ex de,hl			;7841
	ld bc,00002h		;7842   ; dos bytes: patron y color
	ldir		;7845
	dec hl			;7847
	ld a,(hl)			;7848
	ld (de),a			;7849
OBJETO_AVANZA_LISTA:
	ld a,(0e1afh)		;784a   ; con 0xE1AF puesto no se avanza en la lista
	and a			;784d
	ret nz			;784e
	ld hl,0e170h		;784f
	ld a,(0e102h)		;7852   ; subiendo se avanza y bajando se retrocede
	and a			;7855
	jr nz,OBJETO_RETROCEDE		;7856
	inc (hl)			;7858
	ret			;7859
OBJETO_RETROCEDE:		; El `dec (hl)`; los 26 bytes que siguen son la tabla de patrones
	dec (hl)			;785a
	ret			;785b

; ----------------------------------------------------------------------
; DATOS patron_y_color_de_objeto: Trece parejas (patron de sprite, color), una
;   por tipo de objeto. La base es 0x785A, dentro del codigo, asi que el
;   indice empieza en 1
;   0x785c..0x7876  (26 bytes)
DATA_patron_y_color_de_objeto:
	defb 0a4h,00bh	; 785c
	defb 0b0h,00ah	; 785e
	defb 0b4h,00dh	; 7860
	defb 0a4h,00fh	; 7862
	defb 04ch,008h	; 7864
	defb 0b8h,00fh	; 7866
	defb 0c4h,007h	; 7868
	defb 0c0h,009h	; 786a
	defb 0c0h,005h	; 786c
	defb 0cch,00fh	; 786e
	defb 0d0h,00fh	; 7870
	defb 0d4h,00fh	; 7872
	defb 0d8h,00fh	; 7874

; ----------------------------------------------------------------------
; DATOS objetos_por_fase: Que lista de objetos usa cada fase, y 0xFFFF de
;   cierre
;   0x7876..0x7888  (18 bytes)
DATA_objetos_por_fase:
	defw 07888h	; 7876  -> DATA_objetos_7888
	defw 078ach	; 7878  -> DATA_objetos_78AC
	defw 078feh	; 787a  -> DATA_objetos_78FE
	defw 07888h	; 787c  -> DATA_objetos_7888
	defw 0795ch	; 787e  -> DATA_objetos_795C
	defw 0799ch	; 7880  -> DATA_objetos_799C
	defw 0799ch	; 7882  -> DATA_objetos_799C
	defw 07928h	; 7884  -> DATA_objetos_7928
	defw 0ffffh	; 7886

; ----------------------------------------------------------------------
; DATOS objetos_7888: Lista de objetos de la fase: 18 pares (posicion, tipo)
;   0x7888..0x78ac  (36 bytes)
DATA_objetos_7888:
	defb 013h,022h	; 7888
	defb 017h,022h	; 788a
	defb 01dh,022h	; 788c
	defb 020h,031h	; 788e
	defb 02ah,013h	; 7890
	defb 02bh,024h	; 7892
	defb 030h,041h	; 7894
	defb 03bh,003h	; 7896
	defb 03dh,004h	; 7898
	defb 042h,021h	; 789a
	defb 049h,043h	; 789c
	defb 053h,007h	; 789e
	defb 058h,041h	; 78a0
	defb 05bh,043h	; 78a2
	defb 065h,011h	; 78a4
	defb 06bh,006h	; 78a6
	defb 072h,024h	; 78a8
	defb 076h,042h	; 78aa

; ----------------------------------------------------------------------
; DATOS objetos_78AC: Lista de objetos de la fase: 41 pares (posicion, tipo)
;   0x78ac..0x78fe  (82 bytes)
DATA_objetos_78AC:
	defb 012h,021h	; 78ac
	defb 016h,042h	; 78ae
	defb 018h,035h	; 78b0
	defb 019h,005h	; 78b2
	defb 01ch,045h	; 78b4
	defb 01dh,025h	; 78b6
	defb 01eh,015h	; 78b8
	defb 01fh,045h	; 78ba
	defb 022h,005h	; 78bc
	defb 023h,014h	; 78be
	defb 025h,005h	; 78c0
	defb 028h,045h	; 78c2
	defb 029h,025h	; 78c4
	defb 02ah,015h	; 78c6
	defb 02bh,045h	; 78c8
	defb 02eh,005h	; 78ca
	defb 02fh,015h	; 78cc
	defb 035h,016h	; 78ce
	defb 03bh,004h	; 78d0
	defb 03dh,003h	; 78d2
	defb 041h,024h	; 78d4
	defb 04ah,025h	; 78d6
	defb 04dh,025h	; 78d8
	defb 04eh,025h	; 78da
	defb 04fh,025h	; 78dc
	defb 050h,025h	; 78de
	defb 053h,025h	; 78e0
	defb 05ah,042h	; 78e2
	defb 05ch,004h	; 78e4
	defb 05eh,027h	; 78e6
	defb 066h,041h	; 78e8
	defb 068h,003h	; 78ea
	defb 06ah,021h	; 78ec
	defb 06ch,035h	; 78ee
	defb 06eh,005h	; 78f0
	defb 070h,041h	; 78f2
	defb 071h,025h	; 78f4
	defb 072h,015h	; 78f6
	defb 073h,045h	; 78f8
	defb 076h,005h	; 78fa
	defb 077h,015h	; 78fc

; ----------------------------------------------------------------------
; DATOS objetos_78FE: Lista de objetos de la fase: 21 pares (posicion, tipo)
;   0x78fe..0x7928  (42 bytes)
DATA_objetos_78FE:
	defb 012h,022h	; 78fe
	defb 016h,041h	; 7900
	defb 01eh,023h	; 7902
	defb 023h,002h	; 7904
	defb 026h,024h	; 7906
	defb 029h,032h	; 7908
	defb 02ch,021h	; 790a
	defb 032h,024h	; 790c
	defb 035h,031h	; 790e
	defb 038h,022h	; 7910
	defb 03fh,023h	; 7912
	defb 040h,024h	; 7914
	defb 044h,027h	; 7916
	defb 049h,032h	; 7918
	defb 04ah,013h	; 791a
	defb 054h,044h	; 791c
	defb 05dh,003h	; 791e
	defb 066h,022h	; 7920
	defb 06ah,041h	; 7922
	defb 071h,006h	; 7924
	defb 077h,002h	; 7926

; ----------------------------------------------------------------------
; DATOS objetos_7928: Lista de objetos de la fase: 26 pares (posicion, tipo)
;   0x7928..0x795c  (52 bytes)
DATA_objetos_7928:
	defb 00dh,023h	; 7928
	defb 013h,001h	; 792a
	defb 017h,044h	; 792c
	defb 019h,022h	; 792e
	defb 01bh,024h	; 7930
	defb 021h,026h	; 7932
	defb 022h,023h	; 7934
	defb 02ah,042h	; 7936
	defb 02ch,001h	; 7938
	defb 02eh,024h	; 793a
	defb 035h,023h	; 793c
	defb 037h,004h	; 793e
	defb 03bh,042h	; 7940
	defb 041h,023h	; 7942
	defb 044h,014h	; 7944
	defb 049h,047h	; 7946
	defb 04dh,023h	; 7948
	defb 04fh,022h	; 794a
	defb 055h,021h	; 794c
	defb 057h,023h	; 794e
	defb 05dh,024h	; 7950
	defb 05fh,021h	; 7952
	defb 061h,023h	; 7954
	defb 063h,023h	; 7956
	defb 069h,021h	; 7958
	defb 06ah,023h	; 795a

; ----------------------------------------------------------------------
; DATOS objetos_795C: Lista de objetos de la fase: 32 pares (posicion, tipo)
;   0x795c..0x799c  (64 bytes)
DATA_objetos_795C:
	defb 013h,011h	; 795c
	defb 014h,022h	; 795e
	defb 021h,033h	; 7960
	defb 023h,004h	; 7962
	defb 02ah,011h	; 7964
	defb 02bh,024h	; 7966
	defb 030h,041h	; 7968
	defb 03bh,003h	; 796a
	defb 03ch,015h	; 796c
	defb 03eh,025h	; 796e
	defb 041h,025h	; 7970
	defb 042h,025h	; 7972
	defb 043h,025h	; 7974
	defb 044h,025h	; 7976
	defb 047h,025h	; 7978
	defb 04ah,025h	; 797a
	defb 04dh,025h	; 797c
	defb 04eh,025h	; 797e
	defb 04fh,025h	; 7980
	defb 050h,025h	; 7982
	defb 053h,025h	; 7984
	defb 054h,006h	; 7986
	defb 056h,025h	; 7988
	defb 059h,025h	; 798a
	defb 05ah,025h	; 798c
	defb 05bh,025h	; 798e
	defb 05ch,025h	; 7990
	defb 05fh,025h	; 7992
	defb 065h,011h	; 7994
	defb 06bh,007h	; 7996
	defb 072h,021h	; 7998
	defb 076h,042h	; 799a

; ----------------------------------------------------------------------
; DATOS objetos_799C: Lista de objetos de la fase: 24 pares (posicion, tipo)
;   0x799c..0x79cc  (48 bytes)
DATA_objetos_799C:
	defb 00eh,024h	; 799c
	defb 011h,032h	; 799e
	defb 014h,021h	; 79a0
	defb 01ah,023h	; 79a2
	defb 01dh,032h	; 79a4
	defb 020h,023h	; 79a6
	defb 026h,022h	; 79a8
	defb 029h,032h	; 79aa
	defb 02ch,023h	; 79ac
	defb 032h,024h	; 79ae
	defb 035h,032h	; 79b0
	defb 038h,024h	; 79b2
	defb 042h,027h	; 79b4
	defb 046h,041h	; 79b6
	defb 04eh,024h	; 79b8
	defb 052h,046h	; 79ba
	defb 056h,023h	; 79bc
	defb 059h,032h	; 79be
	defb 05ch,021h	; 79c0
	defb 066h,022h	; 79c2
	defb 06ah,041h	; 79c4
	defb 072h,024h	; 79c6
	defb 076h,043h	; 79c8
	defb 0ffh,0ffh	; 79ca

; ======================================================================
; CODIGO 0x79cc..0x7a73  (167 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; MOVER LOS OBJETOS. Van con el scroll, y los que llevan rotulo de puntos suben solos.
; ----------------------------------------------------------------------
MUEVE_OBJETOS:		; Arrastra los siete objetos con el scroll y los quita al salirse
	ld b,007h		;79cc
	ld hl,0e400h		;79ce
	ld a,(0e102h)		;79d1
	and a			;79d4
	ld c,001h		;79d5   ; con el scroll subiendo el objeto baja, y al reves
	jr z,MUEVE_OBJETOS_SENTIDO		;79d7
	ld c,0ffh		;79d9
MUEVE_OBJETOS_SENTIDO:
	ld a,(0e113h)		;79db
	and a			;79de
	jr z,MUEVE_UN_OBJETO		;79df
	ld c,000h		;79e1
MUEVE_UN_OBJETO:
	ld a,(hl)			;79e3
	and a			;79e4
	jr z,MUEVE_OBJETO_HUECO		;79e5
	inc l			;79e7
	cp 006h		;79e8   ; los tipos por debajo del 6 parpadean
	push af			;79ea
	call p,OBJETO_PARPADEA		;79eb
	pop af			;79ee
	dec a			;79ef
	jr z,OBJETO_ANIMADO		;79f0   ; el 1 y el 3 llevan dos fotogramas
	cp 003h		;79f2
	jr z,OBJETO_ANIMADO		;79f4
	inc a			;79f6
	call m,OBJETO_CUENTA_ATRAS		;79f7
	inc l			;79fa
MUEVE_OBJETO_Y:
	ld a,(hl)			;79fb
	add a,c			;79fc
	ld (hl),a			;79fd
	and a			;79fe
	sub 0c9h		;79ff   ; fuera de 0xC9..0xED se quita
	cp 025h		;7a01
	call c,QUITA_OBJETO		;7a03
	ld a,006h		;7a06
MUEVE_OBJETO_SIGUIENTE:
	add a,l			;7a08
	ld l,a			;7a09
	djnz MUEVE_UN_OBJETO		;7a0a
	ret			;7a0c
MUEVE_OBJETO_HUECO:
	ld a,008h		;7a0d
	jr MUEVE_OBJETO_SIGUIENTE		;7a0f
OBJETO_PARPADEA:		; Los objetos que aun no se han cogido parpadean
	cp 00ah		;7a11
	ret nc			;7a13
	push hl			;7a14
	ld de,00005h		;7a15
	add hl,de			;7a18
	ld a,(0e003h)		;7a19   ; el bit 2 del contador enciende y apaga
	and 004h		;7a1c
	ld a,(hl)			;7a1e
	jr z,OBJETO_PARPADEA_PON		;7a1f
	xor a			;7a21
OBJETO_PARPADEA_PON:
	dec l			;7a22
	ld (hl),a			;7a23
	pop hl			;7a24
	ret			;7a25
OBJETO_ANIMADO:		; Los objetos con dos fotogramas
	ld a,(hl)			;7a26
	inc l			;7a27
	inc l			;7a28
	inc l			;7a29
	ld a,(0e003h)		;7a2a   ; los dos fotogramas, 0xA4 y 0xA8
	and 00ch		;7a2d
	cp 00ch		;7a2f
	jr nz,OBJETO_ANIMADO_PON		;7a31
	ld a,004h		;7a33
OBJETO_ANIMADO_PON:
	add a,0a4h		;7a35
	ld (hl),a			;7a37
	dec l			;7a38
	dec l			;7a39
	jr MUEVE_OBJETO_Y		;7a3a
OBJETO_CUENTA_ATRAS:
	dec (hl)			;7a3c
	ret nz			;7a3d
QUITA_OBJETO:		; Quita el objeto y, si era de los que se acumulan, deshace la cuenta
	push hl			;7a3e
	ld a,l			;7a3f   ; redondea al principio de la ficha, que son ocho bytes
	and 0f8h		;7a40
	ld l,a			;7a42
	ld a,(hl)			;7a43
	and a			;7a44
	jr z,QUITA_OBJETO_FIN		;7a45
	ld (hl),000h		;7a47   ; la ficha queda libre y el sprite fuera
	inc l			;7a49
	inc l			;7a4a
	ld (hl),0e0h		;7a4b
	ld hl,0e198h		;7a4d
	cp 005h		;7a50   ; los tipos por debajo del 5 deshacen su cuenta al desaparecer
	jr nc,QUITA_OBJETO_FIN		;7a52
	ex af,af'			;7a54
	ld a,(0e112h)		;7a55   ; 0xE112: en el final de fase las cuentas no se deshacen
	and a			;7a58
	jr nz,QUITA_OBJETO_FIN		;7a59
	ex af,af'			;7a5b
	add a,a			;7a5c   ; dos bytes por clase en 0xE198
	add a,l			;7a5d
	ld l,a			;7a5e
	xor a			;7a5f
	ld (hl),a			;7a60
	inc l			;7a61
	ld (hl),a			;7a62
QUITA_OBJETO_FIN:
	pop hl			;7a63
	ret			;7a64

; ----------------------------------------------------------------------
; EL FINAL DE LA FASE. Cuatro pasos (0xE111): la meta, la pantalla siguiente, la espera y la vuelta a jugar.
; ----------------------------------------------------------------------
PASO_DE_FIN_DE_FASE:		; Despacha el paso del final de fase
	ld a,(0e111h)		;7a65
	dec a			;7a68
	push af			;7a69
	ld a,092h		;7a6a   ; al pasar de fase suena el 0x92
	call nz,PIDE_SONIDO_EN_PARTIDA		;7a6c
	pop af			;7a6f
	call DESPACHA		;7a70

; ----------------------------------------------------------------------
; DATOS tabla_de_fin_de_fase: Los cuatro pasos del final de fase (indice
;   0xE111), destino del despachador de 0x7A70
;   0x7a73..0x7a7b  (8 bytes)
DATA_tabla_de_fin_de_fase:
	defw 07a7bh	; 7a73  -> FIN_META
	defw 07a91h	; 7a75  -> FIN_SIGUIENTE_PANTALLA
	defw 07ad8h	; 7a77  -> FIN_COLOCA_JUGADOR
	defw 07b00h	; 7a79  -> BORRA_ESTADOS_DE_FIN

; ======================================================================
; CODIGO 0x7a7b..0x7af6  (123 bytes)
; ======================================================================


FIN_META:		; El jugador ha llegado a la meta; en las pantallas 8 y 0x11 se va al trono o al final
	ld a,(0e132h)		;7a7b
	cp 008h		;7a7e   ; la pantalla 8 es la del trono
	jp z,PASO_DEL_TRONO		;7a80
	cp 011h		;7a83   ; y la 0x11 la del final
	jp z,PASO_DEL_FINAL		;7a85
	ld a,0e0h		;7a88
	ld (0e123h),a		;7a8a
	ld a,080h		;7a8d
	jr FIN_SIGUIENTE_PASO		;7a8f
FIN_SIGUIENTE_PANTALLA:		; Elige la pantalla siguiente del mapa del mundo y la prepara
	call BORRA_AREA_DE_JUEGO		;7a91
	call APAGA_PUNTO_MAPA		;7a94
	ld de,07b62h		;7a97   ; la tabla del recorrido: dos destinos por pantalla
	ld a,(0e132h)		;7a9a   ; dos destinos por pantalla: 0xE131 elige
	add a,a			;7a9d
	ld hl,0e131h		;7a9e
	add a,(hl)			;7aa1
	call SUMA_A_DE		;7aa2
	ld a,(de)			;7aa5
	ld (0e132h),a		;7aa6
	ld de,07b84h		;7aa9   ; y que fase le toca a la pantalla nueva
	call SUMA_A_DE		;7aac
	ld a,(de)			;7aaf
	ld (0e103h),a		;7ab0
	ld a,(0e133h)		;7ab3   ; 0xE133 dice si se sube o se baja
	ld (0e102h),a		;7ab6
	call PREPARA_FASE		;7ab9
	ld a,(0e102h)		;7abc
	and a			;7abf
	ld hl,000c0h		;7ac0   ; la posicion de salida: 0x00C0 subiendo, 0x0840 bajando
	jr z,FIN_PON_POSICION		;7ac3
	ld hl,00840h		;7ac5
FIN_PON_POSICION:
	ld (0e100h),hl		;7ac8
	call ARRANCA_PANTALLA		;7acb
	ld a,040h		;7ace
FIN_SIGUIENTE_PASO:
	ld (0e004h),a		;7ad0
	ld hl,0e111h		;7ad3
	inc (hl)			;7ad6
	ret			;7ad7
FIN_COLOCA_JUGADOR:		; Coloca al jugador con uno de los dos juegos de 0x7AF6
	ld hl,0e004h		;7ad8
	dec (hl)			;7adb
	ret nz			;7adc
	ld a,(0e131h)		;7add   ; el juego de arriba o el de abajo
	and a			;7ae0
	ld hl,07af6h		;7ae1
	jr z,FIN_COPIA_ESTADO		;7ae4
	ld hl,07afbh		;7ae6
FIN_COPIA_ESTADO:
	ld bc,00005h		;7ae9
	ld de,0e120h		;7aec
	ldir		;7aef
	call PON_SENTIDO		;7af1
	jr FIN_SIGUIENTE_PASO		;7af4

; ----------------------------------------------------------------------
; DATOS jugador_en_el_trono: Dos juegos de cinco bytes para 0xE120: estado 3 o
;   4 (mirando a un lado o al otro), espera 0x11, Y 0x60 y X 0x48 o 0x68
;   0x7af6..0x7b00  (10 bytes)
DATA_jugador_en_el_trono:
	defb 003h,000h,011h,060h,048h	; 7af6
	defb 004h,000h,011h,060h,068h	; 7afb

; ======================================================================
; CODIGO 0x7b00..0x7b11  (17 bytes)
; ======================================================================


BORRA_ESTADOS_DE_FIN:		; Pone a cero los cinco marcadores del final de fase
	xor a			;7b00
	ld (0e111h),a		;7b01   ; 0xE111 el paso del final y 0xE113 el fondo parado
	ld (0e113h),a		;7b04
	ld (0e112h),a		;7b07
	ld (0e11fh),a		;7b0a   ; 0xE11F acaba de morir y 0xE114 el mando bloqueado
	ld (0e114h),a		;7b0d
	ret			;7b10

; ----------------------------------------------------------------------
; DATOS objetos_al_volver: Ocho valores para 0xE170 -por que objeto de la
;   lista se empieza- cuando la fase se recorre de vuelta
;   0x7b11..0x7b19  (8 bytes)
DATA_objetos_al_volver:
	defb 010h,027h,013h,010h,01eh,015h,015h,018h	; 7b11  .'......

; ======================================================================
; CODIGO 0x7b19..0x7b62  (73 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; PREPARAR LA FASE NUEVA. Sube la dificultad, borra los encargos y pone por que objeto de la lista se empieza.
; ----------------------------------------------------------------------
PREPARA_FASE:		; Deja la fase lista: dificultad, encargos a cero y objetos
	call BORRA_ACTORES		;7b19
	ld hl,0e105h		;7b1c   ; la dificultad sube con cada fase, hasta 0x20
	ld a,(hl)			;7b1f
	cp 020h		;7b20
	jr nc,PREPARA_FASE_BORRA		;7b22
	inc (hl)			;7b24
PREPARA_FASE_BORRA:
	ld a,(0e012h)		;7b25   ; si sonaba la 0x95, se corta con la 0x26
	cp 095h		;7b28
	ld a,026h		;7b2a
	call z,PIDE_SONIDO_EN_PARTIDA		;7b2c
	xor a			;7b2f
	ld h,a			;7b30
	ld l,a			;7b31
	ld (0e181h),hl		;7b32   ; sin enemigos encargados ni vivos
	ld (0e171h),a		;7b35   ; sin encargos pendientes
	ld (0e18ch),hl		;7b38   ; y 0xE18C/0xE18D, los enemigos duros
	ld hl,0e1d0h		;7b3b
	ld b,006h		;7b3e   ; seis bytes: los dos encargos de tres
PREPARA_FASE_BUCLE:
	ld (hl),a			;7b40
	inc l			;7b41   ; los seis bytes de los dos encargos
	djnz PREPARA_FASE_BUCLE		;7b42
	xor a			;7b44
	ld h,a			;7b45
	ld l,a			;7b46
	ld (0e185h),a		;7b47
	ld (0e181h),hl		;7b4a
PON_PRIMER_OBJETO:		; Bajando se empieza por el objeto que diga la tabla de 0x7B11
	ld hl,0e170h		;7b4d   ; 0xE170 es por que objeto de la lista se empieza
	ld a,(0e102h)		;7b50   ; subiendo se empieza por el primero
	and a			;7b53
	jr z,PON_PRIMER_OBJETO_GUARDA		;7b54
	ld a,(0e103h)		;7b56
	ld de,07b11h		;7b59
	call SUMA_A_DE		;7b5c
	ld a,(de)			;7b5f
PON_PRIMER_OBJETO_GUARDA:
	ld (hl),a			;7b60
	ret			;7b61

; ----------------------------------------------------------------------
; DATOS recorrido_del_mundo: Diecisiete parejas: a que pantalla se pasa desde
;   cada una segun se vaya por arriba o por abajo (0xE131). Es el mapa del
;   mundo de Pippols
;   0x7b62..0x7b84  (34 bytes)
DATA_recorrido_del_mundo:
	defb 001h,002h	; 7b62
	defb 004h,002h	; 7b64
	defb 005h,003h	; 7b66
	defb 001h,004h	; 7b68
	defb 005h,006h	; 7b6a
	defb 006h,003h	; 7b6c
	defb 007h,008h	; 7b6e
	defb 005h,003h	; 7b70
	defb 000h,000h	; 7b72
	defb 00bh,00ah	; 7b74
	defb 00bh,00dh	; 7b76
	defb 00ch,00eh	; 7b78
	defb 00ah,00dh	; 7b7a
	defb 00eh,00fh	; 7b7c
	defb 00fh,00ch	; 7b7e
	defb 011h,010h	; 7b80
	defb 00eh,00ch	; 7b82

; ----------------------------------------------------------------------
; DATOS fase_por_pantalla: Que fase (0..7) le toca a cada una de las 18
;   pantallas del mundo
;   0x7b84..0x7b96  (18 bytes)
DATA_fase_por_pantalla:
	defb 000h,002h,001h,003h,004h,005h,003h,001h,007h,007h,003h,005h,001h,002h,006h,004h,005h,000h	; 7b84  ..................

; ======================================================================
; CODIGO 0x7b96..0x7b9c  (6 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LA PANTALLA DEL TRONO (la 8). Seis pasos: el jugador llega, se sienta, sale el rotulo y se pasa a la mitad de abajo del mundo.
; ----------------------------------------------------------------------
PASO_DEL_TRONO:		; Despacha el paso de la pantalla del trono
	ld a,(0e1aah)		;7b96
	call DESPACHA		;7b99

; ----------------------------------------------------------------------
; DATOS tabla_del_trono: Los seis pasos de la pantalla del trono (indice
;   0xE1AA), destino del despachador de 0x7B99
;   0x7b9c..0x7ba8  (12 bytes)
DATA_tabla_del_trono:
	defw 07ba8h	; 7b9c  -> TRONO_ESPERA
	defw 07bb4h	; 7b9e  -> TRONO_APARECE
	defw 07bdbh	; 7ba0  -> TRONO_SE_ACERCA
	defw 07bf3h	; 7ba2  -> TRONO_SENTADO
	defw 07bffh	; 7ba4  -> TRONO_ROTULO
	defw 07c10h	; 7ba6  -> TRONO_FIN

; ======================================================================
; CODIGO 0x7ba8..0x7c5c  (180 bytes)
; ======================================================================


TRONO_ESPERA:		; Espera a que no queden enemigos
	ld a,005h		;7ba8
	ld (0e120h),a		;7baa
	ld a,(0e200h)		;7bad   ; mientras quede algun enemigo, se espera
	and a			;7bb0
	ret nz			;7bb1
	jr TRONO_SIGUIENTE_PASO		;7bb2
TRONO_APARECE:		; El del trono aparece con su sonido
	ld a,(0e012h)		;7bb4   ; no aparece mientras suene la 0x92
	cp 092h		;7bb7
	ret z			;7bb9
	ld a,095h		;7bba
	call PIDE_SONIDO_EN_PARTIDA		;7bbc
	ld a,080h		;7bbf
	ld hl,058f0h		;7bc1   ; el sprite del jefe del trono, en 0xE390
	ld (0e390h),hl		;7bc4
	ld hl,007c8h		;7bc7   ; patron de sprite 0xC8 y color 7
	ld (0e392h),hl		;7bca
	ld hl,00cffh		;7bcd   ; 0xE181/0xE182: 0xFF por soltar, del tipo 12
	ld (0e181h),hl		;7bd0
TRONO_PON_ESPERA:
	ld (0e004h),a		;7bd3
TRONO_SIGUIENTE_PASO:
	ld hl,0e1aah		;7bd6
	inc (hl)			;7bd9
	ret			;7bda
TRONO_SE_ACERCA:		; El jugador se va acercando al trono
	call PASO_DEL_JEFE		;7bdb
	ld a,(0e003h)		;7bde
	and 003h		;7be1
	ret nz			;7be3
	ld hl,0e390h		;7be4
	inc (hl)			;7be7   ; el trono baja un pixel cada cuatro fotogramas
	ld a,(0e123h)		;7be8
	add a,002h		;7beb   ; hasta quedarse dos pixeles por encima del jugador
	cp (hl)			;7bed
	ret nz			;7bee
	ld a,080h		;7bef
	jr TRONO_PON_ESPERA		;7bf1
TRONO_SENTADO:
	call PASO_DEL_JEFE		;7bf3
	ld hl,0e004h		;7bf6
	dec (hl)			;7bf9   ; la cuenta de estar sentado
	ret nz			;7bfa
	ld a,040h		;7bfb   ; y 0x40 fotogramas mas para el rotulo
	jr TRONO_PON_ESPERA		;7bfd
TRONO_ROTULO:		; Sale el texto del final
	call PASO_DEL_JEFE		;7bff
	ld hl,0e004h		;7c02
	dec (hl)			;7c05
	ret nz			;7c06
	ld de,07c5ch		;7c07   ; el rotulo de 0x7C5C
	call ESCRIBE_ROTULO		;7c0a
	xor a			;7c0d
	jr TRONO_PON_ESPERA		;7c0e
TRONO_FIN:
	call PASO_DEL_JEFE		;7c10
	ld hl,0e004h		;7c13
	dec (hl)			;7c16
	ret nz			;7c17
CAMBIA_DE_MITAD:		; Da la vuelta al mapa del mundo: 0xE133 cambia y se empieza por la otra punta
	xor a			;7c18
	ld (0e120h),a		;7c19
	ld (0e114h),a		;7c1c
	ld (0e11fh),a		;7c1f
	inc a			;7c22
	ld (0e11eh),a		;7c23
	ld a,0e0h		;7c26
	ld (0e390h),a		;7c28
	ld hl,0e115h		;7c2b
	ld (hl),001h		;7c2e
	ld hl,0e133h		;7c30   ; 0xE133 va cambiando de 0 a 1 y de 1 a 0
	ld a,001h		;7c33
	xor (hl)			;7c35   ; 0xE133 cambia de 0 a 1 y de 1 a 0
	ld (hl),a			;7c36
	ld (0e102h),a		;7c37
	and a			;7c3a
	ld a,000h		;7c3b
	jr z,CAMBIA_PON_PANTALLA		;7c3d
	ld a,009h		;7c3f
CAMBIA_PON_PANTALLA:
	ld (0e132h),a		;7c41   ; la pantalla 0 o la 9, segun la mitad
	jr nz,CAMBIA_PREPARA		;7c44
	ld (0e103h),a		;7c46
CAMBIA_PREPARA:
	call PREPARA_FASE		;7c49
	ld a,004h		;7c4c
	ld (0e111h),a		;7c4e   ; 0xE111 = 4: el paso que vuelve a dejar jugar
	ld a,001h		;7c51
	ld (0e004h),a		;7c53
	call PON_SENTIDO		;7c56   ; y el sentido del disparo, segun se suba o se baje
	jp GENERA_FONDO		;7c59

; ----------------------------------------------------------------------
; DATOS texto_final: Para 0x4393: "BRING BACK", "THE HOLLY GEM", "THE WORLD
;   IS", "WAITING FOR YOU"
;   0x7c5c..0x7c9a  (62 bytes)
DATA_texto_final:
	defb 0e5h,038h,022h,032h,029h,02eh,027h,000h,022h,021h,023h,02bh,0feh,025h,039h,034h	; 7c5c  .8"2).'."!#+.%94
	defb 028h,025h,000h,028h,02fh,02ch,02ch,039h,000h,027h,025h,02dh,0feh,085h,039h,034h	; 7c6c  (%.(/,,9.'%-..94
	defb 028h,025h,000h,037h,02fh,032h,02ch,024h,000h,029h,033h,0feh,0c5h,039h,037h,021h	; 7c7c  (%.7/2,$.)3..97!
	defb 029h,034h,029h,02eh,027h,000h,026h,02fh,032h,000h,039h,02fh,035h,0ffh	; 7c8c  )4).'.&/2.9/5.

; ======================================================================
; CODIGO 0x7c9a..0x7cdd  (67 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; ENEMIGO 12: el que sale en la pantalla del trono.
; ----------------------------------------------------------------------
ENEMIGO_DEL_TRONO:
	call AVANZA		;7c9a
	ld a,(0e003h)		;7c9d   ; el bit 1 del contador anima
	and 002h		;7ca0
	ld a,006h		;7ca2
	jr z,TRONO_ENEMIGO_FOTOGRAMA		;7ca4
	ld a,00fh		;7ca6
TRONO_ENEMIGO_FOTOGRAMA:
	ld (ix+007h),a		;7ca8
	ld a,0c0h		;7cab   ; por debajo de la fila 0xC0 se le quita
	cp (ix+004h)		;7cad
	jr c,TRONO_ENEMIGO_MUERE		;7cb0
	cp (ix+005h)		;7cb2
	ret nc			;7cb5
TRONO_ENEMIGO_MUERE:
	ld (ix+000h),000h		;7cb6
	ld (ix+004h),0e0h		;7cba
	ret			;7cbe
PASO_DEL_JEFE:		; Suelta enemigos y hace parpadear el color del sprite del jefe
	call SUELTA_ENEMIGO_YA		;7cbf
	ld hl,0e181h		;7cc2   ; al llegar a cero se recarga a 0xFF: en el trono no se acaban nunca
	ld a,(hl)			;7cc5
	and a			;7cc6
	jr nz,JEFE_COLOR		;7cc7
	dec (hl)			;7cc9
JEFE_COLOR:
	ld hl,0e393h		;7cca
	ld de,07cddh		;7ccd
	ld a,(0e003h)		;7cd0   ; los bits 2 y 3 del contador eligen el color
	rra			;7cd3
	rra			;7cd4
	and 003h		;7cd5
	call SUMA_A_DE		;7cd7
	ld a,(de)			;7cda
	ld (hl),a			;7cdb
	ret			;7cdc

; ----------------------------------------------------------------------
; DATOS colores_del_parpadeo: Los cuatro colores que se van turnando en el
;   sprite del final: 5, 4, 7 y 15
;   0x7cdd..0x7ce1  (4 bytes)
DATA_colores_del_parpadeo:
	defb 005h,004h,007h,00fh	; 7cdd

; ======================================================================
; CODIGO 0x7ce1..0x7cee  (13 bytes)
; ======================================================================


PASO_DEL_FINAL:		; Despacha el paso de la pantalla final (la 0x11)
	ld a,(0e1aah)		;7ce1   ; 0xE1AA es el paso de la pantalla final
	cp 002h		;7ce4
	push af			;7ce6
	call nc,PASO_DEL_JEFE		;7ce7   ; del paso 2 en adelante ya hay jefe que atender
	pop af			;7cea
	call DESPACHA		;7ceb

; ----------------------------------------------------------------------
; DATOS tabla_del_final: Los seis pasos de la pantalla final (indice 0xE1AA),
;   destino del despachador de 0x7CEB
;   0x7cee..0x7cfa  (12 bytes)
DATA_tabla_del_final:
	defw 07cfah	; 7cee  -> FINAL_PREPARA
	defw 07d65h	; 7cf0  -> FINAL_SUBE
	defw 07da2h	; 7cf2  -> FINAL_BAJA_EL_JEFE
	defw 07db5h	; 7cf4  -> FINAL_ESPERA
	defw 07dc5h	; 7cf6  -> FINAL_DIBUJA_CAMINO
	defw 07e0ah	; 7cf8  -> FINAL_TERMINA

; ======================================================================
; CODIGO 0x7cfa..0x7d2a  (48 bytes)
; ======================================================================


FINAL_PREPARA:		; Carga los caracteres del adorno del final
	ld a,005h		;7cfa
	ld (0e120h),a		;7cfc
	ld hl,00100h		;7cff
	ld (0e120h),hl		;7d02
	ld a,h			;7d05   ; el jugador queda parado en el sitio
	ld (0e122h),a		;7d06
	ld hl,02200h		;7d09
	ld b,004h		;7d0c
FINAL_CARGA:
	push bc			;7d0e
	push hl			;7d0f
	ld de,07d2ah		;7d10   ; los caracteres del adorno del final
	call RLE_TRES_TERCIOS		;7d13
	pop hl			;7d16
	pop bc			;7d17
	ld de,00020h		;7d18   ; una fila mas abajo son 32 bytes
	add hl,de			;7d1b
	djnz FINAL_CARGA		;7d1c
	ld hl,00200h		;7d1e   ; y su tabla de color, desde el caracter 0x40
	ld de,07d4ch		;7d21
	call RLE_TRES_TERCIOS		;7d24
	jp TRONO_SIGUIENTE_PASO		;7d27

; ----------------------------------------------------------------------
; DATOS patrones_del_final: 32 bytes a la VRAM 0x2200 y siguientes: los cuatro
;   caracteres del adorno de la pantalla final
;   0x7d2a..0x7d4c  (34 bytes)
DATA_patrones_del_final:
	defb 0a0h,001h,01bh,00dh,00eh,00fh,00fh,007h,003h,08ch,0d8h,0d8h,0b8h,078h,0b8h,0b0h	; 7d2a  .............x..
	defb 060h,060h,038h,03ch,01eh,00eh,007h,001h,000h,081h,086h,08eh,09ch,0bch,0f8h,0e0h	; 7d3a  ``8<............
	defb 080h,000h	; 7d4a

; ----------------------------------------------------------------------
; DATOS colores_del_final: 128 bytes a la VRAM 0x0200
;   0x7d4c..0x7d65  (25 bytes)
DATA_colores_del_final:
	defb 010h,0f0h,008h,020h,008h,0c0h,010h,0b0h,008h,020h,008h,0c0h,010h,090h,008h,020h	; 7d4c  ... ..... ..... 
	defb 008h,0c0h,010h,0d0h,008h,020h,008h,0c0h,000h	; 7d5c  ..... ...

; ======================================================================
; CODIGO 0x7d65..0x7e15  (176 bytes)
; ======================================================================


FINAL_SUBE:		; El jugador sube solo hasta la fila 0x88
	ld a,(0e003h)		;7d65
	rra			;7d68   ; un pixel si y otro no
	ret c			;7d69
	ld hl,0e123h		;7d6a
	ld a,(hl)			;7d6d
	inc a			;7d6e
	cp 088h		;7d6f   ; sube hasta la fila 0x88
	jr z,FINAL_LLEGA		;7d71
	ld (hl),a			;7d73
	ld a,092h		;7d74   ; y cada paso suena el 0x92
	jp PIDE_SONIDO_EN_PARTIDA		;7d76
FINAL_LLEGA:
	ld a,(0e012h)		;7d79   ; espera a que se calle la 0x92
	cp 092h		;7d7c
	ret z			;7d7e
	ld a,0a1h		;7d7f
	call PIDE_SONIDO_EN_PARTIDA		;7d81
	ld hl,(0e123h)		;7d84
	ld a,l			;7d87
	add a,004h		;7d88   ; el jefe sale cuatro pixeles por debajo del jugador
	ld l,a			;7d8a
	ld (0e390h),hl		;7d8b
	ld hl,007c8h		;7d8e   ; patron de sprite 0xC8 y color 7
	ld (0e392h),hl		;7d91
	ld a,005h		;7d94   ; estado 5: el jugador se queda quieto
	ld (0e120h),a		;7d96
	ld hl,00cffh		;7d99
	ld (0e181h),hl		;7d9c
	jp TRONO_SIGUIENTE_PASO		;7d9f
FINAL_BAJA_EL_JEFE:
	ld a,(0e003h)		;7da2
	rra			;7da5   ; un pixel un fotograma si y otro no
	ret c			;7da6
	ld hl,0e390h		;7da7
	ld a,(hl)			;7daa
	dec a			;7dab   ; el jefe baja hasta la fila 0x10
	ld (hl),a			;7dac
	cp 010h		;7dad
	ret nz			;7daf
	ld a,080h		;7db0   ; y luego 0x80 fotogramas de espera
	jp TRONO_PON_ESPERA		;7db2
FINAL_ESPERA:
	ld hl,0e004h		;7db5
	dec (hl)			;7db8
	ret nz			;7db9
	ld a,080h		;7dba
	ld hl,00cffh		;7dbc   ; 0xE181/0xE182: otra vez 0xFF del tipo 12
	ld (0e181h),hl		;7dbf
	jp TRONO_PON_ESPERA		;7dc2
FINAL_DIBUJA_CAMINO:		; Va marcando las 24 casillas del camino de 0x7E15, cuatro caracteres cada una
	ld a,(0e003h)		;7dc5
	and 00fh		;7dc8   ; una casilla cada 16 fotogramas
	ret nz			;7dca
	ld hl,0e1abh		;7dcb
	inc (hl)			;7dce   ; una casilla mas del camino
	ld a,(hl)			;7dcf
	cp 019h		;7dd0   ; a las 24 casillas se acaba
	jp z,TRONO_SIGUIENTE_PASO		;7dd2
	push af			;7dd5
	ld hl,07e14h		;7dd6
	call SUMA_A_HL		;7dd9
	ld a,(hl)			;7ddc
	ld c,a			;7ddd
	and 00fh		;7dde
	add a,a			;7de0
	add a,a			;7de1
	add a,a			;7de2
	add a,a			;7de3
	add a,008h		;7de4
	ld h,a			;7de6
	ld a,c			;7de7
	and 0f0h		;7de8   ; el nibble alto es la fila y el bajo la columna
	ld l,a			;7dea
	call DIRECCION_DE_NOMBRE		;7deb
	pop af			;7dee
	and 003h		;7def
	add a,a			;7df1
	add a,a			;7df2
	add a,040h		;7df3   ; cuatro caracteres por casilla, del 0x40 al 0x4F
	call 0004dh		;7df5   ; BIOS WRTVRM - Writes data in VRAM
	inc a			;7df8
	inc hl			;7df9
	call 0004dh		;7dfa   ; BIOS WRTVRM - Writes data in VRAM
	inc a			;7dfd
	ld de,0001fh		;7dfe
	add hl,de			;7e01
	call 0004dh		;7e02   ; BIOS WRTVRM - Writes data in VRAM
	inc a			;7e05
	inc hl			;7e06
	jp 0004dh		;7e07   ; BIOS WRTVRM - Writes data in VRAM
FINAL_TERMINA:		; Borra el area de juego y da la vuelta al mundo
	ld a,(0e012h)		;7e0a
	and a			;7e0d
	ret nz			;7e0e
	call BORRA_AREA_DE_JUEGO		;7e0f
	jp CAMBIA_DE_MITAD		;7e12

; ----------------------------------------------------------------------
; DATOS casillas_del_recorrido: Veinticuatro casillas (nibble alto la fila,
;   nibble bajo la columna) que 0x7DC5 va marcando de cuatro en cuatro
;   caracteres: el caminito que se dibuja en la pantalla final
;   0x7e15..0x7e2d  (24 bytes)
DATA_casillas_del_recorrido:
	defb 035h,024h,026h,013h,017h,018h,012h,029h,03ah,021h,04ah,030h	; 7e15  5$&....):!J0
	defb 040h,059h,051h,069h,061h,078h,072h,087h,083h,096h,094h,0a5h	; 7e21  @YQiaxr.....

; ======================================================================
; CODIGO 0x7e2d..0x7fca  (413 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LA META. Segun la fase y la posicion, el jugador llega al final del recorrido y se pasa a la pantalla siguiente.
; ----------------------------------------------------------------------
MIRA_LA_META:		; Mira si el jugador ha llegado al final de la fase
	xor a			;7e2d
	ld (0e1f1h),a		;7e2e
	ld a,(0e11eh)		;7e31   ; 0xE11E puesto: no hay meta que valga
	and a			;7e34
	ret nz			;7e35
	ld bc,0e112h		;7e36
	ld hl,(0e100h)		;7e39
	ld a,(0e132h)		;7e3c
	cp 008h		;7e3f   ; las pantallas 8 y 0x11 tienen su propia meta
	jr z,META_DEL_TRONO		;7e41
	cp 011h		;7e43
	jr z,META_DE_LA_FINAL		;7e45
	ld a,h			;7e47
	cp 005h		;7e48   ; antes de la posicion 0x0500 no hay meta
	jr c,META_PRINCIPIO		;7e4a
	cp 009h		;7e4c
	jp z,META_DA_LA_VUELTA		;7e4e
	ld de,00838h		;7e51   ; la meta esta en la posicion 0x0838
	sbc hl,de		;7e54
	jr nc,META_COMPARA		;7e56
META_NO:
	xor a			;7e58
	ld (bc),a			;7e59
	ret			;7e5a
META_COMPARA:
	ld a,(0e123h)		;7e5b
	cp l			;7e5e
	ret nc			;7e5f
	jr META_LLEGA		;7e60
META_PRINCIPIO:
	or l			;7e62   ; HL es la posicion en la fase: cero es el tope
	jr z,META_DA_LA_VUELTA		;7e63
	ld a,h			;7e65
	and a			;7e66
	jr nz,META_NO		;7e67
	ld a,(0e123h)		;7e69   ; y el jugador tiene que haber llegado hasta ahi
	cp l			;7e6c
	ret c			;7e6d
META_LLEGA:
	ld a,001h		;7e6e
	ld (0e1f1h),a		;7e70   ; 0xE1F1: el jugador esta en la meta
	ld a,(bc)			;7e73
	and a			;7e74
	call z,META_PARA_TODO		;7e75
	jp META_MITAD		;7e78
META_DEL_TRONO:		; La meta de la pantalla 8
	ld a,h			;7e7b
	ld de,00860h		;7e7c   ; la meta del trono, en la 0x0860
	sbc hl,de		;7e7f
	ret c			;7e81
	cp 009h		;7e82   ; pasado el pixel 0x0900 se va al final
	jr z,META_AL_FINAL		;7e84
	ld a,(0e123h)		;7e86
	cp l			;7e89
	ret nc			;7e8a
	ld a,(0e120h)		;7e8b   ; si se esta muriendo, no
	and a			;7e8e
	ret m			;7e8f
	ld a,(bc)			;7e90
	and a			;7e91
	call z,META_PARA_AL_JUGADOR		;7e92
	jp EMPUJA_JUGADOR_ABAJO		;7e95
META_PARA_AL_JUGADOR:
	call META_PARA_TODO		;7e98
	xor a			;7e9b
	ld hl,0e120h		;7e9c   ; estado 0 y subestado 1: quieto
	ld (hl),a			;7e9f
	inc l			;7ea0
	inc a			;7ea1
	ld (hl),a			;7ea2
	ld (0e114h),a		;7ea3   ; 0xE114: el mando deja de responder
	ret			;7ea6
META_AL_FINAL:
	ld a,001h		;7ea7
	ld (0e113h),a		;7ea9   ; 0xE113: el fondo se para
	ld a,(0e120h)		;7eac
	and a			;7eaf
	ret m			;7eb0
	jr META_ARRANCA_FIN		;7eb1
META_DE_LA_FINAL:		; La meta de la pantalla 0x11
	ld a,h			;7eb3   ; solo en los 256 primeros pixeles de la fase
	or a			;7eb4
	ret nz			;7eb5
	or l			;7eb6
	jr z,META_AL_FINAL		;7eb7
	ld a,(0e123h)		;7eb9
	add a,020h		;7ebc   ; y con el jugador 0x20 por debajo
	cp l			;7ebe
	ret c			;7ebf
	ld a,(0e120h)		;7ec0
	and a			;7ec3
	ret m			;7ec4
	ld a,(bc)			;7ec5
	and a			;7ec6
	call z,META_PARA_AL_JUGADOR		;7ec7
	jp EMPUJA_JUGADOR_ARRIBA		;7eca
META_DA_LA_VUELTA:		; Al llegar al tope se da la vuelta y se vuelve por donde se vino
	ld a,(bc)			;7ecd
	and a			;7ece
	call z,META_PARA_TODO		;7ecf
	ld a,001h		;7ed2
	ld (0e113h),a		;7ed4   ; el fondo se para y el jugador cuenta como en la meta
	ld (0e1f1h),a		;7ed7
	ld a,(0e003h)		;7eda   ; la cuenta baja un fotograma si y otro no
	rra			;7edd
	jp c,META_MITAD		;7ede
	ld hl,0e004h		;7ee1
	dec (hl)			;7ee4
	jp nz,META_MITAD		;7ee5
	ld hl,0e102h		;7ee8
	ld a,001h		;7eeb   ; 0xE102 cambia de sentido: ahora se baja
	xor (hl)			;7eed
	ld (hl),a			;7eee
	ld hl,0e105h		;7eef
	ld a,(hl)			;7ef2   ; y sube la dificultad, hasta 0x20
	cp 020h		;7ef3
	jr nc,META_VUELTA_LISTA		;7ef5
	inc (hl)			;7ef7
META_VUELTA_LISTA:
	xor a			;7ef8
	ld (0e113h),a		;7ef9
	inc a			;7efc
	ld (0e11fh),a		;7efd   ; 0xE11F: la vuelta se cuenta como una muerte, que es lo que mira la musica
	call PON_PRIMER_OBJETO		;7f00
META_MITAD:		; Segun la X del jugador (0xE124) se apunta a una mitad o a la otra del mapa del mundo
	ld a,(0e124h)		;7f03
	ld c,000h		;7f06
	cp 0a9h		;7f08   ; pasada la columna 0xA9, o antes de la 0x17, se cambia de mitad
	jr nc,META_PON_MITAD		;7f0a
	cp 017h		;7f0c
	ret nc			;7f0e
	inc c			;7f0f
META_PON_MITAD:
	ld a,c			;7f10
	ld (0e131h),a		;7f11
META_ARRANCA_FIN:
	ld a,(0e112h)		;7f14   ; 0xE112: solo la primera vez se para todo
	and a			;7f17
	call z,META_PARA_TODO		;7f18
	xor a			;7f1b
	ld (0e1aah),a		;7f1c   ; 0xE1AA y 0xE1AB a cero: los pasos del trono y del camino
	ld (0e1abh),a		;7f1f
	inc a			;7f22
	ld (0e114h),a		;7f23
	ld (0e111h),a		;7f26   ; 0xE111 = 1: arranca el final de fase
	ret			;7f29
META_PARA_TODO:		; Para el juego: mata a todos, quita los disparos y suena el 0x92
	ld a,0c0h		;7f2a   ; 0xC0 fotogramas de espera
	ld (0e004h),a		;7f2c
	ld a,(0e120h)		;7f2f
	and a			;7f32
	ret m			;7f33
	ld hl,0e112h		;7f34
	inc (hl)			;7f37
	call MATA_A_TODOS		;7f38
	ld a,0e0h		;7f3b
	ld (0e1e3h),a		;7f3d
	ld (0e1ebh),a		;7f40
	ld a,0ffh		;7f43
	ld (0e11fh),a		;7f45
	ld a,092h		;7f48   ; sonido 0x92
	jp PIDE_SONIDO_EN_PARTIDA		;7f4a
EMPUJA_JUGADOR_ARRIBA:		; Un pixel arriba cada cuatro fotogramas, sin pasar de la fila 0x18
	ld a,(0e003h)		;7f4d
	and 003h		;7f50   ; un pixel cada cuatro fotogramas
	ret nz			;7f52
	ld hl,0e123h		;7f53
	ld a,(hl)			;7f56
	dec a			;7f57
	cp 018h		;7f58   ; sin pasar de la fila 0x18
	ret c			;7f5a
	ld (hl),a			;7f5b
	ret			;7f5c
EMPUJA_JUGADOR_ABAJO:		; Un pixel abajo cada cuatro fotogramas, sin pasar de la 0xA8
	ld a,(0e003h)		;7f5d
	and 003h		;7f60   ; un pixel cada cuatro fotogramas
	ret nz			;7f62
	ld hl,0e123h		;7f63
	ld a,(hl)			;7f66
	inc a			;7f67
	cp 0a8h		;7f68   ; sin pasar de la fila 0xA8
	ret nc			;7f6a
	ld (hl),a			;7f6b
	ret			;7f6c

; ----------------------------------------------------------------------
; LA TABLA DE SPRITES. 32 sprites: el jefe, los cuatro del jugador, los diez enemigos, los siete objetos, los dos disparos y los tres disparos enemigos. El orden de enemigos y objetos se cambia un fotograma si y otro no, para que el limite de cuatro sprites por linea no tape siempre a los mismos.
; ----------------------------------------------------------------------
VUELCA_SPRITES:		; Vuelca la tabla de atributos de sprite a la VRAM 0x3B00
	ld hl,03b00h		;7f6d   ; los cuatro bytes del sprite del jefe
	ld bc,00004h		;7f70   ; los cuatro bytes del sprite del jefe
	ld de,0e390h		;7f73
	call COPIA_A_VRAM		;7f76
	ld hl,03b14h		;7f79   ; y desde 0x3B14 el resto, uno detras de otro
	call PREPARA_ESCRITURA		;7f7c
	exx			;7f7f
	ld a,(0e003h)		;7f80   ; el bit 0 del contador cambia el orden
	rra			;7f83   ; un fotograma si y otro no se cambia el orden
	jr c,VUELCA_OTRO_ORDEN		;7f84
	call VUELCA_ENEMIGOS		;7f86
	call VUELCA_OBJETOS		;7f89
	jr VUELCA_DISPAROS		;7f8c
VUELCA_OTRO_ORDEN:
	call VUELCA_OBJETOS		;7f8e
	call VUELCA_ENEMIGOS		;7f91
VUELCA_DISPAROS:
	ld hl,0e1e3h		;7f94
	ld b,002h		;7f97
	ld e,004h		;7f99   ; los dos disparos del jugador
	call VUELCA_LISTA		;7f9b
	ld a,(0e003h)		;7f9e   ; los disparos enemigos solo tres de cada cuatro fotogramas
	and 003h		;7fa1   ; y los tres disparos enemigos, tres fotogramas de cada cuatro
	ret z			;7fa3
	ld hl,0e1b0h		;7fa4
	ld e,004h		;7fa7
	ld b,003h		;7fa9
	jr VUELCA_LISTA		;7fab
VUELCA_ENEMIGOS:		; Los diez enemigos, cuatro bytes de cada ficha de 16
	ld b,00ah		;7fad
	ld hl,0e204h		;7faf
	ld e,00ch		;7fb2   ; diez fichas de 16 bytes, cuatro utiles
	jr VUELCA_LISTA		;7fb4
VUELCA_OBJETOS:		; Los siete objetos, cuatro bytes de cada ficha de 6
	ld hl,0e402h		;7fb6
	ld b,007h		;7fb9   ; siete fichas de 6 bytes, cuatro utiles
	ld e,004h		;7fbb
VUELCA_LISTA:		; B fichas de cuatro bytes, separadas E+4 bytes
	ld d,004h		;7fbd
VUELCA_FICHA:
	ld a,(hl)			;7fbf   ; los cuatro bytes utiles de la ficha, por el puerto de datos
	out (c),a		;7fc0
	inc l			;7fc2
	dec d			;7fc3
	jr nz,VUELCA_FICHA		;7fc4
	add hl,de			;7fc6   ; y E mas para plantarse en la siguiente
	djnz VUELCA_LISTA		;7fc7
	ret			;7fc9

; ----------------------------------------------------------------------
; DATOS relleno: Los 45 bytes de 0xFF con los que se rellena el cartucho hasta
;   el final
;   0x7fca..0x7ff7  (45 bytes)
DATA_relleno:
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; 7fca  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; 7fda  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; 7fea  .............

; ----------------------------------------------------------------------
; DATOS cola_del_cartucho: Nueve bytes (8C A8 B8 9D B8 9A 06 29 AA) detras del
;   relleno. No hay ninguna instruccion que los lea ni ningun puntero que
;   caiga ahi: PREGUNTA ABIERTA
;   0x7ff7..0x8000  (9 bytes)
DATA_cola_del_cartucho:
	defb 08ch,0a8h,0b8h,09dh,0b8h,09ah,006h,029h,0aah	; 7ff7  .......).
