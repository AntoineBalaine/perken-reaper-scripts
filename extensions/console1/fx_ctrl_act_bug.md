```zig /Users/a266836/Documents/personnel/Experiments/reaper/zigExt/reaperZigWrap-mapping_panel_ui_stack/src/fx_ctrl_actions.zig
const param_idx = @import("mappings.zig").getParamForCC(input.cc, mapping);
```


In the panel input, there's a wrong expectation. The else block always assumes that it's going to receive an input for the FX controls.

That is wrong because the mute and solo buttons are actually not meant to be used by the FX parameters. They're meant to be used by the track parameters. 
As such they always lead into an unreachable. 
We need to update the switch statement to handle all of the cases of controls and CC input specifically.

For those of the CC inputs that are meant to be used by the track controls we need to have a specific block, and for those of the CCs that are meant to be used by the parameters we need to keep the current block.

We need to create some tests that are going to cover all of the cases of CC inputs going into the panel_input action.

The test case we have must lead into the panel input with some valid values from the CCs. We expect that any button values are going to be either 0 or 127. Any knob values can be between 0 and 127.

