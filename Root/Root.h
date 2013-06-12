#ifndef __ROOT_H_
#define __ROOT_H_

#include "SmartIrrigation.h"
#include "message.h"

typedef struct global_data {
	bool serial_busy;
	message_t serial_buf;
} global_data_t;

#endif
