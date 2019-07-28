;Cristal de 4MHz (Fosc)
;CM = 4 / 4 MHz = 1 useg

; Sinal sonoro de 2KHz -> T = 1/f = 0,5 mseg -> T/2 = 0.25 mseg
; TMR0 = 256 ? TEMPO/CM -> TMR0 = 256 ? 0.25mseg/1useg = 6
; TMR0 = 256 ? TEMPO/4CM -> TMR0 = 256 ? 0.25 mseg/(4x1useg) = 193,5
    
; Sinal sonoro de 3KHz -> T = 1/f = 0.3333 mseg -> T/2 = 0.16666 mseg
; TMR0 = 256 ? TEMPO/CM -> TMR0 = 256 ? 0.16666mseg/1useg = 89,34
; TMR0 = 256 ? TEMPO/4CM -> TMR0 = 256 ? 0.16666 mseg/(4x1useg) = 214,35
    
; Sinal sonoro de 800Hz -> T = 1/f = 1,25 mseg -> T/2 = 0,625 mseg
; TMR0 = 256 ? TEMPO/4CM -> TMR0 = 256 ? 0,625mseg/1useg = -369
; Associando o prescaler ao TMR0 com uma divisão do CM por 2:
; TMR0 = 256 ? TEMPO/4CM -> TMR0 = 256 ? 0,625 mseg/(2x1useg) = -56,5
; Associando o prescaler ao TMR0 com uma divisão do CM por 4:
; TMR0 = 256 ? TEMPO/4CM -> TMR0 = 256 ? 0,625 mseg/(4x1useg) = 99,75
   
#INCLUDE P16F628A.INC
    
#DEFINE	    ZONA_01 PORTB,1	    ;
#DEFINE	    ZONA_02 PORTB,3	    ;
#DEFINE	    ZONA_S PORTB,0	    ;
#DEFINE	    TEC PORTB,4		    ;
#DEFINE	    LED_01 PORTA,0	    ;
#DEFINE	    LED_02 PORTA,1	    ;
#DEFINE	    LED_S PORTA,2	    ;
#DEFINE	    LED_A PORTA,3	    ;
#DEFINE	    AF PORTB,5		    ;
#DEFINE	    DISC PORTB,6	    ;

SALVA_W EQU 20H ; Usado para salvar o reg. W nas interrupções
SALVA_S EQU 21H ; Usado para salvar o reg. STATUS nas interrupções
FLAGS	EQU 22H ; Flags do sistema
FREQ	EQU 23H ; Indica a freqüência que será gerado pelo TMR0
    
CONTA1 EQU 24H
CONTA2 EQU 25H
CONTA3 EQU 26H
CONTA4 EQU 27H
CONTA5 EQU 28H

 __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _MCLRE_ON & _BODEN_OFF & _LVP_OFF & _CP_OFF
 
    ORG 000H
    GOTO INICIO
   
    ; -> Interrupção 
    ORG 004H
	MOVWF SALVA_W	    ; Salva contexto
	SWAPF STATUS,W
	MOVWF SALVA_S
	BTFSS INTCON,INTF   ; Int. externa ?
	GOTO  INTTMR0
	
; -> Interrupção externa: Zona Silenciosa
	
	BCF INTCON,INTF	    ; Zera flag de interrupção externa  
	
	BSF FLAGS,2	    ; Indica ao programa principal que ZONA_S foi acionada
	BCF LED_S	    ; Acende o led silencioso
	BSF DISC
	GOTO FIMINT	    ; Sai da interrupção 

; -> Interrupção do Timer 0
INTTMR0:BCF INTCON,T0IF	    ; Zera flag de interrupção do temporizador 0 
    
	MOVFW	FREQ	    ; Pega valor de recarga do TMR0
	MOVWF	TMR0
	
	MOVLW	B'00100000'
	XORWF	PORTB,F	    ; Inverte sinal da sirene
		 
FIMINT:	SWAPF	SALVA_S,W	    ; Recupera contexto
	MOVWF	STATUS
	SWAPF	SALVA_W,F
	SWAPF	SALVA_W,W
	RETFIE
    
    
INICIO: BSF	STATUS,RP0 ; Banco 1 da RAM
	MOVLW   B'10010000'
	MOVWF   TRISA ; Portas RA0 a RA3, RA5 e RA6 como saídas
	MOVLW   B'10011111'
	MOVWF   TRISB ; Portas RB0 a RB3 como saídas
	MOVLW	B'10000001'
			    ; Int. ext. por borda de descida
			    ; TMR0 no modo temporizador com prescaler 1:4
	MOVWF	OPTION_REG
	MOVLW	B'10010000'
	MOVWF	INTCON ; Habilita int. externa e do temporizador 0 
	BCF	STATUS,RP0 ; Banco 0 da RAM
	
	MOVLW   7
	MOVWF   CMCON ; Desabilita comparadores da porta A
	
; -> Valor inicial das portas de saída
 
REINICIO:   BSF LED_01  ;APAGA LED 01
	    BSF LED_02  ;APAGA LED 02
	    BSF LED_S   ;APAGA LED S
	    BSF LED_A   ;APAGA LED A
	    BCF DISC    ;DESLIGA RELE DISCADORA
	    BCF AF	;DESLIGA SIRENE
	    CLRF FLAGS  ;ZERA FLAGS
	
 ; -> Laço Principal
 
TST_Z01: BSF LED_01
	 BCF FLAGS,0
	 BTFSC ZONA_01	;ZONA 1 ABERTA?
	 GOTO TST_Z02	;NÃO, TESTA ZONA 2
	
	BCF LED_01	; ACENDE LED 1
	BSF FLAGS,0	; SETA FLAG INFORMANDO QUE ZONA 1 ESTÁ ABERTA
	 
TST_Z02:BSF LED_02
	BCF FLAGS,1 
	BTFSC ZONA_02	;ZONA 2 ABERTA?
	GOTO TST_TEC	;NÃO, TESTA TECLADO
	
	BCF LED_02	; ACENDE LED 2
	BSF FLAGS,1	; SETA FLAG INFORMANDO QUE ZONA 2 ESTÁ ABERTA
	
TST_TEC: BTFSC TEC	;TECLADO COM SENHA CORRETA?
	 GOTO TST_Z01	

	 MOVF FLAGS,F	
	 BTFSC STATUS,Z	;ALGUMA FLAG SETADA? 
	 GOTO ARMADO	;NÃO, ATIVA ALARME
	 
			;ALGUMA ZONA ABERTA OU ZONA SILENCIOSA ATIVADA
	 BTFSC FLAGS, 2	  ;ZONA SILENCIOSA ACIONADA?
	 GOTO DESATIVA_ZS ;SIM, DESATIVA ZONA SILENCIOSA
	 
	 MOVLW .194
	 MOVWF FREQ
	 BSF INTCON,T0IE
	 CALL LP1SEG
	 BCF INTCON,T0IE
	 BCF AF
	 GOTO TST_Z01
	 

DESATIVA_ZS: BSF LED_S	;DESLIGA LED SILENCIOSO
	     BCF FLAGS, 2   ;LIMPA FLAG DE ZONA SILENCIOSA
	     BCF DISC	    ;DESLIGA DISCADORA
	     CALL LP200MS   ;DEBOUNCING
	     GOTO TST_Z01
    
ARMADO: MOVLW .100
	 MOVWF FREQ
	 BSF INTCON,T0IE
	 CALL LP800MS
	 BCF INTCON,T0IE
	 BCF AF
	 BCF LED_A
	 
TST_Z01_: BTFSC ZONA_01		;ZONA 1 ABERTA?
	  GOTO TST_Z02_		;NÃO, TESTA ZONA 2
	
	 BCF LED_01
	 BSF FLAGS, 0
	 BSF DISC
	 
	 MOVLW .89
	 MOVWF FREQ
	 BSF INTCON,T0IE
	 GOTO TST_TEC_
	 
TST_Z02_:BTFSC ZONA_02		;ZONA 2 ABERTA?
	 GOTO TST_TEC_		;NÃO, TESTA TECLADO
	
	 BCF LED_02
	 BSF FLAGS, 1
	 BSF DISC
	 
	 MOVLW .89
	 MOVWF FREQ
	 BSF INTCON,T0IE
	 
TST_TEC_: BTFSC TEC		;TECLADO COM SENHA CORRETA?
	  GOTO TST_Z01_	
	 
	  MOVF FLAGS,F
	  CALL LP200MS		;DEBOUNCING	
	  BTFSC STATUS,Z	;ALGUMA FLAG SETADA?
	  GOTO REINICIO
	 
	  BSF LED_01
	  BSF LED_02
	  BSF LED_S
	  BCF DISC
	  BCF INTCON,T0IE
	  GOTO TST_Z01_
	 
; -> Laço de tempo

LP1SEG: MOVLW .5 	; 5 x 200 mseg = 1 seg
 	MOVWF CONTA4

LP_200: CALL LP200MS
 	DECFSZ CONTA4,F
 	GOTO LP_200
 	RETURN 

LP800MS: MOVLW .4	; 4 x 200 mseg = 800 mseg
 	 MOVWF CONTA5

LP_200_: CALL LP200MS
 	 DECFSZ CONTA5,F
 	 GOTO LP_200_
 	 RETURN 

LP200MS: MOVLW .200	; 200 x 1 mseg = 200 mseg
	MOVWF CONTA2

LP_1MS: MOVLW .250
	MOVWF CONTA1

LOOP:	NOP
	NOP
	DECFSZ CONTA1,F
	GOTO LOOP
	DECFSZ CONTA2,F
	GOTO LP_1MS
	RETURN 

END