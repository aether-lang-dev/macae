/* mac.trash — move a file or folder to the Trash the way Finder does
 * (NSFileManager, Foundation): it lands in the right Trash for its volume,
 * gets a unique name if one is taken, and "Put Back" works. */
#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

static char s_result[4096], s_err[1024];

static void set_str(char* dst, size_t cap, NSString* s) {
    const char* u = s ? [s UTF8String] : "";
    strncpy(dst, u ? u : "", cap - 1);
    dst[cap - 1] = '\0';
}

/* 1 and result() is where it went; 0 and error() says why. */
int macae_trash_item(const char* path) {
    @autoreleasepool {
        s_result[0] = s_err[0] = '\0';
        NSURL* u = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path ? path : ""]];
        NSURL* out = nil;
        NSError* err = nil;
        BOOL ok = [[NSFileManager defaultManager] trashItemAtURL:u resultingItemURL:&out error:&err];
        if (!ok) {
            set_str(s_err, sizeof(s_err), err ? [err localizedDescription] : @"unknown error");
            return 0;
        }
        set_str(s_result, sizeof(s_result), out ? [out path] : nil);
        return 1;
    }
}
char* macae_trash_result(void) { return strdup(s_result); }
char* macae_trash_error(void)  { return strdup(s_err); }
