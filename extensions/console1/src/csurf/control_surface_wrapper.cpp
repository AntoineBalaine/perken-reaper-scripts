#include "control_surface_wrapper.h"
#include "control_surface.h"
#ifndef _CSURF_H_
#define _CSURF_H_
#include "WDL/localize/localize.h"
#include "../reaper_plugin.h"
#include <stdio.h>

#include "WDL/db2val.h"
#include "WDL/swell/swell-types.h"
#include "WDL/wdlcstring.h"
#include "WDL/wdlstring.h"
#include "WDL/win32_utf8.h"
#include "../resource.h"
#include <new>

#ifndef _WIN32
#include "../../WDL/swell/swell-dlggen.h"
#include "../resource.h"
#include "resource.rc_mac_dlg"
#include "../../WDL/swell/swell-menugen.h"
#include "resource.rc_mac_menu"
#endif

extern "C" {

C_ControlSurface ControlSurface_Create() {
  return new (std::nothrow) ZigControlSurface();
}

void ControlSurface_Destroy(C_ControlSurface instance) {
  delete static_cast<ZigControlSurface *>(instance);
}
}
#endif
