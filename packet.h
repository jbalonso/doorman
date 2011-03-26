#ifndef _PACKET_H_
#define _PACKET_H_

#include "rtc.h"
#include <sha1.h>

const int signature_len = 20;
const int session_secret_len = signature_len;
const int max_cmd_len = 6;
const int max_args_len = 32;
const unsigned long max_signature_age = 500;

class SecurePacketSender : public Print {
  public:
    SecurePacketSender();
    void begin( RTC* _rtc, const char* secret, int secret_len );
    void set_client(Client*);
    void sign();
    virtual void write(uint8_t datum);
    using Print::write;
    
    char session_secret[session_secret_len];
    RTC* _rtc;

  protected:
    const char* _secret;

    int _hmac_initialized;
    int _secret_len;
    void _send_hash(uint8_t*);
    void _init_rekey();
    unsigned long _offset;
    Client* _client;
};

class Packet : public SecurePacketSender {
  public:
    Packet();
    void rekey();
    void timestamp();
    void send();
    boolean parse_char(const char in_byte);
    void reset();
    
    char session[18];
    unsigned long offset;
    char role;
    char cmd[max_cmd_len];
    char args[max_args_len];    
    char signature[2*signature_len];
    boolean packet_ready;
  protected:
    int field;
    int field_pos;
    uint8_t *signature_check;
    //Sha1Class recv_hash;
    boolean verify();
};

#define recv_hash Sha1

#endif

