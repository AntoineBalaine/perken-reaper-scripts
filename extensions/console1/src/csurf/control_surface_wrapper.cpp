#include "control_surface_wrapper.h"
#include "control_surface.h"
#ifndef _CSURF_H_
#define _CSURF_H_
#include <stdio.h>
#include "../reaper_plugin.h"
#include "../../WDL/localize/localize.h"

#include "../../WDL/db2val.h"
#include "../../WDL/wdlstring.h"
#include "../../WDL/wdlcstring.h"
#include "../../WDL/win32_utf8.h"
#include "../resource.h"
#include <new>
#include "../../WDL/swell/swell-types.h"

#ifndef _WIN32
# include "../resource.h"
# include "../../WDL/swell/swell-dlggen.h"
# include "resource.rc_mac_dlg"
# include "../../WDL/swell/swell-menugen.h"
# include "resource.rc_mac_menu"
#endif

extern "C"
{

  C_ControlSurface ControlSurface_Create()
  {
    return new (std::nothrow) ZigControlSurface();
  }

  void ControlSurface_Destroy(C_ControlSurface instance)
  {
    delete static_cast<ZigControlSurface *>(instance);
  }

  void cMidiIn_start(midi_Input *m_midiin){
    m_midiin->start();
  }
  void cMidiIn_SwapBufs(midi_Input *m_midiin, unsigned int timestamp){
      m_midiin->SwapBufs(timestamp);
  }
  MIDI_eventlist *cMidiIn_GetReadBuf(midi_Input *m_midiin){
    return m_midiin->GetReadBuf();
  }
}
#endif
