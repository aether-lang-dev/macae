/* mac.power — keep the Mac awake while work runs (IOKit power assertions),
 * and what is powering it (IOKit power sources). C APIs. */
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/ps/IOPowerSources.h>
#include <IOKit/ps/IOPSKeys.h>
#include <stdlib.h>
#include <string.h>

/* kind: 0 = the system may not idle-sleep (a long scan, a download);
 *       1 = the display may not sleep either (a presentation).
 * Returns an assertion id > 0, or 0 on failure. */
int64_t macae_power_assert(int kind, const char* reason) {
    CFStringRef type = kind == 1 ? kIOPMAssertionTypePreventUserIdleDisplaySleep
                                 : kIOPMAssertionTypePreventUserIdleSystemSleep;
    CFStringRef why = CFStringCreateWithCString(NULL, reason && *reason ? reason : "macae", kCFStringEncodingUTF8);
    IOPMAssertionID id = 0;
    IOReturn rc = IOPMAssertionCreateWithName(type, kIOPMAssertionLevelOn, why, &id);
    CFRelease(why);
    return rc == kIOReturnSuccess ? (int64_t)id : 0;
}

int macae_power_release(int64_t id) {
    if (id <= 0) return 0;
    return IOPMAssertionRelease((IOPMAssertionID)id) == kIOReturnSuccess ? 1 : 0;
}

/* "AC Power", "Battery Power", "UPS Power" or "" */
char* macae_power_source(void) {
    CFTypeRef info = IOPSCopyPowerSourcesInfo();
    if (!info) return strdup("");
    CFStringRef t = IOPSGetProvidingPowerSourceType(info);
    char buf[64] = "";
    if (t) CFStringGetCString(t, buf, sizeof(buf), kCFStringEncodingUTF8);
    CFRelease(info);
    return strdup(buf);
}

/* Battery charge 0..100, or -1 with no battery. */
int macae_power_battery_percent(void) {
    CFTypeRef info = IOPSCopyPowerSourcesInfo();
    if (!info) return -1;
    CFArrayRef list = IOPSCopyPowerSourcesList(info);
    int pct = -1;
    if (list) {
        for (CFIndex i = 0; i < CFArrayGetCount(list) && pct < 0; i++) {
            CFDictionaryRef d = IOPSGetPowerSourceDescription(info, CFArrayGetValueAtIndex(list, i));
            if (!d) continue;
            CFStringRef type = CFDictionaryGetValue(d, CFSTR(kIOPSTypeKey));
            if (type && CFStringCompare(type, CFSTR(kIOPSInternalBatteryType), 0) != kCFCompareEqualTo) continue;
            CFNumberRef cur = CFDictionaryGetValue(d, CFSTR(kIOPSCurrentCapacityKey));
            CFNumberRef max = CFDictionaryGetValue(d, CFSTR(kIOPSMaxCapacityKey));
            int c = 0, m = 0;
            if (cur && max && CFNumberGetValue(cur, kCFNumberIntType, &c) && CFNumberGetValue(max, kCFNumberIntType, &m) && m > 0) {
                pct = (int)((long)c * 100 / m);
            }
        }
        CFRelease(list);
    }
    CFRelease(info);
    return pct;
}
