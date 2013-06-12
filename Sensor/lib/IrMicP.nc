module IrMicP
{
  provides interface SplitControl;
  provides interface MicSetting;
  provides interface Atm128AdcConfig as MicAtm128AdcConfig;

  uses interface Timer<TMilli>;
  uses interface GeneralIO as MicPower;
  uses interface GeneralIO as MicMuxSel;
  uses interface MicaBusAdc as MicAdc;
}
implementation 
{
  
  command error_t SplitControl.start()
  {
    call MicPower.makeOutput();
    call MicPower.set();
    call MicMuxSel.makeOutput();    
    call MicMuxSel.clr();
		
    call MicSetting.muxSel(1);  // Set the mux so that raw microhpone output is selected
    call MicSetting.gainAdjust(0);  // Set the gain of the microphone.

    call Timer.startOneShot(1200); 
    return SUCCESS;
  }

  event void Timer.fired() {
    signal SplitControl.startDone(SUCCESS);
  }
  
  command error_t SplitControl.stop()
  {
    call MicPower.clr();
    call MicPower.makeInput();

    signal SplitControl.stopDone(SUCCESS);
    return SUCCESS;
  }
  
  command error_t MicSetting.muxSel(uint8_t sel)
  {
    if (sel == 0)
    {
      call MicMuxSel.clr();
      return SUCCESS;
    }
    else if (sel == 1)
    {
      call MicMuxSel.set();
      return SUCCESS;
    }
    return FAIL;
  }
  
  command error_t MicSetting.startMic(){
    call MicPower.makeOutput();
    call MicPower.set();
	return SUCCESS;
  }
  
  command error_t MicSetting.stopMic(){
	call MicPower.makeOutput();
        call MicPower.clr();
	return SUCCESS;
  }
  
  command error_t MicSetting.gainAdjust(uint8_t val)    { return SUCCESS; }
  command uint8_t MicSetting.readToneDetector()         { return SUCCESS; }
  async command error_t MicSetting.enable()             { return SUCCESS; }
  async command error_t MicSetting.disable()            { return SUCCESS; }
  default async event error_t MicSetting.toneDetected() { return SUCCESS; }
  async command uint8_t MicAtm128AdcConfig.getChannel() { return call MicAdc.getChannel(); }
  async command uint8_t MicAtm128AdcConfig.getRefVoltage() { return ATM128_ADC_VREF_OFF; }
  async command uint8_t MicAtm128AdcConfig.getPrescaler()  { return ATM128_ADC_PRESCALE; }
}
