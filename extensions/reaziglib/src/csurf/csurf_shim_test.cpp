// Test helpers for csurf.zig: they call a surface through
// IReaperControlSurface's virtual table, the way REAPER does, so that the
// tests check the real dispatch path rather than the C functions directly.
// Compiled only into reaziglib's test binary.

#include "reaper_csurf.h"

extern "C" const char *zcsurf_test_call_type_string(void *surface)
{
    return static_cast<IReaperControlSurface *>(surface)->GetTypeString();
}

extern "C" int zcsurf_test_call_extended(void *surface, int call, void *p1, void *p2, void *p3)
{
    return static_cast<IReaperControlSurface *>(surface)->Extended(call, p1, p2, p3);
}

extern "C" void zcsurf_test_call_set_surface_mute(void *surface, MediaTrack *track, bool mute)
{
    static_cast<IReaperControlSurface *>(surface)->SetSurfaceMute(track, mute);
}

extern "C" bool zcsurf_test_call_get_touch_state(void *surface, MediaTrack *track, int is_pan)
{
    return static_cast<IReaperControlSurface *>(surface)->GetTouchState(track, is_pan);
}
