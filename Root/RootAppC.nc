#include "Root.h"


configuration RootAppC {
}
implementation {
	components MainC, RootC as App;
	components LedsC;

	App.Boot -> MainC;
	App.Leds -> LedsC;
	
	// **********************************************************
	// serial wiring
	// **********************************************************
	components SerialActiveMessageC as Serial;
	components new SerialAMSenderC(AM_SENSOR_MSG)    as SerialSensorSender;
	components new SerialAMSenderC(AM_REPLY_MSG)     as SerialReplySender;
	components new SerialAMReceiverC(AM_REQUEST_MSG) as SerialAMReceiver;

	App.SerialControl    -> Serial;
	App.SerialPacket     -> SerialSensorSender;
	App.SerialSensorSend -> SerialSensorSender;
	App.SerialReplySend  -> SerialReplySender;
	App.SerialReceive    -> SerialAMReceiver.Receive;

	// **********************************************************
	// ctp protocol wiring
	// **********************************************************
	components CollectionC;
	components new CollectionSenderC(AM_SENSOR_MSG);
	components ActiveMessageC as Radio;

	App.CtpSensorReceive -> CollectionC.Receive[AM_SENSOR_MSG];
	App.CtpReplyReceive -> CollectionC.Receive [AM_REPLY_MSG];
	App.RootControl -> CollectionC;
	App.CtpControl -> CollectionC;
	App.RadioControl -> Radio;

	// ************************************************
	// dissemination protocol
	// ************************************************
	components new DisseminatorC(request_msg_t, DISSEMINATE_REQ_KEY);
	components DisseminationC;

	App.DripControl -> DisseminationC;
	App.ReqUpdate -> DisseminatorC;
	
	components DelugeC;

#define IR_QUEUESIZE 50
	components new BigQueueC(msg_data_t, IR_QUEUESIZE) as MsgQueue;
	components new TimerMilliC() as MsgCheckTimer;
	
	App.MsgQueue -> MsgQueue;
	App.MsgCheckTimer -> MsgCheckTimer;

}
