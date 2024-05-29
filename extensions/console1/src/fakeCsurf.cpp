#include "reaper_plugin_functions.h"

#include "fakeCsurf.h"
#include <tuple>
// Implementing the FakeCsurf methods

const char *FakeCsurf::GetTypeString() {
    return "";
}

const char *FakeCsurf::GetDescString() {
    return "";
}

const char *FakeCsurf::GetConfigString() {
    return "";
}

void FakeCsurf::CloseNoReset() {
    ShowConsoleMsg("CloseNoReset\n");
}

void FakeCsurf::Run() {
    // Implementation
}

void FakeCsurf::SetTrackListChange() {
    ShowConsoleMsg("SetTrackListChange\n");
}

void FakeCsurf::SetSurfaceVolume(MediaTrack *trackid, double volume) {
    std::ignore = trackid;
    std::ignore = volume;
    ShowConsoleMsg("SetSurfaceVolume\n");
}

void FakeCsurf::SetSurfacePan(MediaTrack *trackid, double pan) {
    std::ignore = trackid;
    std::ignore = pan;
    ShowConsoleMsg("SetSurfacePan\n");
}

void FakeCsurf::SetSurfaceMute(MediaTrack *trackid, bool mute) {
    std::ignore = trackid;
    std::ignore = mute;
    ShowConsoleMsg("SetSurfaceMute\n");
}

void FakeCsurf::SetSurfaceSelected(MediaTrack *trackid, bool selected) {
    std::ignore = trackid;
    std::ignore = selected;
    ShowConsoleMsg("SetSurfaceSelected\n");
}

void FakeCsurf::SetSurfaceSolo(MediaTrack *trackid, bool solo) {
    std::ignore = trackid;
    std::ignore = solo;
    ShowConsoleMsg("SetSurfaceSolo\n");
}

void FakeCsurf::SetSurfaceRecArm(MediaTrack *trackid, bool recarm) {
    std::ignore = trackid;
    std::ignore = recarm;
    ShowConsoleMsg("SetSurfaceRecArm\n");
}

void FakeCsurf::SetPlayState(bool play, bool pause, bool rec) {
    std::ignore = play;
    std::ignore = pause;
    std::ignore = rec;
    ShowConsoleMsg("SetPlayState\n");
}

void FakeCsurf::SetRepeatState(bool rep) {
    std::ignore = rep;
    ShowConsoleMsg("SetRepeatState\n");
}

void FakeCsurf::SetTrackTitle(MediaTrack *trackid, const char *title) {
    std::ignore = trackid;
    std::ignore = title;
    ShowConsoleMsg("SetTrackTitle\n");
}

bool FakeCsurf::GetTouchState(MediaTrack *trackid, int isPan) {
    std::ignore = trackid;
    std::ignore = isPan;
    ShowConsoleMsg("GetTouchState\n");
    return false;
}

void FakeCsurf::SetAutoMode(int mode) {
    std::ignore = mode;
    ShowConsoleMsg("SetAutoMode\n");
}

void FakeCsurf::ResetCachedVolPanStates() {
    ShowConsoleMsg("ResetCachedVolPanStates\n");
}

void FakeCsurf::OnTrackSelection(MediaTrack *trackid) {
    std::ignore = trackid;
    ShowConsoleMsg("OnTrackSelection\n");
}

bool FakeCsurf::IsKeyDown(int key) {
    std::ignore = key;
    return false;
}

int FakeCsurf::Extended(int call, void *parm1, void *parm2, void *parm3) {
    std::ignore = call;
    std::ignore = parm1;
    std::ignore = parm2;
    std::ignore = parm3;
    ShowConsoleMsg("Extended\n");
    return 0;
}

