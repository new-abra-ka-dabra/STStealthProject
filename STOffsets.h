// STOffsets.h
// ShadowTrackerExtra / PUBG Mobile 4.6.0 (21520) - arm64
// WARNING: These offsets may not match your game version.
// Verify with a class dumper before trusting.

#ifndef STOffsets_h
#define STOffsets_h

// Global engine pointers (VERIFY FOR YOUR BUILD)
#define OFF_GENGINE    0x109CD42A0
#define OFF_GNAMES     0x109888A70
#define OFF_GOBJECTS   0x109ABC718

// Pointer chain
#define OFF_UENGINE_GAMEVIEWPORT        0x0810
#define OFF_GAMEVIEWPORT_WORLD          0x0078
#define OFF_GAMEVIEWPORT_GAMEINSTANCE   0x0080
#define OFF_WORLD_GAMESTATE             0x0428
#define OFF_GAMESTATE_PLAYERARRAY       0x04C8
#define OFF_GAMEINSTANCE_LOCALPLAYERS   0x0048
#define OFF_LOCALPLAYER_PLAYERCONTROLLER 0x0030
#define OFF_PLAYERCONTROLLER_CAMERAMANAGER 0x0548
#define OFF_CAMERAMANAGER_CAMERACACHE   0x0520
#define OFF_CAMERACACHE_POV             0x0010

// POV layout
#define OFF_POV_LOCATION    0x0000
#define OFF_POV_ROTATION    0x0018
#define OFF_POV_FOV         0x0024

// Absolute camera offsets
#define OFF_CAM_X       0x0530
#define OFF_CAM_Y       0x0534
#define OFF_CAM_Z       0x0538
#define OFF_CAM_PITCH   0x0548
#define OFF_CAM_YAW     0x054C
#define OFF_CAM_ROLL    0x0550
#define OFF_CAM_FOV     0x0554

// PlayerState
#define OFF_PS_PLAYERNAME           0x04B8
#define OFF_PS_LIVESTATE            0x13F4
#define OFF_PS_CHARACTEROWNER       0x1410
#define OFF_PS_PLAYERHEALTH         0x142C
#define OFF_PS_PLAYERHEALTHMAX      0x1430
#define OFF_PS_INTEAMINDEX          0x15C0

// Character
#define OFF_CHAR_MESH               0x0510

// Mesh
#define OFF_MESH_CACHEDBONESPACE    0x0CD0

// TArray
#define OFF_TARRAY_DATA    0x00
#define OFF_TARRAY_COUNT   0x08

// FString
#define OFF_FSTRING_DATA   0x00
#define OFF_FSTRING_COUNT  0x08

// FTransform
#define OFF_TRANSFORM_ROTATION     0x00
#define OFF_TRANSFORM_TRANSLATION  0x10

// Bone IDs
#define BONE_HEAD        6
#define BONE_NECK        5
#define BONE_SPINE       4
#define BONE_PELVIS      1
#define BONE_L_HAND      33
#define BONE_R_HAND      17
#define BONE_L_FOOT      62
#define BONE_R_FOOT      55

#endif /* STOffsets_h */
