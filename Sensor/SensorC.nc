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

		interface Timer<TMilli> as DS18B20Timer;
		interface Timer<TMilli> as HumiTimer;
		interface Timer<TMilli> as TempTimer;
		interface Timer<TMilli> as LightTimer;
		interface Timer<TMilli> as MicTimer;
		
		interface Timer<TMilli> as DS18B20ResourceTimer;
		interface Timer<TMilli> as HumiResourceTimer;
		interface Timer<TMilli> as TempResourceTimer;
		interface Timer<TMilli> as LightResourceTimer;
		interface Timer<TMilli> as MicResourceTimer;

		interface Resource as DS18B20ResourceClient;
		interface Resource as HumiResourceClient;
		interface Resource as TempResourceClient;
		interface Resource as LightResourceClient;
		interface Resource as MicResourceClient;

		interface ResourceDefaultOwner as SVDefaultOwner;

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
		interface Read<uint16_t> as Microphone;
		interface SplitControl as MicControl;

#ifdef USING_REMOTE_PRINTF
		interface StdControl as PrintfControl;
#endif
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
	void process_request_sv(const request_msg_t *req);
	void process_request_sensor(const request_msg_t *req, uint8_t type);

/************************************************
* 声音识别算法相关
*************************************************/
	uint16_t power();
	uint16_t complexity(int16_t local_power);
	uint16_t maxPower();
	uint8_t getPhoneme();

#ifndef USING_SERIAL_PRINTF
void printfflush() { }
#endif

/************************************************
* 系统开始
*************************************************/
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
		
		gl.sv_switch = 0;
		gl.sv_default_status = AUTO;

		gl.sensor_period[TYPE_MIC]    = DEFAULT_MIC_PERIOD;
		gl.sensor_threshold[TYPE_MIC]    = DEFAULT_MIC_THRESHOLD;
		memset(gl.mic_reading, 0, sizeof(gl.mic_reading));
		gl.mic_reading_count = 0;
		gl.mic_avr = 0;
		memset(gl.mic_overview, 0, sizeof(gl.mic_overview));
		gl.mic_calibflag = FALSE;
		gl.mic_calib = 0;
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
		if (err == SUCCESS) {
			call CtpControl.start();
			call DripControl.start();
			call MicControl.start();
#ifdef USING_REMOTE_PRINTF
			call PrintfControl.start();
#endif

//			call DS18B20Timer.startOneShot(0);
			call HumiTimer.startOneShot(0);
			call TempTimer.startOneShot(0);
			call LightTimer.startOneShot(0);
		} else {
			report_error();
		}
	}

	event void MicControl.startDone(error_t err) {
		if (err == SUCCESS) {
	//		call MicTimer.startOneShot(0);
		} else {
			report_error();
		}
	}
	
	event void MicControl.stopDone(error_t err) { }

	event void RadioControl.stopDone(error_t err) { }

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
		} else {
			printf("radio busy\n");
			printfflush();
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
		} else {
			printfflush();
		}
	}

	event void DS18B20R.readDone(error_t err, int32_t val) {
		sensor_msg_t sm;
	//	uint8_t ch[4];
	//	uint16_t digit, decimal;
	//	memcpy(ch, &val, sizeof(int32_t));
		memset(&sm, 0, sizeof(sensor_msg_t));
		report_sensor_working();

		printfflush();

		if (err == SUCCESS) {
			call DS18B20Switch.close();

			// 如果大于某一个阈值， 就会请求打开阀门
			if (val > gl.sensor_threshold[TYPE_DS18B20] && gl.sv_default_status == AUTO) {
				call DS18B20ResourceClient.request();
			} else {
				// 否则说明要么阀值低， 不打开， 要么不是auto， 那么我们将这些操作转发到default owner，
				// 由它来决定, 然后在default owner中判断, 此时是应该打开还是关闭
				//printf("signal default granted in ds18b20 readDone\n");
				signal SVDefaultOwner.granted();
			}

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

		call DS18B20Timer.startOneShot(gl.sensor_period[TYPE_DS18B20]);
	}

	event void Humidity.readDone(error_t err, uint16_t val) {
		sensor_msg_t sm;
		memset(&sm, 0, sizeof(sensor_msg_t));
		report_sensor_working();
		//printf("humi val %d\n", val);
		//printfflush();
		if (err == SUCCESS) {
			call HumiditySwitch.close();
			if (val > gl.sensor_threshold[TYPE_YL69] && gl.sv_default_status == AUTO) {
				call HumiResourceClient.request();
			} else {
				//printf("signal default granted in Humi readDone\n");
				signal SVDefaultOwner.granted();
			}

			sm.node_id = TOS_NODE_ID;
			sm.sensor_type = YL69;
	
			sm.sensor_value = val;
			////printf("send sensor msg in humi\n");
			ctp_send_sensor_msg(&sm);
		}
		call HumiTimer.startOneShot(gl.sensor_period[TYPE_YL69]);
	}

	event void Temp.readDone(error_t err, uint16_t val) {
		sensor_msg_t sm;
		memset(&sm, 0, sizeof(sensor_msg_t));
		report_sensor_working();
		//printf("temp val %d\n", val);
		if (err == SUCCESS) {
			if (val > gl.sensor_threshold[TYPE_TEMP] && gl.sv_default_status == AUTO) {
				call TempResourceClient.request();
			} else {
				//printf("signal default granted in Temp readDone\n");
				signal SVDefaultOwner.granted();
			}
		
			sm.node_id = TOS_NODE_ID;
			sm.sensor_type = THERMISTOR;
	
			sm.sensor_value = val;
			//printf("send sensor msg in temp\n");
			ctp_send_sensor_msg(&sm);
		}
		call TempTimer.startOneShot(gl.sensor_period[TYPE_TEMP]);
	}

	event void Light.readDone(error_t err, uint16_t val) {
		sensor_msg_t sm;
		memset(&sm, 0, sizeof(sensor_msg_t));
		report_sensor_working();
		//printf("light val %d\n", val);
		if (err == SUCCESS) {
			if (val < gl.sensor_threshold[TYPE_LIGHT] && gl.sv_default_status == AUTO) {
				call LightResourceClient.request();
			} else {
				//printf("signal default granted in Light readDone\n");
				signal SVDefaultOwner.granted();
			//	call SVSwitch.close();
			}

			sm.node_id = TOS_NODE_ID;
			sm.sensor_type = LIGHT;
	
			sm.sensor_value = val;
			//printf("send sensor msg in light\n");
			ctp_send_sensor_msg(&sm);
		}
		call LightTimer.startOneShot(gl.sensor_period[TYPE_LIGHT]);
	}

	event void Microphone.readDone(error_t err, uint16_t val) {
#if defined(USING_USPEECH)
		uint8_t sample_result;
#elif defined(USING_MIC_AVERAGE)
		uint8_t i;
#endif
	
		if (err != SUCCESS) {
			val = 0xFFFF;
			report_error();
		}
		
		report_sensor_working();
#if defined(USING_USPEECH)
		
		if (gl.mic_reading_count < NREADINGS) {
			gl.mic_reading[gl.mic_reading_count++] = val;

			// 如果没有对Mic进行校正， 先校正
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
			// 开始进行声音识别
			gl.mic_reading_count = 0;

			sample_result = getPhoneme();

			// 发包
		}
		call MicTimer.startOneShot(gl.sensor_period[TYPE_MIC]);	

#elif defined(USING_MIC_AVERAGE)
		// 如果已经校验过了， 那么我们需要进行滤波
		if (gl.mic_calibflag && val < gl.mic_calib) {
			val = gl.mic_calib;
		}

		if (gl.mic_reading_count < NREADINGS) {
			gl.mic_reading[gl.mic_reading_count++] = val;
			// 如果没有对Mic进行校正， 先校正
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

			// 开始处理
			gl.mic_reading_count = 0;
			for (i = 0; i < gl.mic_reading_count; i++) {
				gl.mic_avr += gl.mic_reading[i];	
			}

			gl.mic_avr /= NREADINGS;

			if (gl.mic_avr > gl.sensor_threshold[TYPE_MIC] && gl.sv_default_status == AUTO) {
				call MicResourceClient.request();
			} else {
				//printf("signal default granted in Mic readDone\n");
				signal SVDefaultOwner.granted();
			}
		
			// 由于不需要发往客户端， 因此这里就结束了
		}

		call MicTimer.startOneShot(gl.sensor_period[TYPE_MIC]);	
#else
#error "you must choice the mic working mode!\n"
#endif
	}
	void process_request_sv(const request_msg_t *req) {
		reply_msg_t reply;
		memset(&reply, 0, sizeof(reply_msg_t));
		reply.node_id = TOS_NODE_ID;
		reply.transaction_number = req->transaction_number;
		reply.request_code = req->request_code;
		reply.request_device = req->request_device;
		reply.request_data = req->request_data;

		switch(req->request_code) {
			case SET_SWITCH_STATUS_REQUEST:
				if (req->request_data == ON) {
					gl.sv_default_status = ON;
					//printf("request data: ON\n");
					//printfflush();
				} else if (req->request_data == OFF) {
					gl.sv_default_status = OFF;
					//printf("request data: OFF\n");
					//printfflush();
				} else if (req->request_data == AUTO) {
					gl.sv_default_status = AUTO;
					//printf("request data: AUTO\n");
					//printfflush();
				}
				reply.status = SUCCESS;
				break;
			case GET_SWITCH_STATUS_REQUEST:
				reply.status = SUCCESS;
			case GET_READING_REQUEST:
			case SET_READING_PERIOD_REQUEST:
			case GET_READING_PERIOD_REQUEST:
			case SET_READING_THRESHOLD_REQUEST:
			case GET_READING_THRESHOLD_REQUEST:
				return;
			default:
				return;
		}
		//printf("signal default granted in request sv\n");
		signal SVDefaultOwner.granted();
		ctp_send_reply_msg(&reply);
	}

	void process_request_sensor(const request_msg_t *req, uint8_t type) {
		reply_msg_t reply;
		memset(&reply, 0, sizeof(reply_msg_t));
		reply.node_id = TOS_NODE_ID;
		reply.transaction_number = req->transaction_number;
		reply.request_code = req->request_code;
		reply.request_device = req->request_device;
		reply.request_data = req->request_data;

		switch(req->request_code) {
			case SET_SWITCH_STATUS_REQUEST:
			case GET_SWITCH_STATUS_REQUEST:
			case GET_READING_REQUEST:
				return;
			case SET_READING_PERIOD_REQUEST:
				//printf("set type: %d, period : %d\n", type, req->request_data); 
				gl.sensor_period[type] = req->request_data;
				reply.status = SUCCESS;
				break;
			case GET_READING_PERIOD_REQUEST:
				reply.request_data = gl.sensor_period[type];
				reply.status = SUCCESS;
				break;
			case SET_READING_THRESHOLD_REQUEST:
				//printf("set type: %d, threshold : %d\n", type, req->request_data); 
				gl.sensor_threshold[type] = req->request_data;
				reply.status = SUCCESS;
				break;
			case GET_READING_THRESHOLD_REQUEST:
				reply.request_data = gl.sensor_threshold[type];
				reply.status = SUCCESS;
				break;
			default: 
				return;
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
			default: return;
		}
		//printf("received a command\n");
		//printfflush();
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


	event void DS18B20Timer.fired() {
		call DS18B20Switch.open();
		call DS18B20R.read();
	}


	event void HumiTimer.fired() {
		call HumiditySwitch.open();
		call Humidity.read();
	}

	event void TempTimer.fired() {
		call Temp.read();
	}

	event void LightTimer.fired() {
		call Light.read();	
	}

	event void MicTimer.fired() {
		call Microphone.read();
	}

	// 如果多个传感器需要操作电磁阀门， 这里我们使用arbiter进行仲裁
	event void DS18B20ResourceTimer.fired() {
		//printf("now close SVSwitch from ds18b20Timer\n");
		call SVSwitch.close();
		call DS18B20ResourceClient.release();
	}

	event void HumiResourceTimer.fired() {
		//printf("now close SVSwitch from humiTimer\n");
		call SVSwitch.close();
		call HumiResourceClient.release();
	}

	event void TempResourceTimer.fired() {
		//printf("now close SVSwitch from tempTimer\n");
		call SVSwitch.close();
		call TempResourceClient.release();
	}

	event void LightResourceTimer.fired() {
		//printf("now close SVSwitch from lightTimer\n");
		call SVSwitch.close();
		call LightResourceClient.release();
	}

	event void MicResourceTimer.fired() {
		//printf("now close SVSwitch from micTimer\n");
		call SVSwitch.close();
		call MicResourceClient.release();
	}

	event void DS18B20ResourceClient.granted() {
		// 打开电磁阀门
		call SVSwitch.open();
		call DS18B20ResourceTimer.startOneShot(SV_HOLD_PERIOD);
		//printf("DS18B20 open SV, hold on %d times\n", SV_HOLD_PERIOD);
	}

	event void HumiResourceClient.granted() {
		// 打开电磁阀门
		call SVSwitch.open();
		call HumiResourceTimer.startOneShot(SV_HOLD_PERIOD);
		//printf("Humi open SV, hold on %d times\n", SV_HOLD_PERIOD);
	}

	event void TempResourceClient.granted() {
		// 打开电磁阀门
		call SVSwitch.open();
		call TempResourceTimer.startOneShot(SV_HOLD_PERIOD);
		//printf("Temp open SV, hold on %d times\n", SV_HOLD_PERIOD);
	}

	event void LightResourceClient.granted() {
		// 打开电磁阀门
		call SVSwitch.open();
		call LightResourceTimer.startOneShot(SV_HOLD_PERIOD);
		//printf("Light open SV, hold on %d times\n", SV_HOLD_PERIOD);
	}

	event void MicResourceClient.granted() {
		// 打开电磁阀门
		call SVSwitch.open();
		call MicResourceTimer.startOneShot(SV_HOLD_PERIOD);
		//printf("Mic open SV, hold on %d times\n", SV_HOLD_PERIOD);
	}

	task void check_sv() {
		uint8_t local_val = gl.sv_default_status;
		if (local_val == OFF) {
			call SVSwitch.close();
			//printf("Now, close the switch, switch status: %d\n\n\n", call SVSwitch.getStatus());
		} else if (local_val == ON) {
			call SVSwitch.open();
			//printf("Now, open the switch, switch status: %d\n\n\n", call SVSwitch.getStatus());
		} else if (local_val == AUTO) {
		//	call SVSwitch.close();
		// 	auto 就什么也不做
		//	//printf("Now, set auto\n");
		} else {
			;
		}
	}

	async event void SVDefaultOwner.granted() {
		// 在这里决定吧
		post check_sv();

		//volatile uint8_t local_val;
		//atomic {
		//	local_val = gl.sv_default_status;
		//}
		//if (local_val == OFF) {
		//	call SVSwitch.close();
		//} else if (local_val == ON) {
		//	call SVSwitch.open();
		//} else if (local_val == AUTO) {
		//	call SVSwitch.close();
		// 	auto 就什么也不做
		//	//printf("Now, set auto\n");
		//} else {
		//	;
		//}

	}

	async event void SVDefaultOwner.requested() {
		call SVDefaultOwner.release();
	}

	async event void SVDefaultOwner.immediateRequested() {
	  	call SVDefaultOwner.release();
	}

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
}
