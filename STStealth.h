// STStealth.h
// Disguised as a system image loader helper to blend with iOS dyld cache

#ifndef STStealth_h
#define STStealth_h

#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/sysctl.h>
#include <time.h>

// ============================================================
// STRING OBFUSCATION - compile-time XOR
// ============================================================
#define XSTR_KEY 0x5A

static inline void st_xor(char *s, size_t len) {
    for (size_t i = 0; i < len; i++) s[i] ^= XSTR_KEY;
}

#define OBFUSCATE(str) ({ \
    static char _buf[] = str; \
    static int _init = 0; \
    if (!_init) { st_xor(_buf, sizeof(_buf) - 1); _init = 1; } \
    _buf; \
})

// ============================================================
// ANTI-DEBUG
// ============================================================
static inline int st_anti_debug(void) {
    int mib[4];
    struct kinfo_proc info;
    size_t size = sizeof(info);
    info.kp_proc.p_flag = 0;
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();
    sysctl(mib, 4, &info, &size, NULL, 0);
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

// ============================================================
// DYLD IMAGE HIDING
// ============================================================
struct st_hidden_image {
    const struct mach_header *header;
    const char *path;
    void *next;
};

static struct st_hidden_image *st_hidden_list = NULL;

static inline void st_hide_image(const struct mach_header *mh) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const struct mach_header *h = _dyld_get_image_header(i);
        if (h == mh) {
            struct st_hidden_image *node =
                (struct st_hidden_image *)malloc(sizeof(struct st_hidden_image));
            if (!node) return;
            node->header = mh;
            node->path = _dyld_get_image_name(i);
            node->next = st_hidden_list;
            st_hidden_list = node;
            break;
        }
    }
}

// ============================================================
// DELAYED LOAD (kept for compatibility, unused now)
// ============================================================
static inline void st_delay_load(void) {
    srand((unsigned)time(NULL) ^ getpid());
    int delay = 10 + (rand() % 9);
    sleep(delay);
}

// ============================================================
// MACH-O HEADER WIPE
// ============================================================
static inline void st_wipe_header(void) {
    Dl_info info;
    if (dladdr((void*)&st_wipe_header, &info)) {
        vm_address_t base = (vm_address_t)info.dli_fbase;
        vm_size_t page_size = 0x1000;
        vm_protect(mach_task_self(), base, page_size, 0, VM_PROT_READ | VM_PROT_WRITE);
        memset((void*)base, 0, page_size);
        vm_protect(mach_task_self(), base, page_size, 0, VM_PROT_READ | VM_PROT_EXECUTE);
    }
}

#endif /* STStealth_h */
