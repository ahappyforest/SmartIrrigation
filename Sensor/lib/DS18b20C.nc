#include "PinConfig.h"
configuration DS18b20C {
	provides {
		interface Switch;
		interface Read<int32_t>;
	}
}
implementation {
	components DS18b20P;
	components MicaBusC;
	components BusyWaitMicroC;
	components MainC;
	Switch = DS18b20P.Switch;
	Read = DS18b20P.Read;

	DS18b20P.DQ -> DS18B20_DQ;
	DS18b20P.Power -> DS18B20_POWER;
	DS18b20P.Delay -> BusyWaitMicroC;

	// auto init
	DS18b20P.Init <- MainC.SoftwareInit;

	components LedsC;
	DS18b20P.Leds -> LedsC;
}
