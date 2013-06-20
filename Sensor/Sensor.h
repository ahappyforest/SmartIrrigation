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
	TYPE_MIC = 0x04,

	DEFAULT_DS18B20_PERIOD = 1234,
	DEFAULT_YL69_PERIOD    = 2345,
	DEFAULT_LIGHT_PERIOD   = 3456,
	DEFAULT_TEMP_PERIOD    = 1234,
	DEFAULT_MIC_PERIOD = 1,

//	DEFAULT_DS18B20_THRESHOLD = 30,
//	DEFAULT_YL69_THRESHOLD    = 1000,
//	DEFAULT_LIGHT_THRESHOLD   = 50,
//	DEFAULT_TEMP_THRESHOLD    = 800,
//	DEFAULT_MIC_THRESHOLD  = 900,

	DEFAULT_DS18B20_THRESHOLD = 0xFFFF,
	DEFAULT_YL69_THRESHOLD    = 0xFFFF,
	DEFAULT_LIGHT_THRESHOLD   = 0xFFFF,
	DEFAULT_TEMP_THRESHOLD    = 0xFFFF,
	DEFAULT_MIC_THRESHOLD  = 0xFFFF,
	

	START_READING_DS18B20  = BITSET(0),
	START_READING_YL69     = BITSET(1),
	START_READING_TEMP     = BITSET(2),
	START_READING_LIGHT    = BITSET(3),
	START_READING_MICROPHONE = BITSET(4),

	SV_SWITCH_DS18B20  = BITSET(0),
	SV_SWITCH_YL69     = BITSET(1),
	SV_SWITCH_TEMP     = BITSET(2),
	SV_SWITCH_LIGHT    = BITSET(3),
	SV_SWITCH_USERCONTROL = BITSET(4),
	SV_SWITCH_MICROPHONE  = BITSET(5),

	SV_HOLD_PERIOD = 8000,
};

typedef struct global_data {
	bool radio_busy;

	message_t sensor_buf;
	message_t reply_buf;

	uint16_t sensor_period[5];
	uint16_t sensor_threshold[5];
	uint8_t  sv_switch;
	uint8_t  sv_default_status;

#define NREADINGS 32
	uint16_t mic_reading[NREADINGS];
	uint16_t mic_reading_count;
	uint16_t mic_avr;
	uint16_t mic_overview[7];
	bool     mic_calibflag;
	uint16_t mic_calib;

	uint16_t msg_queue_retry_interval;
} global_data_t;

#define MSG_CHECK_RETRY_INTERVAL 10

// 定义这个结构体解决一个队列包容所有类型
typedef struct msg_data {
        uint8_t msg_type; // type来自与enum中的三种AM_XXX_MSG
        union {
                sensor_msg_t  m_sensor;
                reply_msg_t   m_reply;
        } m_data;

	// op表示对这个消息要进行什么操作
        // uint8_t op;
} msg_data_t;


#endif
