module RootC {
	uses {
		interface Boot;
		interface Leds;
		
		interface SplitControl as SerialControl;
		interface Packet as SerialPacket;
		interface AMSend as SerialSensorSend;
		interface AMSend as SerialReplySend;
		interface Receive as SerialReceive;

		interface Receive as CtpSensorReceive;
		interface Receive as CtpReplyReceive;
		interface RootControl;
		interface StdControl as CtpControl;
		interface SplitControl as RadioControl;

		interface StdControl as DripControl;
		interface DisseminationUpdate<request_msg_t> as ReqUpdate;
	
		interface BigQueue<msg_data_t> as MsgQueue;
		interface Timer<TMilli> as MsgCheckTimer;
	}
}
implementation {
	global_data_t gl;


	void init(void);
	void report_radio_working();
	void report_serial_working();
	void report_error();
	void report_fatal_error();
	void serial_send_sensor_msg(sensor_msg_t *sensor);
	void serial_send_reply_msg(reply_msg_t *reply);
	void process_request(request_msg_t *req);
	msg_data_t msg_queue_data_from_sensor(sensor_msg_t *sm);
	msg_data_t msg_queue_data_from_reply(reply_msg_t *rm);
	error_t process_msg_queue_data(msg_data_t *_m);

	void init(void) {
		gl.serial_busy = FALSE;
		memset(&gl.serial_buf, 0, sizeof(message_t));
		gl.msg_queue_retry_interval = 10;
	}

	void report_radio_working()  { call Leds.led1Toggle(); }
	void report_serial_working() { call Leds.led2Toggle(); }
	void report_error()          { call Leds.led0On(); }
	void report_fatal_error() {	
		call Leds.led0On();
		call Leds.led1On();
		call Leds.led2On();
	}

	void serial_send_sensor_msg(sensor_msg_t *sensor) {
		if (!gl.serial_busy) {
			sensor_msg_t *new_payload = (sensor_msg_t *)(
				call SerialSensorSend.getPayload(&gl.serial_buf, sizeof(sensor_msg_t)));
			if (new_payload == NULL) { 
				report_error();
				return;
			}
			*new_payload = *sensor;
			if (call SerialPacket.maxPayloadLength() < sizeof(sensor_msg_t)) {
				report_error();
				return;
			}

			if (call SerialSensorSend.send(AM_BROADCAST_ADDR, &gl.serial_buf, sizeof(sensor_msg_t)) == SUCCESS) {
				gl.serial_busy = TRUE;
			}
		}
	}


	void serial_send_reply_msg(reply_msg_t *reply) {
		if (!gl.serial_busy) {
			reply_msg_t *new_payload = (reply_msg_t *)(
					call SerialReplySend.getPayload(&gl.serial_buf, sizeof(reply_msg_t)));
			*new_payload = *reply;
			if (new_payload == NULL) { 
				report_error(); 
				return; 
			}
			if (call SerialPacket.maxPayloadLength() < sizeof(reply_msg_t)) {
				report_error();
				return;
			}
			if (call SerialReplySend.send(AM_BROADCAST_ADDR, &gl.serial_buf, sizeof(reply_msg_t)) == SUCCESS) {
				gl.serial_busy = TRUE;
			}
		}
	}

	void process_request(request_msg_t *req) {
		// 主要为操作水泵
		// 1. Dummy Operate
		// 2. Send Reply
		reply_msg_t reply;
		reply.node_id = TOS_NODE_ID;
		reply.transaction_number = req->transaction_number;
		reply.status = SUCCESS;
		serial_send_reply_msg(&reply);
	}
			

	event void Boot.booted() {
		call SerialControl.start();	
	}

	event void SerialControl.startDone(error_t err) {
		if (err == SUCCESS) {
			call RadioControl.start();
		} else {
			report_fatal_error();
		}
	}
	
	event void SerialControl.stopDone(error_t err) { }

	event void RadioControl.startDone(error_t err) {
		if (err == SUCCESS) {
			call CtpControl.start();
			call DripControl.start();
			call RootControl.setRoot();
			call MsgCheckTimer.startOneShot(0);
		} else {
			report_fatal_error();
		}
	}

	event message_t *CtpSensorReceive.receive(message_t *msg, void *payload, uint8_t len) {
		report_radio_working();
		if (len == sizeof(sensor_msg_t)) {
			call MsgQueue.enqueue(msg_queue_data_from_sensor((sensor_msg_t *)payload));
		}
		return msg;
	}

	msg_data_t msg_queue_data_from_sensor(sensor_msg_t *sm) {
		msg_data_t md;
		md.msg_type = AM_SENSOR_MSG;
		md.m_data.m_sensor = *sm;

		return md;

	}

	msg_data_t msg_queue_data_from_reply(reply_msg_t *rm) {
		msg_data_t md;
		md.msg_type = AM_REPLY_MSG;
		md.m_data.m_reply = *rm;

		return md;
	}


	event message_t *CtpReplyReceive.receive(message_t *msg, void *payload, uint8_t len) {
		report_radio_working();
		if (len == sizeof(reply_msg_t)) {
			call MsgQueue.enqueue(msg_queue_data_from_reply((reply_msg_t *)payload));
		}
		return msg;
	}

	event void SerialSensorSend.sendDone(message_t *msg, error_t err) {
		if (msg == &gl.serial_buf) {
			gl.serial_busy = FALSE;
			report_serial_working();
			call MsgCheckTimer.startOneShot(0);
		}
	}

	event void SerialReplySend.sendDone(message_t *msg, error_t err) {
		if (msg == &gl.serial_buf) {
			gl.serial_busy = FALSE;
			report_serial_working();
			call MsgCheckTimer.startOneShot(0);
		}
	}

	event message_t *SerialReceive.receive(message_t *msg, void *payload, uint8_t len) {
		if (len == sizeof(request_msg_t)) {
			request_msg_t *req = (request_msg_t *)payload;
			if (req->node_id == TOS_NODE_ID) {
				process_request(req);
			} else {
				call ReqUpdate.change(req);
			}	
			report_serial_working();
		}
		return msg;
	}

	event void RadioControl.stopDone(error_t err) { }

	error_t process_msg_queue_data(msg_data_t *_m) {
		if (_m->msg_type == AM_SENSOR_MSG) {
			serial_send_sensor_msg(&(_m->m_data.m_sensor));
		} else if (_m->msg_type == AM_REPLY_MSG) {
			serial_send_reply_msg(&(_m->m_data.m_reply));
		} else {
			return FAIL;
		}
		return SUCCESS;
	}


	event void MsgCheckTimer.fired() {
		msg_data_t m_data;
		if (!call MsgQueue.empty()) {
			m_data = call MsgQueue.dequeue();
			if (process_msg_queue_data(&m_data) != SUCCESS) {
				call MsgCheckTimer.startOneShot(gl.msg_queue_retry_interval);
			}
		} else {
			// 等待一段事件再次检查
			call MsgCheckTimer.startOneShot(gl.msg_queue_retry_interval);
		}
	}
	
	
	
}
