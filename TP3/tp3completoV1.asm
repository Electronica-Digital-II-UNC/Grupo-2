;===============================================================================
; @file       G2_TPL3_ED2.asm
;
; @author     Apellido_Nombre
;	      Apellido_Nombre
;	      Apellido_Nombre
;
; @date       dia/mes/año
;
; @version    1.0
;===============================================================================
;===============================================================================
; DIRECTIVAS DE INCLUSIÓN
;===============================================================================
LIST P=16F887			
#include "p16f887.inc"	
	
;===============================================================================
; CONFIGURACIÓN GENERAL DEL MCU
;=============================================================================== 	
__CONFIG _CONFIG1, _XT_OSC & _WDTE_OFF & _MCLRE_ON & _LVP_OFF
;===============================================================================
; DEFINICIÓN DE CONSTANTES
;===============================================================================     
CTRL_DSPL_1	    EQU	    0	    ;Bit de PORTC/TRISC -> RC0
CTRL_DSPL_2	    EQU	    1	    ;Bit de PORTC/TRISC -> RC1
CTRL_DSPL_3	    EQU	    2	    ;Bit de PORTC/TRISC -> RC2
    
;===============================================================================
; DEFINICIÓN DE VARIABLES
;=============================================================================== 
	CBLOCK  0x20
	    DELAY1_Init		;Recarga lazo interno  (p) - uso exclusivo de MUX (2ms5)
	    DELAY2_Init		;Recarga lazo medio    (n) - uso exclusivo de MUX (2ms5)
	    DELAY3_Init		;Recarga lazo externo  (m) - uso exclusivo de MUX (2ms5)
	    DELAY1		;Contador de trabajo lazo interno (scratch, reutilizable)
	    DELAY2		;Contador de trabajo lazo medio   (scratch, reutilizable)
	    DELAY3		;Contador de trabajo lazo externo (scratch, reutilizable)
	    DATA_DSPL_1		;Índice de carácter a mostrar en DSPL1 ('G')
	    DATA_DSPL_2		;Índice de carácter a mostrar en DSPL2 (decena)
	    DATA_DSPL_3		;Índice de carácter a mostrar en DSPL3 (unidad)
	    NUM_MAX_DSPL	;Cantidad de DSPLs activos del sistema (3)
	    COUNTER_DSPL	;Contador de multiplexado (3,2,1)
	    COUNTER_SEGMENTS	;Contador de segmentos para TEST_DSPL (7,6,...,0)
	ENDC

	;SEGMENT_SHADOW reutiliza DATA_DSPL_1: durante TEST_DSPL ese registro
	;todavia no fue inicializado por CFG_DIGITS_DSPL (que corre despues),
	;asi que esta libre para usarse como mascara de segmentos del test.
SEGMENT_SHADOW	    EQU	    DATA_DSPL_1
	
;===============================================================================
; DECLARACIÓN DE MACROS PARA CONFIGURACIÓN DE REGISTROS
;===============================================================================
DSPL_ALL_OFF	MACRO
    BCF	    PORTC,CTRL_DSPL_1
    BCF	    PORTC,CTRL_DSPL_2
    BCF	    PORTC,CTRL_DSPL_3
	ENDM

CFG_DSPL	MACRO
    BANKSEL TRISC
    BCF	    TRISC,CTRL_DSPL_1	;RC0 salida
    BCF	    TRISC,CTRL_DSPL_2	;RC1 salida
    BCF	    TRISC,CTRL_DSPL_3	;RC2 salida
    CLRF    TRISD		;PORTD completo como salida (segmentos a-g, dp)
    BANKSEL ANSEL
    CLRF    ANSEL		;AN0-AN7  -> digital
    CLRF    ANSELH		;AN8-AN13 -> digital
    BANKSEL PORTC
    DSPL_ALL_OFF		;Los 3 dígitos apagados (lógica positiva)
    CLRF    PORTD		;Todos los segmentos apagados (lógica positiva)
    MOVLW   .3
    MOVWF   NUM_MAX_DSPL	;Cantidad de displays activos del sistema
	ENDM

CFG_DIGITS_DSPL	MACRO
    MOVLW   .10			;Índice de 'G' en TABLE_DECO_DSPL_CC
    MOVWF   DATA_DSPL_1
    MOVLW   .0			;Dígito '0' (decena de 02)
    MOVWF   DATA_DSPL_2
    MOVLW   .2			;Dígito '2' (unidad de 02)
    MOVWF   DATA_DSPL_3
	ENDM

CFG_DELAY_2ms5	MACRO
    MOVLW   .91
    MOVWF   DELAY1_Init
    MOVLW   .9
    MOVWF   DELAY2_Init
    MOVLW   .1
    MOVWF   DELAY3_Init
	ENDM

CFG_DELAY_300ms	MACRO
    LOCAL   LOOP_M_300ms, LOOP_N_300ms, LOOP_P_300ms
    MOVLW   .20
    MOVWF   DELAY3
LOOP_M_300ms
    MOVLW   .23
    MOVWF   DELAY2
LOOP_N_300ms
    MOVLW   .216
    MOVWF   DELAY1
LOOP_P_300ms
    DECFSZ  DELAY1,F
    GOTO    LOOP_P_300ms
    DECFSZ  DELAY2,F
    GOTO    LOOP_N_300ms
    DECFSZ  DELAY3,F
    GOTO    LOOP_M_300ms
	ENDM

CFG_DELAY_1s	MACRO
    LOCAL   LOOP_M_1s, LOOP_N_1s, LOOP_P_1s
    MOVLW   .100
    MOVWF   DELAY3
LOOP_M_1s
    MOVLW   .25
    MOVWF   DELAY2
LOOP_N_1s
    MOVLW   .132
    MOVWF   DELAY1
LOOP_P_1s
    DECFSZ  DELAY1,F
    GOTO    LOOP_P_1s
    DECFSZ  DELAY2,F
    GOTO    LOOP_N_1s
    DECFSZ  DELAY3,F
    GOTO    LOOP_M_1s
	ENDM

;===============================================================================
; INICIALIZACIÓN DEL MCU (CÓDIGO ABSOLUTO)
;===============================================================================    
    ORG     0x00	;Vector de Reset
    GOTO    INICIO	;Salto al inicio del programa principal
    ORG     0x05	;Ubicación Programa Principal en la memoria 
			;de programa
		
;===============================================================================
; INICIALIZACIÓN DE MACROS PARA CONFIGURACIÓN DE REGISTROS
;===============================================================================    	    
INICIO	    ;-----Inicialización de Macros-------
    CFG_DSPL
    CFG_DELAY_2ms5
    CALL    TEST_DSPL
    CFG_DIGITS_DSPL
		
;===============================================================================
; INICIO PROGRAMA PRINCIPAL
;===============================================================================						
MAIN_LOOP
    CALL    MUX_DSPL
    GOTO    MAIN_LOOP	
	
;===============================================================================
; SUBRUTINAS
;===============================================================================	 
;*******************************************************************************
; @brief    Retardo genérico por software mediante triple lazo anidado.
;           
; @details  Recarga DELAY1/2/3 a partir de DELAY1_Init/2_Init/3_Init (cargados
;           una única vez por CFG_DELAY_2ms5 en INICIO) y cuenta hasta agotar
;           los tres lazos. Usado exclusivamente por MUX_DSPL (retardo 2,5ms).
;******************************************************************************* 
DELAY_3LOOP
    MOVF    DELAY3_Init,W
    MOVWF   DELAY3
LOOP_M_MUX
    MOVF    DELAY2_Init,W
    MOVWF   DELAY2
LOOP_N_MUX
    MOVF    DELAY1_Init,W
    MOVWF   DELAY1
LOOP_P_MUX
    DECFSZ  DELAY1,F
    GOTO    LOOP_P_MUX
    DECFSZ  DELAY2,F
    GOTO    LOOP_N_MUX
    DECFSZ  DELAY3,F
    GOTO    LOOP_M_MUX
    RETURN

;*******************************************************************************
; @brief    Reinicia el contador de multiplexado.
;*******************************************************************************
RST_COUNTER_DSPL
    MOVLW   .3
    MOVWF   COUNTER_DSPL
    RETURN

;*******************************************************************************
; @brief    Decrementa el contador de multiplexado.
;*******************************************************************************
DECF_COUNTER_DSPL
    DECF    COUNTER_DSPL,F
    RETURN

;*******************************************************************************
; @brief    Tabla de decodificación de caracteres, Cátodo Común (lógica activa
;           en alto).
;           
; @details  Recibe en W el índice de carácter (0-9 = dígitos, 10 = letra 'G')
;           y devuelve en W el patrón de segmentos (bit0=a,...,bit6=g; bit7=dp
;           sin uso).
;******************************************************************************* 
TABLE_DECO_DSPL_CC
    ADDWF   PCL,F
    RETLW   b'00111111'	;0
    RETLW   b'00000110'	;1
    RETLW   b'01011011'	;2
    RETLW   b'01001111'	;3
    RETLW   b'01100110'	;4
    RETLW   b'01101101'	;5
    RETLW   b'01111101'	;6
    RETLW   b'00000111'	;7
    RETLW   b'01111111'	;8
    RETLW   b'01101111'	;9
    RETLW   b'01111101'	;10 = 'G' (mismo patrón que el 6, opción elegida)

;*******************************************************************************
; @brief    Tabla de selección de dígito, Cátodo Común (lógica activa en alto).
;           
; @details  Recibe en W el valor de COUNTER_DSPL (1, 2 ó 3) y devuelve en W la
;           máscara de PORTC que habilita únicamente el transistor de ese DSPL.
;******************************************************************************* 
TABLE_CTRL_DSPL_CC
    ADDWF   PCL,F
    RETLW   0x00		    	;índice 0, relleno (no se usa)
    RETLW   (1<<CTRL_DSPL_1)	;índice 1 -> habilita DSPL_1
    RETLW   (1<<CTRL_DSPL_2)	;índice 2 -> habilita DSPL_2
    RETLW   (1<<CTRL_DSPL_3)	;índice 3 -> habilita DSPL_3

;*******************************************************************************
; @brief    Actualiza segmentos y selección del DSPL_1.
;*******************************************************************************
UPDATE_DSPL_1
    MOVF    DATA_DSPL_1,W
    CALL    TABLE_DECO_DSPL_CC
    MOVWF   PORTD
    MOVF    COUNTER_DSPL,W
    CALL    TABLE_CTRL_DSPL_CC
    MOVWF   PORTC
    CALL    DECF_COUNTER_DSPL
    RETURN

;*******************************************************************************
; @brief    Actualiza segmentos y selección del DSPL_2.
;*******************************************************************************
UPDATE_DSPL_2
    MOVF    DATA_DSPL_2,W
    CALL    TABLE_DECO_DSPL_CC
    MOVWF   PORTD
    MOVF    COUNTER_DSPL,W
    CALL    TABLE_CTRL_DSPL_CC
    MOVWF   PORTC
    CALL    DECF_COUNTER_DSPL
    RETURN

;*******************************************************************************
; @brief    Actualiza segmentos y selección del DSPL_3.
;*******************************************************************************
UPDATE_DSPL_3
    MOVF    DATA_DSPL_3,W
    CALL    TABLE_DECO_DSPL_CC
    MOVWF   PORTD
    MOVF    COUNTER_DSPL,W
    CALL    TABLE_CTRL_DSPL_CC
    MOVWF   PORTC
    CALL    DECF_COUNTER_DSPL
    RETURN

;*******************************************************************************
; @brief    Multiplexado de los 3 displays.
;           
; @details  Se llama en cada vuelta de MAIN_LOOP. Espera 2,5ms y actualiza el
;           display que corresponda según COUNTER_DSPL (3?2?1). Al agotarse
;           reinicia el contador (ese ciclo no actualiza ningún DSPL), dando
;           un período de refresco de 4 x 2,5ms = 10ms.
;******************************************************************************* 
MUX_DSPL
    CALL    DELAY_3LOOP
    MOVF    COUNTER_DSPL,W
    SUBLW   .3
    BTFSC   STATUS,Z
    GOTO    MUX_CALL_3
    MOVF    COUNTER_DSPL,W
    SUBLW   .2
    BTFSC   STATUS,Z
    GOTO    MUX_CALL_2
    MOVF    COUNTER_DSPL,W
    SUBLW   .1
    BTFSC   STATUS,Z
    GOTO    MUX_CALL_1
    CALL    RST_COUNTER_DSPL
    RETURN
MUX_CALL_3
    CALL    UPDATE_DSPL_3
    RETURN
MUX_CALL_2
    CALL    UPDATE_DSPL_2
    RETURN
MUX_CALL_1
    CALL    UPDATE_DSPL_1
    RETURN

;*******************************************************************************
; @brief    Rutina de test de hardware: barrido individual de los 7 segmentos.
;           
; @details  Para cada uno de los 3 DSPL (en orden 3,2,1): enciende un único
;           segmento a la vez, en secuencia a->b->c->d->e->f->g (600ms cada
;           uno), y al terminar enciende los 7 segmentos juntos durante 2s y
;           los apaga durante 2s. SEGMENT_SHADOW actúa como máscara de un solo
;           bit que se desplaza a la izquierda (bit0='a' ... bit6='g').
;******************************************************************************* 
TEST_DSPL
    CALL    RST_COUNTER_DSPL
LOOP_TEST_DSPL
    MOVF    COUNTER_DSPL,W
    CALL    TABLE_CTRL_DSPL_CC
    MOVWF   PORTC
    ;-----Inicializa Patrón SEGMENT_SHADOW @ t=300ms-----
    MOVLW   b'00000001'		;Arranca en el segmento 'a' (bit0)
    MOVWF   SEGMENT_SHADOW
    MOVWF   PORTD
    MOVLW   .7			;7 segmentos por recorrer (a...g)
    MOVWF   COUNTER_SEGMENTS
LOOP_TEST_SEGMENT
    CFG_DELAY_300ms		;STATIC SEGMENT ON
    CFG_DELAY_300ms		;OLD SEGMENT OFF (600ms de intermitencia)
    ;-----Desplazamiento hacia la izquierda de los segmentos SEGMENT_SHADOW---
    BCF	    STATUS,C
    RLF	    SEGMENT_SHADOW,F
    DECF    COUNTER_SEGMENTS,F
    MOVF    SEGMENT_SHADOW,W
    MOVWF   PORTD
    MOVF    COUNTER_SEGMENTS,F
    BTFSS   STATUS,Z
    GOTO    LOOP_TEST_SEGMENT
    ;-----Finaliza Patrón-----
    ;-----Enciende todos los segmentos @ t=2s-----
    MOVLW   b'01111111'
    MOVWF   PORTD
    CFG_DELAY_1s
    CFG_DELAY_1s
    ;-----Apaga todos los segmentos @ t=2s-----
    CLRF    PORTD
    CFG_DELAY_1s
    CFG_DELAY_1s
    CALL    DECF_COUNTER_DSPL
    BTFSS   STATUS,Z
    GOTO    LOOP_TEST_DSPL
    CALL    RST_COUNTER_DSPL
    RETURN
;===============================================================================		
    END
;===============================================================================