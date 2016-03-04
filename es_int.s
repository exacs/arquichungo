* Inicializa el SP y el PC
**************************
    ORG     $0
    DC.L    $8000           * Pila
    DC.L    PR26            * PC

    ORG     $400

* Definición de equivalencias
*********************************

MR1A    EQU     $effc01       * de modo A (escritura)
MR2A    EQU     $effc01       * de modo A (2º escritura)
SRA     EQU     $effc03       * de estado A (lectura)
CSRA    EQU     $effc03       * de seleccion de reloj A (escritura)
CRA     EQU     $effc05       * de control A (escritura)
TBA     EQU     $effc07       * buffer transmision A (escritura)
RBA     EQU     $effc07       * buffer recepcion A  (lectura)

MR1B    EQU     $effc11       * de modo B (escritura)
MR2B    EQU     $effc11       * de modo B (2º escritura)
SRB     EQU     $effc13       * de estado B (lectura)
CSRB    EQU     $effc13       * de seleccion de reloj B (escritura)
CRB     EQU     $effc15       * de control B (escritura)
TBB     EQU     $effc17       * buffer transmision B (escritura)
RBB     EQU     $effc17       * buffer recepcion B  (lectura)

ACR     EQU     $effc09       * de control auxiliar
IMR     EQU     $effc0B       * de mascara de interrupcion ambas (escritura)
ISR     EQU     $effc0B       * de estado de interrupcion de ambas (lectura)
IVR     EQU     $effc19       * vector de interrupccion de AMBAS


* Variables globales
**********************
* Vector de buffers.
*   Contiene las direcciones de inicio de los buffers internos
V_BUFFER:
    DC.L   0,0,0,0

* Copia de IMR
IMRCOPY:
    DC.B 0

* Variable global SALTO
*
* Indica si el siguiente carácter a transmitir es un salto de línea o no
*
* Puede tomar los valores 0 (no es un salto de línea) o 1 (sí es un salto de
* línea) en los siguientes bits:
*
* Bit 0 - Línea de transmisión A
* Bit 1 - Línea de transmisión B
*
* El resto de bits no se tienen en cuenta
SALTO:
    DC.B 0


    ORG      $440



***************************************************************************************************
*
* Subrutina INIT
*
***************************************************************************************************
INIT:
    MOVE.B    #%00010000,CRA      * Reinicia el puntero MR1
    MOVE.B    #%00000011,MR1A     * Solicita interrupccion por cada caracter. 8 bits por caracter
    MOVE.B    #%00000000,MR2A     * Eco desactivado.
    MOVE.B    #%11001100,CSRA     * Velocidad = 38400 bps.
    MOVE.B    #%00000000,ACR      * Velocidad = 38400 bps.
    MOVE.B    #%00000101,CRA      * Transmision y recepcion activados.

    MOVE.B    #%00010000,CRB      * Reinicia el puntero MR1
    MOVE.B    #%00000011,MR1B     * Solicita interrupccion por cada caracter. 8 bits por caracter.
    MOVE.B    #%00000000,MR2B     * Eco desactivado.
    MOVE.B    #%11001100,CSRB     * Velocidad = 38400 bps.
    MOVE.B    #%00000101,CRB      * Transmision y recepcion activados.

    MOVE.B    #%00000000,IMRCOPY  * Permitir interrupción de recepción
    MOVE.B    IMRCOPY,IMR
    MOVE.W    #$2000,SR           * Permite interrupciones

    MOVE.L    #RTI,$100           * 256 = 64 * 4
    MOVE.B    #$40,IVR            * Vector de interrupcion = 64

    MOVE.L    #V_BUFFER,A0        * Vector de buffers internos

    MOVE.L    #BUFI_0,(A0)
    MOVE.L    #BUFI_1,4(A0)
    MOVE.L    #BUFI_2,8(A0)
    MOVE.L    #BUFI_3,12(A0)
    
    MOVE.B    #%00100010,IMRCOPY  * Permitir interrupción de recepción
    MOVE.B    IMRCOPY,IMR

    RTS





***************************************************************************************************
*
* Subrutina RTI
*
***************************************************************************************************

RTI:
    * Guardar los registros A0,D0,D1,D2
    MOVE.L  A0,-(A7)
    MOVE.L  D0,-(A7)
    MOVE.L  D1,-(A7)
    MOVE.L  D2,-(A7)
    MOVE.L  D3,-(A7)
    MOVE.L  D5,-(A7)
    MOVE.L  D6,-(A7)

    LINK    A6,#-8
    * Variables locales
    *
    *    -8(A6).L = Dirección del registro TBA/TBB/RBA/RBB
    
    *    -4(A6).B = Máscara del IMR
    *             bit 0 = 0, inhibe Transmisión A
    *             bit 1 = 0, inhibe Recepción A
    *             bit 4 = 0, inhibe Transmisión B
    *             bit 5 = 0, inhibe Recepción B
    *
    *    -2(A6).B = descriptor de la interrupción
    *             0 = Recepción A
    *             1 = Recepción B
    *             2 = Transmision A
    *             3 = Transmisión B
    *

    *
    MOVE.B  #%11111111,-4(A6)    * Máscara ISR = 11111111
    
    * Paso 1.
    *   Reconocer la fuente de la interrupción y preparar las variables locales
    *
    MOVE.B  ISR,D1
    AND.B   IMRCOPY,D1

    BTST    #0,D1
    BNE     RTI_TA

    BTST    #1,D1
    BNE     RTI_RA

    BTST    #4,D1
    BNE     RTI_TB

    BTST    #5,D1
    BNE     RTI_RB

    RTI_TA:
        MOVE.B #2,-2(A6)
        MOVE.L #TBA,-8(A6)
        MOVE.B #%11111110,-4(A6)
        BRA    RTI_2

    RTI_TB:
        MOVE.B #3,-2(A6)
        MOVE.L #TBB,-8(A6)
        MOVE.B #%11101111,-4(A6)
        BRA    RTI_2

    RTI_RA:
        MOVE.B #0,-2(A6)
        MOVE.L #RBA,-8(A6)
        MOVE.B #%11111101,-4(A6)
        BRA    RTI_2

    RTI_RB:
        MOVE.B #1,-2(A6)
        MOVE.L #RBB,-8(A6)
        MOVE.B #%11011111,-4(A6)
        BRA    RTI_2

    * Paso 2.
    *   Dirigir a Recepción o Transmisión
    RTI_2:
        BTST   #1,-2(A6)
        BNE    RTI_2T
        BEQ    RTI_2R


    * Paso 2-Transmisión
    *   Copia en D0 el carácter que se debe transmitir por la línea
    *
    *   Si salto==true, se copia "\n"
    *   eoc, se copia el primer carácter del Buffer Interno
    RTI_2T:
    MOVE.L  #0,D6
    MOVE.B  -2(A6),D6
    BTST.B  #1,SALTO
    BNE     RTI_2TNS

    * SALTO==true
    * Paso 2-Transmisión-A
    * 
    * Copia en D0 "\n" e inhibe la transmisión si no hay más líneas
    RTI_2TS:
        * Salto = false
        MOVE.L  #0,D6
        MOVE.B  -2(A6),D6
        BCLR.B  D6,SALTO

        MOVE.B  #10,D5           * Transmitir salto de línea

        * Llamar a LINEA
        MOVE.B  -2(A6),D0        * LINEA.Descriptor = -2(A6)
        BSR     LINEA
        CMP.W   #0,D0
        BNE     RTI_3T

        * IMR = IMR & MáscaraIMR
        MOVE.B  -4(A6),D1        * D1 = MáscaraIMR
        AND.B   D1,IMRCOPY       * IMRCOPY = IMR & MáscaraIMR
        MOVE.B  IMRCOPY,IMR      * IMR = IMR & MáscaraIMR
        BRA     RTI_3T

    * SALTO==false.
    * Paso 2-Transmisión-B
    * 
    * Copia en D0 el carácter que haya en el buffer interno
    * Si el carácter es un \r, poner SALTO=true
    RTI_2TNS:
        MOVE.B  -2(A6),D0   * Parámetro Buffer (Interno)
        BSR     LEECAR
        MOVE.B  D0,D5
        CMP.B   #13,D0
        BNE     RTI_3T

        * Poner salto = true
        MOVE.L  #0,D6
        MOVE.B  -2(A6),D6
        BSET.B  D6,SALTO

    * Paso 3-Transmisión
    *   Copia el valor de D0 al vector de transmisión
    RTI_3T:
        MOVE.L  -8(A6),A0
        MOVE.B  D5,(A0)
        
        BRA     RTI_END



    * Paso 2-Recepción
    *   Copia RBA/RBB al buffer interno correspondiente
    *   llamando a la subrutina ESCCAR
    RTI_2R:
        MOVE.B  -2(A6),D0  * Parámetro Buffer (Interno)
        MOVE.L  -8(A6),A0  * RBA/RBB
        MOVE.B  (A0),D1    * Parámetro Caracter
        
        BSR     ESCCAR
    
    
    RTI_END:
        UNLK    A6

        MOVE.L  (A7)+,D6
        MOVE.L  (A7)+,D5
        MOVE.L  (A7)+,D3
        MOVE.L  (A7)+,D2
        MOVE.L  (A7)+,D1
        MOVE.L  (A7)+,D0
        MOVE.L  (A7)+,A0
        RTE



***************************************************************************************************
*
* Subrutina PRINT
*
***************************************************************************************************
* Parámetros
*   8(A6).L   Buffer
*   12(A6).W   Descriptor
*   14(A6).W  Tamaño
*
PRINT:
    LINK    A6,#-4
    * Variables locales
    *   -4(A6).B    MáscaraIMR
    *   -2(A6).W    i
    *
    MOVE.L  #0,D3


    * 1. Copiar el mensaje correspondiente al Buffer Interno de Transmisión A o B

    * 1.1. Comprobar que el Descriptor es válido
    CMP.W   #2,12(A6)
    BGE     PRI_ERR          * Si  Descriptor>=2, error

    * 1.2. Copiar cada carácter llamando a ESCCAR
    MOVE.W  #0,-2(A6) * i = 0

    PRI_BUC:
    * while(i != Tamaño)
    MOVE.W  -2(A6),D2
    MOVE.W  14(A6),D3
    CMP.W   14(A6),D2

    BEQ     PRI_2

        * ESCCAR
        MOVE.W  12(A6),D0
        ADD.W   #2,D0        * ESCCAR.Descriptor = PRINT.Descriptor + 2
        MOVE.L  8(A6),A0
        MOVE.W  -2(A6),D2
        MOVE.B  (A0,D2),D1   * ESCCAR.Caracter = M(Buffer + i)
        BSR     ESCCAR

        * Si (buffer lleno) => salir
        CMP.W   #-1,D0
        BEQ     PRI_2

        * i++
        ADD.W   #1,-2(A6)
        BRA     PRI_BUC


    * 2. Si existe una línea completa en el buffer interno A o B,
    *    permitir interrupciones
    PRI_2:

    * LINEA
    MOVE.W  12(A6),D0
    ADD.L   #2,D0     * LINEA.Descriptor = PRINT.Descriptor + 2
    BSR     LINEA

    * Si D0 == 0, saltar al paso 4
    CMP.W   #0,D0
    BEQ     PRI_4

    * Crear la máscara que permita una interrupción
    CMP.W   #0,12(A6)

    BEQ     PRI_2A
    BRA     PRI_2B

    PRI_2A:
        MOVE.B  #%00000001,-4(A6)
        BRA     PRI_3
    PRI_2B:
        MOVE.B  #%00010000,-4(A6)
        BRA     PRI_3

    * 3. IMR = IMR | MáscaraIMR
    PRI_3:
        MOVE.B  -4(A6),D1
        OR.B    D1,IMRCOPY
        MOVE.B  IMRCOPY,IMR

    * 3. Retornar i
    PRI_4:
        MOVE.W  -2(A6),D0
        BRA     PRI_END

    PRI_ERR:
        MOVE.L  #-1,D0
        BRA     PRI_END

    PRI_END:
    UNLK    A6
    RTS



***************************************************************************************************
*
* Subrutina SCAN
*
***************************************************************************************************

SCAN:
    * Parámetros
    * Buffer (4 bytes)
    * Descriptor (2 bytes)
    * Tamaño (2 bytes)
    LINK    A6,#-8
    * Variables locales
    * -4(A6)  i  - Contador de caracteres de la línea (maximo)
    * -8(A6)  j  - incrementador
    
    * 1. Identificar el buffer interno (parámetro Descriptor)
    MOVE.W  12(A6),D0
    CMP.W   #1,D0
    BGT     SCAN_ERR
    
    * 2. Comprobar que hay una línea completa
    BSR     LINEA
    MOVE.L  D0,-4(A6)
    MOVE.L  #0,-8(A6)

    
    SCAN_BUC:
    * while (i!=0)
    CMP.L   #0,-4(A6)     
    BEQ     SCAN_OK
        
        MOVE.W  12(A6),D0
        BSR     LEECAR
        * D0 vale el carácter. Copiar en el buffer
        MOVE.L  8(A6),A0
        MOVE.L  -8(A6),D2
        MOVE.B  D0,(A0,D2)
        
        * i--
        SUB.L   #1,-4(A6)
        ADD.L   #1,-8(A6)
        BRA     SCAN_BUC

    SCAN_OK:
        MOVE.L -8(A6),D0
    
    SCAN_FIN:
        UNLK   A6
        RTS

    SCAN_ERR:
        MOVE.L #-1,D0
        BRA    SCAN_FIN
    
    

***************************************************************************************************
*
* Subrutina LEECAR
*
***************************************************************************************************

LEECAR:
    MOVE.W  #$7000,SR        * Inhibe interrupciones

    *                        * 1. Leer el vector de buffers para conocer
    *                        *    la dirección de inicio del buffer seleccionado
    *                        *
    MOVE.L  #V_BUFFER,A0     * A0 = V_BUFFER
    AND.L   #3,D0            * Máscara de 2 bits
    ASL.L   #2,D0            * D0 = Buffer * 4
    MOVE.L  (A0,D0),A0       * A0 = [V_BUFFER + Buffer * 4]

    *                        * 2. Si el buffer está vacío, D0=-1 y salir
    *                        * 
    CMP.W   #0,2(A0)         * [A0+2] == 0   significa que está vacío
    BNE     L_novacio        *
        MOVE.L  #-1,D0       * D0 = -1
        MOVE.W  #$2000,SR        * Permite interrupciones
        RTS                  * salir
    
    L_novacio:

    *                        * 3. Obtener el primer carácter del buffer (A0+principio+4)
    MOVE.W  (A0),D0          * D0 = principio = [A0]
    MOVE.B  4(A0,D0),D0      * D0 = [A0+4+principio]
    * EXT.L   D0

    ADD.W   #1,(A0)          * 4. incrementar inicio, decrementar longitud en uso
    SUB.W   #1,2(A0)

    CMP.W   #2000,(A0)       * 5. Comprobar que "inicio" se encuentra entre 0 y 2000
    BLT     L_nomod
        MOVE.W  #0,(A0)
    L_nomod:

    MOVE.W  #$2000,SR        * Permite interrupciones
    RTS



***************************************************************************************************
*
* Subrutina ESCCAR
*
***************************************************************************************************
*
*  Parámetros
*    D0: Buffer. 2 bytes.
*        Buffer Interno en el que copiar el carácter
*
*    D1: Carácter
*        Carácter que se debe copiar
*
ESCCAR:
    MOVE.W  #$7000,SR        * Inhibe interrupciones
    *
    *
    *
    MOVE.L  #V_BUFFER,A0
    AND.L   #3,D0            * Máscara de 2 bits
    ASL.L   #2,D0
    MOVE.L  (A0,D0),A0

    CMP.W   #2000,2(A0)
    BNE     E_nolleno
        MOVE.L #-1,D0
        MOVE.W  #$2000,SR        * Permite interrupciones
        RTS

    E_nolleno:

    MOVE    (A0),D2      * A0 + 4 + (inicio+nElementos)%2000
    ADD     2(A0),D2     * D2 = inicio + nElementos
    CMP.W   #2000,D2
    BLT     E_nomod
        SUB  #2000,D2
                         * D2 = (inicio + nElementos) % 2000
    E_nomod:
    MOVE.B  D1,4(A0,D2)

    ADD.W   #1,2(A0)

    MOVE.L  #0,D0

    MOVE.W  #$2000,SR        * Permite interrupciones
    RTS



***************************************************************************************************
*
* Subrutina LINEA
*
***************************************************************************************************

LINEA:
    *                        * 1. Leer el vector de buffers para conocer
    *                        *    la dirección de inicio del buffer seleccionado
    *                        *
    MOVE.L  #V_BUFFER,A0     * A0 = V_BUFFER
    AND.L   #3,D0            * Máscara de 2 bits
    ASL.L   #2,D0            * D0 = Buffer * 4
    MOVE.L  (A0,D0),A0       * A0 = [V_BUFFER + Buffer * 4]

    *                        * 2. Inicializamos contador
    MOVE.L  #0,D0            * i = 0

    MOVE.W  (A0),D1          * D1 = principio
    MOVE.W  2(A0),D2         * D2 = nElementos

    CMP.W   #0,D2            * Si nElementos=0 => salir
    BEQ     LN_exit

    * MOVE.W  4(A0,D1),A1      * A1 = buffer[principio]

    bucle:
        MOVE.L  D1,D3            * j = principio
        ADD.L   D0,D3            * j = principio + i
        CMP     #2000,D3         
        BLT     LN_nomod
            SUB.L  #2000,D3

        LN_nomod:                 * j = (principio + i) % 2000
        MOVE.B  4(A0,D3),D4       * A1 = buffer[j]
        CMP.B   #13,D4            *
        BEQ     LN_sumuno         * Si A1==13 => sumar 1 y salir

        ADD.W   #1,D0             * 
        CMP.W   D2,D0             * Si i==nElementos => fin del bucle (no encontrado)
    BNE     bucle


    MOVE.L  #0,D0
    BRA     LN_exit

    LN_sumuno:
    ADD.L   #1,D0                * Suma 1 por el carácter 13

    LN_exit:
    RTS

    
PR21:
    BSR     INIT
    MOVE.L  #1,D0
    MOVE.B  #$60,D1
    BSR     ESCCAR

    
    
PR22:
    BSR INIT
    BREAK
    * Llamar a ESCCAR 1500 veces
    * Insertando hexadecimales 30,31,32,33,34,35,36,37,38,39 un total de 150 veces
    MOVE.L  #150,D7       * Contador de 1 a 150
    PR22_1i:
        MOVE.L #$30,D1    * Contador de 30 a 39
                          * Carácter a insertar
        
        PR22_1j:
            MOVE.L #1,D0  * Parámetro Descriptor
            BSR    ESCCAR
            ADD.B  #1,D1
            CMP    #$3a,D1
            BNE    PR22_1j
        
        SUB.L  #1,D7
        CMP.L  #0,D7
        BNE    PR22_1i
    
    BREAK
    
    * Llamar a LEECAR 1500 veces
    MOVE.L  #1500,D7       * Contador de 1 a 1500
    PR22_2i:
        MOVE.L #1,D0
        BSR    LEECAR
        
        SUB.L  #1,D7
        CMP.L  #0,D7
        BNE    PR22_2i
        
    BREAK
    
    * Llamar a ESCCAR 1000 veces
    * Insertando hexadecimales 30,31,32,33,34,35,36,37,38,39 un total de 100 veces
    MOVE.L  #100,D7       * Contador de 1 a 100
    PR22_3i:
        MOVE.L #$30,D1    * Contador de 30 a 39
                          * Carácter a insertar
        
        PR22_3j:
            MOVE.L #1,D0  * Parámetro Descriptor
            BSR    ESCCAR
            ADD.B  #1,D1
            CMP    #$3a,D1
            BNE    PR22_3j
        
        SUB.L  #1,D7
        CMP.L  #0,D7
        BNE    PR22_3i
    
    BREAK
    * Insertar salto de línea
    MOVE.L  #1,D0
    MOVE.B  #13,D1
    BSR     ESCCAR
    
    BREAK
    * Llamar a línea
    MOVE.L  #1,D0
    BSR     LINEA
    
    BREAK


PR26:
    BSR INIT
    PR26_B:
        CMP.B  #%00100010,IMRCOPY
        BNE    PR26_B
    
    * Aquí ha terminado de interrumpir
    BREAK   
    
    MOVE.W #21,-(A7)    * Tamaño = 21 (incl. \r)
    MOVE.W #1,-(A7)     * Recepción por B
    MOVE.L #$8000,-(A7) * Se copiará a partir de la dirección 8000
    BSR    SCAN
    
    ADD.L  #8,A7
    
    BREAK
    ***********************************************************

BUFFER: DS.B    2000   * Buffer para escritura y lectura de caracteres
CONTL:  DC.W    0      * Contador de lineas
CONTC:  DC.W    0      * Contador de caracteres
DIRLEC: DC.L    0      * Direccion de lectura para SCAN
DIRESC: DC.L    0      * Direccion de lectura para PRINT
TAME:   DC.L    0      * Tamano de escritura para print
DESA:   EQU     0      * Descriptor linea A
DESB:   EQU     1      * Descriptor linea B
NLIN:   EQU     10     * Numero de lineas a leer
TAML:   EQU     30     * Tamano de linea para SCAN
TAMB:   EQU     5      * Tamano de bloque para PRINT

TAMBUFF:EQU     2000   * Tamano del buffer


* Heap de memoria

    ORG    $3000

BUFI_0:
    DC.W   0,0      * Campos inicio y longitud en uso
    DS.B   TAMBUFF  * Array con el buffer


BUFI_1:
    DC.W   0,0      * Campos inicio y longitud en uso
    DS.B   TAMBUFF  * Array con el buffer

    
BUFI_2:
    DC.W   0,0      * Campos inicio y longitud en uso
    DS.B   TAMBUFF  * Array con el buffer


BUFI_3:
    DC.W   0,0      * Campos inicio y longitud en uso
    DS.B   TAMBUFF  * Array con el buffer

