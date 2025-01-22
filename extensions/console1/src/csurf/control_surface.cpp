#include "control_surface.h"

extern "C" {
    const char* zGetTypeString();
    const char* zGetDescString();
    const char* zGetConfigString();
void zCloseNoReset();
void zRun();
void zSetTrackListChange();
void zSetSurfaceVolume(MediaTrack *trackid, double volume);
void zSetSurfacePan(MediaTrack *trackid, double pan);
void zSetSurfaceMute(MediaTrack *trackid, bool mute);
void zSetSurfaceSelected(MediaTrack *trackid, bool selected);
void zSetSurfaceSolo(MediaTrack *trackid, bool solo);
void zSetSurfaceRecArm(MediaTrack *trackid, bool recarm);
void zSetPlayState(bool play, bool pause, bool rec);
void zSetRepeatState(bool rep);
void zSetTrackTitle(MediaTrack *trackid, const char *title);
bool zGetTouchState(MediaTrack *trackid, int isPan);
void zSetAutoMode(int mode);
void zResetCachedVolPanStates();
void zOnTrackSelection(MediaTrack *trackid);
bool zIsKeyDown(int key);
int zExtended(int call, void *parm1, void *parm2, void *parm3);
}

ZigControlSurface::ZigControlSurface() {}

const char* ZigControlSurface::GetTypeString() { return zGetTypeString(); }
const char* ZigControlSurface::GetDescString() { return zGetDescString(); }
const char* ZigControlSurface::GetConfigString() { return zGetConfigString(); }

void ZigControlSurface::CloseNoReset() { zCloseNoReset(); }
void ZigControlSurface::Run() { zRun(); }
void ZigControlSurface::SetTrackListChange() { zSetTrackListChange(); }
void ZigControlSurface::SetSurfaceVolume(MediaTrack *trackid, double volume) {
  zSetSurfaceVolume(trackid, volume);
}
void ZigControlSurface::SetSurfacePan(MediaTrack *trackid, double pan) {
  zSetSurfacePan(trackid, pan);
}
void ZigControlSurface::SetSurfaceMute(MediaTrack *trackid, bool mute) {
  zSetSurfaceMute(trackid, mute);
}
void ZigControlSurface::SetSurfaceSelected(MediaTrack *trackid, bool selected) {
  zSetSurfaceSelected(trackid, selected);
}
void ZigControlSurface::SetSurfaceSolo(MediaTrack *trackid, bool solo) {
  zSetSurfaceSolo(trackid, solo);
}
void ZigControlSurface::SetSurfaceRecArm(MediaTrack *trackid, bool recarm) {
  zSetSurfaceRecArm(trackid, recarm);
}
void ZigControlSurface::SetPlayState(bool play, bool pause, bool rec) {
  zSetPlayState(play, pause, rec);
}
void ZigControlSurface::SetRepeatState(bool rep) { zSetRepeatState(rep); }
void ZigControlSurface::SetTrackTitle(MediaTrack *trackid, const char *title) {
  zSetTrackTitle(trackid, title);
}
bool ZigControlSurface::GetTouchState(MediaTrack *trackid, int isPan) {
  return zGetTouchState(trackid, isPan);
}
void ZigControlSurface::SetAutoMode(int mode) { zSetAutoMode(mode); }
void ZigControlSurface::ResetCachedVolPanStates() {
  zResetCachedVolPanStates();
}
void ZigControlSurface::OnTrackSelection(MediaTrack *trackid) {
  zOnTrackSelection(trackid);
}
bool ZigControlSurface::IsKeyDown(int key) { return zIsKeyDown(key); }
int ZigControlSurface::Extended(int call, void *parm1, void *parm2,
                                void *parm3) {
  return zExtended(call, parm1, parm2, parm3);
}
