#ifndef FX_MODEL_GEN_H
#define FX_MODEL_GEN_H

#include <rapidcheck.h>
#include "../types/fx_model.h"
#include <string>
#include <vector>
#include <limits>
#include <cstring> // For strdup

namespace rc {

// Generator for RC_Param
template<>
struct Arbitrary<RC_Param> {
    static Gen<RC_Param> arbitrary() {
        return gen::map(
            gen::tuple(
                gen::nonEmpty(gen::string<std::string>()),  // name (non-empty)
                gen::inRange(0.0, 1.0),                    // normalized_value
                gen::string<std::string>()                 // formatted_value
            ),
            [](const auto &tuple) {
                RC_Param param;
                param.name = strdup(std::get<0>(tuple).c_str());
                param.normalized_value = std::get<1>(tuple);
                param.formatted_value = strdup(std::get<2>(tuple).c_str());
                return param;
            }
        );
    }
};

// Generator for RC_FX
template<>
struct Arbitrary<RC_FX> {
    static Gen<RC_FX> arbitrary() {
        // Generate a boolean with 50% chance of being true/false
        auto renameChanceGen = gen::arbitrary<bool>();
        
        return gen::map(
            gen::tuple(
                gen::container<std::vector<uint8_t>>(gen::inRange(0, 255), 16),  // guid with proper range
                gen::arbitrary<bool>(),                                          // enabled
                gen::resize(10, gen::arbitrary<std::vector<RC_Param>>()),        // params (limit size to 10)
                gen::nonEmpty(gen::string<std::string>()),                       // original_name (non-empty)
                renameChanceGen,                                                 // 50% chance of renaming
                gen::oneOf(
                    gen::just<double>(std::numeric_limits<double>::quiet_NaN()), // NaN for "not set"
                    gen::inRange(-60.0, 0.0)                                     // Valid gain reduction range
                )
            ),
            [](const auto &tuple) {
                RC_FX fx;
                // Copy GUID
                std::copy_n(std::get<0>(tuple).begin(), 16, fx.guid);
                fx.enabled = std::get<1>(tuple);
                
                // Copy params
                const auto &params = std::get<2>(tuple);
                fx.params_count = params.size();
                if (params.empty()) {
                    fx.params = nullptr;
                } else {
                    fx.params = static_cast<RC_Param*>(malloc(sizeof(RC_Param) * params.size()));
                    std::copy(params.begin(), params.end(), fx.params);
                }
                
                // Copy names
                fx.original_name = strdup(std::get<3>(tuple).c_str());
                if (std::get<4>(tuple)) {
                    // Same name
                    fx.renamed_name = strdup(std::get<3>(tuple).c_str());
                } else {
                    // Different name
                    std::string modified = std::get<3>(tuple) + "_renamed";
                    fx.renamed_name = strdup(modified.c_str());
                }
                
                fx.gain_reduction_db = std::get<5>(tuple);
                return fx;
            }
        );
    }
};

} // namespace rc

#endif // FX_MODEL_GEN_H

