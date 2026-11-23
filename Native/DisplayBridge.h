#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// 1: Apple brightness, 2: external DDC, 0: unavailable. No write occurs on read.
int MPReadBrightness(CGDirectDisplayID display, double *value);
bool MPWriteBrightness(CGDirectDisplayID display, double value);
bool MPDecodeBrightnessReply(const uint8_t *bytes, size_t size, uint16_t *current, uint16_t *maximum);
