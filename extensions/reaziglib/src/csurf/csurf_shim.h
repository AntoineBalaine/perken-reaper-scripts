/* C interface of the control surface shim (csurf_shim.cpp). Every callback
 * receives the `ctx` pointer from the table. A NULL callback falls back to
 * IReaperControlSurface's default behaviour; get_type_string and
 * get_desc_string are required. The callbacks table must outlive the surface.
 * Its layout is mirrored by Callbacks in csurf.zig. */

#ifndef REAZIGLIB_CSURF_SHIM_H
#define REAZIGLIB_CSURF_SHIM_H

#ifdef __cplusplus
class MediaTrack;
extern "C" {
#else
#include <stdbool.h>
typedef struct MediaTrack MediaTrack;
#endif

typedef struct zcsurf_callbacks
{
    void *ctx;
    const char *(*get_type_string)(void *ctx);
    const char *(*get_desc_string)(void *ctx);
    const char *(*get_config_string)(void *ctx);
    void (*close_no_reset)(void *ctx);
    void (*run)(void *ctx);
    void (*set_track_list_change)(void *ctx);
    void (*set_surface_volume)(void *ctx, MediaTrack *track, double volume);
    void (*set_surface_pan)(void *ctx, MediaTrack *track, double pan);
    void (*set_surface_mute)(void *ctx, MediaTrack *track, bool mute);
    void (*set_surface_selected)(void *ctx, MediaTrack *track, bool selected);
    void (*set_surface_solo)(void *ctx, MediaTrack *track, bool solo);
    void (*set_surface_rec_arm)(void *ctx, MediaTrack *track, bool recarm);
    void (*set_play_state)(void *ctx, bool play, bool pause, bool rec);
    void (*set_repeat_state)(void *ctx, bool rep);
    void (*set_track_title)(void *ctx, MediaTrack *track, const char *title);
    bool (*get_touch_state)(void *ctx, MediaTrack *track, int is_pan);
    void (*set_auto_mode)(void *ctx, int mode);
    void (*reset_cached_vol_pan_states)(void *ctx);
    void (*on_track_selection)(void *ctx, MediaTrack *track);
    bool (*is_key_down)(void *ctx, int key);
    int (*extended)(void *ctx, int call, void *parm1, void *parm2, void *parm3);
} zcsurf_callbacks;

/* Returns an IReaperControlSurface* for plugin_register("csurf_inst", ...),
 * or NULL if allocation failed. */
void *zcsurf_create(const zcsurf_callbacks *callbacks);

/* Destroys a surface from zcsurf_create. Unregister it first
 * (plugin_register("-csurf_inst", ...)). */
void zcsurf_destroy(void *surface);

#ifdef __cplusplus
}
#endif

#endif
