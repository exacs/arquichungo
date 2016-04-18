
[TOC]

# Consideraciones generales

El espacio de memoria permitido, es decir, direcciones `0x400` a `0x8000` se va a gestionar del siguiente modo:

* Direcciones bajas `0x400` a `0x440`. Variables locales
* Direcciones bajas desde la `0x440` y en orden creciente: subrutinas del programa
* Direcciones medias: desde la `0x2000` y en orden creciente: heap de memoria o memory pool
* Direcciones altas: desde la `0x8000` y de manera decreciente: pila

# Buffer

## Concepto

En este proyecto se ha utilizado la estructura de datos **buffer circular FIFO**. La interfaz necesaria en nuestro caso consiste en una función "introducir" que inserta un elemento al final del buffer y otra función "extraer" que elimina el elemento situado al inicio del buffer. Adicionalmente, se implementa una función que sirve para recorrer el buffer hasta encontrar un retorno de carro.

Dadas las características del buffer, la implementación del buffer circular utilizará un array y dos campos que almacenarán el *inicio* y la *longitud utilizada* del buffer respectivamente.

Por tanto requeriremos de:

* Un **array** que contendrá los datos, en nuestro caso, caracteres.
* Un campo **inicio** que contendrá un entero que marcará en qué posición del array se encuentra el inicio real del buffer (posición del primer carácter del buffer)
* Un campo **fin** que contendrá un entero que marcará en qué posición del array se encuentra el final real del buffer (posición del último carácter insertado)
* Un campo **tamaño** que contendrá un entero que indica el número de caracteres contenidos en el buffer.
* Podría haberse incluido como parte de la estructura un campo **tamaño máximo** para almacenar el tamaño máximo de cada buffer. Sin embargo, como todos los buffers usados en este proyecto son del mismo tamaño, se ha considerado que este campo es innecesario.

Nótese que el campo "tamaño" es redundante, puesto que se puede deducir a partir de inicio y fin. Sin embargo, se ha decidido incluirlo para evitar secciones críticas grandes en las subrutinas LEECAR, ESCCAR y LINEA. Véase el epígrafe "Estudio de concurrencia" para más detalles.

## Ubicación de memoria

Supongamos que existe un buffer cuya dirección de inicio es `BUFF` y cuyo tamaño es `n`.

* Los bytes `BUFF` e `BUFF+1` servirán para almacenar el campo **inicio**.
* Los bytes `BUFF+2` e `BUFF+3` servirán para almacenar el campo **fin**.
* Los bytes `BUFF+4` e `BUFF+5` servirán para almacenar el campo **tamaño**.
* Los bytes `BUFF+6` e `BUFF+7` servirán para almacenar **flags**, es decir, otras variables internas del buffer.
* Los bytes entre `BUFF+8` y `BUFF+8+n` servirán para almacenar el **array** con los datos del buffer (un dato por byte).

## Vector de buffers

En las subrutinas **LEECAR** y **ESCCAR**, se pasa como parámetro un número del 0 al 3 que indica el Buffer que se está seleccionando.

Por tanto, parece conveniente tener un vector de buffers con la ventaja de poder añadir más buffers.

El vector de buffers, en memoria, almacena las direcciones de inicio de los buffers. En este caso se almacena la dirección absoluta.

Por tanto, tendremos un vector de buffers, en la dirección **V_BUFFER** que contiene las direcciones de inicio de los buffer. Usamos las siguientes pseudoinstrucciones:

En el heap de memoria:

```
    ORG $2000

* Buffers Internos
BUFI_0:   DC.B   0,0      * Campos inicio y longitud en uso
          DS.B   TAM_BUFI * Array con el buffer
BUFI_1:   DC.B   0,0      * Campos inicio y longitud en uso
          DS.B   TAM_BUFI * Array con el buffer
BUFI_2:   DC.B   0,0      * Campos inicio y longitud en uso
          DS.B   TAM_BUFI * Array con el buffer
BUFI_3:   DC.B   0,0      * Campos inicio y longitud en uso
          DS.B   TAM_BUFI * Array con el buffer

```

Y en el área de variables globales

```
    ORG $400

* Vector de buffers.
* Contiene las direcciones de inicio de las estructuras buffer

V_BUFFER: DC.L   0,0,0,0
```

Para realizar operaciones sobre el buffer `i` (siendo `i` un número entre 0 y 3) se debe leer el dato contenido en `V_BUFFER + i*4`. Dicho dato es la dirección del buffer `i`. A partir de esta última dirección leída, se encuentran las variables del buffer anteriormente mencionadas.

## Subrutinas

### Inicialización.

De la inicialización del vector `V_BUFFER`, es decir, introducir en él las direcciones correctas de cada buffer interno, se encarga la subrutina `INIT`.

## Operaciones sobre los buffers internos

### Lectura del buffer. LEECAR

Esta subrutina lee el primer carácter del buffer seleccionado y lo retorna en `D0`. Para ello:

1. Comprobar que el buffer no está vacío, es decir, que **tamaño** no sea 0. Si está vacío, copiamos en `D0` el valor `-1` y salimos de la subrutina.
2. Copiar en `D0` el primer carácter que está en la posición **inicio**
3. Aumentar **inicio** en una unidad. Hallamos su módulo 2000 si es necesario.
4. Decrementar **tamaño** en una unidad.

El paso 4 puede ocasionar condiciones de carrera.

### Escritura en el buffer. ESCCAR

Esta subrutina escribe el carácter contenido en `D1` en el buffer seleccionado. 

1. Se comprueba que el buffer no está lleno, es decir, que  **tamaño**  no supere  2000. En el caso de que esté lleno, copiamos en `D0` el valor `-1` y salimos de la subrutina.
2. Copiar en buffer el carácter contenido en `D1`. Para ello, introducimos el carácter en la posición del buffer correspondiente,   **fin**.
3. Aumentamos **fin** en una unidad. Hallamos su módulo 2000 si es necesario.
4. Incrementar **tamaño** en una unidad.
5. Copiar en `D0` un 0, como valor de éxito de la subrutina.

El paso 4 puede ocasionar condiciones de carrera.

### Información del buffer. LINEA

Está subrutina indica si hay una línea en el buffer seleccionado.

1. Comprobar que el buffer no está vacío. Si está vacío, copiamos en `D0` el valor `-1` y salimos de la subrutina.
2. Realizar un bucle con un puntero que va de **inicio** a **fin**.
3. Si se encuentra línea se devuelve en `D0` el tamaño de esta.

En este caso, la salida del bucle del paso 2, es que el puntero sea igual o mayor que **fin**. Dado que, **fin** solamente se incrementa en las otras subrutinas, la lectura de esta variable en LINEA, no ocasiona problemas de concurrencia.

# Print+RTI. Escritura de un mensaje por una línea

Cuando el programa llama a la subrutina PRINT, el resultado final debe ser que por una de las dos líneas aparezca un mensaje.

Esto se realiza mediante la coordinación de las subrutinas PRINT y RTI.

Por un lado, PRINT actúa del siguiente modo:

1. Se copia el mensaje correspondiente en el buffer interno de transmisión A o B. Para ello se llama a la subrutina ESCCAR por cada carácter del mensaje
2. Se retorna la longitud del mensaje por D0
3. Se decide si se permiten las interrupciones o no. Si existe un carácter "\r" en el buffer interno de transmisión A o B, permitir las interrupciones de transmisión de dicha línea. En caso contrario, PRINT no inhibe las interrupciones porque puede ser que se siga transmitiendo. La responsabilidad de inhibir la interrupción recae sobre RTI.
4. La subrutina PRINT no se encarga de nada más.

Paralelamente a lo anterior, la subrutina RTI puede estar tratando interrupciones de transmisión. Si es el caso, se debe proceder del siguiente modo:

1. Verificar si hay que transmitir una "\n". Para saber si se ha de transmitir dicho carácter, se consulta el **flag** del buffer correspondiente, que tendrá un 1 si se debe transmitir dicho carácter. En caso afirmativo, transmitir "\n", inhibir la transmisión en dicha línea y poner un 0 en el **flag**. En caso negativo, continuar. 
2. Extraer el primer carácter del buffer interno de transmisión del dispositivo que ha solicitado la interrupción.
3. Verificar si es un "\r". En caso afirmativo, indicar que la siguiente transmisión debe ser el carácter "\n" y continuar. Esta indicación se realiza poniendo un 1 en el **flag** del buffer correspondiente. En caso negativo, continuar.
4. Copiar el carácter extraido al buffer de transmisión de la línea correspondiente.

# Scan. Lectura de un mensaje.
Cuando el programa llama a SCAN comprueba si el buffer interno de recepción contiene un salto de línea llmando a LINEA. Si esto se cumple se copia el contenido a una dirección de memoria. SCAN es independiente de RTI.

# Estudio de Concurrencia
Para reducir al mínimo posible las secciones críticas del programa, se usan las variables **inicio**, **fin** y **tamaño** de cada uno de los buffers internos. Estas variables se usan de la siguiente manera:

* **inicio**. LEECAR la incrementa. LINEA la lee una vez al principio.
* **fin**. ESCCAR la incrementa. LINEA la lee para saber el final del recorrido.
* **tamaño**. LEECAR y ESCCAR la incrementan y decrementan respectivamente. Esto si puede provocar condiciones de carrera, por lo que la manipulación de esta variable es sección crítica.

### Prueba de concurrencia

Mediante esta prueba queremos comprobar que efectivamente `PRINT` tiene un comportamiento no bloqueante y que la rutina de tratamiento de la interrupción guarda correctamente los valores de los registros. 

En primer lugar se realiza un print de un mensaje que forma una línea (`Hola Mundo\r`).

```
* Programa de prueba

PRUE01:
    BSR INIT
    
    * Llamada a PRINT
    MOVE.W  #11,-(A7)        * Tamaño
    MOVE.W  #0,-(A7)         * Descriptor
    MOVE.L  #MSG1,-(A7)      * Buffer
    BSR     PRINT


* Heap de memoria

    ORG $2000
    MSG1: DC.B 'Hola Mundo, adios mundo, que tal mundo, hola datsi, adios datsi. Hola ensamblador, adios ensamblador. Hola proyecto, adios proyecto -!=__ueueue',13
```

Para probar el paralelismo de la ejecución con el periférico, utilizamos un bucle infinito en el programa principal hasta que termine la escritura, es decir, hasta que las interrupciones de transmisión estén inhibidas.

```
* Programa de prueba

PRUE01:
    BSR INIT
    
    * Llamada a PRINT
    MOVE.W  #144,-(A7)       * Tamaño
    MOVE.W  #0,-(A7)         * Descriptor
    MOVE.L  #MSG1,-(A7)      * Buffer
    BSR     PRINT

	* Bucle infinito
	MOVE.L  #0,D0
	MOVE.L  #0,D1
	MOVE.L  #0,D2
	MOVE.L  #0,D3
	MOVE.L  #0,D4
	MOVE.L  #0,D5
	MOVE.L  #0,D6

	PRUE01_B:
		ADD.L  #1,D0
		ADD.L  #1,D1
		ADD.L  #1,D2
		ADD.L  #1,D3
		ADD.L  #1,D4
		ADD.L  #1,D5
		ADD.L  #1,D6
		BTST   #0,IMRCOPY
		BNE    PRUE01_B
	
	BREAK
```

Cuando la ejecución llegue a `BREAK`, los registros D0 a D6 deben tener los mismos valores y ser distintos de 0.

### Prueba 2. Print de una línea dividida en varios mensajes

Estas son las conclusiones tras sucesivas ejecuciones de esta prueba:

1. En todas las ejecuciones, los registros tienen los mismos valores. Es decir, las pruebas acaban con éxito

2. Los registros terminan teniendo valores diferentes en una y otra ejecución. Esto hace patente el carácter impredecible del periférico.

3. Los valores finales de los registros que se han observado rondan el $2000$ en base 10. Teniendo en cuenta que se transmiten 144 caracteres y que en el bucle hay 7 instrucciones:

   $${{2000 \times 7} \over {144}} =  97,22$$

   Se ejecutan unas 97 instrucciones entre una interrupción y otra.

A continuación se muestra una variación de la prueba anterior en la que se simula una ejecución mientras que las dos líneas transmiten algo:

```
PRUE01:
    BSR INIT
    
    * Llamada a PRINT
    MOVE.W  #144,-(A7)       * Tamaño
    MOVE.W  #0,-(A7)         * Descriptor
    MOVE.L  #MSG1,-(A7)      * Buffer
    BSR     PRINT
    ADD.L   #8,A7

    * Llamada a PRINT
    MOVE.W  #144,-(A7)       * Tamaño
    MOVE.W  #1,-(A7)         * Descriptor
    MOVE.L  #MSG1,-(A7)      * Buffer
    BSR     PRINT
    ADD.L   #8,A7

    * Bucle infinito
    MOVE.L  #0,D0
    MOVE.L  #0,D1
    MOVE.L  #0,D2
    MOVE.L  #0,D3
    MOVE.L  #0,D4
    MOVE.L  #0,D5
    MOVE.L  #0,D6

    PRUE01_B:
        ADD.L  #1,D0
        ADD.L  #1,D1
        ADD.L  #1,D2
        ADD.L  #1,D3
        ADD.L  #1,D4
        ADD.L  #1,D5
        ADD.L  #1,D6
        CMP.B  #%00100010,IMRCOPY
        BNE    PRUE01_B
    
    BREAK
```

### Prueba de impresión de una línea en múltiples llamadas

En la siguiente prueba se llama a la subrutina PRINT 61 veces. El salto de línea solo se transmite en la última llamada.

Debe aparecer por las líneas A y B las cadenas "12345678900987654321 " repetidas 20 veces en una sola línea.

```
* Programa de prueba

PRUE02:
    BSR INIT
    
    * Llamada a PRINT
    MOVE.W  #4,-(A7)        * Tamaño
    MOVE.W  #0,-(A7)        * Descriptor
    MOVE.L  #MSG2a,-(A7)    * Buffer
    BSR     PRINT

    MOVE.W  #6,-(A7)        * Tamaño
    MOVE.W  #0,-(A7)        * Descriptor
    MOVE.L  #MSG2b,-(A7)    * Buffer
    BSR     PRINT

    MOVE.W  #1,-(A7)        * Tamaño
    MOVE.W  #0,-(A7)        * Descriptor
    MOVE.L  #MSG2c,-(A7)    * Buffer
    BSR     PRINT
    * Mismo bucle infinito que en la anterior prueba
    * ...
    BREAK

* Heap de memoria

    ORG $2000
    MSG2a: DC.B '1234567890'
    MSG2b: DC.B '0987654321'
    MSG2c: DC.B ' '
    MSG2d: DC.B 13
```

### Prueba 3. Print de varias líneas de varias líneas de texto

En esta prueba se llama a la subrutina PRINT 7 veces. Se transmiten saltos de línea en la 3ª y 6ª llamadas a PRINT

El resultado emitido por las líneas debe ser idéntico a la anterior prueba.

En este caso se han añadido dos bucles infinitos esperando a que finalicen las transmisiones. Se han puesto intencionadamente después de las llamdadas 4ª y 7ª a PRINT, es decir, bastante después de que se hayan transmitido los saltos de línea.

```
* Programa de prueba

PRUEBA02:
    BSR INIT
    
    * Llamada a PRINT
    MOVE.W  #4,-(A7)        * Tamaño
    MOVE.W  #0,-(A7)        * Descriptor
    MOVE.L  #MSG3a,-(A7)    * Buffer
    BSR     PRINT

    MOVE.W  #6,-(A7)        * Tamaño
    MOVE.W  #0,-(A7)        * Descriptor
    MOVE.L  #MSG3b,-(A7)    * Buffer
    BSR     PRINT

    MOVE.W  #1,-(A7)        * Tamaño
    MOVE.W  #0,-(A7)        * Descriptor
    MOVE.L  #MSG3c,-(A7)    * Buffer
    BSR     PRINT

    MOVE.W  #10,-(A7)       * Tamaño
    MOVE.W  #0,-(A7)        * Descriptor
    MOVE.L  #MSG3d,-(A7)    * Buffer
    BSR     PRINT

    * Mismo bucle infinito que en la anterior prueba
    *...
    BREAK
	
    MOVE.W  #5,-(A7)        * Tamaño
    MOVE.W  #0,-(A7)        * Descriptor
    MOVE.L  #MSG3e,-(A7)    * Buffer
    BSR     PRINT

    MOVE.W  #2,-(A7)        * Tamaño
    MOVE.W  #0,-(A7)        * Descriptor
    MOVE.L  #MSG3f,-(A7)    * Buffer
    BSR     PRINT

    MOVE.W  #5,-(A7)        * Tamaño
    MOVE.W  #0,-(A7)        * Descriptor
    MOVE.L  #MSG3g,-(A7)    * Buffer
    BSR     PRINT

	* Mismo bucle infinito que en la anterior prueba
	* ...
    BREAK

* Heap de memoria

    ORG $2000
    MSG3a: DC.B 'Hola'
    MSG3b: DC.B ' Mundo'
    MSG3c: DC.B 13
    MSG3d: DC.B 'Que tal, '
    MSG3e: DC.B 'Mundo'
    MSG3f: DC.B '?',13
    MSG3g: DC.B 'Adios'
```

# Anexo 1. Iteraciones anteriores del Buffer
En un intento anterior, el buffer circular no tenía los mismos campos. De hecho, no tenía los campos **fin** ni **flags**. Esto tuvo como consecuencia secciones críticas muy grandes debido a que en la subrutina LINEA utilizaba **tamaño** para obtener el final del bucle, es decir, que dicho tamaño no podía modificarse durante todo el bucle de LINEA, ocasionando una sección crítica en todo el bucle.
