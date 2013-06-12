#include "ds18b20.h"
#include "irrigation.h"

module DS18b20P {
	provides {
		interface Init;
		interface Switch;
		interface Read<int32_t>;
	}
	uses {
		interface Leds;
		interface GeneralIO as Power;
		interface GeneralIO as DQ;

		// 1 uS    -> internal 8MHZ clock
		// 1.09uS  -> external crystal
		interface BusyWait<TMicro, uint16_t> as Delay;
	}
}
implementation {
	int32_t digital_part;    //  温度值的整数部分
	uint16_t decimal_part;   //  温度值的小数部分
	uint8_t status = OFF;

	// close, when initialize
	command error_t Init.init(void) {
		call Switch.open();
		return SUCCESS;
	}

	command error_t Switch.open(void) {
		if (status == ON) {
			return SUCCESS;
		}
		call Power.makeOutput();
		call Power.set();
		call Delay.wait(100);
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


	static uint8_t _reset() {
		uint8_t i;
		call DQ.clr();
		call DQ.makeOutput();
		call Delay.wait(480);
		
		call DQ.makeInput();
		call Delay.wait(60);
		i = call DQ.get(); 
		call Delay.wait(420);

		digital_part = 0;
		decimal_part = 0;
		
		return i;
	}


	static void _write_bit(uint8_t bit) {
		call DQ.clr();
		call DQ.makeOutput();
		call Delay.wait(1);
		if (bit) {
			call DQ.makeInput();
		}
		call Delay.wait(60);
		call DQ.makeInput();
	}

	static uint8_t _read_bit(void) {
		uint8_t bit = 0;
		
		call DQ.clr();
		call DQ.makeOutput();
		call Delay.wait(1);
		
		call DQ.makeInput();
		call Delay.wait(14);
		
		if (call DQ.get()) {
			bit = 1;
		}

		call Delay.wait(45);
		return bit;
	}


	static uint8_t _read_byte(void) {
		uint8_t i = 8, n = 0;

		while (i--) {
			n >>= 1;
			n |= (_read_bit() << 7);
		}
		return n;
	}

		
	static void _write_byte(uint8_t byte) {
		uint8_t i = 8;
		while (i--) {
			_write_bit(byte & 1);
			byte >>= 1;
		}
	}

#define _DECIMAL_STEPS_12BIT 625
#define _DECIMAL_STEPS_9BIT  500

	static void _read_temperature() {
		uint8_t temperature[2];
		int8_t digit;
		uint16_t decimal;

		_reset();
		_write_byte(DS18B20_CMD_SKIPROM);
		_write_byte(DS18B20_CMD_CONVERTTEMP);
		
		//Wait until conversion is complete
		while(!_read_bit());
		//Reset, skip ROM and send command to read Scratchpad
		call Leds.led0Toggle();

		_reset();
		_write_byte(DS18B20_CMD_SKIPROM);
		_write_byte(DS18B20_CMD_RSCRATCHPAD);
		//Read Scratchpad (only 2 first bytes)
		temperature[0]=_read_byte();
		temperature[1]=_read_byte();
		_reset();
		
		//Store temperature integer digits and decimal digits
		digit=temperature[0]>>4;
		digit|=(temperature[1]&0x7)<<4;
		//Store decimal digits
		decimal=temperature[0]&0xf;
		decimal*=_DECIMAL_STEPS_12BIT;
		
		digital_part = digit;
		decimal_part = decimal;

		//sprintf(buffer, "%+d.%04u C", digit, decimal);
		
		//sprintf(buffer, "%d.%d\n",temperature[0]/2, (temperature[0]&1)*5 );
		//usart_write_str(buffer);
	}

	task void get_temperature_task() {
		_read_temperature();
		signal Read.readDone(SUCCESS, digital_part << 16 | (decimal_part));
	}

	command error_t Read.read() {
		return post get_temperature_task();
	}
}
