#include <SPI.h>
#include <stdio.h>

#include "rtc.h"

RTC::RTC() {}

void RTC::begin(int cs_pin) { 
  // Save configuration parameters
  cs = cs_pin;
  other_mode = SPCR;
  
  // Initialize the SPI framework
  rtc_spi.begin(cs);
  rtc_mode = (SPCR & ~SPI_MODE_MASK) | SPI_MODE1;
  
  // Configure the RTC device
  SPCR = rtc_mode;
  rtc_spi.select();
  rtc_spi.transfer(0x8E);
  rtc_spi.transfer(0x60);
  rtc_spi.deselect();
  SPCR = other_mode;
  
  // Pause
  delay(10);
}

void RTC::SetTimeDate(){ 
	int TimeDate [7]={second,minute,hour,0,day,month,year};
        SPCR = rtc_mode;
	for(int i=0; i<=6;i++){
		if(i==3)
			i++;
		int b= TimeDate[i]/10;
		int a= TimeDate[i]-b*10;
		if(i==2){
			if (b==2)
				b=B00000010;
			else if (b==1)
				b=B00000001;
		}	
		TimeDate[i]= a+(b<<4);
		
                
                rtc_spi.select();
		rtc_spi.transfer(i+0x80); 
		rtc_spi.transfer(TimeDate[i]);
                rtc_spi.deselect();
        }
        SPCR = other_mode;
}
//=====================================
void RTC::GetTimeDate(){
	int TimeDate [7]; //second,minute,hour,null,day,month,year		
	for(int i=0; i<=6;i++){
		if(i==3)
			i++;

                SPCR = rtc_mode;
                rtc_spi.select();
		rtc_spi.transfer(i+0x00); 
		unsigned int n = rtc_spi.transfer(0x00);        
		rtc_spi.deselect();
                SPCR = other_mode;
                
		int a=n & B00001111;    
		if(i==2){	
			int b=(n & B00110000)>>4; //24 hour mode
			if(b==B00000010)
				b=20;        
			else if(b==B00000001)
				b=10;
			TimeDate[i]=a+b;
		}
		else if(i==4){
			int b=(n & B00110000)>>4;
			TimeDate[i]=a+b*10;
		}
		else if(i==5){
			int b=(n & B00010000)>>4;
			TimeDate[i]=a+b*10;
		}
		else if(i==6){
			int b=(n & B11110000)>>4;
			TimeDate[i]=a+b*10;
		}
		else{	
			int b=(n & B01110000)>>4;
			TimeDate[i]=a+b*10;	
			}
	}

        // Record time data
        year = TimeDate[6];
        month = TimeDate[5];
        day = TimeDate[4];
        hour = TimeDate[2];
        minute = TimeDate[1];
        second = TimeDate[0];
}

const char* RTC::GetTimeStamp() {
  GetTimeDate();
  sprintf(buf, "%04u-%02u%02u-%02u%02u.%02u",
          (1900 + year),
          month,
          day,
          hour,
          minute,
          second);
  buf[17] = '\0';
  last_timestamp = buf;
  return buf;
}
