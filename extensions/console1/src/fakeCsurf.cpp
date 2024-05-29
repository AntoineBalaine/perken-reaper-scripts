#include "reaper_plugin_functions.h"

#include "fakeCsurf.h"
#include <tuple>
// Implementing the FakeCsurf methods

FakeCsurf::FakeCsurf(const ZigCsurf* zigCsurf): zigCsurf(zigCsurf) { }


// Method implementations
const char* FakeCsurf::GetTypeString() {
    return zigCsurf->GetTypeString(this);
}

const char* FakeCsurf::GetDescString() {
    return zigCsurf->GetDescString(this);
}

const char* FakeCsurf::GetConfigString() {
    return zigCsurf->GetConfigString(this);
}

void FakeCsurf::CloseNoReset() {
    zigCsurf->CloseNoReset(this);
}

void FakeCsurf::Run() {
    zigCsurf->Run(this);
}

void FakeCsurf::SetTrackListChange() {
    zigCsurf->SetTrackListChange(this);
}

void FakeCsurf::SetSurfaceVolume(MediaTrack* trackid, double volume) {
    zigCsurf->SetSurfaceVolume(this, trackid, volume);
}

void FakeCsurf::SetSurfacePan(MediaTrack* trackid, double pan) {
    zigCsurf->SetSurfacePan(this, trackid, pan);
}

void FakeCsurf::SetSurfaceMute(MediaTrack* trackid, bool mute) {
    zigCsurf->SetSurfaceMute(this, trackid, mute);
}

void FakeCsurf::SetSurfaceSelected(MediaTrack* trackid, bool selected) {
    zigCsurf->SetSurfaceSelected(this, trackid, selected);
}

void FakeCsurf::SetSurfaceSolo(MediaTrack* trackid, bool solo) {
    zigCsurf->SetSurfaceSolo(this, trackid, solo);
}

void FakeCsurf::SetSurfaceRecArm(MediaTrack* trackid, bool recarm) {
    zigCsurf->SetSurfaceRecArm(this, trackid, recarm);
}

void FakeCsurf::SetPlayState(bool play, bool pause, bool rec) {
    zigCsurf->SetPlayState(this, play, pause, rec);
}

void FakeCsurf::SetRepeatState(bool rep) {
    zigCsurf->SetRepeatState(this, rep);
}

void FakeCsurf::SetTrackTitle(MediaTrack* trackid, const char* title) {
    zigCsurf->SetTrackTitle(this, trackid, title);
}

bool FakeCsurf::GetTouchState(MediaTrack* trackid, int isPan) {
    return zigCsurf->GetTouchState(this, trackid, isPan);
}

void FakeCsurf::SetAutoMode(int mode) {
    zigCsurf->SetAutoMode(this, mode);
}

void FakeCsurf::ResetCachedVolPanStates() {
    zigCsurf->ResetCachedVolPanStates(this);
}

void FakeCsurf::OnTrackSelection(MediaTrack* trackid) {
    zigCsurf->OnTrackSelection(this, trackid);
}

bool FakeCsurf::IsKeyDown(int key) {
    return zigCsurf->IsKeyDown(this, key);
}

int FakeCsurf::Extended(int call, void* parm1, void* parm2, void* parm3) {
    return zigCsurf->Extended(this, call, parm1, parm2, parm3);
}
