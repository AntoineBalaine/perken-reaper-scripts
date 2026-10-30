// Because SWELL emulates Win32 on macOS and Linux only (its headers need
// POSIX headers such as dlfcn.h), Windows gets the real Win32 types instead.
#ifdef _WIN32
#include <windows.h>
#else
#include "WDL/swell/swell-types.h"
#endif
#include "WDL/wdltypes.h"
#include <stdbool.h>
#ifdef __cplusplus
#include "../reaper_plugin.h"
/*#include "../WDL/localize/localize.h"*/
extern "C" {
#endif

typedef void *C_ControlSurface;
typedef void *MidiInput;
typedef void *MIDIEventlist;

typedef struct MediaTrack
    MediaTrack; // Forward declaration of MediaTrack as an opaque struct
C_ControlSurface ControlSurface_Create();

void ControlSurface_Destroy(C_ControlSurface instance);

HWND configFunc(const char *type_string, HWND parent,
                const char *initConfigString);
typedef struct _REAPER_reaper_csurf_reg_t reaper_csurf_reg_t;

#ifdef __cplusplus
}
#endif
