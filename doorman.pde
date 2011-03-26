#include <SPI.h>

#include "eeprom_config.h"
#include <WiFly.h>
#include <_Spi.h> // borrow the SPI library used in WiFly
#include <TrueRandom.h>
#include "rtc.h"
#include "packet.h"
#include "sha1.h"

Client client((const char*) NULL, 4269);
RTC rtc;

char essid[33];  // 63
char passphrase[33];
char secret[] = "1234567890123456789012345678901234567890123456789012345678901234";
const char server[] = "jalonso-laptop.jayst";
const int retries_before_reset = 16;


Packet pkt;
boolean keyed;
boolean was_connected;
void setup() {  
  Serial.begin(9600);
  Serial.println("doorman booting...");
  WiFly.begin();
  
  Serial.println("seeding random number generator...");
  randomSeed(TrueRandom.random());
  
  wifly_init();
  
  Serial.println("initializing RTC...");
  rtc.begin(6);

  Serial.println("initializing security engine...");
  pkt.begin(&rtc, secret, 64);
  keyed = false;
  
  Serial.println("connecting to server...");
  pkt.set_client(&client);
  was_connected = client.connect(server);
  if( !was_connected ) client.stop();
  
}

int retries;
void wifly_init() {
  retries = 0;
  
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
    WiFly.configure(WIFLY_BAUD, 38400);
    Serial.print("IP: ");
    Serial.println(WiFly.ip());
  } else {
    Serial.println("wifi credentials not found!");
  }
}

void loop() {
  //String timestamp = ReadTimeDate();
  service_serial();

  if( was_connected && client.connected() ) { 
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
  } else {
    // Reset connection information
    Serial.println("lost connection...");
    if( was_connected ) client.stop();
    keyed = false;
    
    // Wait
    Serial.println("waiting...");
    delay(1000);
    
    // Attempt connection to server
    Serial.println("reconnecting...");
    was_connected = client.connect(server);
    if( !was_connected ) client.stop();
    if( !was_connected && ++retries > retries_before_reset ) wifly_init();
    if( was_connected ) retries = 0;
  }
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
