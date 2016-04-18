    ORG     $0
    DC.L    $8000           * Pila
    DC.L    INICIO          * PC
    
********************************************************************************
*   REGIÓN DE TEXTO
********************************************************************************
    ORG     $400
    
TAMANYO EQU     2000          * Buffer para escritura y lectura de caracteres

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
    
    INIT:
        MOVE.L    #V,A0        * Vector de buffers internos

        MOVE.L    #V0,(A0)
        MOVE.L    #V1,4(A0)
        MOVE.L    #V2,8(A0)
        MOVE.L    #V3,12(A0)
        
        * Preparación de periféricos
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

        MOVE.B    #%00100010,IMRCOPY  * Permitir interrupción de recepción
        MOVE.B    IMRCOPY,IMR

        MOVE.L    #RTI,$100           * 256 = 64 * 4
        MOVE.B    #$40,IVR            * Vector de interrupcion = 64
        
        * MOVE.W    #$2000,SR           * Permite interrupciones
        RTS

*******************************************************************************
    
    LEECAR:
        * Selección de buffer
        AND.L   #$3,D0
        ASL.L   #2,D0
        MOVE.L  #V,A0
        MOVE.L  (A0,D0),A0
                
        *Comprobación de buffer vacío
        CMP     #0,4(A0)
        BEQ     b_vacio
        
        MOVE    (A0),D1
        MOVE.B  8(A0,D1),D0
        
        *Actualización de variables
        ADD     #1,(A0)      * Incrementa "inicio"
        MOVE    SR,D7                                  * Inicio seccion crítica
        MOVE    #$2700,SR                              * Inicio seccion critica
        SUB     #1,4(A0)     * Decrementa "tamanyo"    *
        MOVE    D7,SR                                  * Fin sección crítica

        *Comprobamos que inicio no se pasa de 2000 
        CMP     #2000,(A0)
        BLT     modLee
        SUB     #2000,(A0)

        modLee:
        RTS
        
        b_vacio:
            MOVE.L  #-1,D0
            RTS

*******************************************************************************

    ESCCAR:
        * Selección de buffer
        AND.L   #$3,D0
        ASL.L   #2,D0
        MOVE    #V,A0
        MOVE.L  (A0,D0),A0
        
        * Comprobación de buffer lleno
        CMP     #2000,4(A0)
        BEQ     b_lleno

        MOVE    2(A0),D2
        MOVE.B  D1,8(A0,D2)
        
        * Actualización de variables
        ADD     #1,2(A0)   * Incrementar "fin"         
        MOVE    SR,D7                                  * Inicio Sección crítica
        MOVE    #$2700,SR                              * Inicio Sección crítica
        ADD     #1,4(A0)   * Incrementar "tamano"      *
        MOVE    D7,SR                                  * Fin sección crítica
                                                       
        *Comprobamos que fin no se pasa de 2000        
        CMP     #2000,2(A0)                            
        BLT     modEsc                                 
        SUB     #2000,2(A0)                            
                                                       
        modEsc:                                        
        RTS

        b_lleno:
            MOVE.L  #-1,D0
            RTS
        
*******************************************************************************
        
    LINEA:        
        * Selección de buffer
        ASL.L   #2,D0       * D0 * 4 -> D0
        MOVE.L  #V,A0       * V -> A0
        MOVE.L  (A0,D0),A0  * M(V+D0*4) -> A0

        *Comprobación de buffer vacío
        CMP     #0,4(A0)
        BEQ     vacLin
        MOVE    (A0),D1
        
        *Inicializamos D0,D1,D2
        MOVE.L  #0,D0         * D0 = contador de caraacteres
        * MOVE    SR,D7                                  * Sección crítica
        * MOVE    #$2700,SR                              *
        MOVE    (A0),D1       * D1 = puntero. Inicializado a inicio
        MOVE    2(A0),D2      * D2 = fin
       
        bucLin:
		    CMP     D1,D2    * Si se ha llegado al final, significa que no se ha encontrado linea
			BEQ     vacLin   * Saltar a vacLin

            ADD     #1,D0

            CMP.B   #$0d,8(A0,D1)     * Si se ha encontrado salto de línea
            BEQ     encLin            * Saltar a encLin

            ADD     #1,D1    * Avanzar puntero

            CMP     #2000,D1 * puntero = puntero % 2000
            BLT     modLin   * puntero = puntero % 2000
            MOVE    #0,D1    * puntero = puntero % 2000

            modLin:
            BRA     bucLin


        encLin:
            BRA     endLin
        
        vacLin:
            MOVE.L  #0,D0
            BRA     endLin
    
        endLin:
            RTS

*******************************************************************************

    SCAN:
        *Comprobación de parámetros
        CMP.L  #0,4(A7)
        BLT    errScan     * Si Buffer < 0, error
        CMP.W  #0,8(A7)
        BLT    errScan     * Si Descriptor < 0, error
        CMP.W  #1,8(A7)
        BGT    errScan     * Si Descriptor > 1, error
        CMP    #0,10(A7)
        BLT    errScan     * Si Tamaño < 0, error
        
        *Llamamos a línea
        MOVE.L #0,D0
        MOVE   8(A7),D0
        BSR    LINEA

        *Comprobamos si es una linea de tamaño valido
        MOVE     10(A7),D4
        CMP      #0,D0
        BEQ      vacScan     * Si D0 = 0, salir
        CMP      10(A7),D0
        BGT      vacScan     * Si D0 > Tamaño, salir
        MOVE.L   #0,D3
        MOVE     D0,D2
        bucScan:
            *Llamamos a LEECAR
            MOVE    8(A7),D0
            BSR     LEECAR
            MOVE.L  4(A7),A2
            MOVE.B  D0,(A2,D3)
            ADD     #1,D3
            CMP     D3,D2
            BNE     bucScan
        MOVE    D2,D0
        RTS

        errScan:
            MOVE.L #-1,D0
            RTS

        vacScan:
            MOVE #0,D0
            RTS

*******************************************************************************

    PRINT:
        *Comprobación de párametros
        CMP.L  #0,4(A7)
        BLT    errPrint      * Si Buffer < 0, error
        CMP    #0,8(A7)
        BLT    errPrint      * Si Descriptor < 0, error
        CMP    #1,8(A7)
        BGT    errPrint      * Si Descriptor > 1, error
        CMP    #0,10(A7)
        BLT    errPrint      * Si Tamaño < 0, error

        MOVE   #0,D3
        bucPrint:
            CMP    10(A7),D3
            BEQ    buc2Print
            *Llamamos a ESCCAR
            MOVE.L 4(A7),A2
            MOVE.B (A2,D3),D1
            MOVE   8(A7),D0
            ADD    #2,D0
            BSR    ESCCAR
            ADD    #1,D3
            BRA    bucPrint
        buc2Print:

        *Llamamos a LINEA
        MOVE    8(A7),D0
        ADD     #2,D0
        BSR     LINEA
        
        *Si hay linea se permiten transmisiones
        CMP     #0,D0
        BLE     noLinPrint
        MOVE    8(A7),D4
        MULU    #4,D4
        BSET    D4,IMRCOPY
        MOVE.B  IMRCOPY,IMR


        noLinPrint:
            MOVE    D3,D0
            RTS

        errPrint:
            MOVE.L #-1,D0
            RTS

*******************************************************************************
    RTI:
        MOVE.L  A0,-(A7)
        MOVE.L  A1,-(A7)
        MOVE.L  A2,-(A7)
        MOVE.L  A3,-(A7)
        MOVE.L  A4,-(A7)
        MOVE.L  A5,-(A7)
        MOVE.L  A6,-(A7)
        MOVE.L  D0,-(A7)
        MOVE.L  D1,-(A7)
        MOVE.L  D2,-(A7)
        MOVE.L  D3,-(A7)
        MOVE.L  D4,-(A7)
        MOVE.L  D5,-(A7)
        MOVE.L  D6,-(A7)
        MOVE.L  D7,-(A7)


        * Identificar fuente de interrupción
        MOVE.B  ISR,D5
        AND.B   IMRCOPY,D5

        BTST    #1,D5
        BNE     rA_RTI
        BTST    #5,D5
        BNE     rB_RTI

        BTST    #0,D5
        BNE     tA_RTI
        BTST    #4,D5
        BNE     tB_RTI

        rA_RTI:
            MOVE   #0,D0
            MOVE.B RBA,D1
            BRA    recRTI

        rB_RTI:
            MOVE   #1,D0
            MOVE.B RBB,D1
            BRA    recRTI

        recRTI:
            BSR    ESCCAR
            BRA    endRTI

        tA_RTI:
            MOVE.L #V,A2     * A2 = V
            MOVE.L 8(A2),A2  * A2 = M(V+4*2)

            CMP    #1,6(A2)
            BNE    tA_no10_RTI   * Si VARIABLEUNIVERSAL = 0, no enviar #10
            
            * Enviar #10 por línea de transmision A
            MOVE.B #10,TBA
            MOVE   #0,6(A2)
            
            * Comprobar si hay más líneas
            MOVE.L #2,D0
            BSR    LINEA

            CMP    #0,D0
            BNE    endRTI      * Si LINEA no retorna 0, hay líneas, no inhibir
            BCLR   #0,IMRCOPY
            MOVE.B IMRCOPY,IMR
            BRA    endRTI

            * No enviar #10 por línea de transmision A
            tA_no10_RTI:
                MOVE   #2,D0
                BSR    LEECAR
                MOVE.B D0,TBA
                CMP    #13,D0
                BNE    endRTI
                MOVE   #1,6(A2) *
                BRA    endRTI




        tB_RTI:
            MOVE.L #V,A2       * A2 = V
            MOVE.L 12(A2),A2   * A2 = M(V+4*3)

            CMP    #1,6(A2)
            BNE    tB_no10_RTI * Si VARIABLEUNIVERSAL = 0, no enviar #10
            
            * Enviar #10 por línea de transmision B
            MOVE.B #10,TBB
            MOVE   #0,6(A2)

            * Comprobar si hay más líneas
            MOVE.L #3,D0
            BSR    LINEA

            CMP    #0,D0
            BNE    endRTI      * Si LINEA no retorna 0, hay líneas, no inhibir

            BCLR   #4,IMRCOPY
            MOVE.B IMRCOPY,IMR
            BRA    endRTI

            * No enviar #10 por línea de transmision B
            tB_no10_RTI:
                MOVE   #3,D0   * Leer del Buffer Interno #3 (transmisión B)
                BSR    LEECAR
                MOVE.B D0,TBB  * D0 -> TBB. Transmitir
                CMP    #13,D0  * Si D0=13, VARIABLEUNIVERSAL = 1
                BNE    endRTI
                MOVE   #1,6(A2)
                BRA    endRTI
            
        endRTI:
            MOVE.L  (A7)+,D7
            MOVE.L  (A7)+,D6
            MOVE.L  (A7)+,D5
            MOVE.L  (A7)+,D4
            MOVE.L  (A7)+,D3
            MOVE.L  (A7)+,D2
            MOVE.L  (A7)+,D1
            MOVE.L  (A7)+,D0
            MOVE.L  (A7)+,A6
            MOVE.L  (A7)+,A5
            MOVE.L  (A7)+,A4
            MOVE.L  (A7)+,A3
            MOVE.L  (A7)+,A2
            MOVE.L  (A7)+,A1
            MOVE.L  (A7)+,A0

            RTE

*******************************************************************************
*   REGIÓN DE VARIABLES GLOBALES
********************************************************************************
    V:      DC.L   0,0,0,0
    IMRCOPY:DC.B   0

********************************************************************************
*   REGIÓN DE HEAP
********************************************************************************
    ORG     $1000

*
    V0:     DC.W   0,0,0,0
            DS.B   TAMANYO
    V1:     DC.W   0,0,0,0
            DS.B   TAMANYO
    V2:     DC.W   0,0,0,0
            DS.B   TAMANYO
    V3:     DC.W   0,0,0,0
            DS.B   TAMANYO

********************************************************************************
*   REGIÓN DE PRUEBAS
********************************************************************************
    ORG     $4000

BUFFER: DS.B    2100   * Buffer para escritura y lectura de caracteres
CONTL:  DC.W    0      * Contador de lineas
CONTC:  DC.W    0      * Contador de caracteres
DIRLEC: DC.L    0      * Direccion de lectura para SCAN
DIRESC: DC.L    0      * Direccion de lectura para PRINT
TAME:   DC.L    0      * Tamano de escritura para print
DESA:   EQU     0      * Descriptor linea A
DESB:   EQU     1      * Descriptor linea B

NLIN:   EQU     15     * Numero de lineas a leer
TAML:   EQU     100    * Tamano de linea para SCAN
TAMB:   EQU     5      * Tamano de bloque para PRINT
    
    
INICIO: * Manejadores de excepciones
    MOVE.L  #BUS_ERROR,8     * Bus error handler
    MOVE.L  #ADDRESS_ER,12   * Address error handler
    MOVE.L  #ILLEGAL_IN,16   * Illegal instruction handler
    MOVE.L  #PRIV_VIOLT,32   * Privilege Violation handler

    BSR     INIT
    MOVE.W  #$2000,SR        * Permite interrupciones

BUCPR:
    MOVE.W  #0,CONTC         * Inicializa contador de caracteres
    MOVE.W  #NLIN,CONTL      * Inicializa contador de lineas
    MOVE.L  #BUFFER,DIRLEC   * Direccion de lectura = comienzo del buffer

OTRAL:
    MOVE.W  #TAML,-(A7)      * Tamano maximo de la linea
    MOVE.W  #DESB,-(A7)      * Puerto A
    MOVE.L  DIRLEC,-(A7)     * Direccion de lectura

ESPL:
    BSR     SCAN
    CMP.L   #0,D0
    BEQ     ESPL             * Si no se ha leido la linea, se intenta de nuevo
    ADD.L   #8,A7            * Reestablece la pila
    ADD.L   D0,DIRLEC        * Calcula la nueva direccion de lectura
    ADD.W   D0,CONTC         * Actualiza el contador de caracteres

    SUB.W   #1,CONTL         * Actualiza el numero de lineas leidas.
    BNE     OTRAL            * Si no se han leido todas, se vuelve a leer

    MOVE.L  #BUFFER,DIRLEC   * DIreccion de lectura = comienzo del buffer

OTRAE:
    MOVE.W  #TAMB,TAME       * Tamano de escritura = tamano de bloque

ESPE:
    MOVE.W  TAME,-(A7)       * Tamano de escritura
        MOVE.W  #DESA,-(A7)      * Puerto B
        MOVE.L  DIRLEC,-(A7)     * Direccion de lectura
    * BREAK
    BSR     PRINT
    ADD.L   #8,A7            * Reestablece la pila
    ADD.L   D0,DIRLEC        * Calcula la nueva direccion del buffer
    SUB.W   D0,CONTC         * Actualiza el contador de caracteres
    BEQ     SALIR            * Si no quedan caracteres, se acaba
    SUB.W   D0,TAME          * Actualiza el tamano de escritura
    BNE     ESPE             * Si no se ha escrito todo el bloque, se insiste
    CMP.W   #TAMB,CONTC      * Si el numero de caracteres restantes es menor que el establecido, se transmite ese numero
    BHI     OTRAE            * Siguiente bloque
    MOVE.W  CONTC,TAME
    BRA     ESPE             * Siguiente bloque

SALIR:
    BRA     BUCPR

FIN:
    BREAK

BUS_ERROR:
    BREAK                    * Bus error handler
    NOP

ADDRESS_ER:
    BREAK                    * Address error handler
    NOP

ILLEGAL_IN:
    BREAK                    * Illegal instruction handler
    NOP

PRIV_VIOLT:
    BREAK                    * Priviledge violation handler
    NOP
