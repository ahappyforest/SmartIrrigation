#ifndef __SENSOR_H_
#define __SENSOR_H

#include "SmartIrrigation.h"
#include "message.h"

#define BITSET(n) (1 << (n))

enum {
	TYPE_DS18B20 = 0x00,
	TYPE_YL69 = 0x01,
	TYPE_LIGHT = 0x02,
	TYPE_TEMP = 0x03,
#ifdef USING_MIC
	TYPE_MIC = 0x04,
#endif
	DEFAULT_DS18B20_PERIOD = 3000,
	DEFAULT_YL69_PERIOD    = 3000,
	DEFAULT_LIGHT_PERIOD   = 3000,
	DEFAULT_TEMP_PERIOD    = 3000,
#ifdef USING_MIC
	DEFAULT_MIC_PERIOD = 1,
#endif
	DEFAULT_DS18B20_THRESHOLD = 30,
	DEFAULT_YL69_THRESHOLD    = 0,
	DEFAULT_LIGHT_THRESHOLD   = 50,
	DEFAULT_TEMP_THRESHOLD    = 800,
#ifdef USING_MIC
	DEFAULT_MIC_THRESHOLD  = 900,
#endif
	START_READING_DS18B20  = BITSET(0),
	START_READING_YL69     = BITSET(1),
	START_READING_TEMP     = BITSET(2),
	START_READING_LIGHT    = BITSET(3),
#ifdef USING_MIC
	START_READING_MICROPHONE = BITSET(4),
#endif

	SV_SWITCH_DS18B20  = BITSET(0),
	SV_SWITCH_YL69     = BITSET(1),
	SV_SWITCH_TEMP     = BITSET(2),
	SV_SWITCH_LIGHT    = BITSET(3),
	SV_SWITCH_USERCONTROL = BITSET(4),
#ifdef USING_MIC
	SV_SWITCH_MICROPHONE  = BITSET(5),
#endif

	SVSWITCH_DELAY_TIME = 8000,

};

typedef struct global_data {
	bool radio_busy;

	message_t sensor_buf;
	message_t reply_buf;

	uint16_t sensor_period[5];
	uint16_t sensor_threshold[5];
	uint8_t  sensor_flag;
	uint8_t  sv_switch;
	uint8_t  auto_flag;

	uint16_t ds18b20_lasttime;
	uint16_t yl69_lasttime;
	uint16_t temp_lasttime;
	uint16_t light_lasttime;


#ifdef  USING_MIC
#define NREADINGS 32
	uint16_t mic_reading[NREADINGS];
	uint16_t mic_reading_count;
	uint16_t mic_avr;
	uint16_t mic_lasttime;
	uint16_t mic_overview[7];
	bool     mic_calibflag;
	uint16_t mic_calib;
#endif
} global_data_t;


#endif
