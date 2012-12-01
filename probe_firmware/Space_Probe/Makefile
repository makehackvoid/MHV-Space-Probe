BOARD_TAG    = uno
ARDUINO_PORT = /dev/ttyACM3

ARDUINO_DIR   = /usr/share/arduino
ARDMK_DIR     = /usr
AVR_TOOLS_DIR = /usr

ARDUINO_LIBS = SPI Ethernet Ethernet/utility SD TinyWebServer EthernetDHCP EthernetDHCP/utility Flash
#ARDUINO_USER_LIBS = TinyWebServer EthernetDHCP Flash
#USER_LIBS     = $(patsubst %,$(USER_LIB_PATH)/%,$(ARDUINO_USER_LIBS))

CFLAGS += -Wno-deprecated-declarations -D__PROG_TYPES_COMPAT__

include /usr/share/arduino/Arduino.mk
