// STMenu.mm
// ImGui menu for iOS with proper Metal backend init, font atlas
// build, and safe render loop.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CADisplayLink.h>
#import <objc/runtime.h>
#include <os/log.h>

#include "imgui.h"
#include "imgui_impl_metal.h"
#include "STESP.h"

#define STLOG(fmt, ...) os_log(OS_LOG_DEFAULT, "[STStealth] " fmt, ##__VA_ARGS__)

// ============================================================
// GLOBAL STATE
// ============================================================
static bool g_menuOpen = false;
static bool g_espEnabled = false;
static bool g_espBox = true;
static bool g_espName = true;
static bool g_espHealth = true;
static bool g_espDistance = true;
static bool g_espBones = false;

static bool g_buttonDragging = false;
static ImVec2 g_buttonPos = ImVec2(100, 200);
static ImVec2 g_dragOffset;

static float g_screenW = 0;
static float g_screenH = 0;

// ============================================================
// OVERLAY VIEW
// ============================================================
@interface STOverlayView : UIView
@end

@implementation STOverlayView

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        self.opaque = NO;
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    CGFloat bx = g_buttonPos.x, by = g_buttonPos.y, bs = 60;
    if (point.x >= bx && point.x <= bx + bs && point.y >= by && point.y <= by + bs) {
        return self;
    }
    if (g_menuOpen) {
        CGFloat mw = 280, mh = 320;
        CGFloat mx = g_screenW * 0.5f - mw * 0.5f;
        CGFloat my = g_screenH * 0.5f - mh * 0.5f;
        if (point.x >= mx && point.x <= mx + mw && point.y >= my && point.y <= my + mh) {
            return self;
        }
    }
    return nil;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    CGPoint p = [t locationInView:self];
    CGFloat bx = g_buttonPos.x, by = g_buttonPos.y, bs = 60;
    if (p.x >= bx && p.x <= bx + bs && p.y >= by && p.y <= by + bs) {
        g_buttonDragging = true;
        g_dragOffset = ImVec2(p.x - bx, p.y - by);
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (g_buttonDragging) {
        UITouch *t = [touches anyObject];
        CGPoint p = [t locationInView:self];
        g_buttonPos.x = p.x - g_dragOffset.x;
        g_buttonPos.y = p.y - g_dragOffset.y;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    CGPoint p = [t locationInView:self];
    CGFloat bx = g_buttonPos.x, by = g_buttonPos.y, bs = 60;
    if (p.x >= bx && p.x <= bx + bs && p.y >= by && p.y <= by + bs) {
        g_menuOpen = !g_menuOpen;
    }
    g_buttonDragging = false;
}

@end

// ============================================================
// RENDER TARGET
// ============================================================
@interface STMenuRenderer : NSObject
- (void)render:(CADisplayLink *)link;
@end

static STOverlayView *g_overlay = nil;
static id<MTLDevice> g_device = nil;
static id<MTLCommandQueue> g_queue = nil;
static STMenuRenderer *g_renderer = nil;
static CADisplayLink *g_displayLink = nil;

@implementation STMenuRenderer

- (void)render:(CADisplayLink *)link {
    @autoreleasepool {
        if (!g_overlay) return;

        if (g_screenW == 0) {
            CGRect bounds = [UIScreen mainScreen].bounds;
            g_screenW = bounds.size.width;
            g_screenH = bounds.size.height;
        }

        CAMetalLayer *layer = (CAMetalLayer *)g_overlay.layer;
        id<CAMetalDrawable> drawable = [layer nextDrawable];
        if (!drawable) return;

        MTLRenderPassDescriptor *desc = [MTLRenderPassDescriptor renderPassDescriptor];
        desc.colorAttachments[0].texture = drawable.texture;
        desc.colorAttachments[0].loadAction = MTLLoadActionClear;
        desc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
        desc.colorAttachments[0].storeAction = MTLStoreActionStore;

        ImGui_ImplMetal_NewFrame(desc);
        ImGui::NewFrame();

        // Floating button
        {
            ImGui::SetNextWindowPos(g_buttonPos, ImGuiCond_Always);
            ImGui::SetNextWindowSize(ImVec2(60, 60), ImGuiCond_Always);
            ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 30.0f);
            ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0.1f, 0.6f, 0.2f, 0.85f));
            ImGui::Begin("##stbtn", nullptr,
                ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize |
                ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_NoMove |
                ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoBringToFrontOnFocus |
                ImGuiWindowFlags_NoInputs);
            ImGui::SetCursorPos(ImVec2(18, 18));
            ImGui::TextColored(ImVec4(1,1,1,1), "ST");
            ImGui::End();
            ImGui::PopStyleColor();
            ImGui::PopStyleVar();
        }

        // ESP drawing
        if (g_espEnabled) {
            uintptr_t world = st_get_world();
            if (world) {
                STVec3 camLoc;
                STRot camRot;
                float fov;
                if (st_get_camera(camLoc, camRot, fov)) {
                    uintptr_t gameState = st_read_ptr(world + OFF_WORLD_GAMESTATE);
                    if (gameState && gameState > 0x1000) {
                        uintptr_t playerArray = st_read_ptr(gameState + OFF_GAMESTATE_PLAYERARRAY);
                        if (playerArray && playerArray > 0x1000) {
                            uintptr_t arrData = st_read_ptr(playerArray + OFF_TARRAY_DATA);
                            int32_t arrCount = st_read_i32(playerArray + OFF_TARRAY_COUNT);
                            if (arrData && arrData > 0x1000 && arrCount > 0 && arrCount < 200) {
                                ImDrawList *draw = ImGui::GetBackgroundDrawList();
                                for (int i = 0; i < arrCount; i++) {
                                    uintptr_t ps = st_read_ptr(arrData + i * 8);
                                    if (!ps || ps < 0x1000) continue;
                                    STPlayerData pd;
                                    st_read_player(ps, pd);
                                    if (!pd.valid) continue;

                                    float hx, hy, fx, fy;
                                    if (!st_world_to_screen(pd.headPos, camLoc, camRot, fov, g_screenW, g_screenH, hx, hy)) continue;
                                    if (!st_world_to_screen(pd.feetPos, camLoc, camRot, fov, g_screenW, g_screenH, fx, fy)) continue;

                                    float boxH = fy - hy;
                                    if (boxH < 2.0f || boxH > 2000.0f) continue;
                                    float boxW = boxH * 0.5f;
                                    float left = hx - boxW * 0.5f;
                                    float right = hx + boxW * 0.5f;
                                    float top = hy;
                                    float bottom = fy;

                                    if (g_espBox) {
                                        draw->AddRect(ImVec2(left, top), ImVec2(right, bottom),
                                                      IM_COL32(0, 255, 0, 255), 0, 0, 1.5f);
                                    }
                                    if (g_espName && pd.name[0]) {
                                        draw->AddText(ImVec2(left, top - 14),
                                                      IM_COL32(255, 255, 255, 255), pd.name);
                                    }
                                    if (g_espHealth && pd.healthMax > 0) {
                                        float pct = pd.health / pd.healthMax;
                                        if (pct > 1) pct = 1;
                                        if (pct < 0) pct = 0;
                                        float barW = 3;
                                        draw->AddRectFilled(ImVec2(left - barW - 2, top),
                                                            ImVec2(left - 2, bottom),
                                                            IM_COL32(0, 0, 0, 180));
                                        draw->AddRectFilled(ImVec2(left - barW - 2, bottom - (bottom - top) * pct),
                                                            ImVec2(left - 2, bottom),
                                                            IM_COL32((int)(255*(1-pct)), (int)(255*pct), 0, 255));
                                    }
                                    if (g_espDistance) {
                                        float dx = pd.headPos.x - camLoc.x;
                                        float dy = pd.headPos.y - camLoc.y;
                                        float dz = pd.headPos.z - camLoc.z;
                                        float dist = sqrtf(dx*dx + dy*dy + dz*dz) / 100.0f;
                                        char dbuf[32];
                                        snprintf(dbuf, sizeof(dbuf), "%.0fm", dist);
                                        draw->AddText(ImVec2(left, bottom + 2),
                                                      IM_COL32(255, 255, 0, 255), dbuf);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Menu
        if (g_menuOpen) {
            ImGui::SetNextWindowSize(ImVec2(280, 320), ImGuiCond_FirstUseEver);
            ImGui::SetNextWindowPos(ImVec2(g_screenW * 0.5f - 140, g_screenH * 0.5f - 160),
                                    ImGuiCond_FirstUseEver);
            ImGui::Begin("ST Menu", &g_menuOpen,
                         ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize);

            ImGui::Text("ESP Settings");
            ImGui::Separator();
            ImGui::Checkbox("Enable ESP", &g_espEnabled);
            ImGui::Checkbox("Box", &g_espBox);
            ImGui::Checkbox("Name", &g_espName);
            ImGui::Checkbox("Health", &g_espHealth);
            ImGui::Checkbox("Distance", &g_espDistance);
            ImGui::Checkbox("Bones", &g_espBones);
            ImGui::Separator();
            if (ImGui::Button("Close", ImVec2(260, 30))) {
                g_menuOpen = false;
            }
            ImGui::End();
        }

        ImGui::Render();

        id<MTLCommandBuffer> cmd = [g_queue commandBuffer];
        id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:desc];
        ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmd, enc);
        [enc endEncoding];
        [cmd presentDrawable:drawable];
        [cmd commit];
    }
}

@end

// ============================================================
// PUBLIC START
// ============================================================
void st_start_menu(void) {
    STLOG("st_start_menu called");
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow && !w.hidden && w.alpha > 0.5) {
                keyWindow = w;
                break;
            }
        }
        if (!keyWindow) {
            STLOG("no valid key window");
            return;
        }
        if (keyWindow.bounds.size.width < 100) {
            STLOG("key window too small");
            return;
        }

        STLOG("key window: %@", NSStringFromCGRect(keyWindow.bounds));

        g_screenW = keyWindow.bounds.size.width;
        g_screenH = keyWindow.bounds.size.height;

        g_overlay = [[STOverlayView alloc] initWithFrame:keyWindow.bounds];
        if (!g_overlay) {
            STLOG("overlay alloc failed");
            return;
        }
        [keyWindow addSubview:g_overlay];

        g_device = MTLCreateSystemDefaultDevice();
        if (!g_device) {
            STLOG("metal device nil");
            return;
        }
        g_queue = [g_device newCommandQueue];
        if (!g_queue) {
            STLOG("command queue nil");
            return;
        }

        IMGUI_CHECKVERSION();
        ImGui::CreateContext();
        ImGuiIO &io = ImGui::GetIO();
        io.DisplaySize = ImVec2(g_screenW, g_screenH);
        io.Fonts->AddFontDefault();
        io.Fonts->Build();  // <-- CRITICAL FIX

        if (!ImGui_ImplMetal_Init(g_device)) {
            STLOG("ImGui_ImplMetal_Init failed");
            return;
        }

        g_renderer = [[STMenuRenderer alloc] init];
        g_displayLink = [CADisplayLink displayLinkWithTarget:g_renderer
                                                    selector:@selector(render:)];
        if (!g_displayLink) {
            STLOG("display link nil");
            return;
        }
        [g_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

        STLOG("=== MENU STARTED ===");
    });
}
