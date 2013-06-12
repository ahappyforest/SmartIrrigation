COMPONENT=RootAppC
BOOTLOADER=tosboot


CFLAGS += -I../
CFLAGS += -I$(TOSDIR)/lib/net -I$(TOSDIR)/lib/net/drip
CFLAGS += -I$(TOSDIR)/lib/net/ctp
CFLAGS += -I$(TOSDIR)/lib/net/le
CFLAGS += -DDELUGE_BASESTATION
CFLAGS += -I./lib

BUILD_EXTRA_DEPS = sensor_msg.py reply_msg.py request_msg.py

sensor_msg.py: ../SmartIrrigation.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=sensor_msg ../SmartIrrigation.h sensor_msg -o sensor_msg.py
reply_msg.py: ../SmartIrrigation.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=reply_msg ../SmartIrrigation.h reply_msg -o reply_msg.py
request_msg.py: ../SmartIrrigation.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=request_msg ../SmartIrrigation.h request_msg -o request_msg.py


include $(MAKERULES)
