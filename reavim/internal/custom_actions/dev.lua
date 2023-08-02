local dev = {}

function dev.fxDevices()
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSa0b0ec0b58437033fddcf576a71873629fafcdc7"), 0)
end

function dev.repl()
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS9aebe6a6a706099d8a0af623f132ce89ed88ac10"), 0)
end

function GetOpenProjects()
  local projects = {}
  local p = 0
  repeat
    local proj = reaper.EnumProjects(p)
    if reaper.ValidatePtr(proj, 'ReaProject*') then
      projects[#projects + 1] = proj
    end
    p = p + 1
  until not proj
  return projects
end

---@alias FX_handle {hwnd: HWND, track: MediaTrack, item?: MediaItem, take?: MediaItem_Take, fx_idx: number, isInputFx: boolean}

local function getAllFxChainWindows()
  local hwnds = {}
  local projects = GetOpenProjects()
  --get focused fx window
  local focused_hwnd = reaper.JS_Window_GetFocus()
  local focused_fx = reaper.JS_Window_FindChildByID(focused_hwnd, 0x3E8)
  if focused_fx then
    local t = {
      hwnd = focused_fx,
      track = reaper.JS_Window_GetLongPtr(focused_fx, "USER"),
      fx_idx = reaper.JS_Window_GetLongPtr(focused_fx, "ID")
    } ---@type FX_handle
    hwnds[#hwnds + 1] = t
  end
  local chain = reaper.CF_GetFocusedFXChain()
  reaper.TrackFX_GetFXName(hwnd, "")
end

function GetAllFloatingFXWindows()
  ---@type FX_handle[]
  local hwnds = {}
  local projects = GetOpenProjects()

  local TrackFX_GetFloatingWindow = reaper.TrackFX_GetFloatingWindow
  local TakeFX_GetFloatingWindow = reaper.TakeFX_GetFloatingWindow

  for _, proj in ipairs(projects) do
    local master_track = reaper.GetMasterTrack(proj)
    for fx_idx = 0, reaper.TrackFX_GetCount(master_track) - 1 do
      local hwnd = TrackFX_GetFloatingWindow(master_track, fx_idx)
      local t = { hwnd = hwnd, track = master_track, fx_idx = fx_idx } ---@type FX_handle
      if hwnd then hwnds[#hwnds + 1] = t end
    end
    for t = 0, reaper.CountTracks(proj) - 1 do
      local track = reaper.GetTrack(proj, t)
      for fx_idx = 0, reaper.TrackFX_GetCount(track) - 1 do
        local hwnd = TrackFX_GetFloatingWindow(track, fx_idx)
        local t = { hwnd = hwnd, track = track, fx_idx = fx_idx } ---@type FX_handle
        if hwnd then hwnds[#hwnds + 1] = t end
      end
      for fx_idx = 0, reaper.TrackFX_GetRecCount(track) - 1 do
        local fx_in = fx_idx + 0x1000000
        local hwnd = TrackFX_GetFloatingWindow(track, fx_in)
        local t = { hwnd = hwnd, track = track, fx_idx = fx_idx } ---@type FX_handle
        t.isInputFx = true
        if hwnd then hwnds[#hwnds + 1] = hwnd end
      end

      for i = 0, reaper.CountTrackMediaItems(track) - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        for tk = 0, reaper.GetMediaItemNumTakes(item) - 1 do
          local take = reaper.GetMediaItemTake(item, tk)
          if reaper.ValidatePtr(take, 'MediaItem_Take*') then
            for fx_idx = 0, reaper.TakeFX_GetCount(take) - 1 do
              local hwnd = TakeFX_GetFloatingWindow(take, fx_idx)
              if hwnd then
                local t = {} ---@type FX_handle
                t.hwnd = hwnd
                t.track = track
                t.item = item
                t.take = take
                t.fx_idx = fx_idx
                hwnds[#hwnds + 1] = t
              end
            end
          end
        end
      end
    end
  end
  return hwnds
end

---@alias FX_param {param_name: string, value: number, minval: number, maxval: number, param_idx: number}
function dev.devAction()
  -- add "hello world" to system clipboard
  reaper.CF_SetClipboard("hello world")
end

return dev
