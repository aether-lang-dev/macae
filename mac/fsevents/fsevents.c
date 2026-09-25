/* mac.fsevents — what changed under a directory tree, from the FSEvents
 * service (CoreServices, a C API). A watch delivers on its own dispatch
 * queue into a buffer; the caller polls the buffer whenever it likes, so no
 * run loop is needed. Events since a remembered id can be replayed, which is
 * how an app that saved its last event id knows what to rescan. */
#include <CoreServices/CoreServices.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    char*    path;
    uint64_t flags;
    uint64_t id;
} Ev;

typedef struct {
    FSEventStreamRef stream;
    dispatch_queue_t queue;
    pthread_mutex_t  mu;
    Ev*  pending; int npending, cap_pending;   /* filled by the callback */
    Ev*  batch;   int nbatch;                  /* handed out by poll */
    int  started;
} Watch;

static void cb(ConstFSEventStreamRef s, void* info, size_t n, void* paths,
               const FSEventStreamEventFlags flags[], const FSEventStreamEventId ids[]) {
    (void)s;
    Watch* w = (Watch*)info;
    char** ps = (char**)paths;
    pthread_mutex_lock(&w->mu);
    for (size_t i = 0; i < n; i++) {
        if (w->npending == w->cap_pending) {
            int ncap = w->cap_pending ? w->cap_pending * 2 : 64;
            Ev* nb = (Ev*)realloc(w->pending, (size_t)ncap * sizeof(Ev));
            if (!nb) break;
            w->pending = nb; w->cap_pending = ncap;
        }
        Ev* e = &w->pending[w->npending++];
        e->path = strdup(ps[i]);
        e->flags = flags[i];
        e->id = ids[i];
    }
    pthread_mutex_unlock(&w->mu);
}

/* since_id: kFSEventStreamEventIdSinceNow (-1 as int64, i.e. UINT64_MAX)
 * for "from now", or an id from a previous run to replay what happened
 * after it. latency: seconds the service may coalesce before delivering. */
void* macae_fsevents_open(const char* path, int64_t since_id, double latency) {
    Watch* w = (Watch*)calloc(1, sizeof(Watch));
    if (!w) return NULL;
    pthread_mutex_init(&w->mu, NULL);
    CFStringRef p = CFStringCreateWithCString(NULL, path, kCFStringEncodingUTF8);
    if (!p) { free(w); return NULL; }
    CFArrayRef arr = CFArrayCreate(NULL, (const void**)&p, 1, &kCFTypeArrayCallBacks);
    FSEventStreamContext ctx = { 0, w, NULL, NULL, NULL };
    FSEventStreamEventId since = since_id < 0 ? kFSEventStreamEventIdSinceNow : (FSEventStreamEventId)since_id;
    w->stream = FSEventStreamCreate(NULL, cb, &ctx, arr, since, latency,
                                    kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer);
    CFRelease(arr);
    CFRelease(p);
    if (!w->stream) { pthread_mutex_destroy(&w->mu); free(w); return NULL; }
    w->queue = dispatch_queue_create("macae.fsevents", DISPATCH_QUEUE_SERIAL);
    FSEventStreamSetDispatchQueue(w->stream, w->queue);
    if (!FSEventStreamStart(w->stream)) {
        FSEventStreamInvalidate(w->stream);
        FSEventStreamRelease(w->stream);
        dispatch_release(w->queue);
        pthread_mutex_destroy(&w->mu);
        free(w);
        return NULL;
    }
    w->started = 1;
    return w;
}

static void free_batch(Watch* w) {
    for (int i = 0; i < w->nbatch; i++) free(w->batch[i].path);
    free(w->batch);
    w->batch = NULL; w->nbatch = 0;
}

/* Ask the service to deliver anything it is still coalescing, now. */
void macae_fsevents_flush(void* h) {
    Watch* w = (Watch*)h;
    if (w && w->started) FSEventStreamFlushSync(w->stream);
}

/* Move everything delivered so far into the current batch; its size. */
int macae_fsevents_poll(void* h) {
    Watch* w = (Watch*)h;
    if (!w) return 0;
    free_batch(w);
    pthread_mutex_lock(&w->mu);
    w->batch = w->pending; w->nbatch = w->npending;
    w->pending = NULL; w->npending = 0; w->cap_pending = 0;
    pthread_mutex_unlock(&w->mu);
    return w->nbatch;
}

static Ev* at(void* h, int i) {
    Watch* w = (Watch*)h;
    if (!w || i < 0 || i >= w->nbatch) return NULL;
    return &w->batch[i];
}
char*   macae_fsevents_path(void* h, int i)  { Ev* e = at(h, i); return strdup(e ? e->path : ""); }
int64_t macae_fsevents_flags(void* h, int i) { Ev* e = at(h, i); return e ? (int64_t)e->flags : 0; }
int64_t macae_fsevents_id(void* h, int i)    { Ev* e = at(h, i); return e ? (int64_t)e->id : 0; }

/* The service's current event id: remember it, and open_since(it) next run
 * replays what changed meanwhile. */
int64_t macae_fsevents_current_id(void) { return (int64_t)FSEventsGetCurrentEventId(); }
/* The id of the newest event this watch has been told about. */
int64_t macae_fsevents_latest_id(void* h) {
    Watch* w = (Watch*)h;
    if (!w || !w->started) return 0;
    return (int64_t)FSEventStreamGetLatestEventId(w->stream);
}

void macae_fsevents_close(void* h) {
    Watch* w = (Watch*)h;
    if (!w) return;
    if (w->started) {
        FSEventStreamStop(w->stream);
        FSEventStreamInvalidate(w->stream);
        FSEventStreamRelease(w->stream);
        dispatch_release(w->queue);
    }
    free_batch(w);
    for (int i = 0; i < w->npending; i++) free(w->pending[i].path);
    free(w->pending);
    pthread_mutex_destroy(&w->mu);
    free(w);
}
