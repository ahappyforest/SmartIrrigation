interface Signal {
	void sample();
	unsigned int maxPower();
	unsigned int power();
	unsigned int complexity(int power);
	unsigned long fpowerex(int sum, int xtra);
	int snr(int power);
	void calibrate();
	char getPhoneme(); 
	void voiceFormants();
	int goertzel(int freq);
};
