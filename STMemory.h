// STMemory.h
// Read-only memory access. No writes to game memory at all.

#ifndef STMemory_h
#define STMemory_h

#include <mach/mach.h>
#include <stdint.h>
#include <string.h>
#include <mach-o/dyld.h>
#include <math.h>

static uintptr_t st_ue4_base = 0;

static inline uintptr_t st_get_base(const char *module) {
    if (st_ue4_base) return st_ue4_base;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, module)) {
            st_ue4_base = (uintptr_t)_dyld_get_image_header(i);
            return st_ue4_base;
        }
    }
    return 0;
}

static inline bool st_read(uintptr_t addr, void *out, size_t size) {
    if (!addr || !out || size == 0 || size > 0x1000) return false;
    vm_size_t out_size = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(),
                                          (vm_address_t)addr,
                                          (vm_size_t)size,
                                          (vm_address_t)out,
                                          &out_size);
    return (kr == KERN_SUCCESS && out_size == size);
}

template <typename T>
static inline T st_read_t(uintptr_t addr) {
    T val = {};
    st_read(addr, &val, sizeof(T));
    return val;
}

static inline uintptr_t st_read_ptr(uintptr_t addr) {
    return st_read_t<uintptr_t>(addr);
}

static inline float st_read_float(uintptr_t addr) {
    return st_read_t<float>(addr);
}

static inline int32_t st_read_i32(uintptr_t addr) {
    return st_read_t<int32_t>(addr);
}

static inline uint8_t st_read_u8(uintptr_t addr) {
    return st_read_t<uint8_t>(addr);
}

struct STVec3 { float x, y, z; };
static inline STVec3 st_read_vec3(uintptr_t addr) {
    return st_read_t<STVec3>(addr);
}

struct STRot { float pitch, yaw, roll; };
static inline STRot st_read_rot(uintptr_t addr) {
    return st_read_t<STRot>(addr);
}

static inline bool st_read_fstring(uintptr_t addr, char *out, size_t out_size) {
    uintptr_t data = st_read_ptr(addr + 0x00);
    int32_t count = st_read_i32(addr + 0x08);
    if (!data || count <= 0 || count > 128) return false;

    uint16_t wbuf[128] = {0};
    if (!st_read(data, wbuf, count * 2)) return false;

    size_t j = 0;
    for (int i = 0; i < count && j < out_size - 1; i++) {
        uint16_t wc = wbuf[i];
        if (wc < 0x80) {
            out[j++] = (char)wc;
        } else if (wc < 0x800) {
            out[j++] = 0xC0 | (wc >> 6);
            out[j++] = 0x80 | (wc & 0x3F);
        } else {
            out[j++] = 0xE0 | (wc >> 12);
            out[j++] = 0x80 | ((wc >> 6) & 0x3F);
            out[j++] = 0x80 | (wc & 0x3F);
        }
    }
    out[j] = 0;
    return true;
}

#endif /* STMemory_h */
