interface WaterPumpControl<val_t> {
	command error_t setPressure(val_t val);
	command error_t getPressure(val_t val);
}	
	
