/* mac.fda — has this process been granted Full Disk Access? There is no API
 * that answers; the honest probe (OpenDisk's) is to try reading things TCC
 * protects. Each probe that EXISTS must be readable for a "granted". A
 * probe that does not exist says nothing. Plain libSystem. */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

/* 1 readable, 0 denied (EPERM/EACCES), -1 absent. */
static int probe_dir(const char* p) {
    struct stat st;
    if (lstat(p, &st) != 0) return -1;
    DIR* d = opendir(p);
    if (d) { closedir(d); return 1; }
    return (errno == EPERM || errno == EACCES) ? 0 : -1;
}
static int probe_file(const char* p) {
    struct stat st;
    if (lstat(p, &st) != 0) return -1;
    int fd = open(p, O_RDONLY | O_CLOEXEC);
    if (fd >= 0) { close(fd); return 1; }
    return (errno == EPERM || errno == EACCES) ? 0 : -1;
}

/* 1 granted, 0 denied, 2 undetermined (nothing to probe exists). */
int macae_fda_probe(void) {
    const char* home = getenv("HOME");
    if (!home || !*home) return 2;
    const char* dirs[] = { "/Library/Containers/com.apple.stocks", "/Library/Safari",
                           "/Library/Mail", "/Library/Messages", NULL };
    int seen = 0;
    char buf[4096];
    for (int i = 0; dirs[i]; i++) {
        snprintf(buf, sizeof(buf), "%s%s", home, dirs[i]);
        int r = probe_dir(buf);
        if (r == 0) return 0;
        if (r == 1) seen = 1;
    }
    int r = probe_file("/Library/Preferences/com.apple.TimeMachine.plist");
    if (r == 0) return 0;
    if (r == 1) seen = 1;
    return seen ? 1 : 2;
}
