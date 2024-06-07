#ifndef FAKECSURF_HPP
#define FAKECSURF_HPP

#include "../reaper_plugin_functions.h" // Include the header where IReaperControlSurface is declared

// All of the following functions are called from C++ and implemented in Rust.
// extern "C" const char *zGetTypeString();
// extern "C" const char *zGetDescString();
// extern "C" const char *zGetConfigString();
extern "C" void zCloseNoReset();
extern "C" void zRun();
extern "C" void zSetTrackListChange();
extern "C" void zSetSurfaceVolume(MediaTrack *trackid, double volume);
extern "C" void zSetSurfacePan(MediaTrack *trackid, double pan);
extern "C" void zSetSurfaceMute(MediaTrack *trackid, bool mute);
extern "C" void zSetSurfaceSelected(MediaTrack *trackid, bool selected);
extern "C" void zSetSurfaceSolo(MediaTrack *trackid, bool solo);
extern "C" void zSetSurfaceRecArm(MediaTrack *trackid, bool recarm);
extern "C" void zSetPlayState(bool play, bool pause, bool rec);
extern "C" void zSetRepeatState(bool rep);
extern "C" void zSetTrackTitle(MediaTrack *trackid, const char *title);
extern "C" bool zGetTouchState(MediaTrack *trackid, int isPan);
extern "C" void zSetAutoMode(int mode);
extern "C" void zResetCachedVolPanStates();
extern "C" void zOnTrackSelection(MediaTrack *trackid);
extern "C" bool zIsKeyDown(int key);
extern "C" int zExtended(int call, void *parm1, void *parm2, void *parm3);

class ZigControlSurface : public IReaperControlSurface {
public:
  ZigControlSurface();
  const char *GetTypeString() override;
  const char *GetDescString() override;
  const char *GetConfigString() override;

  void CloseNoReset() override;
  void Run() override;
  void SetTrackListChange() override;
  void SetSurfaceVolume(MediaTrack *trackid, double volume) override;
  void SetSurfacePan(MediaTrack *trackid, double pan) override;
  void SetSurfaceMute(MediaTrack *trackid, bool mute) override;
  void SetSurfaceSelected(MediaTrack *trackid, bool selected) override;
  void SetSurfaceSolo(MediaTrack *trackid, bool solo) override;
  void SetSurfaceRecArm(MediaTrack *trackid, bool recarm) override;
  void SetPlayState(bool play, bool pause, bool rec) override;
  void SetRepeatState(bool rep) override;
  void SetTrackTitle(MediaTrack *trackid, const char *title) override;
  bool GetTouchState(MediaTrack *trackid, int isPan) override;
  void SetAutoMode(int mode) override;
  void ResetCachedVolPanStates() override;
  void OnTrackSelection(MediaTrack *trackid) override;
  bool IsKeyDown(int key) override;
  int Extended(int call, void *parm1, void *parm2, void *parm3) override;
};

#endif // FAKECSURF_HPP
