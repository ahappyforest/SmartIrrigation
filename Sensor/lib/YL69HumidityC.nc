#include "PinConfig.h"

configuration YL69HumidityC {
	provides {
		interface Switch;
		interface Read<uint16_t>;
	}
}
implementation {
	components YL69HumidityControlP as Control;
	components YL69HumidityP as Device;
	components MicaBusC;
	components MainC;
	components new AdcReadClientC() as Adc;
	components BusyWaitMicroC; // 保证设备有足够的启动时间
	
	// 1. Control
	Control.Power -> YL69_POWER;
	Control.Delay -> BusyWaitMicroC;
	Switch = Control.Switch;
	
	// 2. Device
	Device.SoilHumidityAdc -> YL69_ADO;
	Device.Atm128AdcConfig <- Adc;
	Read = Adc.Read;

	// 3. auto Init
	Control.Init <- MainC.SoftwareInit;
}
