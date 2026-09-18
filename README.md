# LG IR
***Transmisor IR (modos service) para LG***

![](https://github.com/Arturrito63/LG_IR_ATtiny85/blob/main/Docs/esquema.jpg) 

### Descripción...

En este proyecto utilizo un ATtiny85-20 que tenía a mano dado que no necesito conectar más de 3 botones y un led infrarojo. En el diagrama de arriba se lo muestra alimentado con 9Vots, el cual se reduce a 5Volts mediante un regulador 78L05, pero este puede reemplazarse con un conector USB y conectarlo a una fuente o cargador de 5VDC regulados.  
Si bien el MCU puede trabajar con tensiones mas bajas, se necesita un reloj interno a 8Mhz y esto solo es posible por encima de los 4Volts.

El [Protocolo NEC](https://www.sbprojects.net/knowledge/ir/nec.php) utiliza una portadora (carrier) de 38KHhz sobre la cual se envían los pulsos de marca (inicio), dirección (addr) y datos (data).


Para obtener los 38Khz utilizo el TIMER0 en modo CTC y activo la salida OC0A en PB0. En DDRB PB0 y PB1 se configuran como salida, PB0 será una salida push-pull mientras que PB1 lo será como pull-up y esto se determina con los bits correspondientes en PORTB.  
Los bits en PORTB para los pines PB1, PB2, PB3 y PB4 se configuran en 1 (pull-up), PB1 es una salida mientras que los restantes son entradas para los pulsadores.

Al conectar el LED IR con una resistencia en serie de 330 Ohms a los pines PB0 (ánodo) y PB1 (cátodo), este solo emitirá los 38khz presentes en PB0 cuando haya un 0 lógico en PB1 (conducción del LED). Esto permite que una vez iniciado el TIMER0 y OC0A presente en PB0, el programa solo debe generar la trama de pulsos correpondientes al pulsador presionado.

*Si no se presiona ningún botón (pulsador), el programa ejecuta un Power Down y el MCU se apaga hasta que se produzca una interrupción PCINT al presionar algún botón.*

El pulsador conectado al pin PB2 envía los dos primeros bytes (addr + data) almacenados al inicio de la EEPROM, 0x0000 = addr y 0x0001 = data.  
El pulsador conectado al pin PB3 hará lo mismo con los dos siguientes bytes y asi lo hará PB4 con el tercer par de bytes.  
Los datos almacenados el el archivo "eeprom.eep" en la carpeta LG_IR\Debug contienen los tres pares de bytes para los mandos InStart, EzAdjust y PowerOnly respectivamente.  
Este archivo debe grabarse en la EEPROM del ATtiny85 junto con el archivo LG_IR.hex también el la misma carpeta que deberá grabarse en la memoria FLASH.  

Los pares de bytes son los siguientes:  
0x0000  04  
0x0001  FB  
0x0002  04  
0x0003  FF  
0x0004  04  
0x0005  EF 

### InStart
![](https://github.com/Arturrito63/LG_IR_ATtiny85/blob/main/Docs/LG_InStart.jpg)


### EzAdjust
![](https://github.com/Arturrito63/LG_IR_ATtiny85/blob/main/Docs/LG_EzAdjust.jpg)


### PowerOnly
![](https://github.com/Arturrito63/LG_IR_ATtiny85/blob/main/Docs/LG_PowerOnly.jpg)

Para los 3 casos anteriores, D2 corresponde a PB1 (cátodo) y puede verse la trama de pulsos invertidos, mientras que D3 corresponde PB0 (ánodo) y en este se puede ver la portadora de 38Khz.

Por defecto el ATtiny85 viene de fabrica funcionando a 1Mhz (oscilador interno a 8Mhz y divisor por 8 **CKDIV8** activado), esto es con **lfuse**= 0x62. Para que funcione a 8Mhz hay que desactivar **CKDIV8**, para ello debemos cambiar **lfuse** a 0xE2.

***AVRDUDESS***
![](https://github.com/Arturrito63/LG_IR_ATtiny85/blob/main/Docs/AVRDUDESS.jpg)

Si presionamos **Bit Selector** en AVRDUDESS podemos ver los **fuses** y **lock bits**

![](https://github.com/Arturrito63/LG_IR_ATtiny85/blob/main/Docs/fuses_&_look_bits.jpg)

Antes o después de programar el MCU se debe cambiar cualquier valor presente en la casilla que marca la imagen (L) por 0xE2 y presionar "Write", de esta forma ya queda funcionando a 8Mhz.

------------
***El mismo proyecto utilizando un ATtiny13***  
El circuito es exactamente el mismo, pero cambia el programa (hay que adecuarlo a un reloj de 9.6Mhz)  
[LG_IR_ATtiny13A](https://github.com/Arturrito63/LG_IR_ATtiny13A)

