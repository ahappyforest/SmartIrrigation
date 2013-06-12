COMPONENT=SensorAppC
SENSORBOARD=mts300
BOOTLOADER=tosboot

CFLAGS += -DMTS300CB
CFLAGS += -I../
CFLAGS += -I$(TOSDIR)/lib/net -I$(TOSDIR)/lib/net/drip
CFLAGS += -I$(TOSDIR)/lib/net/ctp
CFLAGS += -I$(TOSDIR)/lib/net/le
CFLAGS += -I./lib

CFLAGS += -DUSING_MIC
CFLAGS += -lm


include $(MAKERULES)
