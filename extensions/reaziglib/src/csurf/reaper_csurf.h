/***************************************
*** REAPER Plug-in API — IReaperControlSurface only
**
** Copyright (C) 2006-2015, Cockos Incorporated
**
**    This software is provided 'as-is', without any express or implied
**    warranty.  In no event will the authors be held liable for any damages
**    arising from the use of this software.
**
**    Permission is granted to anyone to use this software for any purpose,
**    including commercial applications, and to alter it and redistribute it
**    freely, subject to the following restrictions:
**
**    1. The origin of this software must not be misrepresented; you must not
**       claim that you wrote the original software. If you use this software
**       in a product, an acknowledgment in the product documentation would be
**       appreciated but is not required.
**    2. Altered source versions must be plainly marked as such, and must not be
**       misrepresented as being the original software.
**    3. This notice may not be removed or altered from any source distribution.
**
** ALTERED SOURCE: this file contains only the IReaperControlSurface class from
** reaper_plugin.h (justinfrankel/reaper-sdk @ 6c755b2), so that the control
** surface shim compiles without the rest of the SDK and WDL/SWELL. The class
** itself is unchanged.
*/

#ifndef REAZIGLIB_REAPER_CSURF_H
#define REAZIGLIB_REAPER_CSURF_H

class MediaTrack;

class IReaperControlSurface
{
  public:
    IReaperControlSurface() { }
    virtual ~IReaperControlSurface() { }

    virtual const char *GetTypeString()=0; // simple unique string with only A-Z, 0-9, no spaces or other chars
    virtual const char *GetDescString()=0; // human readable description (can include instance specific info)
    virtual const char *GetConfigString()=0; // string of configuration data

    virtual void CloseNoReset() { } // close without sending "reset" messages, prevent "reset" being sent on destructor


    virtual void Run() { } // called 30x/sec or so.


    // these will be called by the host when states change etc
    virtual void SetTrackListChange() { }
    virtual void SetSurfaceVolume(MediaTrack *trackid, double volume) { }
    virtual void SetSurfacePan(MediaTrack *trackid, double pan) { }
    virtual void SetSurfaceMute(MediaTrack *trackid, bool mute) { }
    virtual void SetSurfaceSelected(MediaTrack *trackid, bool selected) { }
    virtual void SetSurfaceSolo(MediaTrack *trackid, bool solo) { } // trackid==master means "any solo"
    virtual void SetSurfaceRecArm(MediaTrack *trackid, bool recarm) { }
    virtual void SetPlayState(bool play, bool pause, bool rec) { }
    virtual void SetRepeatState(bool rep) { }
    virtual void SetTrackTitle(MediaTrack *trackid, const char *title) { }
    virtual bool GetTouchState(MediaTrack *trackid, int isPan) { return false; }
    virtual void SetAutoMode(int mode) { } // automation mode for current track

    virtual void ResetCachedVolPanStates() { } // good to flush your control states here

    virtual void OnTrackSelection(MediaTrack *trackid) { } // track was selected

    virtual bool IsKeyDown(int key) { return false; } // VK_CONTROL, VK_MENU, VK_SHIFT, etc, whatever makes sense for your surface

    virtual int Extended(int call, void *parm1, void *parm2, void *parm3) { return 0; } // return 0 if unsupported
};

#endif
