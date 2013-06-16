#ifndef __ROOT_H_
#define __ROOT_H_

#include "SmartIrrigation.h"
#include "message.h"

typedef struct global_data {
	bool serial_busy;
	message_t serial_buf;
	uint16_t msg_queue_retry_interval;
} global_data_t;

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
