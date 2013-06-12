#include "PinConfig.h"

configuration SolenoidValvesC {
	provides interface Switch;
}
implementation {
	components SolenoidValvesP as Device;
	components BusyWaitMicroC as Delay;
	components MicaBusC;
	components MainC;

	Device.Power -> SOLENOIDVALVES_POWER;
	Device.Delay -> Delay;
	Switch = Device;

	Device.Init <- MainC.SoftwareInit;
}
