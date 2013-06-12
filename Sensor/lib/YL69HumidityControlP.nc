#include "irrigation.h"

module YL69HumidityControlP {
	provides {
		interface Init;
		interface Switch;
	}
	uses {
		interface BusyWait<TMicro, uint16_t> as Delay;
		interface GeneralIO as Power;
	}
}
implementation {
	uint8_t status = OFF;
	
	command error_t Init.init(void) {
		call Switch.close();
		return SUCCESS;
	}

	command error_t Switch.open(void) {
		if (status == ON) {
			return SUCCESS;
		}
		call Power.makeOutput();
		call Power.clr();  // 由于使用了PNP型三极管, 低电平打开设备
		call Delay.wait(100);
		status = ON;
		return SUCCESS;
	}
	
	command error_t Switch.close(void) {
		if (status == OFF) {
			return SUCCESS;
		}
		call Power.set(); // 高点平关闭设备， 至于要不要makeInput, 还不知道
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
