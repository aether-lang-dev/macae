/* mac.volume — a volume's capacity and identity the way Finder counts it,
 * from NSURL's volume resource keys (Foundation). statvfs cannot see
 * purgeable space; "available for important usage" can. Split try/get like
 * std.fs's stat: try(path) fills the fields, the getters read them. */
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static int64_t s_total, s_avail, s_important, s_opportunistic;
static int s_removable, s_ejectable, s_internal, s_browsable, s_root, s_readonly;
static char s_name[1024], s_format[256], s_mount[4096], s_err[512];

static void set_str(char* dst, size_t cap, NSString* s) {
    const char* u = s ? [s UTF8String] : "";
    strncpy(dst, u ? u : "", cap - 1);
    dst[cap - 1] = '\0';
}
static int64_t num(NSDictionary* d, NSURLResourceKey k) {
    NSNumber* n = d[k];
    return n ? [n longLongValue] : 0;
}
static int flag(NSDictionary* d, NSURLResourceKey k) {
    NSNumber* n = d[k];
    return n ? ([n boolValue] ? 1 : 0) : 0;
}

int macae_volume_try(const char* path) {
    @autoreleasepool {
        s_total = s_avail = s_important = s_opportunistic = 0;
        s_removable = s_ejectable = s_internal = s_browsable = s_root = s_readonly = 0;
        s_name[0] = s_format[0] = s_mount[0] = s_err[0] = '\0';
        NSURL* u = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path ? path : ""]];
        NSError* err = nil;
        NSDictionary* d = [u resourceValuesForKeys:@[
            NSURLVolumeTotalCapacityKey, NSURLVolumeAvailableCapacityKey,
            NSURLVolumeAvailableCapacityForImportantUsageKey,
            NSURLVolumeAvailableCapacityForOpportunisticUsageKey,
            NSURLVolumeNameKey, NSURLVolumeLocalizedFormatDescriptionKey, NSURLVolumeURLKey,
            NSURLVolumeIsRemovableKey, NSURLVolumeIsEjectableKey, NSURLVolumeIsInternalKey,
            NSURLVolumeIsBrowsableKey, NSURLVolumeIsRootFileSystemKey, NSURLVolumeIsReadOnlyKey]
            error:&err];
        if (!d) {
            set_str(s_err, sizeof(s_err), err ? [err localizedDescription] : @"unknown error");
            return 0;
        }
        s_total = num(d, NSURLVolumeTotalCapacityKey);
        s_avail = num(d, NSURLVolumeAvailableCapacityKey);
        s_important = num(d, NSURLVolumeAvailableCapacityForImportantUsageKey);
        s_opportunistic = num(d, NSURLVolumeAvailableCapacityForOpportunisticUsageKey);
        s_removable = flag(d, NSURLVolumeIsRemovableKey);
        s_ejectable = flag(d, NSURLVolumeIsEjectableKey);
        s_internal = flag(d, NSURLVolumeIsInternalKey);
        s_browsable = flag(d, NSURLVolumeIsBrowsableKey);
        s_root = flag(d, NSURLVolumeIsRootFileSystemKey);
        s_readonly = flag(d, NSURLVolumeIsReadOnlyKey);
        set_str(s_name, sizeof(s_name), d[NSURLVolumeNameKey]);
        set_str(s_format, sizeof(s_format), d[NSURLVolumeLocalizedFormatDescriptionKey]);
        NSURL* mu = d[NSURLVolumeURLKey];
        set_str(s_mount, sizeof(s_mount), mu ? [mu path] : nil);
        return 1;
    }
}

int64_t macae_volume_total(void)         { return s_total; }
int64_t macae_volume_available(void)     { return s_avail; }
int64_t macae_volume_important(void)     { return s_important; }
int64_t macae_volume_opportunistic(void) { return s_opportunistic; }
int     macae_volume_removable(void)     { return s_removable; }
int     macae_volume_ejectable(void)     { return s_ejectable; }
int     macae_volume_internal(void)      { return s_internal; }
int     macae_volume_browsable(void)     { return s_browsable; }
int     macae_volume_root(void)          { return s_root; }
int     macae_volume_readonly(void)      { return s_readonly; }
char*   macae_volume_name(void)          { return strdup(s_name); }
char*   macae_volume_format(void)        { return strdup(s_format); }
char*   macae_volume_mount_point(void)   { return strdup(s_mount); }
char*   macae_volume_error(void)         { return strdup(s_err); }

/* The mounted volumes Finder would show (hidden ones skipped). Split
 * count/get: mounted() fills the list, mounted_path(i) reads it. */
static char** s_vols; static int s_nvols;

int macae_volume_mounted(void) {
    @autoreleasepool {
        for (int i = 0; i < s_nvols; i++) free(s_vols[i]);
        free(s_vols); s_vols = NULL; s_nvols = 0;
        NSArray* urls = [[NSFileManager defaultManager]
            mountedVolumeURLsIncludingResourceValuesForKeys:@[]
            options:NSVolumeEnumerationSkipHiddenVolumes];
        if (!urls) return 0;
        s_vols = (char**)calloc((size_t)[urls count] + 1, sizeof(char*));
        if (!s_vols) return 0;
        for (NSURL* u in urls) {
            const char* p = [[u path] UTF8String];
            if (p) s_vols[s_nvols++] = strdup(p);
        }
        return s_nvols;
    }
}
char* macae_volume_mounted_path(int i) {
    if (i < 0 || i >= s_nvols) return strdup("");
    return strdup(s_vols[i]);
}
