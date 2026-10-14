/* C interface to qm-dsp's bar and beat tracker (qm_bridge.cpp). Mirrored by
 * the extern declarations in beat.zig. All memory in a result is owned by
 * the bridge; release it with perken_beat_result_free. */

#ifndef PERKEN_QM_BRIDGE_H
#define PERKEN_QM_BRIDGE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct perken_beat_params
{
    /* Tempo the beat-period estimate is biased towards, in BPM (120 in
     * qm-dsp's own plugin). */
    double input_tempo;
    /* Non-zero: keep the beat period near input_tempo (useful when the
     * tempo is known roughly and the tracker would pick half or double). */
    int constrain_tempo;
    /* Beat tracking smoothness and tightness (0.9 and 4.0 in the plugin). */
    double alpha;
    double tightness;
    /* Beats per bar for downbeat detection (4 in the plugin). */
    int beats_per_bar;
} perken_beat_params;

typedef struct perken_beat_result
{
    /* Beat positions in seconds from the start of the audio. */
    double *beat_times;
    size_t beat_count;
    /* Indices into beat_times of the beats that start a bar. */
    int *downbeats;
    size_t downbeat_count;
    /* Empty on success, otherwise why the analysis failed. */
    char error[160];
} perken_beat_result;

/* Tracks beats and downbeats in mono audio. Returns 0 on success; on failure
 * returns non-zero and describes the problem in result->error. Always pair
 * with perken_beat_result_free. */
int perken_beat_track(const float *mono, size_t frames, double sample_rate,
                     const perken_beat_params *params, perken_beat_result *result);

void perken_beat_result_free(perken_beat_result *result);

#ifdef __cplusplus
}
#endif

#endif
