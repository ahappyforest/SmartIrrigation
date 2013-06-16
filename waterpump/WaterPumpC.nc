#include "printf.h"
module WaterPumpC {
	uses {
		interface Boot;
		interface Leds;
		interface Send as ReplySend;
		interface Packet as CtpPacket;
		interface SplitControl as RadioControl;
		interface StdControl as CtpControl;
		
		interface DisseminationValue<request_msg_t> as ReqValue;
		interface StdControl as DripControl;

		interface GeneralIO as WaterPumpPower;
	}
}
implementation {
	bool water_pump_status = OFF;
	bool radio_busy = FALSE;
	message_t reply_buf;

	void open_water_pump() {
		call WaterPumpPower.set();
		water_pump_status = ON;
	}

	void close_water_pump() {
		call WaterPumpPower.clr();
		water_pump_status = OFF;
	}

	void Init() {
		call WaterPumpPower.makeOutput();
		call WaterPumpPower.clr();
		water_pump_status = OFF;
		radio_busy = FALSE;
		memset(&reply_buf, 0, sizeof(reply_msg_t));
		
	}

	void ctp_send_reply_msg(reply_msg_t *reply) {
		if (!radio_busy) {
			reply_msg_t *new_payload = (reply_msg_t *)(
				call ReplySend.getPayload(&reply_buf, sizeof(reply_msg_t)));
			if (new_payload == NULL) { 
				return;
			}
			*new_payload = *reply;
			if (call CtpPacket.maxPayloadLength() < sizeof(reply_msg_t)) {
				return;
			}

			if (call ReplySend.send(&reply_buf, sizeof(reply_msg_t)) == SUCCESS) {
				call Leds.led1Toggle();
				radio_busy = TRUE;
			}
		} else {
			;
		}
	}


	event void Boot.booted() {
		Init();
		call RadioControl.start();
	}

	event void RadioControl.startDone(error_t err) {
		if (err == SUCCESS) {
			call CtpControl.start();
			call DripControl.start();
		} else {
			call Leds.led0On();
		}
	}

	event void RadioControl.stopDone(error_t err) { }

	event void ReqValue.changed() {
		reply_msg_t reply;
		const request_msg_t *req = call ReqValue.get();
		memset(&reply, 0, sizeof(reply_msg_t));
		reply.node_id = TOS_NODE_ID;
		reply.transaction_number = req->transaction_number;
		reply.request_code = req->request_code;
		reply.request_device = req->request_device;
		reply.request_data = req->request_data;

		printf("value changed\n");
		printfflush();
		if (req->request_device == WATERPUMP) {
			switch (req->request_code) {
				case SET_SWITCH_STATUS_REQUEST:
					if (req->request_data == ON) {
						printf("now open water pump\n");
						open_water_pump();
					} else if (req->request_data == OFF) {
						printf("now close water pump\n");
						close_water_pump();
					} else {
						return;	
					}	
					reply.status = SUCCESS;
					break;
				case GET_SWITCH_STATUS_REQUEST:
					reply.request_data = water_pump_status;
					reply.status = SUCCESS;
					break;

				default:
					return;
			}
			ctp_send_reply_msg(&reply);
		} else {
			;
		}
	}

	event void ReplySend.sendDone(message_t *msg, error_t err) {
		if (msg == &reply_buf) {
			radio_busy = FALSE;
		}
	}
}
