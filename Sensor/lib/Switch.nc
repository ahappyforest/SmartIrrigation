interface Switch {
	command error_t open(void);
	command error_t close(void);
	command error_t toggle(void);
	command uint8_t getStatus(void);
}
