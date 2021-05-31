# 2.4GHz Slim Tx remix for t-lite without bay

thanks for the original disign

### PCB manufacturing

Upload the Gerber file to https://jlcpcb.com/RAT.  Check the price for 5, 10, and 30 pieces.  It is sometimes cheaper to order 30 than 10 and only a minor increase in price compared to 5.

*PCB Thickness: 1mm*

### BOM

- E28-2G4M27S SX1280 Wireless module 2.4G 27dBm https://www.aliexpress.com/item/33004335921.html
- 3.3V DC-DC Step Up/Down Power Supply https://www.pololu.com/product/2873
found it there  https://easyeda.com/jyesmith/expresslrs-jumper-t-lite
- 10k 0805 resistor https://www.aliexpress.com/item/4000049692396.html
- SMA or RPSMA connector https://www.aliexpress.com/item/4000848776660.html https://www.aliexpress.com/item/4000848776660.html
- WROOM32 module https://www.aliexpress.com/item/ESP32-ESP-32S-WIFI-Bluetooth-Module-240MHz-Dual-Core-CPU-MCU-Wireless-Network-Board-ESP-WROOM/4000230070560.html
- 10uF 3528 Cap https://www.aliexpress.com/item/32666405364.html?algo_pvid=365ae59d-9e6c-46b7-9792-2656b0961f70&algo_expid=365ae59d-9e6c-46b7-9792-2656b0961f70-6&btsid=0bb0623116027669252885518ea610&ws_ab_test=searchweb0_0,searchweb201602_,searchweb201603_
- 4x 12mm M2 screws

### Build order

- Solder the e28 module.  Dont forget to change the zero ohm resistor near the ufl.  Default is to use the PCB antenna, it must be repositioned to use the ufl.
- Solder the WROOM32 module
- Solder the 2x 10k resistors
- Solder the capacitor
- Solder the 3.3V DC-DC Step Up/Down Power Supply 
This is a diffrent to the orginal PCB design

<img src="img/DC.jpg" width="30%">

- Apply tape to the base of the regulator pcb to insulate it from potentially shorting with the vias on the main pcb. Solder on a 4 pin straight header and then to the PCB.
- Solder 3x silicon wires to the 3 pin header pads (G, V, S), use the wires and the conector from the orignal bay mounted like here.
- Picture 2. show Jye internal modul but wiring is the same.

<img src="img/wire.jpg" width="30%"> <img src="img/wire2.jpg" width="30%">


    
### STLs

- use the t-lite STL

### Build Pics

<img src="img/PCB.jpg" width="30%"> <img src="img/print.png" width="30%"> <img src="img/t-lite.jpg" width="30%">

### Schematic and PCB layout

<img src="img/schm.png" width="30%">
<img src="img/pcb.png" width="30%">

### Flashing 

- Connect an FTDI to the GND, 3v3, TX and RX pins on the left header, then hold the boot pin to ground while powering up, and flash the DIY_2400_TX_ESP32_SX1280_E28_via_UART build in pio

<img src="img/ftdi-wiring.png" width="30%">

