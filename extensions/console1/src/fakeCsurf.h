#ifndef FAKECSURF_HPP
#define FAKECSURF_HPP

#include "reaper_plugin_functions.h" // Include the header where IReaperControlSurface is declared
#include "zigCsurfStruct.h"

class FakeCsurf : public IReaperControlSurface {
public:
  FakeCsurf(const ZigCsurf* zigCsurf);
private:
    const ZigCsurf* zigCsurf;
public:
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
