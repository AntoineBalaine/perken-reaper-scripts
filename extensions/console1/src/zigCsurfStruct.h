#ifndef ZIGIREAPERCONTROLSURFACE_H
#define ZIGIREAPERCONTROLSURFACE_H

#ifdef __cplusplus
extern "C" {
#endif


#include <stdint.h> // for standard integer types
#include <stdbool.h> // for bool type

typedef struct ZigCsurf{
  // Add other fields as needed
  const char *(*GetTypeString)(const struct ZigCsurf *self);
  const char *(*GetDescString)(const struct ZigCsurf *self);
  const char *(*GetConfigString)(const struct ZigCsurf *self);
  void (*CloseNoReset)(const struct ZigCsurf *self);
  void (*Run)(const struct ZigCsurf *self);
  void (*SetTrackListChange)(const struct ZigCsurf *self);
  void (*SetSurfaceVolume)(const struct ZigCsurf *self,
                           struct MediaTrack *trackid, double volume);
  void (*SetSurfacePan)(const struct ZigCsurf *self,
                        struct MediaTrack *trackid, double pan);
  void (*SetSurfaceMute)(const struct ZigCsurf *self,
                         struct MediaTrack *trackid, bool mute);
  void (*SetSurfaceSelected)(const struct ZigCsurf *self,
                             struct MediaTrack *trackid, bool selected);
  void (*SetSurfaceSolo)(const struct ZigCsurf *self,
                         struct MediaTrack *trackid, bool solo);
  void (*SetSurfaceRecArm)(const struct ZigCsurf *self,
                           struct MediaTrack *trackid, bool recarm);
  void (*SetPlayState)(const struct ZigCsurf *self, bool play,
                       bool pause, bool rec);
  void (*SetRepeatState)(const struct ZigCsurf *self, bool rep);
  void (*SetTrackTitle)(const struct ZigCsurf *self,
                        struct MediaTrack *trackid, const char *title);
  bool (*GetTouchState)(const struct ZigCsurf *self,
                        struct MediaTrack *trackid, int isPan);
  void (*SetAutoMode)(const struct ZigCsurf *self, int mode);
  void (*ResetCachedVolPanStates)(const struct ZigCsurf *self);
  void (*OnTrackSelection)(const struct ZigCsurf *self,
                           struct MediaTrack *trackid);
  bool (*IsKeyDown)(const struct ZigCsurf *self, int key);
  int (*Extended)(const struct ZigCsurf *self, int call, void *parm1,
                  void *parm2, void *parm3);
} ZigCsurf;

#ifdef __cplusplus
}
#endif

#endif // MY_STRUCT_H
