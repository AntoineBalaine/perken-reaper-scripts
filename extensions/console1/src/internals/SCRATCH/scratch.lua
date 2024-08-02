local VSDEBUG =
	dofile("/home/antoine/.vscode-oss/extensions/antoinebalaine.reascript-docs-0.1.9/debugger/LoadDebug.lua")

local CONTROLLER_NAME = "PRKN_C1"
local GATE = 1 -- assume gate and comp are always in same place
local COMP = 2
--[[
  **Toggle Mapping of Left Aux Input of FX in Container**

  for selected track,
  if it has less than 4 input channels, set it to 4
  if it has a container with less than 4 channels, set it to 4
  toggle the left aux input of an fx in the container (subidx tbd)
]]
local function getSubContainerIdx(subidx, container_idx, mediaTrack)
	return 0x2000000 + (subidx * (reaper.TrackFX_GetCount(mediaTrack) + 1)) + container_idx
end

local SC = {
	OFF = "off",
	TOSHAPE = "toshape",
	TOCOMP = "tocomp",
}

---@enum SCCHANGE
local SCCHANGE = {
	TURNON = 1,
	TURNOFF = 2,
	TOGGLE = 3,
}

---@param tr MediaTrack
---@param subidx integer
---@param onoff ?SCCHANGE
local function getSetFxSC(tr, subidx, onoff)
	local connected = true
	local channels = { 2, 3 }
	local isOutput = 0
	local hi32 = 0
	for k, channel in ipairs(channels) do
		local Lo32, Hi32 = reaper.TrackFX_GetPinMappings(tr, subidx, isOutput, channel) --Get current pin
		local channelMask = 2 ^ channel
		local isConnected = (Lo32 & channelMask) > 0
		if onoff ~= nil then
			if isConnected then
				if onoff == SCCHANGE.TURNON then
					connected = isConnected
				else
					Lo32 = Lo32 - channelMask
					local pinSuccess = reaper.TrackFX_SetPinMappings(tr, subidx, isOutput, channel, Lo32, Hi32)
					if pinSuccess == true then
						pinSuccess = not isConnected
					else
						pinSuccess = isConnected
					end
				end
			else
				if onoff == SCCHANGE.TURNOFF then
					connected = isConnected
				else
					Lo32 = Lo32 + channelMask
					local pinSuccess = reaper.TrackFX_SetPinMappings(tr, subidx, isOutput, channel, Lo32, Hi32)
					if pinSuccess == true then
						pinSuccess = not isConnected
					else
						pinSuccess = isConnected
					end
				end
			end
		else
			connected = isConnected
		end
	end
	return connected
end

function main()
	local tr = reaper.GetSelectedTrack(0, 0)
	local container_idx = 0
	-- local container_idx = reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false)
	---container_nch : number of internal channels for container<br>
	---container_nch_in : number of input pins for container<br>
	---container_nch_out : number of output pints for container<br>
	---container_nch_feedback : number of internal feedback channels enabled in container<br>

	local subidx2, val = reaper.TrackFX_GetNamedConfigParm(tr, container_idx, "container_item.1")
	local subidx = getSubContainerIdx(GATE + 1, container_idx + 1, tr)
	getSetFxSC(tr, subidx, SCCHANGE.TURNOFF)
end
main()
