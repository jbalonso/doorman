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

// EEPROM parameters
char essid[33];
char passphrase[33];
const int secret_len = 64;
char secret[secret_len];
const int max_server_len = 32;
char server[max_server_len];
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
  get_from_addr( ADDR_HMAC_SECRET, secret );
  pkt.begin(&rtc, secret, secret_len);
  keyed = false;
  
  Serial.println("connecting to server...");
  char* srv_addr = get_from_addr( ADDR_SERVER_NAME, server );
  pkt.set_client(&client);
  was_connected = client.connect(srv_addr);
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
      // Rekey if appropriate
      if( !keyed || pkt.key_expired() ) {
        pkt.rekey();
        keyed = true;
      }
      if (client.available()) {
        char c = client.read();
        if( pkt.parse_char(c) ) {
          if( pkt.packet_ready ) { 
            if( 0 == strcmp(pkt.cmd, "PING") ) send_ping();
            else if( 0 == strcmp(pkt.cmd, "OPEN") ) do_open();
            else if( 0 == strcmp(pkt.cmd, "TIME") ) do_time();
            else if( 0 == strcmp(pkt.cmd, "PANIC") ) do_panic();
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

// Send a PING packet
void send_ping() {
  strcpy(pkt.cmd, "PING");
  strcpy(pkt.args, "");
  pkt.timestamp();
  pkt.send();
}

// Open the door
void do_open() {
  strcpy(pkt.cmd, "OPEN");
  pkt.timestamp();
  pkt.send();
}

// Update the RTC
void do_time() {
  int field = 1;
  int pos = 0;
  
  for( int i=0; pkt.args[i]; i++ )
    set_datetime(&field, &pos, pkt.args[i]);
    
  pkt.rekey();
  keyed = true;
}

// Engage emergency lockout (manual reset will be required)
void do_panic() {
  strcpy(pkt.cmd, "PANIC");
  strcpy(pkt.args, "");
  pkt.timestamp();
  pkt.send();
  Serial.println("PANIC received: engaging lockout.");
  delay(1000);
  while(1);
}

int _ss_field = 0;
int _ss_char = 0;
void service_serial() {
  if( Serial.available() > 0 ) {
    if( _ss_field > 0 && _ss_field <= 6 ) set_datetime(&_ss_field, &_ss_char, Serial.read());
    else if( _ss_field == 7 ) read_str_into_eeprom(ADDR_WIFI_ESSID, essid, "Setting ESSID: ");
    else if( _ss_field == 8 ) read_str_into_eeprom(ADDR_WIFI_SECRET, passphrase, "Setting network Passphrase: ");
    else if( _ss_field == 9 ) set_secret();
    else if( _ss_field == 10 ) read_str_into_eeprom(ADDR_SERVER_NAME, server, "Setting server Hostname: ");
    else {
      switch( Serial.read() ) {
        case 'T':  _ss_field = 1; break;  // set Time
        case 'E':  _ss_field = 7; break;  // set Essid
        case 'P':  _ss_field = 8; break;  // set wireless Passphrase
        case 'S':  _ss_field = 9; break;  // set shared Secret
        case 'H':  _ss_field = 10; break; // set Host
        default: Serial.println("Unknown command");
      }
    }
  }
}

void read_str_into_eeprom( uint16_t addr, char* dst, const char* msg ) {
  // Read characters into buffer, ignoring line feeds
  char c = Serial.read();
  if( c == '\r' ) return;
  dst[_ss_char++] = c;
  
  // Terminate on carriage return
  if( dst[_ss_char-1] == '\n' ) {
    // String should be null-terminated
    dst[_ss_char-1] = 0;
    
    // Save to EEPROM
    write_to_addr(addr, dst, _ss_char);
    Serial.print( msg );
    Serial.println( dst );

    // Reset
    _ss_char = 0;
    _ss_field = 0;
  }
}

byte _sdt_datetime[] = {0, 0, 0, 0, 0, 0}; // MM DD YYY, HH MM SS
char _sdt_parse[] = {'\0', '\0', '\0'};

// Tmmddyyhhmmss
void set_datetime(int* field, int* pos, char in_char) {
  _sdt_parse[(*pos)++] = in_char;
  if( *pos == 2 ) {
    *pos = 0;
    _sdt_datetime[*field-1] = atoi(_sdt_parse);
    (*field)++;
    if( *field == 7 ) {
        rtc.year = _sdt_datetime[2] + 100;
        rtc.month = _sdt_datetime[0];
        rtc.day = _sdt_datetime[1];
        rtc.hour = _sdt_datetime[3];
        rtc.minute = _sdt_datetime[4];
        rtc.second = _sdt_datetime[5];
        rtc.SetTimeDate();
        Serial.println("clock set");
        *field = 0;
    }
  }
}

void set_secret() {
  // Read the hexadecimal character
  char c = Serial.read();
  
  // Skip spaces
  if( c == ' ' || c == '\r' ) return;
  
  // Terminate on carriage return
  if( c == '\n' ) {
    // Make sure the full secret has been received
    if( _ss_char != 2*secret_len )
      Serial.println("ERROR: secret underflow");
    else {
      // Save to EEPROM
      Serial.println("Setting shared Secret");
      write_to_addr(ADDR_HMAC_SECRET, secret, secret_len);
      keyed = false;
    }

    // Reset
    _ss_char = 0;
    _ss_field = 0;
    return;
  }
  
  // Warn if secret is full
  if( _ss_char >= 2*secret_len ) {
    Serial.println("ERROR: secret overflow");
    _ss_char = 0;
    _ss_field = 0;
    return;
  }
  
  // Compute the index and offset of the secret
  byte idx = _ss_char / 2;
  byte offset = 1 - (_ss_char % 2);  // High-order nybbles first
  
  // Convert the hexadecimal character into an integer
  byte val = 0;
  if( c >= 'a' ) val = 10 + c - 'a';
  else if( c >= 'A' ) val = 10 + c - 'A';
  else val = c - '0';
  
  // Update the secret accordingly
  byte mask = 0x0f << (offset * 4);
  secret[idx] &= ~mask;
  secret[idx] |= val << (offset * 4);
  
  // Advance the index
  _ss_char++;
}

