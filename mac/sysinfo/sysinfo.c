/* mac.sysinfo — what this Mac is, from sysctl(3). Plain libSystem, no
 * framework. Strings are strdup'd for Aether (`@heap`); "" when a key is
 * absent (an Intel Mac has no hw.optional.arm64, a VM may lack a model). */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <unistd.h>

static char* str_key(const char* key) {
    size_t len = 0;
    if (sysctlbyname(key, NULL, &len, NULL, 0) != 0 || len == 0) return strdup("");
    char* buf = (char*)malloc(len + 1);
    if (!buf) return strdup("");
    if (sysctlbyname(key, buf, &len, NULL, 0) != 0) { free(buf); return strdup(""); }
    buf[len] = '\0';
    return buf;
}

static int64_t int_key(const char* key, int64_t missing) {
    int64_t v64 = 0;
    size_t len = sizeof(v64);
    if (sysctlbyname(key, &v64, &len, NULL, 0) != 0) return missing;
    if (len == sizeof(int32_t)) { int32_t v32; memcpy(&v32, &v64, sizeof(v32)); return v32; }
    return v64;
}

char*   macae_sysinfo_model(void)        { return str_key("hw.model"); }
char*   macae_sysinfo_os_version(void)   { return str_key("kern.osproductversion"); }
char*   macae_sysinfo_os_build(void)     { return str_key("kern.osversion"); }
char*   macae_sysinfo_cpu_brand(void)    { return str_key("machdep.cpu.brand_string"); }
char*   macae_sysinfo_hostname(void)     { return str_key("kern.hostname"); }
int64_t macae_sysinfo_memory_bytes(void) { return int_key("hw.memsize", 0); }
int     macae_sysinfo_cpu_count(void)    { return (int)int_key("hw.ncpu", 0); }
int     macae_sysinfo_perf_cores(void)   { return (int)int_key("hw.perflevel0.physicalcpu", 0); }
int     macae_sysinfo_eff_cores(void)    { return (int)int_key("hw.perflevel1.physicalcpu", 0); }
/* 1 on Apple silicon (hw.optional.arm64 exists and is 1), 0 on Intel. */
int     macae_sysinfo_apple_silicon(void) { return int_key("hw.optional.arm64", 0) == 1 ? 1 : 0; }
/* 1 when this process runs under Rosetta 2 (sysctl.proc_translated). */
int     macae_sysinfo_translated(void)   { return int_key("sysctl.proc_translated", 0) == 1 ? 1 : 0; }
int64_t macae_sysinfo_boot_time(void) {
    struct timeval tv; size_t len = sizeof(tv);
    if (sysctlbyname("kern.boottime", &tv, &len, NULL, 0) != 0) return 0;
    return (int64_t)tv.tv_sec;
}
int64_t macae_sysinfo_page_size(void)    { return (int64_t)getpagesize(); }
