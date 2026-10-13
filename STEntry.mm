// STEntry.mm
// Dylib constructor with game-state polling.
// Does absolutely nothing until the game is fully loaded
// and past the resource download.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <os/log.h>
#include <mach-o/dyld.h>
#include "STStealth.h"
#include "STMenu.h"

#define STLOG(fmt, ...) os_log(OS_LOG_DEFAULT, "[STStealth] " fmt, ##__VA_ARGS__)

// ============================================================
// GAME STATE DETECTION
// ============================================================
static BOOL st_is_download_active(void) {
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (!w.isKeyWindow) continue;
        if (w.subviews.count < 2) return YES;
    }
    return NO;
}

static BOOL st_is_game_ready(void) {
    uint32_t count = _dyld_image_count();
    BOOL found_main = NO;
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, "ShadowTrackerExtra")) {
            found_main = YES;
            break;
        }
    }
    if (!found_main) return NO;
    if (st_is_download_active()) return NO;

    UIWindow *keyWindow = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow && !w.hidden && w.alpha > 0.5) {
            keyWindow = w;
            break;
        }
    }
    if (!keyWindow) return NO;
    if (keyWindow.bounds.size.width < 100) return NO;
    return YES;
}

// ============================================================
// WAIT LOOP
// ============================================================
static void st_wait_for_game(int attempt) {
    if (attempt > 600) {   // ~10 minutes max
        STLOG("gave up waiting");
        return;
    }
    if (!st_is_game_ready()) {
        if (attempt % 15 == 0) STLOG("waiting... attempt %d", attempt);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            st_wait_for_game(attempt + 1);
        });
        return;
    }
    STLOG("=== GAME READY ===");
    st_start_menu();
}

// ============================================================
// ENTRY
// ============================================================
__attribute__((constructor))
static void st_dylib_init(void) {
    STLOG("=== DYLIB LOADED ===");
    STLOG("pid = %d", getpid());

    const struct mach_header *mh = NULL;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "STStealth")) {
            mh = _dyld_get_image_header(i);
            STLOG("found self at image %u", i);
            break;
        }
    }
    if (mh) st_hide_image(mh);

    if (st_anti_debug()) {
        STLOG("debugger attached, bailing");
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        // Long initial delay: let ACE run its first scan AND
        // let the game start its resource download.
        STLOG("initial 30s delay");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            STLOG("starting game-state polling");
            st_wait_for_game(0);
        });
    });
}
