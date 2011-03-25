#ifndef _RTC_H_
#define _RTC_H_

#include <_Spi.h>

class RTC {
  public:
    RTC();
    void begin( int cs_pin );
    void GetTimeDate();
    void SetTimeDate();
    const char* GetTimeStamp();
    const char* last_timestamp;
    
    int year;
    int month;
    int day;
    
    int hour;
    int minute;
    int second;
    
  private:
    int cs;
    uint8_t rtc_mode;
    uint8_t other_mode;
    SpiDevice rtc_spi;
    char buf[18];
};

#endif
