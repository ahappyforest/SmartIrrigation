COMPONENT=SensorAppC
SENSORBOARD=mts300
BOOTLOADER=tosboot

CFLAGS += -DMTS300CB
CFLAGS += -I../
CFLAGS += -I$(TOSDIR)/lib/net -I$(TOSDIR)/lib/net/drip
CFLAGS += -I$(TOSDIR)/lib/net/ctp
CFLAGS += -I$(TOSDIR)/lib/net/le
CFLAGS += -I./lib

CFLAGS += -lm

CFLAGS += -I$(TOSDIR)/lib/printf

#功能的定义
CFLAGS += -DUSING_MIC
#CFLAGS += -DUSING_REMOTE_PRINTF
CFLAGS += -DUSING_SERIAL_PRINTF


include $(MAKERULES)
