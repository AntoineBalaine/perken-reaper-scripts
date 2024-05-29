#ifndef ZIGIREAPERCONTROLSURFACE_H
#define ZIGIREAPERCONTROLSURFACE_H

#ifdef __cplusplus
extern "C" {
#endif


#include <stdint.h> // for standard integer types
#include <stdbool.h> // for bool type

typedef struct {
  // Add other fields as needed
  const char *(*GetTypeString)(struct IReaperControlSurface *self);
  const char *(*GetDescString)(struct IReaperControlSurface *self);
  const char *(*GetConfigString)(struct IReaperControlSurface *self);
  void (*CloseNoReset)(struct IReaperControlSurface *self);
  void (*Run)(struct IReaperControlSurface *self);
  void (*SetTrackListChange)(struct IReaperControlSurface *self);
  void (*SetSurfaceVolume)(struct IReaperControlSurface *self,
                           struct MediaTrack *trackid, double volume);
  void (*SetSurfacePan)(struct IReaperControlSurface *self,
                        struct MediaTrack *trackid, double pan);
  void (*SetSurfaceMute)(struct IReaperControlSurface *self,
                         struct MediaTrack *trackid, bool mute);
  void (*SetSurfaceSelected)(struct IReaperControlSurface *self,
                             struct MediaTrack *trackid, bool selected);
  void (*SetSurfaceSolo)(struct IReaperControlSurface *self,
                         struct MediaTrack *trackid, bool solo);
  void (*SetSurfaceRecArm)(struct IReaperControlSurface *self,
                           struct MediaTrack *trackid, bool recarm);
  void (*SetPlayState)(struct IReaperControlSurface *self, bool play,
                       bool pause, bool rec);
  void (*SetRepeatState)(struct IReaperControlSurface *self, bool rep);
  void (*SetTrackTitle)(struct IReaperControlSurface *self,
                        struct MediaTrack *trackid, const char *title);
  bool (*GetTouchState)(struct IReaperControlSurface *self,
                        struct MediaTrack *trackid, int isPan);
  void (*SetAutoMode)(struct IReaperControlSurface *self, int mode);
  void (*ResetCachedVolPanStates)(struct IReaperControlSurface *self);
  void (*OnTrackSelection)(struct IReaperControlSurface *self,
                           struct MediaTrack *trackid);
  bool (*IsKeyDown)(struct IReaperControlSurface *self, int key);
  int (*Extended)(struct IReaperControlSurface *self, int call, void *parm1,
                  void *parm2, void *parm3);
} ZigCsurf;

#ifdef __cplusplus
}
#endif

#endif // MY_STRUCT_H
