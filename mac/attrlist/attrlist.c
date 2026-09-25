/* mac.attrlist — read a whole directory in one pass with getattrlistbulk(2):
 * every entry's name, kind, file id, link count and allocated size, without a
 * stat(2) per entry. It is how OpenDisk scans a terabyte in seconds. Plain
 * libSystem (sys/attr.h), no framework.
 *
 * A listing is a heap handle the caller frees. Entries are copied out of the
 * kernel buffer, so the handle is self-contained. */
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/attr.h>
#include <sys/stat.h>
#include <sys/vnode.h>
#include <unistd.h>

typedef struct {
    char*    name;
    int      kind;      /* 1 file, 2 dir, 3 symlink, 4 other (std.fs's numbering) */
    uint64_t fileid;
    uint32_t nlink;
    int64_t  alloc;     /* allocated bytes; 0 for a directory */
    int64_t  size;      /* logical bytes; 0 for a directory */
} Entry;

typedef struct {
    Entry* items;
    int    count;
    int    cap;
    int    err;         /* errno of the failure that ended the read, or 0 */
} Listing;

static void push(Listing* l, Entry e) {
    if (l->count == l->cap) {
        int ncap = l->cap ? l->cap * 2 : 64;
        Entry* n = (Entry*)realloc(l->items, (size_t)ncap * sizeof(Entry));
        if (!n) { free(e.name); return; }
        l->items = n; l->cap = ncap;
    }
    l->items[l->count++] = e;
}

static int kind_of(uint32_t objtype) {
    switch (objtype) {
    case VREG: return 1;
    case VDIR: return 2;
    case VLNK: return 3;
    default:   return 4;
    }
}

/* The attributes are packed in bit order within each group, with two
 * exceptions the man page names: ATTR_CMN_RETURNED_ATTRS first, then
 * ATTR_CMN_ERROR. Every field is 4-byte aligned; 8-byte fields are memcpy'd. */
static void parse(Listing* l, char* buf, int n) {
    char* p = buf;
    for (int i = 0; i < n; i++) {
        uint32_t len; memcpy(&len, p, 4);
        char* f = p + 4;
        attribute_set_t ret; memcpy(&ret, f, sizeof(ret)); f += sizeof(ret);
        Entry e; memset(&e, 0, sizeof(e));
        int skip = 0;
        if (ret.commonattr & ATTR_CMN_ERROR) { uint32_t err; memcpy(&err, f, 4); f += 4; if (err) skip = 1; }
        if (ret.commonattr & ATTR_CMN_NAME) {
            attrreference_t ref; memcpy(&ref, f, sizeof(ref));
            const char* nm = f + ref.attr_dataoffset;
            e.name = strndup(nm, ref.attr_length);
            f += sizeof(ref);
        }
        if (ret.commonattr & ATTR_CMN_OBJTYPE) { uint32_t t; memcpy(&t, f, 4); e.kind = kind_of(t); f += 4; }
        if (ret.commonattr & ATTR_CMN_FILEID) { memcpy(&e.fileid, f, 8); f += 8; }
        if (ret.fileattr & ATTR_FILE_LINKCOUNT) { memcpy(&e.nlink, f, 4); f += 4; }
        if (ret.fileattr & ATTR_FILE_TOTALSIZE) { memcpy(&e.size, f, 8); f += 8; }
        if (ret.fileattr & ATTR_FILE_ALLOCSIZE) { memcpy(&e.alloc, f, 8); f += 8; }
        if (!skip && e.name) push(l, e); else free(e.name);
        p += len;
    }
}

void* macae_attrlist_read(const char* dir) {
    Listing* l = (Listing*)calloc(1, sizeof(Listing));
    if (!l) return NULL;
    int fd = open(dir, O_RDONLY | O_DIRECTORY | O_CLOEXEC);   /* the ROOT may be a symlink (/etc); entries are never followed */
    if (fd < 0) { l->err = errno; return l; }
    struct attrlist al;
    memset(&al, 0, sizeof(al));
    al.bitmapcount = ATTR_BIT_MAP_COUNT;
    al.commonattr = ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_ERROR | ATTR_CMN_NAME
                  | ATTR_CMN_OBJTYPE | ATTR_CMN_FILEID;
    al.fileattr = ATTR_FILE_LINKCOUNT | ATTR_FILE_TOTALSIZE | ATTR_FILE_ALLOCSIZE;
    size_t bufsz = 256 * 1024;
    char* buf = (char*)malloc(bufsz);
    if (!buf) { close(fd); l->err = ENOMEM; return l; }
    for (;;) {
        int n = getattrlistbulk(fd, &al, buf, bufsz, 0);
        if (n < 0) { l->err = errno; break; }
        if (n == 0) break;
        parse(l, buf, n);
    }
    free(buf);
    close(fd);
    return l;
}

int      macae_attrlist_count(void* h)          { return h ? ((Listing*)h)->count : 0; }
int      macae_attrlist_errno(void* h)          { return h ? ((Listing*)h)->err : ENOMEM; }
static Entry* at(void* h, int i) {
    Listing* l = (Listing*)h;
    if (!l || i < 0 || i >= l->count) return NULL;
    return &l->items[i];
}
char*    macae_attrlist_name(void* h, int i)    { Entry* e = at(h, i); return strdup(e ? e->name : ""); }
int      macae_attrlist_kind(void* h, int i)    { Entry* e = at(h, i); return e ? e->kind : 0; }
int64_t  macae_attrlist_fileid(void* h, int i)  { Entry* e = at(h, i); return e ? (int64_t)e->fileid : 0; }
int      macae_attrlist_nlink(void* h, int i)   { Entry* e = at(h, i); return e ? (int)e->nlink : 0; }
int64_t  macae_attrlist_alloc(void* h, int i)   { Entry* e = at(h, i); return e ? e->alloc : 0; }
int64_t  macae_attrlist_size(void* h, int i)    { Entry* e = at(h, i); return e ? e->size : 0; }

void macae_attrlist_free(void* h) {
    Listing* l = (Listing*)h;
    if (!l) return;
    for (int i = 0; i < l->count; i++) free(l->items[i].name);
    free(l->items);
    free(l);
}
