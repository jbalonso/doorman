#include <SPI.h>
#include <stdio.h>

const int  cs=6; // RTC chip select 

#include <_Spi.h> // borrow the SPI library used in WiFly

SpiDevice rtc_spi;

byte rtc_mode, wifly_mode;

//=====================================
int RTC_init(){ 
  rtc_spi.begin(cs);
  SPCR = rtc_mode;
  rtc_spi.select();
  rtc_spi.transfer(0x8E);
  rtc_spi.transfer(0x60);
  rtc_spi.deselect();
  SPCR = wifly_mode;
  delay(10);
	  //pinMode(cs,OUTPUT); // chip select
	  // start the SPI library:
	  //SPI.begin();
	  //SPI.setBitOrder(MSBFIRST); 
	  //SPI.setDataMode(SPI_MODE1); // both mode 1 & 3 should work 
	  //set control register 
	  //digitalWrite(cs, LOW);  
	  //SPI.transfer(0x8E);
	  //SPI.transfer(0x60); //60= disable Osciallator and Battery SQ wave @1hz, temp compensation, Alarms disabled
	  //digitalWrite(cs, HIGH);
	  //delay(10);
}
//=====================================
int SetTimeDate(int d, int mo, int y, int h, int mi, int s){ 
	int TimeDate [7]={s,mi,h,0,d,mo,y};
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
		//digitalWrite(cs, LOW);
		//SPI.transfer(i+0x80); 
		//SPI.transfer(TimeDate[i]);        
		//digitalWrite(cs, HIGH);
        }
        SPCR = wifly_mode;
}
//=====================================
String ReadTimeDate(){
	int TimeDate [7]; //second,minute,hour,null,day,month,year		
        String temp;
        char buf[17];
	for(int i=0; i<=6;i++){
		if(i==3)
			i++;
                SPCR = rtc_mode;
                rtc_spi.select();
		rtc_spi.transfer(i+0x00); 
		unsigned int n = rtc_spi.transfer(0x00);        
		rtc_spi.deselect();
                SPCR = wifly_mode;
		//digitalWrite(cs, LOW);
		//SPI.transfer(i+0x00); 
		//unsigned int n = SPI.transfer(0x00);        
		//digitalWrite(cs, HIGH);
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
        temp += millis();
        sprintf(buf, "%04u-%02u%02u-%02u%02u.%02u",
                (1900 + TimeDate[6]),
                TimeDate[5],
                TimeDate[4],
                TimeDate[2],
                TimeDate[1],
                TimeDate[0]);
        temp += ": ";
        temp += buf;
        /*
	temp += TimeDate[5];
	temp += "/" ;
	temp += TimeDate[4];
	temp += "/";
	temp += 1900L + TimeDate[6];
	temp += " ";
	temp += TimeDate[2];
	temp += ":";
	temp += TimeDate[1];
	temp += ":";
	temp += TimeDate[0];*/
        return temp;
}
