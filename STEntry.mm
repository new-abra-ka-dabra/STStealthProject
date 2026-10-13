// STEntry.mm
// Dylib constructor. Runs on dlopen. Delays, then starts menu.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "STStealth.h"
#include "STMenu.h"

__attribute__((constructor))
static void st_dylib_init(void) {
    // 1. Disguise ourselves as a system image
    const struct mach_header *mh = (const struct mach_header *)_dyld_get_image_header(0);
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "STStealth")) {
            mh = _dyld_get_image_header(i);
            break;
        }
    }
    st_hide_image(mh);

    // 2. Wait for ACE initial scan to finish, then start menu
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        st_delay_load();

        if (st_anti_debug()) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            st_start_menu();
        });
    });
}
