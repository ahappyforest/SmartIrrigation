#include "printf.h"

module TestSVC {
	uses {
		interface Boot;
		interface Leds;
		interface Timer<TMilli>;
//		interface GeneralIO as PW0;
//		interface GeneralIO as PW1;
//		interface GeneralIO as PW2;
//		interface GeneralIO as PW3;
//		interface GeneralIO as PW4;
//		interface GeneralIO as PW6;
		interface GeneralIO as PW7;

//		interface GeneralIO as PW5;
//		interface Switch as DS18b20Switch;
//		interface Read<int32_t> as DS18b20;

	}
}
implementation {
	bool flag = FALSE;
	
	event void Boot.booted() {
		call PW7.makeOutput();
		call PW7.set();
		call Timer.startPeriodic(1000);
	} 

	event void Timer.fired() {
//		flag? call PW7.set() : call PW7.clr();
//		flag = flag? FALSE : TRUE;

		call Leds.led1Toggle();
	}
}
