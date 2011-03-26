#include "WProgram.h"
#include "Print.h"

#include <WiFly.h>
#include "packet.h"

#include "sha1.h"

#include <stdio.h>

SecurePacketSender::SecurePacketSender() {
  _secret = NULL;
  _secret_len = 0;

  _hmac_initialized = 0;
  _client = NULL;
}

void SecurePacketSender::begin( RTC* rtc, const char* secret, int secret_len ) {
  _secret = secret;
  _secret_len = secret_len;
  _rtc = rtc;
}

void SecurePacketSender::set_client(Client* client) {
  _client = client;
}

void SecurePacketSender::write(uint8_t datum) {
  _client->write(datum);
  if( !_hmac_initialized ) {
    Sha1.initHmac( (const uint8_t *) session_secret, session_secret_len );
    _hmac_initialized = 1;
  }
  Sha1.write(datum);
}

void SecurePacketSender::sign() {
  if( _hmac_initialized ) {
    _hmac_initialized = 0;
    _send_hash( Sha1.resultHmac() );    
  }
}

void SecurePacketSender::_send_hash(uint8_t* hash) {
  int i;
  _client->print(';');
  for (i=0; i<20; i++) {
    _client->print("0123456789abcdef"[hash[i]>>4]);
    _client->print("0123456789abcdef"[hash[i]&0xf]);
  }
  _client->println();
}

Packet::Packet() {}

void Packet::rekey() {
  // Initialize HMAC on main shared secret, not session secret
  Sha1.initHmac( (const uint8_t *) _secret, _secret_len );
  
  // Update session string
  _rtc->GetTimeStamp();
  _offset = millis();
  
  // Initialize the packet
  role = 'S';
  strcpy(cmd, "REKEY");
  sprintf(args, "SHA1 %04d", random(10000));
  timestamp();
  
  // Compute the session key
  Sha1.print(_rtc->last_timestamp);
  Sha1.print(';');
  Sha1.print(offset);
  Sha1.print(';');
  Sha1.print(role);
  Sha1.print(';');
  Sha1.print(cmd);
  Sha1.print(';');
  Sha1.print(args);
  memcpy(session_secret, Sha1.resultHmac(), session_secret_len );
  
  // Transmit the packet
  send();
}

void Packet::timestamp() { offset = millis() - _offset; }

void Packet::send() {
  // Always slave
  role = 'S';
  
  // Transmit packet
  print(_rtc->last_timestamp);
  print(';');
  print(offset);
  print(';');
  print(role);
  print(';');
  print(cmd);
  print(';');
  print(args);
  sign();
}

void Packet::reset() {
  field = 0;
  field_pos = 0;
  packet_ready = false;
}

boolean Packet::verify() {
  // Verify session
  if( memcmp( session, _rtc->last_timestamp, 18 ) ) return false;
  
  // Accept only master-role messages
  if( role != 'M' ) return false;
  
  // Determine if the signature age is acceptible
  unsigned long time = millis() - _offset;
  unsigned long age = time - offset;
  if( age > max_signature_age && -age > max_signature_age ) return false;
  
  // Determine if the session age is acceptible
  // FIXME=================================================================
  
  // Verify signature
  // FIXME: THIS ROUTINE IS VULNERABLE TO SIDE CHANNEL ATTACKS!
  int i;
  for (i=0; i<20; i++) {
    if( signature[2*i]   != ("0123456789abcdef"[signature_check[i]>>4])  ) return false;
    if( signature[2*i+1] != ("0123456789abcdef"[signature_check[i]&0xf]) ) return false;
  }
  
  // Operation Complete!
  return true;
}

boolean Packet::parse_char(const char in_byte) {
  if( in_byte == '\n' && field != 5 ) { reset(); return true; }
  
  switch(field) {
    case 0:
      if( field_pos == 0 ) recv_hash.initHmac( (const uint8_t *) session_secret, session_secret_len );
      recv_hash.write(in_byte);
      if( in_byte == ';' ) { field++; field_pos = 0; }
      else session[field_pos++] = in_byte;
      break;
    case 1:
      if( field_pos == 0 ) offset = 0;
      recv_hash.write(in_byte);
      if( in_byte == ';' ) { field++; field_pos = 0; }
      else { offset *= 10; offset += (in_byte - '0'); field_pos++; }
      break;
    case 2:
      if( field_pos == 0 ) role = '\0';
      field_pos++;
      recv_hash.write(in_byte);
      if( in_byte == ';' ) { field++; field_pos = 0; }
      else { role = in_byte; }
      break;
    case 3:
      recv_hash.write(in_byte);
      if( in_byte == ';' ) { field++; cmd[field_pos] = '\0'; field_pos = 0; }
      else {
        if( field_pos >= max_cmd_len - 1 ) break;
        cmd[field_pos++] = in_byte;
      }
      break;
    case 4:
      if( in_byte == ';' ) {
        signature_check = recv_hash.resultHmac();
        field++;
        args[field_pos] = '\0';
        field_pos = 0;
      }
      else {
        recv_hash.write(in_byte);
        if( field_pos >= max_args_len - 1 ) break;
        args[field_pos++] = in_byte;
      }
      break;
    case 5:
      if( in_byte == '\n' ) {
        // Verify the signature
        packet_ready = verify();
        field = 0; field_pos = 0;
        return true;
      }
      else {
        if( field_pos >= 2*signature_len ) break;
        signature[field_pos++] = in_byte;
      }
  }
  
  // Indicate that we are reading bytes
  return false;
}
