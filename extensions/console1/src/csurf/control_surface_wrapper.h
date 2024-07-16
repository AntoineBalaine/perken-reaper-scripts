#include <stdbool.h>
#include "../../WDL/swell/swell-types.h"
#ifdef __cplusplus
extern "C" {
#endif

typedef void *C_ControlSurface;
typedef struct MediaTrack
    MediaTrack; // Forward declaration of MediaTrack as an opaque struct
C_ControlSurface ControlSurface_Create();
void ControlSurface_Destroy(C_ControlSurface instance);
/*const char *FakeCsurf_GetTypeString(C_FakeCsurf instance);*/
/*const char *FakeCsurf_GetDescString(C_FakeCsurf instance);*/
/*const char *FakeCsurf_GetConfigString(C_FakeCsurf instance);*/
/*void FakeCsurf_CloseNoReset(C_FakeCsurf instance);*/
/*void FakeCsurf_Run(C_FakeCsurf instance);*/
/*void FakeCsurf_SetTrackListChange(C_FakeCsurf instance);*/
/*void FakeCsurf_SetSurfaceVolume(C_FakeCsurf instance, MediaTrack *trackid,*/
/*                                double volume);*/
/*void FakeCsurf_SetSurfacePan(C_FakeCsurf instance, MediaTrack *trackid,*/
/*                             double pan);*/
/*void FakeCsurf_SetSurfaceMute(C_FakeCsurf instance, MediaTrack *trackid,*/
/*                              bool mute);*/
/*void FakeCsurf_SetSurfaceSelected(C_FakeCsurf instance, MediaTrack *trackid,*/
/*                                  bool selected);*/
/*void FakeCsurf_SetSurfaceSolo(C_FakeCsurf instance, MediaTrack *trackid,*/
/*                              bool solo);*/
/*void FakeCsurf_SetSurfaceRecArm(C_FakeCsurf instance, MediaTrack *trackid,*/
/*                                bool recarm);*/
/*void FakeCsurf_SetPlayState(C_FakeCsurf instance, bool play, bool pause,*/
/*                            bool rec);*/
/*void FakeCsurf_SetRepeatState(C_FakeCsurf instance, bool rep);*/
/*void FakeCsurf_SetTrackTitle(C_FakeCsurf instance, MediaTrack *trackid,*/
/*                             const char *title);*/
/*bool FakeCsurf_GetTouchState(C_FakeCsurf instance, MediaTrack *trackid,*/
/*                             int isPan);*/
/*void FakeCsurf_SetAutoMode(C_FakeCsurf instance, int mode);*/
/*void FakeCsurf_ResetCachedVolPanStates(C_FakeCsurf instance);*/
/*void FakeCsurf_OnTrackSelection(C_FakeCsurf instance, MediaTrack *trackid);*/
/*bool FakeCsurf_IsKeyDown(C_FakeCsurf instance, int key);*/
/*int FakeCsurf_Extended(C_FakeCsurf instance, int call, void *parm1, void
 * *parm2,*/
/*                       void *parm3);*/
HWND configFunc(const char *type_string, HWND parent, const char *initConfigString);
#ifdef __cplusplus
}
#endif
