--[[
modulesList.ini

[INPUT]
JS: Volume/Pan Smoother
[EQ]
VST: ReaEQ (Cockos)
[DEFAULTS]
EQ = "VST: ReaEQ (Cockos)"
COMP = "VST: ReaComp (Cockos)"
GATE = "VST: ReaGate (Cockos)"
SAT = "JS: Saturation"
]]
local map = {
	knob1 = "param1",
	knob2 = "param2",
}
local modules = {
	-- this needs to be a set
	INPUT = {
		default = "JS: Volume/Pan Smoother",
		mappings = { ["JS: Volume/Pan Smoother"] = map },
	},
	EQ = {
		["VST: ReaEQ (Cockos)"] = true,
		["ProQ"] = true,
	},
	COMP = {
		["VST: ReaComp (Cockos)"] = true,
		["ReaComp"] = true,
		["Pro-C"] = true,
	},
	GATE = {
		["VST: ReaGate (Cockos)"] = true,
		["pro-c"] = true,
	},
	SAT = {
		["JS: Saturation"] = true,
	},
}
local function loadDefaultChain() end

---@param tbl {isPresent: boolean, idx: number}[]
local function allAreValid(tbl)
	for k, v in pairs(tbl) do
		if not v[1] then
			return false
		end
	end
	return true
end

---@param tr MediaTrack
---@param subidx number
---@param cntnr_idx number
local function getSubContainerIdx(tr, subidx, cntnr_idx)
	return 0x2000000 + (reaper.TrackFX_GetCount(tr) + 1) * subidx + cntnr_idx
end

local function checkTrackState()
	local fxname = "PRKN_C1"
	local tr = reaper.GetSelectedTrack2(0, 0, false)
	local ctnr_idx = reaper.TrackFX_GetByName(tr, fxname, false)
	if ctnr_idx == -1 then
		loadDefaultChain()
		return
	end
	local isDirty = false
	local count = reaper.TrackFX_GetNamedConfigParm(tr, ctnr_idx, "container_count")
	if count > #modules or count < #modules then
		-- container's dirty, invalidate and reload
		reaper.TrackFX_Delete(tr, ctnr_idx)
		loadDefaultChain()
		return
	end

	local module_checks = {
		INPUT = { false, 0 },
		EQ = { false, 1 },
		GATE = { false, 2 },
		COMP = { false, 3 },
		SAT = { false, 4 },
	}

	for i = 0, count - 1 do
		local cntr_rv, fx_item = reaper.TrackFX_GetNamedConfigParm(tr, ctnr_idx, "container_item." .. i)
		local has_name, cur_fx_name = reaper.TrackFX_GetFXName(tr, fx_item)

		-- find a matching effect name in one of the modules sub-tables.
		for k, module in pairs(modules) do
			if module[cur_fx_name] then
				module_checks[k][1] = true
				module_checks[k][2] = i
				if k == "INPUT" then
					-- check if the input module is in the correct position
					if i ~= 0 then
						isDirty = true
					end
				elseif k == "SAT" then
					-- check if the saturator module is in the correct position
					if i ~= count - 1 then
						isDirty = true
					end
				end
			end
		end
	end

	if isDirty then
		if module_checks.INPUT[2] ~= 0 then
			do
				local subidx = module_checks.INPUT[2]
				reaper.TrackFX_CopyToTrack(
					tr,
					getSubContainerIdx(tr, subidx, ctnr_idx),
					tr,
					getSubContainerIdx(tr, 0, ctnr_idx),
					true
				)
				-- now that the fx indexes are all invalid, let's recurse.
				return checkTrackState()
			end
		end

		if module_checks.SAT[2] ~= count - 1 then
			do
				local subidx = module_checks.INPUT[2]
				reaper.TrackFX_CopyToTrack(
					tr,
					getSubContainerIdx(tr, subidx, ctnr_idx),
					tr,
					getSubContainerIdx(tr, 5, ctnr_idx),
					true
				)
				-- now that the fx indexes are all invalid, let's recurse.

				return checkTrackState()
			end
		end

		-- for each missing module, insert it in the correct position
		for k, module in pairs(module_checks) do
			if not module[1] then
				-- insert the missing module
				local default_for_module = findDefaultForModule(k)
				-- insertion is done at end of fx list, so this doesn't invalidate the fx indexes we already have
				local fx_idx = reaper.TrackFX_AddByName(tr, default_for_module, false, -1)
				reaper.TrackFX_CopyToTrack(tr, fx_idx, tr, getSubContainerIdx(tr, module[2], ctnr_idx), true)
			end
		end

		local order = nil
		if allAreValid(module_checks) then
			--[[
  if one of the modules is still marked as false, 
  it needs to be inserted in the container.
How do we identify the three possible orders?
this needs to be an enum
enum {
  EQ-S-C
  S-C-EQ
  S-EQ-C
}
]]
			if module_checks.EQ[2] == 1 and module_checks.GATE[2] == 2 and module_checks.COMP[2] == 3 then
				order = "EQ-S-C"
			elseif module_checks.GATE[2] == 1 and module_checks.COMP[2] == 2 and module_checks.EQ[2] == 3 then
				order = "S-C-EQ"
			else
				order = "S-EQ-C"
			end
		else
			-- now that the fx indexes are all invalid, let's recurse.
			return checkTrackState()
		end
		return order
	end
end
