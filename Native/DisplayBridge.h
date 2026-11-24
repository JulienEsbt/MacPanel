#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// 1: Apple brightness, 2: external DDC, 0: unavailable. No write occurs on read.
int MPReadBrightness(CGDirectDisplayID display, double *value);
bool MPWriteBrightness(CGDirectDisplayID display, double value);
bool MPDecodeBrightnessReply(const uint8_t *bytes, size_t size, uint16_t *current, uint16_t *maximum);
bool MPDecodeVCPReply(const uint8_t *bytes, size_t size, uint8_t code, uint16_t *current, uint16_t *maximum);
bool MPReadDisplayVolume(CGDirectDisplayID display, double *value);
bool MPWriteDisplayVolume(CGDirectDisplayID display, double value);

// Process counters for the current user only; never reads arguments or environment.
NSArray<NSDictionary<NSString *, NSNumber *> *> *MPProcessCounters(void);
