// C bridge over qm-dsp's bar and beat tracker. The analysis follows qm-dsp's
// own Vamp plugin (qm-vamp-plugins, plugins/BarBeatTrack.cpp) step for step:
// the same step and frame sizes, detection-function settings, tempo tracker
// calls and downbeat detection. The audio is processed in one call instead
// of the plugin's block-by-block host calls.
//
// qm-dsp is C++ and may throw (allocation failures), so every exception is
// caught here: none may cross into Zig or REAPER.

#include "qm_bridge.h"

#include "dsp/onsets/DetectionFunction.h"
#include "dsp/tempotracking/DownBeat.h"
#include "dsp/tempotracking/TempoTrackV2.h"
#include "maths/MathUtilities.h"

#include <cstdlib>
#include <cstring>
#include <exception>
#include <vector>

// BarBeatTracker::m_stepSecs: 512 samples at 44100 Hz.
static const double kStepSecs = 0.01161;

static void setError(cajun_beat_result *result, const char *message)
{
    std::strncpy(result->error, message, sizeof(result->error) - 1);
    result->error[sizeof(result->error) - 1] = 0;
}

extern "C" int cajun_beat_track(const float *mono, size_t frames, double sample_rate,
                                const cajun_beat_params *params, cajun_beat_result *result)
{
    std::memset(result, 0, sizeof(*result));
    if (!mono || !params || sample_rate <= 0) {
        setError(result, "invalid arguments");
        return 1;
    }

    try {
        // BarBeatTracker::getPreferredStepSize / getPreferredBlockSize.
        int step = int(sample_rate * kStepSecs + 0.0001);
        if (step < 1) step = 1;
        const int frame_length = step * 2;
        if (frames < size_t(frame_length) * 4) {
            setError(result, "audio too short to analyse");
            return 1;
        }

        // BarBeatTracker::initialise.
        DFConfig config;
        config.DFType = DF_COMPLEXSD;
        config.stepSize = step;
        config.frameLength = frame_length;
        config.dbRise = 3;
        config.adaptiveWhitening = false;
        config.whiteningRelaxCoeff = -1;
        config.whiteningFloor = -1;

        DetectionFunction df(config);
        // The decimation factor aims at resampling to about 3 kHz and must be
        // a power of two (BarBeatTrackerData's constructor).
        const int factor = MathUtilities::nextPowerOfTwo(int(sample_rate / 3000));
        DownBeat down_beat(float(sample_rate), factor, step);
        down_beat.setBeatsPerBar(params->beats_per_bar);

        // BarBeatTracker::process, once per hop. The detection function takes
        // doubles; DownBeat buffers one step's worth of each block.
        std::vector<double> df_output;
        std::vector<double> block(frame_length);
        for (size_t start = 0; start + size_t(frame_length) <= frames; start += size_t(step)) {
            for (int i = 0; i < frame_length; ++i) block[i] = mono[start + i];
            df_output.push_back(df.processTimeDomain(block.data()));
            down_beat.pushAudioBlock(mono + start);
        }

        // BarBeatTracker::barBeatTrack.
        std::vector<double> df_values;
        std::vector<double> beat_period;
        std::vector<double> tempi;
        for (size_t i = 2; i < df_output.size(); ++i) { // the plugin discards the first two
            df_values.push_back(df_output[i]);
            beat_period.push_back(0.0);
        }
        if (df_values.empty()) {
            setError(result, "no detection-function output");
            return 1;
        }

        TempoTrackV2 tracker(float(sample_rate), step);
        tracker.calculateBeatPeriod(df_values, beat_period, tempi, params->input_tempo,
                                    params->constrain_tempo != 0);
        std::vector<double> beats;
        tracker.calculateBeats(df_values, beat_period, beats, params->alpha, params->tightness);

        std::vector<int> downbeats;
        size_t down_length = 0;
        const float *downsampled = down_beat.getBufferedAudio(down_length);
        down_beat.findDownBeats(downsampled, down_length, beats, downbeats);

        // The plugin's timestamps: beat index (in hops) times the step size,
        // from the start of the audio.
        result->beat_count = beats.size();
        result->beat_times = static_cast<double *>(std::malloc(sizeof(double) * (beats.size() + 1)));
        result->downbeat_count = downbeats.size();
        result->downbeats = static_cast<int *>(std::malloc(sizeof(int) * (downbeats.size() + 1)));
        if (!result->beat_times || !result->downbeats) {
            cajun_beat_result_free(result);
            setError(result, "out of memory");
            return 1;
        }
        for (size_t i = 0; i < beats.size(); ++i) {
            const size_t frame = size_t(beats[i]) * size_t(step);
            result->beat_times[i] = double(frame) / sample_rate;
        }
        for (size_t i = 0; i < downbeats.size(); ++i) result->downbeats[i] = downbeats[i];
        return 0;
    } catch (const std::exception &e) {
        cajun_beat_result_free(result);
        setError(result, e.what());
        return 1;
    } catch (...) {
        cajun_beat_result_free(result);
        setError(result, "unknown error in qm-dsp");
        return 1;
    }
}

extern "C" void cajun_beat_result_free(cajun_beat_result *result)
{
    if (!result) return;
    std::free(result->beat_times);
    std::free(result->downbeats);
    result->beat_times = 0;
    result->downbeats = 0;
    result->beat_count = 0;
    result->downbeat_count = 0;
}
