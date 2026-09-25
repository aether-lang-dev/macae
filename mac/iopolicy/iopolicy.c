/* mac.iopolicy — the I/O policy of this process or thread, setiopolicy_np(3).
 * A disk scanner lowers itself to THROTTLE so the user's foreground apps
 * keep their disk bandwidth (OpenDisk did exactly this). Plain libSystem. */
#include <errno.h>
#include <sys/resource.h>

/* scope: 0 = this process, 1 = the calling thread. Returns 0 or errno. */
int macae_iopolicy_set(int policy, int scope) {
    int sc = scope == 1 ? IOPOL_SCOPE_THREAD : IOPOL_SCOPE_PROCESS;
    if (setiopolicy_np(IOPOL_TYPE_DISK, sc, policy) != 0) return errno ? errno : -1;
    return 0;
}

/* The current policy, or -1. */
int macae_iopolicy_get(int scope) {
    int sc = scope == 1 ? IOPOL_SCOPE_THREAD : IOPOL_SCOPE_PROCESS;
    return getiopolicy_np(IOPOL_TYPE_DISK, sc);
}

int macae_iopolicy_default(void)   { return IOPOL_DEFAULT; }
int macae_iopolicy_important(void) { return IOPOL_IMPORTANT; }
int macae_iopolicy_passive(void)   { return IOPOL_PASSIVE; }
int macae_iopolicy_throttle(void)  { return IOPOL_THROTTLE; }
int macae_iopolicy_utility(void)   { return IOPOL_UTILITY; }
int macae_iopolicy_standard(void)  { return IOPOL_STANDARD; }
