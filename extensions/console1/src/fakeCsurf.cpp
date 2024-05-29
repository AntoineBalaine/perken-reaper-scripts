#include "reaper_plugin_functions.h"

#include "fakeCsurf.h"
#include <tuple>
// Implementing the FakeCsurf methods

FakeCsurf::FakeCsurf(const ZigCsurf* zigCsurf): zigCsurf(zigCsurf) { }


// Method implementations
const char* FakeCsurf::GetTypeString() {
    return zigCsurf->GetTypeString(zigCsurf);
}

const char* FakeCsurf::GetDescString() {
    return zigCsurf->GetDescString(zigCsurf);
}

const char* FakeCsurf::GetConfigString() {
    return zigCsurf->GetConfigString(zigCsurf);
}

void FakeCsurf::CloseNoReset() {
    zigCsurf->CloseNoReset(zigCsurf);
}

void FakeCsurf::Run() {
    zigCsurf->Run(zigCsurf);
}

void FakeCsurf::SetTrackListChange() {
    zigCsurf->SetTrackListChange(zigCsurf);
}

void FakeCsurf::SetSurfaceVolume(MediaTrack* trackid, double volume) {
    zigCsurf->SetSurfaceVolume(zigCsurf, trackid, volume);
}

void FakeCsurf::SetSurfacePan(MediaTrack* trackid, double pan) {
    zigCsurf->SetSurfacePan(zigCsurf, trackid, pan);
}

void FakeCsurf::SetSurfaceMute(MediaTrack* trackid, bool mute) {
    zigCsurf->SetSurfaceMute(zigCsurf, trackid, mute);
}

void FakeCsurf::SetSurfaceSelected(MediaTrack* trackid, bool selected) {
    zigCsurf->SetSurfaceSelected(zigCsurf, trackid, selected);
}

void FakeCsurf::SetSurfaceSolo(MediaTrack* trackid, bool solo) {
    zigCsurf->SetSurfaceSolo(zigCsurf, trackid, solo);
}

void FakeCsurf::SetSurfaceRecArm(MediaTrack* trackid, bool recarm) {
    zigCsurf->SetSurfaceRecArm(zigCsurf, trackid, recarm);
}

void FakeCsurf::SetPlayState(bool play, bool pause, bool rec) {
    zigCsurf->SetPlayState(zigCsurf, play, pause, rec);
}

void FakeCsurf::SetRepeatState(bool rep) {
    zigCsurf->SetRepeatState(zigCsurf, rep);
}

void FakeCsurf::SetTrackTitle(MediaTrack* trackid, const char* title) {
    zigCsurf->SetTrackTitle(zigCsurf, trackid, title);
}

bool FakeCsurf::GetTouchState(MediaTrack* trackid, int isPan) {
    return zigCsurf->GetTouchState(zigCsurf, trackid, isPan);
}

void FakeCsurf::SetAutoMode(int mode) {
    zigCsurf->SetAutoMode(zigCsurf, mode);
}

void FakeCsurf::ResetCachedVolPanStates() {
    zigCsurf->ResetCachedVolPanStates(zigCsurf);
}

void FakeCsurf::OnTrackSelection(MediaTrack* trackid) {
    zigCsurf->OnTrackSelection(zigCsurf, trackid);
}

bool FakeCsurf::IsKeyDown(int key) {
    return zigCsurf->IsKeyDown(zigCsurf, key);
}

int FakeCsurf::Extended(int call, void* parm1, void* parm2, void* parm3) {
    return zigCsurf->Extended(zigCsurf, call, parm1, parm2, parm3);
}
