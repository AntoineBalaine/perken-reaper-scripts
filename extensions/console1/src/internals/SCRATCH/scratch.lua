--[[
  **Toggle Mapping of Left Aux Input of FX in Container**

  for selected track,
  if it has less than 4 input channels, set it to 4
  if it has a container with less than 4 channels, set it to 4
  toggle the left aux input of an fx in the container (subidx tbd)
]]
Tr = reaper.GetSelectedTrack(0, 0)
Fx = 0
IsOut = 0 -- input = 0, output = 1
PluginType, InPins, OutPins = reaper.TrackFX_GetIOSize(Tr, Fx)

TrIns = reaper.GetMediaTrackInfo_Value(Tr, "I_NCHAN")
if InPins < 4 then
	reaper.SetMediaTrackInfo_Value(Tr, "I_NCHAN", 4)
end

---container_nch : number of internal channels for container<br>
---container_nch_in : number of input pins for container<br>
---container_nch_out : number of output pints for container<br>
---container_nch_feedback : number of internal feedback channels enabled in container<br>

rv, buf = reaper.TrackFX_GetNamedConfigParm(Tr, Fx, "container_nch")
if buf < 4 then
	-- create a container with 4 channels - mapping i/o is automatic
	reaper.TrackFX_SetNamedConfigParm(Tr, Fx, "container_nch", "4")
	reaper.TrackFX_SetNamedConfigParm(Tr, Fx, "container_nch_in", "4")
end

FxInPin = 2 -- left aux
subIdx = 0x20001 -- getContainerSubIdx
Lo, Hi = reaper.TrackFX_GetPinMappings(Tr, subIdx, IsOut, FxInPin) --Get current pin
TrChan = 2
ChanMask = 2 ^ TrChan
Val = (Lo & ChanMask) > 0

if Val then
	Lo = Lo - ChanMask -- disconnect channel
else
	Lo = Lo + ChanMask -- connect
end

reaper.TrackFX_SetPinMappings(Tr, subIdx, IsOut, FxInPin, Lo, Hi)
