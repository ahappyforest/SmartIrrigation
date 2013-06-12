#ifndef _PIN_CONFIG_H
#define _PIN_CONFIG_H

#define DS18B20_DQ           MicaBusC.PW2  // DS18b20的数据线
#define DS18B20_POWER        MicaBusC.PW4  // 电源线控制线, 低电平有效
#define SOLENOIDVALVES_POWER MicaBusC.PW7  // 电磁阀们控制线, 低电平有效
#define YL69_POWER           MicaBusC.PW1  // 土壤湿度传感器， 电源控制线, 低电平有效
#define YL69_ADO             MicaBusC.Adc7 // 土壤湿度传感器, ADC采集线, 低电平有效

#endif
