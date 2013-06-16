#include "waterpump.h"
#define NEW_PRINTF_SEMANTICS
#include "printf.h"


configuration WaterPumpAppC {
}
implementation {
	components MainC, WaterPumpC as App;
	components LedsC;

	App.Boot -> MainC;
	App.Leds -> LedsC;

	// Ctp用来发送回应的， 没有receive, 接收走的是分发协议
	// **********************************************************
	// ctp protocol wiring
	// **********************************************************
	components new CollectionSenderC(AM_SENSOR_MSG) as CtpSensorSender;
	components new CollectionSenderC(AM_REPLY_MSG)  as CtpReplySender;
	components ActiveMessageC as Radio;
	components CollectionC;

	App.ReplySend  -> CtpReplySender;
	App.CtpPacket  -> CollectionC;

	App.RadioControl -> Radio;
	App.CtpControl -> CollectionC;

	// ************************************************
	// dissemination protocol
	// ************************************************
	components new DisseminatorC(request_msg_t, DISSEMINATE_REQ_KEY);
	components DisseminationC;

	App.ReqValue -> DisseminatorC;
	App.DripControl -> DisseminationC;

	// *********************************************************
	// 水泵
	components MicaBusC;
	App.WaterPumpPower -> MicaBusC.Int0;
		
	components PrintfC, SerialStartC;
}
