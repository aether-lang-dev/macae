/* mac.keychain — a secret in the user's login keychain, as a generic
 * password keyed by (service, account). Security.framework's C API. The
 * item is created with the default access: the app that made it reads it
 * back without a prompt; another app prompts the user. */
#include <Security/Security.h>
#include <stdlib.h>
#include <string.h>

static CFStringRef cfs(const char* s) {
    return CFStringCreateWithCString(NULL, s ? s : "", kCFStringEncodingUTF8);
}

static CFMutableDictionaryRef query(const char* service, const char* account) {
    CFMutableDictionaryRef q = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks,
                                                         &kCFTypeDictionaryValueCallBacks);
    CFStringRef s = cfs(service), a = cfs(account);
    CFDictionarySetValue(q, kSecClass, kSecClassGenericPassword);
    CFDictionarySetValue(q, kSecAttrService, s);
    CFDictionarySetValue(q, kSecAttrAccount, a);
    CFRelease(s); CFRelease(a);
    return q;
}

/* OSStatus: 0 ok, errSecItemNotFound (-25300), errSecAuthFailed (-25293), … */
int macae_keychain_set(const char* service, const char* account, const char* secret) {
    CFMutableDictionaryRef q = query(service, account);
    SecItemDelete(q);                 /* replace, not duplicate */
    CFDataRef d = CFDataCreate(NULL, (const UInt8*)(secret ? secret : ""), (CFIndex)strlen(secret ? secret : ""));
    CFDictionarySetValue(q, kSecValueData, d);
    OSStatus st = SecItemAdd(q, NULL);
    CFRelease(d);
    CFRelease(q);
    return (int)st;
}

static int s_last_status;
int macae_keychain_last_status(void) { return s_last_status; }

/* The secret, or "" — last_status() tells "" apart from not-found. */
char* macae_keychain_get(const char* service, const char* account) {
    CFMutableDictionaryRef q = query(service, account);
    CFDictionarySetValue(q, kSecReturnData, kCFBooleanTrue);
    CFDictionarySetValue(q, kSecMatchLimit, kSecMatchLimitOne);
    CFTypeRef out = NULL;
    s_last_status = (int)SecItemCopyMatching(q, &out);
    CFRelease(q);
    if (s_last_status != errSecSuccess || !out) return strdup("");
    CFDataRef d = (CFDataRef)out;
    CFIndex n = CFDataGetLength(d);
    char* r = (char*)malloc((size_t)n + 1);
    if (!r) { CFRelease(out); return strdup(""); }
    memcpy(r, CFDataGetBytePtr(d), (size_t)n);
    r[n] = '\0';
    CFRelease(out);
    return r;
}

int macae_keychain_delete(const char* service, const char* account) {
    CFMutableDictionaryRef q = query(service, account);
    OSStatus st = SecItemDelete(q);
    CFRelease(q);
    return (int)st;
}

/* Can this process use the keychain at all? A READ probe is not enough: a
 * session with no UI (ssh, some CI) answers "not found" to a lookup and
 * "user interaction is not allowed" (-25308) to a write. So: add a probe
 * item and delete it again. 1 only when the add succeeded. */
int macae_keychain_available(void) {
    const char* svc = "org.macae.probe";
    OSStatus st = (OSStatus)macae_keychain_set(svc, "probe", "probe");
    if (st != errSecSuccess) return 0;
    macae_keychain_delete(svc, "probe");
    return 1;
}

char* macae_keychain_status_text(int st) {
    CFStringRef s = SecCopyErrorMessageString((OSStatus)st, NULL);
    if (!s) return strdup("");
    char buf[512];
    if (!CFStringGetCString(s, buf, sizeof(buf), kCFStringEncodingUTF8)) buf[0] = '\0';
    CFRelease(s);
    return strdup(buf);
}
