#include "WDL/swell/swell-types.h"
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
