#ifndef TRACK_MODEL_GEN_H
#define TRACK_MODEL_GEN_H

#include <rapidcheck.h>
#include "../types/track_model.h"
#include "fx_model_gen.h"
#include <string>
#include <vector>
#include <limits>
#include <cstring> // For strdup

namespace rc {

// Generator for RC_TrackInfo
template<>
struct Arbitrary<RC_TrackInfo> {
    static Gen<RC_TrackInfo> arbitrary() {
        return gen::map(
            gen::tuple(
                gen::arbitrary<bool>(),                // phase
                gen::inRange(1, 8),                   // num_channels (1-8 channels)
                gen::inRange(0.0, 2.0),               // volume (0-2.0 range)
                gen::inRange(-1.0, 1.0),              // pan (-1.0 to 1.0)
                gen::arbitrary<bool>(),                // mute
                gen::inRange(0, 2)                    // solo (0=off, 1=solo, 2=solo-in-place)
            ),
            [](const auto &tuple) {
                RC_TrackInfo info;
                info.phase = std::get<0>(tuple);
                info.num_channels = std::get<1>(tuple);
                info.volume = std::get<2>(tuple);
                info.pan = std::get<3>(tuple);
                info.mute = std::get<4>(tuple);
                info.solo = std::get<5>(tuple);
                return info;
            }
        );
    }
};

// Generator for RC_PeakInfo
template<>
struct Arbitrary<RC_PeakInfo> {
    static Gen<RC_PeakInfo> arbitrary() {
        return gen::map(
            gen::tuple(
                gen::inRange(0.0, 1.0),  // left peak (0.0-1.0)
                gen::inRange(0.0, 1.0)   // right peak (0.0-1.0)
            ),
            [](const auto &tuple) {
                RC_PeakInfo peak_info;
                peak_info.left = std::get<0>(tuple);
                peak_info.right = std::get<1>(tuple);
                return peak_info;
            }
        );
    }
};

// Generator for RC_AutomationMode
template<>
struct Arbitrary<RC_AutomationMode> {
    static Gen<RC_AutomationMode> arbitrary() {
        return gen::element(TRIM, READ, TOUCH, LATCH, PREVIEW, WRITE);
    }
};

// Generator for RC_Track
template<>
struct Arbitrary<RC_Track> {
    static Gen<RC_Track> arbitrary() {
        // Generate a boolean with 20% chance of having peak info
        auto hasPeakInfoGen = gen::weightedOneOf(
            std::make_pair(8, gen::just(false)),  // 80% chance of no peak info
            std::make_pair(2, gen::just(true))    // 20% chance of having peak info
        );
        
        return gen::map(
            gen::tuple(
                gen::nonEmpty(gen::string<std::string>()),                // name (non-empty)
                gen::resize(5, gen::arbitrary<std::vector<RC_FX>>()),     // fx_list (limit to 5 FX)
                gen::arbitrary<RC_AutomationMode>(),                      // automation_mode
                gen::arbitrary<RC_TrackInfo>(),                           // info
                hasPeakInfoGen,                                           // whether to have peak info
                gen::arbitrary<RC_PeakInfo>()                             // peak_info (used only if hasPeakInfo is true)
            ),
            [](const auto &tuple) {
                RC_Track track;
                track.name = strdup(std::get<0>(tuple).c_str());
                
                // Copy FX list
                const auto &fx_list = std::get<1>(tuple);
                track.fx_count = fx_list.size();
                if (fx_list.empty()) {
                    track.fx_list = nullptr;
                } else {
                    track.fx_list = static_cast<RC_FX*>(malloc(sizeof(RC_FX) * fx_list.size()));
                    std::copy(fx_list.begin(), fx_list.end(), track.fx_list);
                }
                
                track.automation_mode = std::get<2>(tuple);
                track.info = std::get<3>(tuple);
                
                // Set peak info if needed
                if (std::get<4>(tuple)) {
                    track.peak_info = static_cast<RC_PeakInfo*>(malloc(sizeof(RC_PeakInfo)));
                    *track.peak_info = std::get<5>(tuple);
                } else {
                    track.peak_info = nullptr;
                }
                
                return track;
            }
        );
    }
};

// Generator for RC_Session
template<>
struct Arbitrary<RC_Session> {
    static Gen<RC_Session> arbitrary() {
        // Generate a boolean with 50% chance of having a last touched track
        auto hasLastTouchedGen = gen::arbitrary<bool>();
        
        return gen::map(
            gen::tuple(
                gen::resize(10, gen::arbitrary<std::vector<RC_Track>>()),  // tracks (limit to 10 tracks)
                gen::inRange(0.0, 1000.0),                                // cursor_position
                gen::arbitrary<RC_AutomationMode>()                       // global_automation_mode
            ),
            [](const auto &tuple) {
                RC_Session session;
                
                // Copy tracks
                const auto &tracks = std::get<0>(tuple);
                session.track_count = tracks.size();
                if (tracks.empty()) {
                    session.tracks = nullptr;
                } else {
                    session.tracks = static_cast<RC_Track*>(malloc(sizeof(RC_Track) * tracks.size()));
                    std::copy(tracks.begin(), tracks.end(), session.tracks);
                }
                
                // Initialize selected tracks (randomly select up to half of the tracks)
                size_t max_selected = tracks.size() / 2 + 1;
                std::vector<size_t> selected_indices;
                for (size_t i = 0; i < tracks.size(); i++) {
                    if (selected_indices.size() < max_selected && *gen::arbitrary<bool>()) {
                        selected_indices.push_back(i);
                    }
                }
                
                session.selected_track_count = selected_indices.size();
                if (selected_indices.empty()) {
                    session.selected_tracks = nullptr;
                } else {
                    session.selected_tracks = static_cast<size_t*>(malloc(sizeof(size_t) * selected_indices.size()));
                    std::copy(selected_indices.begin(), selected_indices.end(), session.selected_tracks);
                }
                
                // Set last touched track if there are any tracks
                if (!tracks.empty() && *gen::arbitrary<bool>()) {
                    session.last_touched_track_index = static_cast<size_t*>(malloc(sizeof(size_t)));
                    *session.last_touched_track_index = *gen::inRange<size_t>(0, tracks.size() - 1);
                } else {
                    session.last_touched_track_index = nullptr;
                }
                
                session.cursor_position = std::get<1>(tuple);
                session.global_automation_mode = std::get<2>(tuple);
                
                return session;
            }
        );
    }
};

// Shrink functions for the custom types
template<>
struct Shrinkable<RC_TrackInfo> : public ShrinkableImpl<RC_TrackInfo> {
    using ShrinkableImpl<RC_TrackInfo>::ShrinkableImpl;
};

template<>
struct Shrinkable<RC_PeakInfo> : public ShrinkableImpl<RC_PeakInfo> {
    using ShrinkableImpl<RC_PeakInfo>::ShrinkableImpl;
};

template<>
struct Shrinkable<RC_Track> : public ShrinkableImpl<RC_Track> {
    using ShrinkableImpl<RC_Track>::ShrinkableImpl;
};

template<>
struct Shrinkable<RC_Session> : public ShrinkableImpl<RC_Session> {
    using ShrinkableImpl<RC_Session>::ShrinkableImpl;
};

} // namespace rc

#endif // TRACK_MODEL_GEN_H
