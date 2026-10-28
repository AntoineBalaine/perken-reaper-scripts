-- @noindex
-- The mock controller of the MFT lab: the six modes, the names of their eight parameters, the hue of each
-- mode on the controller's color wheel, the transport functions, and the values of the encoders. Nothing here
-- talks to REAPER or to the plugin: the lab is a dummy, made to look at the panel. This file is read once, when
-- the lab starts.
local M = {}

-- The hue of each mode is the default of the preferences (`color_io`, `color_gate` and so on), a position on the
-- wheel of the controller's LEDs.
M.modes = {
  { id = "IO", hue = 15, params = { "Input gain", "Input pan", "Trim", "Output gain", "Width", "Mono", "Saturation", "Dry/wet" } },
  { id = "GATE", hue = 94, params = { "Threshold", "Attack", "Hold", "Release", "Range", "Hysteresis", "Sidechain", "Mix" } },
  { id = "EQ", hue = 60, params = { "Low gain", "Low freq", "Low mid gain", "Low mid freq", "High mid gain", "High mid freq", "High gain", "High freq" } },
  { id = "COMP", hue = 86, params = { "Threshold", "Ratio", "Attack", "Release", "Knee", "Makeup", "Mix", "Lookahead" } },
  { id = "SETTINGS", hue = 73, params = {} },
  { id = "TRANSPORT", hue = 107, params = {} },
}

-- What each of the eight top encoders does in transport mode: the icon that stands for its rotation, the name of
-- the rotation and the name of the press.
M.transport = {
  { icon = "jog", rotation = "Jog", press = "Play/Stop" },
  { icon = "item", rotation = "Item", press = "Play/Pause" },
  { icon = "zoom_h", rotation = "Zoom H", press = "FitH" },
  { icon = "zoom_v", rotation = "Zoom V", press = "FitV" },
  { icon = "rate", rotation = "Rate", press = "Rate=1" },
  { icon = "grid", rotation = "Grid", press = "Snap" },
  { icon = "track", rotation = "Trk", press = "NewTrk" },
  { icon = "marker", rotation = "Mkr", press = "Marker" },
}

M.side_left = { "L1 Chain", "L2 Hide", "L3 FXsel" }
M.side_right = { "R1 Mute", "R2 Solo", "R3 Phase" }

-- The slots of the settings form, and the plugins that its drop-downs offer.
M.slots = { "Input", "Gate", "EQ", "Comp", "Output" }
M.plugins = {
  "CLAP: Surge XT (Surge Synth Team)", "JS: Saturation", "JS: Volume/Pan Smoother v5", "VST: ReaComp (Cockos)",
  "VST: ReaEQ (Cockos)", "VST: ReaGate (Cockos)", "VST: ReaLimit (Cockos)", "VST: ReaXcomp (Cockos)",
  "VST3: Pro-C 2 (FabFilter)", "VST3: Pro-G (FabFilter)", "VST3: Pro-Q 3 (FabFilter)", "VST3: Pro-L 2 (FabFilter)",
  "VST3: SSL Native Channel Strip 2 (Solid State Logic)", "VST3: Vitamin (Slate Digital)",
}

-- A fresh state: the first mode, a value for every encoder of every mode, a few encoders that map nothing, and the
-- keys and the form at rest.
function M.new()
  local state = {
    mode = 1,
    values = {},
    mapped = {},
    -- The side keys that stay lit once pressed, by their label.
    lit = {},
    slot_plugin = { M.plugins[3], M.plugins[6], M.plugins[5], M.plugins[4], M.plugins[2] },
    settings_cursor = 1,
    led_test = false,
    calibrating = false,
    calibration_step = 1,
  }
  for m = 1, #M.modes do
    state.values[m], state.mapped[m] = {}, {}
    for i = 1, 8 do
      state.values[m][i] = ((m * 37 + i * 29) % 100) / 100
      state.mapped[m][i] = true
    end
  end
  -- Two encoders of the gate map nothing, to see how an empty encoder looks.
  state.mapped[2][7], state.mapped[2][8] = false, false
  return state
end

-- Moves every value along a slow wave, to see the rings and the pointers turn.
function M.animate(state, frame)
  for m = 1, #M.modes do
    for i = 1, 8 do
      state.values[m][i] = 0.5 + 0.5 * math.sin(frame * 0.02 + i * 0.7 + m)
    end
  end
end

return M
