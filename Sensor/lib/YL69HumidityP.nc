module YL69HumidityP {
	provides interface Atm128AdcConfig;
	uses interface MicaBusAdc as SoilHumidityAdc;
}
implementation
{
	async command uint8_t Atm128AdcConfig.getChannel() {
		return call SoilHumidityAdc.getChannel();
	}
	
	async command uint8_t Atm128AdcConfig.getRefVoltage() {
//		return ATM128_ADC_VREF_OFF;
		return ATM128_ADC_VREF_AVCC;
	}

	async command uint8_t Atm128AdcConfig.getPrescaler() {
		return ATM128_ADC_PRESCALE;
	}
}
