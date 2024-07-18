#include <stdbool.h>
#include "../../WDL/swell/swell-types.h"
#include "../../WDL/wdltypes.h"
#ifdef __cplusplus
#include "../reaper_plugin.h"
/*#include "../WDL/localize/localize.h"*/
extern "C" {
#endif
const char *__localizeFunc(const char *str, const char *subctx, int flags);
#define __LOCALIZE(str, ctx) __localizeFunc("" str "", "" ctx "", 0)
typedef void *C_ControlSurface;
typedef struct MediaTrack
    MediaTrack; // Forward declaration of MediaTrack as an opaque struct
C_ControlSurface ControlSurface_Create();
void ControlSurface_Destroy(C_ControlSurface instance);
HWND configFunc(const char *type_string, HWND parent, const char *initConfigString);
typedef struct _REAPER_reaper_csurf_reg_t reaper_csurf_reg_t;

#ifdef __cplusplus
}
#endif
