#include "fakeCSurfWrapper.h"

#include "fakeCsurf.h"
#include <new>

extern "C" {

C_FakeCsurf FakeCsurf_Create(const ZigCsurf* zigCsurf) {
    return new(std::nothrow) FakeCsurf(zigCsurf);
}

void FakeCsurf_Destroy(C_FakeCsurf instance) {
    delete static_cast<FakeCsurf*>(instance);
}

const char* FakeCsurf_GetTypeString(C_FakeCsurf instance) {
    return static_cast<FakeCsurf*>(instance)->GetTypeString();
}

const char* FakeCsurf_GetDescString(C_FakeCsurf instance) {
    return static_cast<FakeCsurf*>(instance)->GetDescString();
}

const char* FakeCsurf_GetConfigString(C_FakeCsurf instance) {
    return static_cast<FakeCsurf*>(instance)->GetConfigString();
}

void FakeCsurf_CloseNoReset(C_FakeCsurf instance) {
    static_cast<FakeCsurf*>(instance)->CloseNoReset();
}

void FakeCsurf_Run(C_FakeCsurf instance) {
    static_cast<FakeCsurf*>(instance)->Run();
}

void FakeCsurf_SetTrackListChange(C_FakeCsurf instance) {
    static_cast<FakeCsurf*>(instance)->SetTrackListChange();
}

void FakeCsurf_SetSurfaceVolume(C_FakeCsurf instance, MediaTrack* trackid, double volume) {
    static_cast<FakeCsurf*>(instance)->SetSurfaceVolume(trackid, volume);
}

void FakeCsurf_SetSurfacePan(C_FakeCsurf instance, MediaTrack* trackid, double pan) {
    static_cast<FakeCsurf*>(instance)->SetSurfacePan(trackid, pan);
}

void FakeCsurf_SetSurfaceMute(C_FakeCsurf instance, MediaTrack* trackid, bool mute) {
    static_cast<FakeCsurf*>(instance)->SetSurfaceMute(trackid, mute);
}

void FakeCsurf_SetSurfaceSelected(C_FakeCsurf instance, MediaTrack* trackid, bool selected) {
    static_cast<FakeCsurf*>(instance)->SetSurfaceSelected(trackid, selected);
}

void FakeCsurf_SetSurfaceSolo(C_FakeCsurf instance, MediaTrack* trackid, bool solo) {
    static_cast<FakeCsurf*>(instance)->SetSurfaceSolo(trackid, solo);
}

void FakeCsurf_SetSurfaceRecArm(C_FakeCsurf instance, MediaTrack* trackid, bool recarm) {
    static_cast<FakeCsurf*>(instance)->SetSurfaceRecArm(trackid, recarm);
}

void FakeCsurf_SetPlayState(C_FakeCsurf instance, bool play, bool pause, bool rec) {
    static_cast<FakeCsurf*>(instance)->SetPlayState(play, pause, rec);
}

void FakeCsurf_SetRepeatState(C_FakeCsurf instance, bool rep) {
    static_cast<FakeCsurf*>(instance)->SetRepeatState(rep);
}

void FakeCsurf_SetTrackTitle(C_FakeCsurf instance, MediaTrack* trackid, const char* title) {
    static_cast<FakeCsurf*>(instance)->SetTrackTitle(trackid, title);
}

bool FakeCsurf_GetTouchState(C_FakeCsurf instance, MediaTrack* trackid, int isPan) {
    return static_cast<FakeCsurf*>(instance)->GetTouchState(trackid, isPan);
}

void FakeCsurf_SetAutoMode(C_FakeCsurf instance, int mode) {
    static_cast<FakeCsurf*>(instance)->SetAutoMode(mode);
}

void FakeCsurf_ResetCachedVolPanStates(C_FakeCsurf instance) {
    static_cast<FakeCsurf*>(instance)->ResetCachedVolPanStates();
}

void FakeCsurf_OnTrackSelection(C_FakeCsurf instance, MediaTrack* trackid) {
    static_cast<FakeCsurf*>(instance)->OnTrackSelection(trackid);
}

bool FakeCsurf_IsKeyDown(C_FakeCsurf instance, int key) {
    return static_cast<FakeCsurf*>(instance)->IsKeyDown(key);
}

int FakeCsurf_Extended(C_FakeCsurf instance, int call, void* parm1, void* parm2, void* parm3) {
    return static_cast<FakeCsurf*>(instance)->Extended(call, parm1, parm2, parm3);
}

}

