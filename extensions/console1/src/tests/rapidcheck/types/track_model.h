#ifndef TRACK_MODEL_H
#define TRACK_MODEL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stddef.h>
#include "fx_model.h"

// Automation mode enum (matches the Zig enum in transport_actions.zig)
typedef enum {
    TRIM,
    READ,
    TOUCH,
    LATCH,
    PREVIEW,
    WRITE
} RC_AutomationMode;

// Track info struct
typedef struct {
    bool phase;
    int num_channels;
    double volume;
    double pan;
    bool mute;
    int solo;
} RC_TrackInfo;

// Peak info struct
typedef struct {
    double left;
    double right;
} RC_PeakInfo;

// Track struct
typedef struct {
    char* name;
    RC_FX* fx_list;
    size_t fx_count;
    RC_AutomationMode automation_mode;
    RC_TrackInfo info;
    RC_PeakInfo* peak_info;  // Optional, NULL when not set
} RC_Track;

// Session struct
typedef struct {
    RC_Track* tracks;
    size_t track_count;
    size_t* selected_tracks;
    size_t selected_track_count;
    size_t* last_touched_track_index;  // Optional, NULL when not set
    double cursor_position;
    RC_AutomationMode global_automation_mode;
} RC_Session;

// Memory management functions
void rc_track_info_init(RC_TrackInfo* info);
void rc_peak_info_init(RC_PeakInfo* peak_info);
void rc_track_init(RC_Track* track);
void rc_session_init(RC_Session* session);

RC_Track* rc_track_create(const char* name);
RC_Session* rc_session_create();

void rc_track_free(RC_Track* track);
void rc_session_free(RC_Session* session);

// Track operations
void rc_track_add_fx(RC_Track* track, RC_FX* fx);
void rc_session_add_track(RC_Session* session, RC_Track* track);
void rc_session_select_track(RC_Session* session, size_t track_index);

// Utility functions
RC_Session* rc_initialize_test_state();

#ifdef __cplusplus
}
#endif

#endif // TRACK_MODEL_H
