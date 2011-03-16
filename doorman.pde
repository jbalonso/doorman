//#include <rtc.h>
#include <SPI.h>
#include <stdio.h>

#include "eeprom_config.h"

const int  cs=6; // RTC chip select 

/*
 * Web Server
 *
 * (Based on Ethernet's WebServer Example)
 *
 * A simple web server that shows the value of the analog input pins.
 */

#include <WiFly.h>
#include <_Spi.h> // borrow the SPI library used in WiFly
#include <TrueRandom.h>

Server server(80);
SpiDevice rtc_spi;
//RTC rtc(8);

byte rtc_mode, wifly_mode;

char essid[63];
char passphrase[63];

void setup() {  
  Serial.begin(9600);
  Serial.println("doorman booting...");
  WiFly.begin();
  
  Serial.println("seeding random number generator...");
  randomSeed(TrueRandom.random());
  
  Serial.println("loading wifi credentials...");
  char* _essid = get_from_addr( ADDR_WIFI_ESSID, essid );
  char* _passphrase = get_from_addr( ADDR_WIFI_SECRET, passphrase );
  
  if( _essid && _passphrase ) {
    Serial.println("connecting to wifi network...");
    if (!WiFly.join(essid, passphrase)) {
      do {
        Serial.println("waiting before retry...");
        delay(5000);
      } while( !WiFly.join(essid, passphrase) );
    }
    Serial.print("IP: ");
    Serial.println(WiFly.ip());
  } else {
    Serial.println("wifi credentials not found!");
  }

  wifly_mode = SPCR;
  rtc_mode = (SPCR & ~SPI_MODE_MASK) | SPI_MODE1;
  
  RTC_init();
  Serial.println("RTC initialized");

  
  server.begin();
}

void loop() {
  //String timestamp = ReadTimeDate();
  service_serial();
  
  Client client = server.available();
  if (client) {
    // an http request ends with a blank line
    boolean current_line_is_blank = true;
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        // if we've gotten to the end of the line (received a newline
        // character) and the line is blank, the http request has ended,
        // so we can send a reply
        if (c == '\n' && current_line_is_blank) {
          // send a standard http response header
          client.println("HTTP/1.1 200 OK");
          client.println("Content-Type: text/html");
          client.println();
          
          // output the value of each analog input pin
          for (int i = 0; i < 6; i++) {
            client.print("analog input ");
            client.print(i);
            client.print(" is ");
            client.print(analogRead(i));
            client.println("<br />");
            client.print("time is ");
            //client.print(timestamp);
            client.print(ReadTimeDate());
            client.println("<br />");

          }
          break;
        }
        if (c == '\n') {
          // we're starting a new line
          current_line_is_blank = true;
        } else if (c != '\r') {
          // we've gotten a character on the current line
          current_line_is_blank = false;
        }
      }
    }
    // give the web browser time to receive the data
    delay(100);
    client.stop();
  }
  
  /*rtc.GetDateTime();
  String temp;
  Serial.print(rtc.hour); Serial.print(':'); Serial.print(rtc.minute); Serial.print(':'); Serial.print(rtc.second);
  Serial.print(' ');
  Serial.print(rtc.month); Serial.print('/'); Serial.print(rtc.day); Serial.print('/');  Serial.print(rtc.year);
  Serial.println(temp);*/
  //Serial.println(ReadTimeDate());
  //delay(1000);
}

int _ss_field = 0;
int _ss_char = 0;
void service_serial() {
  if( Serial.available() > 0 ) {
    if( _ss_field > 0 && _ss_field <= 6 ) set_datetime();
    else if( _ss_field == 7 ) set_essid();
    else if( _ss_field == 8 ) set_passphrase();
    else {
      switch( Serial.read() ) {
        case 'T':  _ss_field = 1; break;  // set Time
        case 'E':  _ss_field = 7; break;  // set Essid
        case 'P':  _ss_field = 8; break;  // set wireless Passphrase
        case 'S':  _ss_field = 9; break;  // set shared Secret
        default: Serial.println("Unknown command");
      }
    }
  }
}

void set_essid() {
  essid[_ss_char++] = Serial.read();
  
  // Terminate on carriage return
  if( essid[_ss_char-1] == '\r' ) {
    // String should be null-terminated
    essid[_ss_char] = 0;
    
    // Save to EEPROM
    write_to_addr(ADDR_WIFI_ESSID, essid, _ss_char);
    Serial.print( "Setting ESSID: " );
    Serial.println( essid );

    // Reset
    _ss_char = 0;
    _ss_field = 0;
  }
}

void set_passphrase() {
  passphrase[_ss_char++] = Serial.read();
  
  // Terminate on carriage return
  if( passphrase[_ss_char-1] == '\r' ) {
    // String should be null-terminated
    passphrase[_ss_char] = 0;
    
    // Save to EEPROM
    write_to_addr(ADDR_WIFI_SECRET, passphrase, _ss_char);
    Serial.print( "Setting network passphrase: " );
    Serial.println( passphrase );

    // Reset
    _ss_char = 0;
    _ss_field = 0;
  }
}

byte _sdt_datetime[] = {0, 0, 0, 0, 0, 0}; // MM DD YYY, HH MM SS
char _sdt_parse[] = {'\0', '\0', '\0'};

// Tmmddyyhhmmss
void set_datetime() {
  _sdt_parse[_ss_char++] = Serial.read();
  if( _ss_char == 2 ) {
    _ss_char = 0;
    _sdt_datetime[_ss_field-1] = atoi(_sdt_parse);
    _ss_field++;
    if( _ss_field == 7 ) {
      SetTimeDate(
        _sdt_datetime[1],
        _sdt_datetime[0],
        _sdt_datetime[2] + 100,
        _sdt_datetime[3],
        _sdt_datetime[4],
        _sdt_datetime[5] );
      Serial.println("clock set");
      _ss_field = 0;
    }
  }
}

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
        sprintf(buf, "%04u-%02u%02u-%02u%02u%02u",
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
