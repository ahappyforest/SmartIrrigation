#include "Sensor.h"

configuration SensorAppC {
}
implementation {
	components MainC, SensorC as App;
	components LedsC;
	components new TimerMilliC() as SensorTimer;

	App.Boot -> MainC;
	App.Leds -> LedsC;
	App.SensorTimer -> SensorTimer;
	
	// **********************************************************
	// ctp protocol wiring
	// **********************************************************
	components new CollectionSenderC(AM_SENSOR_MSG) as CtpSensorSender;
	components new CollectionSenderC(AM_REPLY_MSG)  as CtpReplySender;
	components ActiveMessageC as Radio;
	components CollectionC;

	App.SensorSend -> CtpSensorSender;
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
	// 各种传感器
	//   1. DS18B20        //  土壤温度传感器
	//   2. YL69Humidity   //  土壤湿度传感器
	//   3. Temp           //  空气温度传感器
	//   4. Photo          //  光照传感器
	//   5. SolenoidValves //  电磁阀门

	components DS18b20C;
	App.DS18B20Switch -> DS18b20C;
	App.DS18B20R   -> DS18b20C;

	components YL69HumidityC;
	App.HumiditySwitch -> YL69HumidityC;
	App.Humidity -> YL69HumidityC;

	components new TempC();
	App.Temp -> TempC;
	
	components new PhotoC();
	App.Light -> PhotoC;
	
	components SolenoidValvesC as SV;
	App.SVSwitch -> SV;
#ifdef USING_MIC
	components IrMicC;
	App.Microphone -> IrMicC;
	App.MicControl -> IrMicC;
#endif

	// 远程烧写
	components DelugeC;

	// 远程PrintfC
	components PrintfC;
	App.PrintfControl -> PrintfC;
}
