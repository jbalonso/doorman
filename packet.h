#ifndef _PACKET_H_
#define _PACKET_H_

const int session_secret_len = 64;

class SecurePacketSender : public Print {
  public:
    SecurePacketSender();
    void begin( const char* secret, int secret_len );
    void set_client(Client*);
    void sign();
    virtual void write(uint8_t datum);
    using Print::write;
  private:
    const char* _secret;
    char _session_secret[session_secret_len];
    int _hmac_initialized;
    int _secret_len;
    void _send_hash(uint8_t*);
    void _init_rekey();
    Client* _client;
};

#endif

