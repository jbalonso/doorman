#include <SPI.h>

#include "eeprom_config.h"

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
#include "rtc.h"
#include "packet.h"
#include "sha1.h"

Server server(4269);
RTC rtc;

char essid[33];  // 63
char passphrase[33];
char secret[] = "1234567890123456789012345678901234567890123456789012345678901234";

Packet pkt;
boolean keyed;
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
  
  Serial.println("initializing RTC...");
  rtc.begin(6);

  Serial.println("initializing security engine...");
  pkt.begin(&rtc, secret, 64);
  keyed = false;
  
  Serial.println("launching server...");
  server.begin();
}

void loop() {
  //String timestamp = ReadTimeDate();
  service_serial();
  
  Client client = server.available();
  if (client) {
    while (client.connected()) {
      pkt.set_client(&client);
      if (client.available()) {
        char c = client.read();
        if( pkt.parse_char(c) ) {
          if( pkt.packet_ready ) client.println("accepted!");
          else {
            client.println("rejected!");
            if( !keyed ) {
              // Rekey if not already done
              pkt.rekey();
              keyed = true;
            } else {
              strcpy(pkt.cmd, "PING");
              strcpy(pkt.args, "");
              pkt.timestamp();
              pkt.send();
            }
          }
            
        }
      }
    }
    // give the web browser time to receive the data
    delay(100);
    client.stop();
    keyed = false;
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
        rtc.year = _sdt_datetime[2] + 100;
        rtc.month = _sdt_datetime[0];
        rtc.day = _sdt_datetime[1];
        rtc.hour = _sdt_datetime[3];
        rtc.minute = _sdt_datetime[4];
        rtc.second = _sdt_datetime[5];
        rtc.SetTimeDate();
        Serial.println("clock set");
        _ss_field = 0;
    }
  }
}
