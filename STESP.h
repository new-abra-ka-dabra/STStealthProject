// STESP.h
#ifndef STESP_h
#define STESP_h

#include "STMemory.h"
#include "STOffsets.h"

struct STPlayerData {
    uintptr_t playerState;
    uintptr_t character;
    char name[64];
    float health;
    float healthMax;
    STVec3 headPos;
    STVec3 feetPos;
    bool valid;
};

static uintptr_t st_get_ue4_base(void) {
    return st_get_base("ShadowTrackerExtra");
}

static uintptr_t st_get_world(void) {
    uintptr_t base = st_get_ue4_base();
    if (!base) return 0;
    uintptr_t engine = st_read_ptr(base + OFF_GENGINE);
    if (!engine) return 0;
    uintptr_t viewport = st_read_ptr(engine + OFF_UENGINE_GAMEVIEWPORT);
    if (!viewport) return 0;
    return st_read_ptr(viewport + OFF_GAMEVIEWPORT_WORLD);
}

static uintptr_t st_get_local_player_controller(void) {
    uintptr_t base = st_get_ue4_base();
    if (!base) return 0;
    uintptr_t engine = st_read_ptr(base + OFF_GENGINE);
    if (!engine) return 0;
    uintptr_t viewport = st_read_ptr(engine + OFF_UENGINE_GAMEVIEWPORT);
    if (!viewport) return 0;
    uintptr_t gameInstance = st_read_ptr(viewport + OFF_GAMEVIEWPORT_GAMEINSTANCE);
    if (!gameInstance) return 0;
    uintptr_t localPlayers = st_read_ptr(gameInstance + OFF_GAMEINSTANCE_LOCALPLAYERS);
    if (!localPlayers) return 0;
    uintptr_t lp0 = st_read_ptr(localPlayers + OFF_TARRAY_DATA);
    if (!lp0) return 0;
    return st_read_ptr(lp0 + OFF_LOCALPLAYER_PLAYERCONTROLLER);
}

static bool st_get_camera(STVec3 &camLoc, STRot &camRot, float &fov) {
    uintptr_t pc = st_get_local_player_controller();
    if (!pc) return false;
    uintptr_t camMgr = st_read_ptr(pc + OFF_PLAYERCONTROLLER_CAMERAMANAGER);
    if (!camMgr) return false;

    camLoc.x = st_read_float(camMgr + OFF_CAM_X);
    camLoc.y = st_read_float(camMgr + OFF_CAM_Y);
    camLoc.z = st_read_float(camMgr + OFF_CAM_Z);
    camRot.pitch = st_read_float(camMgr + OFF_CAM_PITCH);
    camRot.yaw = st_read_float(camMgr + OFF_CAM_YAW);
    camRot.roll = st_read_float(camMgr + OFF_CAM_ROLL);
    fov = st_read_float(camMgr + OFF_CAM_FOV);

    return camLoc.x != 0 && camLoc.y != 0;
}

static bool st_world_to_screen(const STVec3 &world, const STVec3 &camLoc,
                                const STRot &camRot, float fov,
                                float screenW, float screenH,
                                float &outX, float &outY) {
    float dx = world.x - camLoc.x;
    float dy = world.y - camLoc.y;
    float dz = world.z - camLoc.z;

    float p = camRot.pitch * (float)M_PI / 180.0f;
    float y = camRot.yaw   * (float)M_PI / 180.0f;
    float r = camRot.roll  * (float)M_PI / 180.0f;

    float sp = sinf(p), cp = cosf(p);
    float sy = sinf(y), cy = cosf(y);
    float sr = sinf(r), cr = cosf(r);

    float x1 = dx * cr - dy * sr;
    float y1 = dx * sr + dy * cr;
    float z1 = dz;

    float x2 = x1;
    float y2 = y1 * cp - z1 * sp;
    float z2 = y1 * sp + z1 * cp;

    float x3 = x2 * cy - y2 * sy;
    float y3 = x2 * sy + y2 * cy;
    float z3 = z2;

    if (x3 < 1.0f) return false;

    float fovRad = fov * (float)M_PI / 180.0f;
    float tanHalf = tanf(fovRad * 0.5f);

    float screenX = (y3 / x3) / (tanHalf * (screenW / screenH)) * 0.5f + 0.5f;
    float screenY = 0.5f - (z3 / x3) / tanHalf * 0.5f;

    outX = screenX * screenW;
    outY = screenY * screenH;
    return true;
}

static void st_read_player(uintptr_t playerState, STPlayerData &out) {
    memset(&out, 0, sizeof(out));
    out.playerState = playerState;
    if (!playerState) return;

    st_read_fstring(playerState + OFF_PS_PLAYERNAME, out.name, sizeof(out.name));
    out.health = st_read_float(playerState + OFF_PS_PLAYERHEALTH);
    out.healthMax = st_read_float(playerState + OFF_PS_PLAYERHEALTHMAX);
    out.character = st_read_ptr(playerState + OFF_PS_CHARACTEROWNER);
    if (!out.character) return;

    uintptr_t mesh = st_read_ptr(out.character + OFF_CHAR_MESH);
    if (!mesh) return;

    uintptr_t bonesData = st_read_ptr(mesh + OFF_MESH_CACHEDBONESPACE + OFF_TARRAY_DATA);
    if (!bonesData) return;

    uintptr_t headTransform = bonesData + (BONE_HEAD * 0x30);
    out.headPos = st_read_vec3(headTransform + OFF_TRANSFORM_TRANSLATION);

    uintptr_t pelvisTransform = bonesData + (BONE_PELVIS * 0x30);
    out.feetPos = st_read_vec3(pelvisTransform + OFF_TRANSFORM_TRANSLATION);

    out.valid = true;
}

#endif /* STESP_h */
