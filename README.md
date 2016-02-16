B1;3409;0c#Crazyflie 2.0 Firmware

This project contains the original source code for the Crazyflie 2.0 firmware with a rewritten part in SPARK 2014.
More information can be found on the
[Bitcraze wiki](http://wiki.bitcraze.se/projects:crazyflie2:index)
and
[AdaCore Blog post](http://blog.adacore.com/how-to-prevent-drone-crashes-using-spark)

####Folder description
#####C Code
```
./              | Root, contains the Makefile
 + init         | Contains the main.c
 + config       | Configuration files
 + drivers      | Hardware driver layer
 |  + src       | Drivers source code
 |  + interface | Drivers header files. Interface to the HAL layer
 + hal          | Hardware abstaction layer
 |  + src       | HAL source code
 |  + interface | HAL header files. Interface with the other parts of the program
 + modules      | Firmware operating code and headers
 |  + src       | Firmware tasks source code and main.c
 |  + interface | Operating headers. Configure the firmware environement
 + utils        | Utils code. Implement utility block like the console.
 |  + src       | Utils source code
 |  + interface | Utils header files. Interface with the other parts of the program
 + platform     | Platform specific files. Not really used yet
 + scripts      | Misc. scripts for LD, OpenOCD, make, version control, ...
 |              | *** The two following folders contains the unmodified files ***
 + lib          | Libraries
 |  + FreeRTOS  | Source FreeRTOS folder. Cleaned up from the useless files
 |  + STM32...  | Library folders of the ST STM32 peripheral libs
 |  + CMSIS     | Core abstraction layer

##### SPARK code
```
 + ada_spark       | Contains the parts that have been reimplemented in SPARK
 |  . cf_spark.gpr | The .gpr project file used to build the firmware part written in SPARK
 |  + config       | Configuration files
 |  + drivers      | SPARK interface for the C drivers
 |  + hal          | SPARK interface for the HAL
 |  + lib          | SPARK interface for external libs (e.g: FreeRTOS)
 |  + modules      | Contains the rewritten modules in SPARK (e.g: Stabilization system)
 |  + types        | Contains type definitions that is common to the whole SPARK code
 |  + utils        | Contains utility packages used by the modules rewritten in SPARK
```
####Make targets
```
all        : Shortcut for build
compile    : Compile cflie.hex. WARNING: Do NOT update version.c
build      : Update version.c and compile cflie.elf/hex
clean_o    : Clean only the Objects files, keep the executables (ie .elf, .hex)
clean      : Clean every compiled files
mrproper   : Clean every compiled files and the classical editors backup files

cload      : If the crazyflie-clients-python is placed on the same directory level and the Crazyradio/Crazyradio PA
             is inserted it will try to flash the firmware using the wireless bootloader.
flash      : Flash cflie.elf using OpenOCD
halt       : Halt the target using OpenOCD
reset      : Reset the target using OpenOCD
openocd    : Launch OpenOCD
```
