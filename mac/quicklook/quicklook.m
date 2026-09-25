/* mac.quicklook — the thumbnails and previews Finder shows.
 *
 * thumbnail(): QuickLookThumbnailing renders any file the system can
 * preview (PDF, images, video frames, documents) to a PNG at the size asked,
 * synchronously here (the framework is asynchronous; a semaphore waits).
 * Works from a plain process, no app or window needed.
 *
 * preview(): the Quick Look panel (Quartz) over the app's window — the
 * Space-bar preview. It needs a running NSApplication, so it works inside
 * an aether-ui app and reports "no application" from a bare tool. */
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <Quartz/Quartz.h>
#import <QuickLookThumbnailing/QuickLookThumbnailing.h>
#import <ImageIO/ImageIO.h>
#include <stdlib.h>
#include <string.h>

static char s_err[1024];
static void set_err(NSString* s) {
    const char* u = s ? [s UTF8String] : "";
    strncpy(s_err, u ? u : "", sizeof(s_err) - 1);
    s_err[sizeof(s_err) - 1] = '\0';
}
char* macae_quicklook_error(void) { return strdup(s_err); }

static int write_png(CGImageRef img, const char* out) {
    NSURL* u = [NSURL fileURLWithPath:[NSString stringWithUTF8String:out]];
    CGImageDestinationRef dst = CGImageDestinationCreateWithURL((CFURLRef)u, CFSTR("public.png"), 1, NULL);
    if (!dst) return 0;
    CGImageDestinationAddImage(dst, img, NULL);
    int ok = CGImageDestinationFinalize(dst) ? 1 : 0;
    CFRelease(dst);
    return ok;
}

/* 1 and a PNG at `out`, or 0 and error(). `timeout_s` bounds the wait. */
int macae_quicklook_thumbnail(const char* path, int w, int h, const char* out, double timeout_s) {
    @autoreleasepool {
        s_err[0] = '\0';
        /* The generator returns a generic icon for ANY path, even one that
         * does not exist; that is not a thumbnail of the file. Check first. */
        if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithUTF8String:path ? path : ""]]) {
            set_err(@"no such file"); return 0;
        }
        if (@available(macOS 10.15, *)) {
            NSURL* u = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path ? path : ""]];
            QLThumbnailGenerationRequest* req = [[[QLThumbnailGenerationRequest alloc]
                initWithFileAtURL:u size:CGSizeMake(w, h) scale:1.0
                representationTypes:QLThumbnailGenerationRequestRepresentationTypeAll] autorelease];
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            __block int ok = 0;
            __block NSString* why = nil;
            [[QLThumbnailGenerator sharedGenerator] generateBestRepresentationForRequest:req
                completionHandler:^(QLThumbnailRepresentation* rep, NSError* error) {
                    if (rep) {
                        CGImageRef img = [rep CGImage];
                        ok = img ? write_png(img, out) : 0;
                        if (!ok) why = [@"could not write PNG" retain];
                    } else {
                        why = [(error ? [error localizedDescription] : @"no representation") retain];
                    }
                    dispatch_semaphore_signal(sem);
                }];
            long waited = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout_s * NSEC_PER_SEC)));
            dispatch_release(sem);
            if (waited != 0) { set_err(@"timed out waiting for the thumbnail"); return 0; }
            if (!ok) set_err(why);
            [why release];
            return ok;
        }
        set_err(@"needs macOS 10.15");
        return 0;
    }
}

/* ─── The Quick Look panel ──────────────────────────────────────── */

@interface MacaePreviewItems : NSObject <QLPreviewPanelDataSource, QLPreviewPanelDelegate>
@property (retain) NSArray* urls;
@end
@implementation MacaePreviewItems
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel*)panel { return (NSInteger)[self.urls count]; }
- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel*)panel previewItemAtIndex:(NSInteger)i { return self.urls[(NSUInteger)i]; }
- (void)dealloc { self.urls = nil; [super dealloc]; }
@end

static MacaePreviewItems* s_items;

/* Show the panel over the app's key window with these files (newline-
 * separated). 1 = shown; 0 and error() when there is no running app. */
int macae_quicklook_preview(const char* paths) {
    @autoreleasepool {
        s_err[0] = '\0';
        if (!NSApp) { set_err(@"no application: the Quick Look panel needs an NSApplication"); return 0; }
        NSArray* parts = [[NSString stringWithUTF8String:paths ? paths : ""] componentsSeparatedByString:@"\n"];
        NSMutableArray* urls = [NSMutableArray array];
        for (NSString* p in parts) if ([p length]) [urls addObject:[NSURL fileURLWithPath:p]];
        if (![urls count]) { set_err(@"no paths"); return 0; }
        if (!s_items) s_items = [[MacaePreviewItems alloc] init];
        s_items.urls = urls;
        QLPreviewPanel* panel = [QLPreviewPanel sharedPreviewPanel];
        [panel setDataSource:s_items];
        [panel setDelegate:s_items];
        [panel reloadData];
        [panel makeKeyAndOrderFront:nil];
        return 1;
    }
}
int macae_quicklook_preview_visible(void) {
    @autoreleasepool {
        if (!NSApp || ![QLPreviewPanel sharedPreviewPanelExists]) return 0;
        return [[QLPreviewPanel sharedPreviewPanel] isVisible] ? 1 : 0;
    }
}
void macae_quicklook_preview_close(void) {
    @autoreleasepool {
        if (NSApp && [QLPreviewPanel sharedPreviewPanelExists]) [[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
    }
}
int macae_quicklook_has_app(void) { return NSApp ? 1 : 0; }
