#import "DisplayBridge.h"
#import <IOKit/IOKitLib.h>
#import <dlfcn.h>
#import <math.h>
#import <unistd.h>
#import <libproc.h>

NSArray<NSDictionary<NSString *, NSNumber *> *> *MPProcessCounters(void) {
    int bytes = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    if (bytes <= 0 || bytes > 4 * 1024 * 1024) return @[];
    int capacity = bytes + 4096;
    pid_t *pids = calloc(1, (size_t)capacity);
    if (!pids) return @[];
    int count = proc_listpids(PROC_ALL_PIDS, 0, pids, capacity) / (int)sizeof(pid_t);
    NSMutableArray *result = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        struct proc_taskallinfo info = {0};
        if (pids[i] <= 0 || proc_pidinfo(pids[i], PROC_PIDTASKALLINFO, 0, &info, sizeof(info)) != sizeof(info) ||
            info.pbsd.pbi_uid != getuid()) continue;
        [result addObject:@{@"pid": @(pids[i]), @"parent": @(info.pbsd.pbi_ppid),
            @"started": @(info.pbsd.pbi_start_tvsec * 1000000 + info.pbsd.pbi_start_tvusec),
            @"cpu": @(info.ptinfo.pti_total_user + info.ptinfo.pti_total_system),
            @"memory": @(info.ptinfo.pti_resident_size)}];
    }
    free(pids);
    return result;
}

// DDC framing and Apple Silicon framebuffer/proxy matching adapted from
// waydabber/m1ddc (MIT), commit 9d75fb6c407ac60dc77a9e32c43d60fd0e6d1612.
// See Resources/m1ddc-LICENSE.txt. Luminance (0x10) and speaker volume (0x62) only.
// Changes: bounded buffers, fixed packet lengths, explicit CF/IO releases,
// dynamic symbol detection and no CLI, EDID parser, input switching or power commands.
typedef CFTypeRef (*CreateService)(CFAllocatorRef, io_service_t);
typedef IOReturn (*I2C)(CFTypeRef, uint32_t, uint32_t, void *, uint32_t);
typedef CFDictionaryRef (*DisplayInfo)(CGDirectDisplayID);
typedef int (*GetBrightness)(CGDirectDisplayID, float *);
typedef int (*SetBrightness)(CGDirectDisplayID, float);
static CreateService createService;
static I2C readI2C, writeI2C;
static DisplayInfo displayInfo;
static GetBrightness getBrightness;
static SetBrightness setBrightness;

static void loadSymbols(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Framework handles intentionally live for the process lifetime.
        void *io = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY | RTLD_LOCAL);
        void *core = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY | RTLD_LOCAL);
        void *ds = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY | RTLD_LOCAL);
        if (io) {
            createService = (CreateService)dlsym(io, "IOAVServiceCreateWithService");
            readI2C = (I2C)dlsym(io, "IOAVServiceReadI2C");
            writeI2C = (I2C)dlsym(io, "IOAVServiceWriteI2C");
        }
        if (core) displayInfo = (DisplayInfo)dlsym(core, "CoreDisplay_DisplayCreateInfoDictionary");
        if (ds) {
            getBrightness = (GetBrightness)dlsym(ds, "DisplayServicesGetBrightness");
            setBrightness = (SetBrightness)dlsym(ds, "DisplayServicesSetBrightness");
        }
    });
}

static CFTypeRef copyTransport(CGDirectDisplayID display, uint32_t *chip) {
#if !defined(__arm64__)
    return NULL;
#else
    if (!createService || !readI2C || !writeI2C || !displayInfo || CGDisplayIsBuiltin(display)) return NULL;
    CFDictionaryRef info = displayInfo(display);
    if (!info) return NULL;
    CFTypeRef path = CFDictionaryGetValue(info, CFSTR("IODisplayLocation"));
    io_service_t adapter = (path && CFGetTypeID(path) == CFStringGetTypeID())
        ? IORegistryEntryCopyFromPath(kIOMainPortDefault, path) : 0;
    CFRelease(info);
    if (!adapter) return NULL;
    uint64_t adapterID = 0;
    kern_return_t status = IORegistryEntryGetRegistryEntryID(adapter, &adapterID);
    IOObjectRelease(adapter);
    if (status != KERN_SUCCESS) return NULL;
    io_registry_entry_t root = IORegistryGetRootEntry(kIOMainPortDefault);
    io_iterator_t iterator = 0;
    status = IORegistryEntryCreateIterator(root, kIOServicePlane, kIORegistryIterateRecursively, &iterator);
    IOObjectRelease(root);
    if (status != KERN_SUCCESS) return NULL;
    bool matches = false;
    CFTypeRef result = NULL;
    io_service_t service;
    while ((service = IOIteratorNext(iterator))) {
        if (IOObjectConformsTo(service, "IOMobileFramebuffer")) {
            uint64_t identifier = 0;
            matches = IORegistryEntryGetRegistryEntryID(service, &identifier) == KERN_SUCCESS && identifier == adapterID;
        } else if (matches && IOObjectConformsTo(service, "DCPAVServiceProxy")) {
            CFTypeRef location = IORegistryEntryCreateCFProperty(service, CFSTR("Location"), kCFAllocatorDefault, 0);
            bool external = location && CFGetTypeID(location) == CFStringGetTypeID() && CFEqual(location, CFSTR("External"));
            if (location) CFRelease(location);
            if (external) {
                *chip = 0x37;
                io_service_t parent = 0;
                if (IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent) == KERN_SUCCESS) {
                    CFTypeRef provider = IORegistryEntryCreateCFProperty(parent, CFSTR("EPICProviderClass"), kCFAllocatorDefault, 0);
                    if (provider && CFGetTypeID(provider) == CFStringGetTypeID() && CFEqual(provider, CFSTR("AppleDCPMCDP29XX"))) *chip = 0xB7;
                    if (provider) CFRelease(provider);
                    IOObjectRelease(parent);
                }
                result = createService(kCFAllocatorDefault, service);
            }
        }
        IOObjectRelease(service);
        if (result) break;
    }
    IOObjectRelease(iterator);
    return result;
#endif
}

bool MPDecodeBrightnessReply(const uint8_t *bytes, size_t size, uint16_t *current, uint16_t *maximum) {
    return MPDecodeVCPReply(bytes, size, 0x10, current, maximum);
}

bool MPDecodeVCPReply(const uint8_t *bytes, size_t size, uint8_t code, uint16_t *current, uint16_t *maximum) {
    if (!bytes || size < 11 || !current || !maximum || bytes[0] != 0x6E || bytes[1] != 0x88 ||
        bytes[2] != 2 || bytes[3] != 0 || bytes[4] != code || (code != 0x10 && code != 0x62)) return false;
    uint8_t checksum = 0x50;
    for (size_t i = 0; i < 10; i++) checksum ^= bytes[i];
    if (checksum != bytes[10]) return false;
    uint16_t max = ((uint16_t)bytes[6] << 8) | bytes[7];
    uint16_t cur = ((uint16_t)bytes[8] << 8) | bytes[9];
    if (max == 0 || cur > max) return false;
    *current = cur; *maximum = max;
    return true;
}

static bool readDDC(CFTypeRef service, uint32_t chip, uint8_t code, uint16_t *current, uint16_t *maximum) {
    for (int attempt = 0; attempt < 3; attempt++) {
        uint8_t request[4] = {0x82, 0x01, code, 0};
        request[3] = 0x6E ^ 0x51 ^ request[0] ^ request[1] ^ request[2];
        IOReturn sent = writeI2C(service, chip, 0x51, request, sizeof(request));
        usleep(10000);
        if (sent == kIOReturnSuccess) sent = writeI2C(service, chip, 0x51, request, sizeof(request));
        if (sent != kIOReturnSuccess) continue;
        usleep(50000);
        uint8_t reply[12] = {0};
        IOReturn received = readI2C(service, chip, 0x51, reply, sizeof(reply));
        if (received == kIOReturnSuccess &&
            MPDecodeVCPReply(reply, sizeof(reply), code, current, maximum)) return true;
        usleep(50000);
    }
    return false;
}

int MPReadBrightness(CGDirectDisplayID display, double *value) {
    if (!value || !CGDisplayIsOnline(display)) return 0;
    loadSymbols();
    float nativeValue = -1;
    if (getBrightness && setBrightness && getBrightness(display, &nativeValue) == 0 &&
        isfinite(nativeValue) && nativeValue >= 0 && nativeValue <= 1) {
        *value = nativeValue; return 1;
    }
    uint32_t chip;
    CFTypeRef service = copyTransport(display, &chip);
    if (!service) return 0;
    uint16_t current, maximum;
    bool success = readDDC(service, chip, 0x10, &current, &maximum);
    CFRelease(service);
    if (!success) return 0;
    *value = (double)current / maximum;
    return 2;
}

bool MPWriteBrightness(CGDirectDisplayID display, double value) {
    if (!isfinite(value) || value < 0 || value > 1 || !CGDisplayIsOnline(display)) return false;
    loadSymbols();
    float nativeValue = -1;
    if (getBrightness && setBrightness && getBrightness(display, &nativeValue) == 0 &&
        isfinite(nativeValue) && nativeValue >= 0 && nativeValue <= 1) return setBrightness(display, (float)value) == 0;
    uint32_t chip;
    CFTypeRef service = copyTransport(display, &chip);
    if (!service) return false;
    uint16_t current, maximum;
    bool success = readDDC(service, chip, 0x10, &current, &maximum);
    if (success) {
        uint16_t target = (uint16_t)lround(value * maximum);
        uint8_t request[6] = {0x84, 0x03, 0x10, target >> 8, target & 0xFF, 0};
        request[5] = 0x6E ^ 0x51 ^ request[0] ^ request[1] ^ request[2] ^ request[3] ^ request[4];
        success = writeI2C(service, chip, 0x51, request, sizeof(request)) == kIOReturnSuccess;
    }
    CFRelease(service);
    return success;
}

bool MPReadDisplayVolume(CGDirectDisplayID display, double *value) {
    if (!value || CGDisplayIsBuiltin(display) || !CGDisplayIsOnline(display)) return false;
    loadSymbols();
    uint32_t chip;
    CFTypeRef service = copyTransport(display, &chip);
    if (!service) return false;
    uint16_t current, maximum;
    bool success = readDDC(service, chip, 0x62, &current, &maximum);
    CFRelease(service);
    if (success) *value = (double)current / maximum;
    return success;
}

bool MPWriteDisplayVolume(CGDirectDisplayID display, double value) {
    if (!isfinite(value) || value < 0 || value > 1 || CGDisplayIsBuiltin(display) || !CGDisplayIsOnline(display)) return false;
    loadSymbols();
    uint32_t chip;
    CFTypeRef service = copyTransport(display, &chip);
    if (!service) return false;
    uint16_t current, maximum;
    bool success = readDDC(service, chip, 0x62, &current, &maximum);
    if (success) {
        uint16_t target = (uint16_t)lround(value * maximum);
        uint8_t request[6] = {0x84, 0x03, 0x62, target >> 8, target & 0xFF, 0};
        request[5] = 0x6E ^ 0x51 ^ request[0] ^ request[1] ^ request[2] ^ request[3] ^ request[4];
        success = writeI2C(service, chip, 0x51, request, sizeof(request)) == kIOReturnSuccess;
    }
    CFRelease(service);
    return success;
}
