// Control surface shim: a C++ subclass of REAPER's IReaperControlSurface that
// forwards every virtual method to a table of plain C callbacks, so that a Zig
// extension can register a control surface (plugin_register("csurf_inst"))
// and receive REAPER's state-change notifications.
//
// REAPER calls this class through its C++ virtual table, so this file must be
// compiled with REAPER's own toolchain (MSVC on Windows, Apple clang on macOS,
// gcc on Linux); see extensions/README.md. reaziglib.addCsurf does that.
//
// The shim uses no C++ standard library, exceptions or RTTI, so an extension
// that uses it does not need to bundle a C++ runtime. The few runtime hooks
// the compiler still references (operator delete for the deleting destructor,
// the pure-virtual handler) are defined at the end of this file.

#include "reaper_csurf.h"
#include "csurf_shim.h"

typedef decltype(sizeof(0)) zcsurf_size_t;

extern "C" void *malloc(zcsurf_size_t size);
extern "C" void free(void *ptr);
extern "C" void abort(void);

// Placement new, declared here because <new> belongs to the C++ standard
// library this shim avoids.
inline void *operator new(zcsurf_size_t, void *where) noexcept { return where; }

#if defined(_MSC_VER)
#define ZCSURF_HIDDEN
#else
#define ZCSURF_HIDDEN __attribute__((visibility("hidden")))
#endif

class ZigSurface final : public IReaperControlSurface
{
  public:
    explicit ZigSurface(const zcsurf_callbacks *callbacks) : cb(callbacks) { }

    const zcsurf_callbacks *cb;

    const char *GetTypeString() override { return cb->get_type_string(cb->ctx); }
    const char *GetDescString() override { return cb->get_desc_string(cb->ctx); }
    const char *GetConfigString() override { return cb->get_config_string ? cb->get_config_string(cb->ctx) : ""; }

    void CloseNoReset() override { if (cb->close_no_reset) cb->close_no_reset(cb->ctx); }
    void Run() override { if (cb->run) cb->run(cb->ctx); }

    void SetTrackListChange() override { if (cb->set_track_list_change) cb->set_track_list_change(cb->ctx); }
    void SetSurfaceVolume(MediaTrack *tr, double v) override { if (cb->set_surface_volume) cb->set_surface_volume(cb->ctx, tr, v); }
    void SetSurfacePan(MediaTrack *tr, double p) override { if (cb->set_surface_pan) cb->set_surface_pan(cb->ctx, tr, p); }
    void SetSurfaceMute(MediaTrack *tr, bool m) override { if (cb->set_surface_mute) cb->set_surface_mute(cb->ctx, tr, m); }
    void SetSurfaceSelected(MediaTrack *tr, bool s) override { if (cb->set_surface_selected) cb->set_surface_selected(cb->ctx, tr, s); }
    void SetSurfaceSolo(MediaTrack *tr, bool s) override { if (cb->set_surface_solo) cb->set_surface_solo(cb->ctx, tr, s); }
    void SetSurfaceRecArm(MediaTrack *tr, bool r) override { if (cb->set_surface_rec_arm) cb->set_surface_rec_arm(cb->ctx, tr, r); }
    void SetPlayState(bool play, bool pause, bool rec) override { if (cb->set_play_state) cb->set_play_state(cb->ctx, play, pause, rec); }
    void SetRepeatState(bool rep) override { if (cb->set_repeat_state) cb->set_repeat_state(cb->ctx, rep); }
    void SetTrackTitle(MediaTrack *tr, const char *title) override { if (cb->set_track_title) cb->set_track_title(cb->ctx, tr, title); }
    bool GetTouchState(MediaTrack *tr, int is_pan) override { return cb->get_touch_state ? cb->get_touch_state(cb->ctx, tr, is_pan) : false; }
    void SetAutoMode(int mode) override { if (cb->set_auto_mode) cb->set_auto_mode(cb->ctx, mode); }
    void ResetCachedVolPanStates() override { if (cb->reset_cached_vol_pan_states) cb->reset_cached_vol_pan_states(cb->ctx); }
    void OnTrackSelection(MediaTrack *tr) override { if (cb->on_track_selection) cb->on_track_selection(cb->ctx, tr); }
    bool IsKeyDown(int key) override { return cb->is_key_down ? cb->is_key_down(cb->ctx, key) : false; }
    int Extended(int call, void *p1, void *p2, void *p3) override { return cb->extended ? cb->extended(cb->ctx, call, p1, p2, p3) : 0; }
};

extern "C" ZCSURF_HIDDEN void *zcsurf_create(const zcsurf_callbacks *callbacks)
{
    void *mem = malloc(sizeof(ZigSurface));
    if (!mem) return 0;
    // The pointer handed to REAPER must be the IReaperControlSurface
    // sub-object; with single inheritance it is the object's own address.
    IReaperControlSurface *surface = new (mem) ZigSurface(callbacks);
    return surface;
}

extern "C" ZCSURF_HIDDEN void zcsurf_destroy(void *surface)
{
    if (!surface) return;
    ZigSurface *s = static_cast<ZigSurface *>(static_cast<IReaperControlSurface *>(surface));
    s->~ZigSurface();
    free(s);
}

// Runtime hooks referenced by the virtual table. The deleting destructor is
// never called with memory from operator new (zcsurf_destroy frees the
// object itself), and no pure virtual method is ever called on a complete
// ZigSurface, so these only satisfy the linker. None of them interposes on
// the host's: macOS binds symbols per library, Linux loads plugins without
// exposing their symbols to other libraries, and Windows exports only symbols
// marked for export.
#if defined(_MSC_VER)
// MSVC's runtime is not linked into the extension, so the shim provides the
// hooks MSVC's code generation references.
void operator delete(void *ptr) noexcept { free(ptr); }
void operator delete(void *ptr, zcsurf_size_t) noexcept { free(ptr); }
extern "C" int _purecall(void) { abort(); return 0; }
#else
// Weak, so that an extension that does link a C++ runtime gets the
// runtime's definitions instead of a duplicate-symbol error. operator delete
// can not be hidden: the language declares it implicitly with default
// visibility.
__attribute__((weak)) void operator delete(void *ptr) noexcept { free(ptr); }
__attribute__((weak)) void operator delete(void *ptr, zcsurf_size_t) noexcept { free(ptr); }
extern "C" __attribute__((weak)) ZCSURF_HIDDEN void __cxa_pure_virtual() { abort(); }
#endif
