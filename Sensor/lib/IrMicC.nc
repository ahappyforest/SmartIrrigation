configuration IrMicC {
	provides {
		interface Read<uint16_t>;
		interface SplitControl;
	}
}
implementation {
	components IrMicP as Device;
	components MicaBusC;
	components new AdcReadClientC() as Adc;
	components new TimerMilliC() as WarmupTimer;
	
	Device.MicPower -> MicaBusC.PW3;
	Device.MicMuxSel -> MicaBusC.PW6;
	Device.MicAdc -> MicaBusC.Adc2;
	Device.MicAtm128AdcConfig <- Adc;
	Device.Timer -> WarmupTimer;

	Read = Adc;
	SplitControl = Device;
}
