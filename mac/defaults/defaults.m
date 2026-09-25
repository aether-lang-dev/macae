/* mac.defaults — app settings in the place macOS keeps them
 * (NSUserDefaults, Foundation): ~/Library/Preferences/<suite>.plist,
 * readable with `defaults read <suite>`, synced by cfprefsd. */
#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

static NSUserDefaults* suite(const char* name) {
    return [[[NSUserDefaults alloc] initWithSuiteName:[NSString stringWithUTF8String:name ? name : ""]] autorelease];
}
static NSString* key(const char* k) { return [NSString stringWithUTF8String:k ? k : ""]; }

int macae_defaults_has(const char* s, const char* k) {
    @autoreleasepool { return [suite(s) objectForKey:key(k)] != nil ? 1 : 0; }
}
char* macae_defaults_get_string(const char* s, const char* k) {
    @autoreleasepool {
        id v = [suite(s) objectForKey:key(k)];
        if (!v) return strdup("");
        NSString* str = [v isKindOfClass:[NSString class]] ? v : [v description];
        const char* u = [str UTF8String];
        return strdup(u ? u : "");
    }
}
int64_t macae_defaults_get_int(const char* s, const char* k) {
    @autoreleasepool {
        id v = [suite(s) objectForKey:key(k)];
        return v && [v respondsToSelector:@selector(longLongValue)] ? [v longLongValue] : 0;
    }
}
double macae_defaults_get_float(const char* s, const char* k) {
    @autoreleasepool {
        id v = [suite(s) objectForKey:key(k)];
        return v && [v respondsToSelector:@selector(doubleValue)] ? [v doubleValue] : 0.0;
    }
}
int macae_defaults_get_bool(const char* s, const char* k) {
    @autoreleasepool { return [suite(s) boolForKey:key(k)] ? 1 : 0; }
}
void macae_defaults_set_string(const char* s, const char* k, const char* v) {
    @autoreleasepool { [suite(s) setObject:[NSString stringWithUTF8String:v ? v : ""] forKey:key(k)]; }
}
void macae_defaults_set_int(const char* s, const char* k, int64_t v) {
    @autoreleasepool { [suite(s) setObject:@(v) forKey:key(k)]; }
}
void macae_defaults_set_float(const char* s, const char* k, double v) {
    @autoreleasepool { [suite(s) setObject:@(v) forKey:key(k)]; }
}
void macae_defaults_set_bool(const char* s, const char* k, int v) {
    @autoreleasepool { [suite(s) setBool:(v != 0) forKey:key(k)]; }
}
void macae_defaults_remove(const char* s, const char* k) {
    @autoreleasepool { [suite(s) removeObjectForKey:key(k)]; }
}
/* Forget every key of the suite (its plist goes away). */
void macae_defaults_remove_suite(const char* s) {
    @autoreleasepool {
        [[NSUserDefaults standardUserDefaults]
            removePersistentDomainForName:[NSString stringWithUTF8String:s ? s : ""]];
    }
}
/* Write pending changes out now (they are written anyway, shortly). */
int macae_defaults_sync(const char* s) {
    @autoreleasepool { return [suite(s) synchronize] ? 1 : 0; }
}
