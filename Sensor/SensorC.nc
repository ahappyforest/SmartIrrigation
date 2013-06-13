#include "Timer.h"

#ifdef USING_SERIAL_PRINTF
#include "printf.h"
#endif

#ifdef USING_REMOTE_PRINTF
#include "irprintf.h"
#endif

#include "math.h"


module SensorC {
	uses {
		interface Boot;
		interface Leds;
		interface Timer<TMilli> as SensorTimer;
		
		interface Send as SensorSend;
		interface Send as ReplySend;
		interface Packet as CtpPacket;
		interface SplitControl as RadioControl;
		interface StdControl as CtpControl;
		
		interface DisseminationValue<request_msg_t> as ReqValue;
		interface StdControl as DripControl;
		
		interface Switch as DS18B20Switch;
		interface Switch as HumiditySwitch;
		interface Switch as SVSwitch;

		interface Read<int32_t>  as DS18B20R;
		interface Read<uint16_t> as Humidity;
		interface Read<uint16_t> as Temp;
		interface Read<uint16_t> as Light;
#ifdef USING_MIC
		interface Read<uint16_t> as Microphone;
		interface SplitControl as MicControl;
#endif

		interface StdControl as PrintfControl;
	}
}
implementation {
	global_data_t gl;

	/*************************************************
	 * 各种函数声明
	 ************************************************/
	void init();
	void report_radio_working();
        void report_sensor_working();
        void report_error();
        void report_fatal_error();
	void ctp_send_sensor_msg(sensor_msg_t *sensor);
	void ctp_send_reply_msg(reply_msg_t *reply);
	void check_sv(uint8_t flag);
	void process_request_sv(const request_msg_t *req);
	void process_request_sensor(const request_msg_t *req, uint8_t type);
#ifdef USING_MIC
	uint16_t power();
	uint16_t complexity(int16_t local_power);
	uint16_t maxPower();
	uint8_t getPhoneme();
#endif

	void init() {
		gl.radio_busy = FALSE;
		memset(&gl.sensor_buf, 0, sizeof(message_t));
		memset(&gl.reply_buf, 0,  sizeof(message_t));
		gl.sensor_period[TYPE_DS18B20] = DEFAULT_DS18B20_PERIOD;
		gl.sensor_period[TYPE_YL69]    = DEFAULT_YL69_PERIOD;
		gl.sensor_period[TYPE_LIGHT]   = DEFAULT_LIGHT_PERIOD;
		gl.sensor_period[TYPE_TEMP]    = DEFAULT_TEMP_PERIOD;

		gl.sensor_threshold[TYPE_DS18B20] = DEFAULT_DS18B20_THRESHOLD;
		gl.sensor_threshold[TYPE_YL69]    = DEFAULT_YL69_THRESHOLD;
		gl.sensor_threshold[TYPE_LIGHT]   = DEFAULT_LIGHT_THRESHOLD;
		gl.sensor_threshold[TYPE_TEMP]    = DEFAULT_TEMP_THRESHOLD;
		
		gl.sensor_flag = 0;	
		gl.sv_switch = 0;
		gl.auto_flag = TRUE;

		
		gl.ds18b20_lasttime = 0;
		gl.yl69_lasttime = 0;
		gl.temp_lasttime = 0;
		gl.light_lasttime = 0;

#ifdef USING_MIC
		gl.sensor_period[TYPE_MIC]    = DEFAULT_MIC_PERIOD;
		gl.sensor_threshold[TYPE_MIC]    = DEFAULT_MIC_THRESHOLD;
		memset(gl.mic_reading, 0, sizeof(gl.mic_reading));
		gl.mic_reading_count = 0;
		gl.mic_avr = 0;
		gl.mic_lasttime = 0;
		memset(gl.mic_overview, 0, sizeof(gl.mic_overview));
		gl.mic_calibflag = FALSE;
		gl.mic_calib = 0;
#endif
			
	}

	void report_radio_working()  { call Leds.led1Toggle(); }
        void report_sensor_working() { call Leds.led2Toggle(); }
        void report_error()          { call Leds.led0On(); }
        void report_fatal_error() {
                call Leds.led0On();
                call Leds.led1On();
                call Leds.led2On();
        }

	event void Boot.booted() {
		init();
		call RadioControl.start();
	}

	event void RadioControl.startDone(error_t err) {
		uint16_t local_time;
		if (err == SUCCESS) {
			call CtpControl.start();
			call DripControl.start();
#ifdef USING_REMOTE_PRINTF
			call PrintfControl.start();
#endif
#ifdef USING_MIC
			call MicControl.start();
#endif
	//		gl.sensor_flag |= START_READING_YL69    |
	//				  START_READING_LIGHT   |
	//				  START_READING_TEMP;
	//				  START_READING_DS18B20; 
			gl.sensor_flag |= START_READING_LIGHT | START_READING_TEMP | START_READING_YL69;

			// 初始时间， 保证每一个传感器都有自己的时间节点
			// 在每个时间节点做自己的事情
			local_time = call SensorTimer.getNow();
			gl.ds18b20_lasttime =  local_time;
			gl.yl69_lasttime = local_time;
			gl.temp_lasttime = local_time;
			gl.light_lasttime = local_time;
#ifdef USING_MIC
			gl.mic_lasttime = call SensorTimer.getNow();
#endif
			call SensorTimer.startPeriodic(1);
		} else {
			report_error();
		}
	}

#ifdef USING_MIC
	event void MicControl.startDone(error_t err) {
		if (err == SUCCESS) {
			gl.sensor_flag |= START_READING_MICROPHONE;
		} else {
			report_error();
		}
	}
	
	event void MicControl.stopDone(error_t err) { }
#endif

	event void RadioControl.stopDone(error_t err) { }

	event void SensorTimer.fired() {
		uint16_t local_time = call SensorTimer.getNow();
//		report_sensor_working();
//		printf("sensor timer fired\n");
		if (gl.sensor_flag & START_READING_DS18B20) {
			if (local_time - gl.ds18b20_lasttime < gl.sensor_period[TYPE_DS18B20]) { return; }
			call DS18B20Switch.open();
			call DS18B20R.read();
			gl.sensor_flag &= ~START_READING_DS18B20;
		} 

		if (gl.sensor_flag & START_READING_YL69) {
			if (local_time - gl.yl69_lasttime < gl.sensor_period[TYPE_YL69]) { return; }
			call HumiditySwitch.open();
			call Humidity.read();
			gl.sensor_flag &= ~START_READING_YL69;
		}

		if (gl.sensor_flag & START_READING_TEMP) {
			if (local_time - gl.temp_lasttime < gl.sensor_period[TYPE_TEMP]) { return; }
			call Temp.read();
			gl.sensor_flag &= ~START_READING_TEMP;
		}

		if (gl.sensor_flag & START_READING_LIGHT) {
			if (local_time - gl.light_lasttime < gl.sensor_period[TYPE_LIGHT]) { return; }
			call Light.read();
			gl.sensor_flag &= ~START_READING_LIGHT;
		}

#ifdef USING_MIC
		if (gl.sensor_flag & START_READING_MICROPHONE) {
			if (local_time - gl.mic_lasttime < gl.sensor_period[TYPE_MIC]) { return; }
			call Microphone.read();
			gl.sensor_flag &= ~START_READING_MICROPHONE;
		}
#endif
	}
	

	void ctp_send_sensor_msg(sensor_msg_t *sensor) {
		if (!gl.radio_busy) {
			sensor_msg_t *new_payload = (sensor_msg_t *)(
				call SensorSend.getPayload(&gl.sensor_buf, sizeof(sensor_msg_t)));
			if (new_payload == NULL) { 
				report_error();
				return;
			}
			*new_payload = *sensor;
			if (call CtpPacket.maxPayloadLength() < sizeof(sensor_msg_t)) {
				report_error();
				return;
			}

			if (call SensorSend.send(&gl.sensor_buf, sizeof(sensor_msg_t)) == SUCCESS) {
				report_radio_working();
				gl.radio_busy = TRUE;
			}
		}
	}

	void ctp_send_reply_msg(reply_msg_t *reply) {
		if (!gl.radio_busy) {
			reply_msg_t *new_payload = (reply_msg_t *)(
				call ReplySend.getPayload(&gl.reply_buf, sizeof(reply_msg_t)));
			if (new_payload == NULL) { 
				report_error();
				return;
			}
			*new_payload = *reply;
			if (call CtpPacket.maxPayloadLength() < sizeof(reply_msg_t)) {
				report_error();
				return;
			}

			if (call ReplySend.send(&gl.reply_buf, sizeof(reply_msg_t)) == SUCCESS) {
				report_radio_working();
				gl.radio_busy = TRUE;
			}
		}
	}

	void check_sv(uint8_t flag) {
		if (gl.auto_flag == TRUE) {
			if (flag) {
				call SVSwitch.open();
			} else {
				call SVSwitch.close();
			}
		} else {
			if (flag & SV_SWITCH_USERCONTROL) {
				call SVSwitch.open();
			} else {
				call SVSwitch.close();
			}
		}
	}

	event void DS18B20R.readDone(error_t err, int32_t val) {
		sensor_msg_t sm;
	//	uint8_t ch[4];
	//	uint16_t digit, decimal;
	//	memcpy(ch, &val, sizeof(int32_t));
		memset(&sm, 0, sizeof(sensor_msg_t));

		if (err == SUCCESS) {
			call DS18B20Switch.close();

			gl.ds18b20_lasttime = call SensorTimer.getNow();
			gl.sensor_flag |= START_READING_DS18B20;
			if (val > gl.sensor_threshold[TYPE_DS18B20]) {
				gl.sv_switch |= SV_SWITCH_DS18B20;
			} else {
				gl.sv_switch &= ~SV_SWITCH_DS18B20;
			}

			check_sv(gl.sv_switch);

		
			sm.node_id = TOS_NODE_ID;
			sm.sensor_type = DS18B20;
	
						
	/*		digit = ch[0];
			digit = (digit << 8) | ch[1];
			
			decimal = ch[2];
			decimal = (decimal << 8) | ch[3];

			sm.sensor_value = digit;
			sm.reserved[0] = decimal;
	*/	
			sm.sensor_value = val;

			ctp_send_sensor_msg(&sm);
		}
	}

	event void Humidity.readDone(error_t err, uint16_t val) {
		sensor_msg_t sm;
		memset(&sm, 0, sizeof(sensor_msg_t));
		if (err == SUCCESS) {
			call HumiditySwitch.close();
			gl.yl69_lasttime = call SensorTimer.getNow();
			gl.sensor_flag |= START_READING_YL69;
			if (val > gl.sensor_threshold[TYPE_YL69]) {
				gl.sv_switch |= SV_SWITCH_YL69;
			} else {
				gl.sv_switch &= ~SV_SWITCH_YL69;
			}

			check_sv(gl.sv_switch);

		
			sm.node_id = TOS_NODE_ID;
			sm.sensor_type = YL69;
	
			sm.sensor_value = val;
			ctp_send_sensor_msg(&sm);
		}
	}

	event void Temp.readDone(error_t err, uint16_t val) {
		sensor_msg_t sm;
		memset(&sm, 0, sizeof(sensor_msg_t));
		if (err == SUCCESS) {
			gl.temp_lasttime = call SensorTimer.getNow();
			gl.sensor_flag |= START_READING_TEMP;
			if (val > gl.sensor_threshold[TYPE_TEMP]) {
				gl.sv_switch |= SV_SWITCH_TEMP;
			} else {
				gl.sv_switch &= ~SV_SWITCH_TEMP;
			}

			check_sv(gl.sv_switch);

		
			sm.node_id = TOS_NODE_ID;
			sm.sensor_type = THERMISTOR;
	
			sm.sensor_value = val;
			ctp_send_sensor_msg(&sm);
		}
	}

	event void Light.readDone(error_t err, uint16_t val) {
		sensor_msg_t sm;
		memset(&sm, 0, sizeof(sensor_msg_t));
		if (err == SUCCESS) {
			gl.sensor_flag |= START_READING_LIGHT;
			gl.light_lasttime = call SensorTimer.getNow();
			if (val > gl.sensor_threshold[TYPE_LIGHT]) {
				gl.sv_switch |= SV_SWITCH_LIGHT;
			} else {
				gl.sv_switch &= ~SV_SWITCH_LIGHT;
			}

			check_sv(gl.sv_switch);

		
			sm.node_id = TOS_NODE_ID;
			sm.sensor_type = LIGHT;
	
			sm.sensor_value = val;
			ctp_send_sensor_msg(&sm);
		}
	}
#ifdef USING_MIC
	event void Microphone.readDone(error_t err, uint16_t val) {
		//uint16_t i;
		uint8_t sample_result;
	
		if (err != SUCCESS) {
			val = 0xFFFF;
			report_error();
		}
		
		// 滤波, 由于麦克风设备的采集曲线是围绕着一条线上下震动的， 因此为了方便
		// 取平均值， 我们将500以下部分取值变为500
		// if (val < 500) val = 500;

		report_sensor_working();
		gl.mic_lasttime = call SensorTimer.getNow();
		gl.sensor_flag |= START_READING_MICROPHONE;
		gl.sensor_period[TYPE_MIC] = DEFAULT_MIC_PERIOD;
		
		
		if (gl.mic_reading_count < NREADINGS) {
			gl.mic_reading[gl.mic_reading_count++] = val;

			// 对Mic进行校正
			if (!gl.mic_calibflag) {	
				if (gl.mic_reading_count == 4) {
					gl.mic_calibflag = TRUE;
					gl.mic_calib =  gl.mic_reading[0] +
						        gl.mic_reading[1] +
							gl.mic_reading[2] +
							gl.mic_reading[3];
					gl.mic_calib /= 4;	
				}
			}
		} else {
			gl.mic_reading_count = 0;
			// gl.mic_reading_count >= NREADINGS
			//for (i = 0; i < NREADINGS; i++) {
			//	gl.mic_avr += gl.mic_reading[i];
			//}

			//gl.mic_avr /= NREADINGS;				

			//printf("mic avr: %d\n", gl.mic_avr);
		
			sample_result = getPhoneme();
			printf("sample_result: %c\n", sample_result);
			
			//if (gl.mic_avr > gl.sensor_threshold[TYPE_MIC]) {
			//	gl.sv_switch |= SV_SWITCH_MICROPHONE;
			//} else {
			//	gl.sv_switch &= ~SV_SWITCH_MICROPHONE;
			//}

			//check_sv(gl.sv_switch);
      		
      			// 如果水泵是打开的， 那么采集需要等一个延迟时间
			//if (gl.sv_switch) {
			//	gl.sensor_period[TYPE_MIC] = SVSWITCH_DELAY_TIME;
			//}
		}
	}
#endif		

	void process_request_sv(const request_msg_t *req) {
		reply_msg_t reply;
		memset(&reply, 0, sizeof(reply_msg_t));
		reply.node_id = TOS_NODE_ID;
		reply.transaction_number = req->transaction_number;

		switch(req->request_code) {
			case SET_SWITCH_STATUS_REQUEST:
				if (req->request_data == ON) {
					gl.sv_switch |= SV_SWITCH_USERCONTROL;
					gl.auto_flag = FALSE;
				} else if (req->request_data == OFF) {
					gl.sv_switch &= ~SV_SWITCH_USERCONTROL;
					gl.auto_flag = FALSE;
				} else if (req->request_data == AUTO) {
					gl.auto_flag = TRUE;
					return;
				}
				reply.status = SUCCESS;
				break;
			case GET_SWITCH_STATUS_REQUEST:
				reply.status = call SVSwitch.getStatus();		
			case GET_READING_REQUEST:
			case SET_READING_PERIOD_REQUEST:
			case GET_READING_PERIOD_REQUEST:
			case SET_READING_THRESHOLD_REQUEST:
			case GET_READING_THRESHOLD_REQUEST:
				return;
		}

		ctp_send_reply_msg(&reply);
	}

	void process_request_sensor(const request_msg_t *req, uint8_t type) {
		reply_msg_t reply;
		memset(&reply, 0, sizeof(reply_msg_t));
		reply.node_id = TOS_NODE_ID;
		reply.transaction_number = req->transaction_number;

		switch(req->request_code) {
			case SET_SWITCH_STATUS_REQUEST:
			case GET_SWITCH_STATUS_REQUEST:
			case GET_READING_REQUEST:
				return;
			case SET_READING_PERIOD_REQUEST:
				gl.sensor_period[type] = req->request_data;
				reply.status = SUCCESS;
				break;
			case GET_READING_PERIOD_REQUEST:
				reply.status = gl.sensor_period[type];
			case SET_READING_THRESHOLD_REQUEST:
				gl.sensor_threshold[type] = req->request_data;
				reply.status = SUCCESS;
			case GET_READING_THRESHOLD_REQUEST:
				reply.status = gl.sensor_threshold[type];
				break;
		}
		ctp_send_reply_msg(&reply);
	}

	event void ReqValue.changed() {
		// 数组的下表是device, 返回的是type, type指的是Sensor.h中的TYPE_XXXX.
		uint8_t device_to_type[6] = {
				0x00,
				0x00,
				0x01, // YL69
				0x02, // LIGHT
				0x03, // TEMP
				0x00  // DS18B20
			};
		const request_msg_t *req = call ReqValue.get();
		if (req->node_id != TOS_NODE_ID) { return; }
		switch(req->request_device) {
			case SOLENOIDVALVES:
				process_request_sv(req);
				break;
			case YL69:
			case LIGHT:
			case THERMISTOR:
			case DS18B20:
				process_request_sensor(req, device_to_type[req->request_device]);
				break;
		}
	}

	event void SensorSend.sendDone(message_t *msg, error_t err) {
		if (msg == &gl.sensor_buf) {
			gl.radio_busy = FALSE;
		}

	}

	event void ReplySend.sendDone(message_t *msg, error_t err) {
		if (msg == &gl.reply_buf) {
			gl.radio_busy = FALSE;
		}
	}
#ifdef USING_MIC
#define SILENCE 92
#define F_DECTION_3
	uint16_t power() {
		uint16_t j = 0;
		int8_t i = 0;
		while(i < 32) {
			j += abs(gl.mic_reading[i]);
			i++;
		}
		return j;
	}

	uint16_t complexity(int16_t local_power){
		int16_t j = 0;
		int8_t i = 1;
		while(i < 32) {
			j += abs(gl.mic_reading[i] - gl.mic_reading[i-1]);
			i++;
		}
		return (j*100)/local_power;
	}

	uint16_t maxPower() {
		uint8_t i =0;
		uint16_t max = 0;
		while (i < 32) {
			if(max < abs(gl.mic_reading[i])) {
				max = abs(gl.mic_reading[i]);
			}
        		i++;
    		}
    		return max;
	}

	uint8_t getPhoneme(){
		if(power()>SILENCE){
			uint8_t coeff = 0;
			uint8_t f = 0;
			uint16_t k = complexity(power()); 
			gl.mic_overview[6] = gl.mic_overview[5];
			gl.mic_overview[5] = gl.mic_overview[4];
			gl.mic_overview[4] = gl.mic_overview[3];
			gl.mic_overview[3] = gl.mic_overview[2];
			gl.mic_overview[2] = gl.mic_overview[1];
			gl.mic_overview[1] = gl.mic_overview[0];
			gl.mic_overview[0] = k;
			while(f<6){
				coeff += gl.mic_overview[f];
				f++;
			}
			coeff /= 7;
#if F_DETECTION > 0
			micPower = 0.05 * maxPower() + (1 - 0.05) * micPower;
			if (micPower>37) {
				return 'f';
			}
#endif
			if(coeff<30 && coeff>20){
				return 'u';
			}
			else {
				if(coeff<33){
					return 'e';
				}
				else{
					if(coeff<46){
						return 'o';
					}
					else{
						if(coeff<60){
							return 'v';
						}
						else{
							if(coeff<80){
								return 'h';
							}
							else{
								if(coeff>80){
									return 's';
								}
								else{
									return 'm';
								}
							}
						}
					}
				}
			}
		}
		else{
			return ' ';
		}
	}
#endif
}
