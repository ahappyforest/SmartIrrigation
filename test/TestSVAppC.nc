#define NEW_PRINTF_SEMANTICS
#include "printf.h"

configuration TestSVAppC {
}
implementation {
	components MainC, LedsC;
	components TestSVC as App;
	components new TimerMilliC() as Timer;
	components MicaBusC;

	App.Boot -> MainC;
	App.Leds -> LedsC;
	App.Timer -> Timer;
//	App.PW0 -> MicaBusC.PW0;
//	App.PW1 -> MicaBusC.PW1;
//	App.PW2 -> MicaBusC.PW2;
//	App.PW3 -> MicaBusC.PW3;
//	App.PW4 -> MicaBusC.PW4;
//	App.PW6 -> MicaBusC.PW6;
	App.PW7 -> MicaBusC.PW7;

//	App.PW6 -> MicaBusC.PW6;

	components DelugeC;
	components PrintfC;

//	components DS18b20C;
//	App.DS18b20Switch -> DS18b20C;
//	App.DS18b20 -> DS18b20C;

//	components SerialStartC;
}
	
	
