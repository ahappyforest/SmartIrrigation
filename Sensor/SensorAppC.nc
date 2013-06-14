#include "Sensor.h"

#ifdef USING_SERIAL_PRINTF
#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#endif

#define SOLENOIDVALVES_ARBITER_RESOURCE "SV.Arbiter.Resource"

configuration SensorAppC {
}
implementation {
	components MainC, SensorC as App;
	components LedsC;
	components new TimerMilliC() as DS18B20Timer;
	components new TimerMilliC() as HumiTimer;
	components new TimerMilliC() as TempTimer;
	components new TimerMilliC() as LightTimer;
	components new TimerMilliC() as MicTimer;

	components new TimerMilliC() as DS18B20ResourceTimer;
	components new TimerMilliC() as HumiResourceTimer;
	components new TimerMilliC() as TempResourceTimer;
	components new TimerMilliC() as LightResourceTimer;
	components new TimerMilliC() as MicResourceTimer;

	App.Boot -> MainC;
	App.Leds -> LedsC;

	App.DS18B20Timer -> DS18B20Timer;
	App.HumiTimer -> HumiTimer;
	App.TempTimer -> TempTimer;
	App.LightTimer -> LightTimer;
	App.MicTimer -> MicTimer;

enum {
	DS18B20_RESOURCE_CLIENT_ID = unique(SOLENOIDVALVES_ARBITER_RESOURCE),
	HUMI_RESOURCE_CLIENT_ID = unique(SOLENOIDVALVES_ARBITER_RESOURCE),
	TEMP_RESOURCE_CLIENT_ID = unique(SOLENOIDVALVES_ARBITER_RESOURCE),
	LIGHT_RESOURCE_CLIENT_ID = unique(SOLENOIDVALVES_ARBITER_RESOURCE),
	MIC_RESOURCE_CLIENT_ID = unique(SOLENOIDVALVES_ARBITER_RESOURCE),
};
	components new FcfsArbiterC(SOLENOIDVALVES_ARBITER_RESOURCE) as SVResource;

	App.DS18B20ResourceClient -> SVResource.Resource[DS18B20_RESOURCE_CLIENT_ID];
	App.HumiResourceClient -> SVResource.Resource[HUMI_RESOURCE_CLIENT_ID];
	App.TempResourceClient -> SVResource.Resource[TEMP_RESOURCE_CLIENT_ID];
	App.LightResourceClient -> SVResource.Resource[LIGHT_RESOURCE_CLIENT_ID];
	App.MicResourceClient -> SVResource.Resource[MIC_RESOURCE_CLIENT_ID];
	App.SVDefaultOwner -> SVResource.ResourceDefaultOwner;

	App.DS18B20ResourceTimer -> DS18B20ResourceTimer;
	App.HumiResourceTimer -> HumiResourceTimer;
	App.TempResourceTimer -> TempResourceTimer;
	App.LightResourceTimer -> LightResourceTimer;
	App.MicResourceTimer -> MicResourceTimer;
	
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
	components IrMicC;
	App.Microphone -> IrMicC;
	App.MicControl -> IrMicC;

	// 远程烧写
	components DelugeC;

#ifdef USING_REMOTE_PRINTF
	// 远程PrintfC
	components IrPrintfC;
	App.PrintfControl -> IrPrintfC;
#endif

#ifdef USING_SERIAL_PRINTF
	components PrintfC, SerialStartC;
#endif
}
