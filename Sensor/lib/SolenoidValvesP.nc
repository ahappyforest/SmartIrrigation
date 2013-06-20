#include "irrigation.h"


module SolenoidValvesP {
	provides {
		interface Init;
		interface Switch;
	}
	uses {
		interface GeneralIO as Power;
		interface BusyWait<TMicro, uint16_t> as Delay;
	}
}
implementation {
	uint8_t status = OFF;

	command error_t Init.init() {
		call Power.clr();
		return SUCCESS;
	}

	command error_t Switch.open(void) {
		if (status == ON) {
			return SUCCESS;
		}
		call Power.makeOutput();
		call Power.set();     // 使用N-MOSFET, 高电平有效
		call Delay.wait(100); // 延时100us, 确保已经打开
		status = ON;
		return SUCCESS;
	}

	command error_t Switch.close(void) {
		if (status == OFF) {
			return SUCCESS;
		}
		call Power.clr();
//		call Power.makeInput();
		call Delay.wait(100);
		status = OFF;
		return SUCCESS;
	}

	command error_t Switch.toggle(void) {
		if (status == ON) {
			call Switch.close();
		} else {
			call Switch.open();
		}
		return SUCCESS;
	}
	
	command uint8_t Switch.getStatus(void) {
		return status;
	}
}
