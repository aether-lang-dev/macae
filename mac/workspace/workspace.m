/* mac.workspace — NSWorkspace (AppKit): open a file in its app, reveal it in
 * Finder, open with a chosen app, which app would open a file or URL, what
 * is running and frontmost. None of it needs an NSApplication of our own. */
#import <AppKit/AppKit.h>
#include <stdlib.h>
#include <string.h>

static NSURL* file_url(const char* p) {
    return [NSURL fileURLWithPath:[NSString stringWithUTF8String:p ? p : ""]];
}
static char* dup_path(NSURL* u) {
    const char* p = u ? [[u path] UTF8String] : NULL;
    return strdup(p ? p : "");
}

int macae_workspace_open_path(const char* path) {
    @autoreleasepool { return [[NSWorkspace sharedWorkspace] openURL:file_url(path)] ? 1 : 0; }
}
int macae_workspace_open_url(const char* url) {
    @autoreleasepool {
        NSURL* u = [NSURL URLWithString:[NSString stringWithUTF8String:url ? url : ""]];
        if (!u) return 0;
        return [[NSWorkspace sharedWorkspace] openURL:u] ? 1 : 0;
    }
}
/* Finder window showing the item, selected. */
void macae_workspace_reveal(const char* path) {
    @autoreleasepool { [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[file_url(path)]]; }
}
/* Open `path` with the app bundle at `app`. Asynchronous; 1 = requested. */
int macae_workspace_open_with(const char* path, const char* app) {
    @autoreleasepool {
        if (@available(macOS 10.15, *)) {
            NSWorkspaceOpenConfiguration* cfg = [NSWorkspaceOpenConfiguration configuration];
            [[NSWorkspace sharedWorkspace] openURLs:@[file_url(path)] withApplicationAtURL:file_url(app)
                                       configuration:cfg completionHandler:nil];
            return 1;
        }
        return 0;
    }
}
/* The .app that would open the file, or "" — no side effect. */
char* macae_workspace_app_for_path(const char* path) {
    @autoreleasepool {
        if (@available(macOS 12.0, *)) {
            return dup_path([[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:file_url(path)]);
        }
        return strdup("");
    }
}
/* The .app that would open the URL scheme (the default browser for https). */
char* macae_workspace_app_for_url(const char* url) {
    @autoreleasepool {
        NSURL* u = [NSURL URLWithString:[NSString stringWithUTF8String:url ? url : ""]];
        if (!u) return strdup("");
        if (@available(macOS 12.0, *)) {
            return dup_path([[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:u]);
        }
        return strdup("");
    }
}
/* The .app with this bundle identifier, or "". */
char* macae_workspace_app_for_bundle_id(const char* bid) {
    @autoreleasepool {
        if (@available(macOS 12.0, *)) {
            return dup_path([[NSWorkspace sharedWorkspace]
                URLForApplicationWithBundleIdentifier:[NSString stringWithUTF8String:bid ? bid : ""]]);
        }
        return strdup("");
    }
}
char* macae_workspace_frontmost_app(void) {
    @autoreleasepool {
        NSRunningApplication* a = [[NSWorkspace sharedWorkspace] frontmostApplication];
        const char* n = a ? [[a localizedName] UTF8String] : NULL;
        return strdup(n ? n : "");
    }
}
/* Running apps: count, then bundle id / name by index (a snapshot). */
static NSArray* s_running;
int macae_workspace_running(void) {
    @autoreleasepool {
        [s_running release];
        s_running = [[[NSWorkspace sharedWorkspace] runningApplications] retain];
        return (int)[s_running count];
    }
}
char* macae_workspace_running_bundle_id(int i) {
    @autoreleasepool {
        if (!s_running || i < 0 || i >= (int)[s_running count]) return strdup("");
        NSRunningApplication* a = s_running[(NSUInteger)i];
        const char* s = [[a bundleIdentifier] UTF8String];
        return strdup(s ? s : "");
    }
}
char* macae_workspace_running_name(int i) {
    @autoreleasepool {
        if (!s_running || i < 0 || i >= (int)[s_running count]) return strdup("");
        NSRunningApplication* a = s_running[(NSUInteger)i];
        const char* s = [[a localizedName] UTF8String];
        return strdup(s ? s : "");
    }
}
