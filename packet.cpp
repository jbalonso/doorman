#include "WProgram.h"
#include "Print.h"

#include <WiFly.h>
#include "packet.h"

#include "sha1.h"

SecurePacketSender::SecurePacketSender() {
  _secret = NULL;
  _secret_len = 0;

  _hmac_initialized = 0;
  _client = NULL;
}

void SecurePacketSender::begin( const char* secret, int secret_len ) {
  _secret = secret;
  _secret_len = secret_len;
}

void SecurePacketSender::set_client(Client* client) {
  _client = client;
}

void SecurePacketSender::write(uint8_t datum) {
  _client->write(datum);
  if( !_hmac_initialized ) {
    Sha1.initHmac( (const uint8_t *) _session_secret, session_secret_len );
    _hmac_initialized = 1;
  }
  Sha1.write(datum);
}

void SecurePacketSender::_init_rekey() {
    Sha1.initHmac( (const uint8_t *) _secret, _secret_len );
    _hmac_initialized = 1;
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
