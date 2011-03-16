#include <EEPROM.h>
#include "eeprom_config.h"

int len_from_addr(uint16_t addr) {
  return EEPROM.read(addr);
}

char* get_from_addr(uint16_t addr, char* buf) {
  int len = len_from_addr(addr);
  if( len == 255 ) return NULL;
  
  for( int i = 0; i < len; i++ )
    buf[i] = EEPROM.read(addr+i+1);
  return buf;
}

void write_to_addr(uint16_t addr, const char *buf, uint8_t len) {
  EEPROM.write(addr, len);
  for( int i = 0; i < len; i++ )
    EEPROM.write(addr + i + 1, buf[i]);
}
