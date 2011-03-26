#ifndef _EEPROM_CONFIG_H_
#define _EEPROM_CONFIG_H_

const uint16_t ADDR_WIFI_ESSID =  0x0000;  // Max length: 63+1
const uint16_t ADDR_WIFI_SECRET = 0x0040;  // Max length: 63+1
const uint16_t ADDR_HMAC_SECRET = 0x0100;  // Max length: 64+1
const uint16_t ADDR_SERVER_NAME = 0x0200;  // Max length: 32+1

#endif
