/* mac.bundle — the .app this process lives in (NSBundle, Foundation): its
 * path, identifier, resources — and the same facts about any .app on disk.
 * A bare binary has a "main bundle" too (its directory) with no identifier. */
#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

static char* dup_str(NSString* s) {
    const char* u = s ? [s UTF8String] : NULL;
    return strdup(u ? u : "");
}

char* macae_bundle_path(void)        { @autoreleasepool { return dup_str([[NSBundle mainBundle] bundlePath]); } }
char* macae_bundle_identifier(void)  { @autoreleasepool { return dup_str([[NSBundle mainBundle] bundleIdentifier]); } }
char* macae_bundle_resource_path(void) { @autoreleasepool { return dup_str([[NSBundle mainBundle] resourcePath]); } }
char* macae_bundle_executable(void)  { @autoreleasepool { return dup_str([[NSBundle mainBundle] executablePath]); } }
char* macae_bundle_name(void) {
    @autoreleasepool {
        NSDictionary* info = [[NSBundle mainBundle] infoDictionary];
        NSString* n = info[@"CFBundleDisplayName"];
        if (!n) n = info[@"CFBundleName"];
        return dup_str(n);
    }
}
char* macae_bundle_version(void) {
    @autoreleasepool { return dup_str([[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"]); }
}
/* Any Info.plist string of the main bundle. */
char* macae_bundle_info(const char* key) {
    @autoreleasepool {
        id v = [[NSBundle mainBundle] infoDictionary][[NSString stringWithUTF8String:key ? key : ""]];
        if (!v) return strdup("");
        return dup_str([v isKindOfClass:[NSString class]] ? v : [v description]);
    }
}
/* 1 when running from a .app bundle (there is an Info.plist with an id). */
int macae_bundle_is_bundled(void) {
    @autoreleasepool {
        NSBundle* b = [NSBundle mainBundle];
        return [b bundleIdentifier] != nil && [[b bundlePath] hasSuffix:@".app"] ? 1 : 0;
    }
}
/* Facts about another .app on disk. */
char* macae_bundle_id_of(const char* app) {
    @autoreleasepool { return dup_str([[NSBundle bundleWithPath:[NSString stringWithUTF8String:app ? app : ""]] bundleIdentifier]); }
}
char* macae_bundle_name_of(const char* app) {
    @autoreleasepool {
        NSBundle* b = [NSBundle bundleWithPath:[NSString stringWithUTF8String:app ? app : ""]];
        NSDictionary* info = [b infoDictionary];
        NSString* n = info[@"CFBundleDisplayName"];
        if (!n) n = info[@"CFBundleName"];
        return dup_str(n);
    }
}
char* macae_bundle_version_of(const char* app) {
    @autoreleasepool {
        NSBundle* b = [NSBundle bundleWithPath:[NSString stringWithUTF8String:app ? app : ""]];
        return dup_str([b infoDictionary][@"CFBundleShortVersionString"]);
    }
}
