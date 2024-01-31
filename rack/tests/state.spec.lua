require 'busted.runner' ()
local State = require("state.state")
describe("State tests", function()
    _G.reaper = {
        GetLastTouchedFX = function() --[[ last_fx]] end,
        GetSelectedTrack2 = function() --[[MediaTrack]] end,
        GetTrackGUID = function() --[[trackGuid]] end,
        GetTrackName = function() --[[_, trackname]] end,
        TrackFX_Delete = function() --[[has_deleted]] end,
        TrackFX_GetCount = function() --[[trackFxCount]] end,
        TrackFX_GetEnabled = function() --[[fxEnabled]] end,
        TrackFX_GetFXGUID = function() --[[fxGuid]] end,
        TrackFX_GetFXName = function() --[[_, fxname]] end,
        TrackFX_GetParamName = function() --[[_, paramName]] end,
    }

    -- local track        = reaper.GetSelectedTrack2(0, 0, false)
    -- local _, trackName = reaper.GetTrackName(track)
    -- local has_deleted  = reaper.TrackFX_Delete(self.Track.track, fx.index - 1)
    -- local trackGuid    = reaper.GetTrackGUID(track) -- get the track's GUID
    -- local trackFxCount = reaper.TrackFX_GetCount(track)
    -- local last_fx      = reaper.GetLastTouchedFX()
    -- local _, fxName    = reaper.TrackFX_GetFXName(track, fxNumber)
    -- local _, paramName = reaper.TrackFX_GetParamName(track, fxNumber, paramNumber)
    -- local fxGuid       = reaper.TrackFX_GetFXGUID(track, fxNumber or 0)
    -- local fxEnabled    = reaper.TrackFX_GetEnabled(track, fxNumber)
    -- local fxGuid       = reaper.TrackFX_GetFXGUID(self.Track.track, idx)
    -- local _, fxName    = reaper.TrackFX_GetFXName(self.Track.track, idx)
    -- local fxEnabled    = reaper.TrackFX_GetEnabled(self.Track.track, idx)
    -- --
    it("should initialize the state and fetch its values", function()
        ---initialize state and pass the correct values
        local state = State:init()
        assert.is_nil(state.Track)

        ---Setup some FX to pass into the state
        ---@type TrackFX[]
        local fx = {}
        for idx = 1, 3 do
            ---@type TrackFX
            local cur_fx = {
                number = idx,
                name = "fxname" .. idx,
                guid = "fx_guid" .. idx,
                enabled = true,
                index = idx
            }
            table.insert(fx, cur_fx)
        end

        _G.reaper.GetSelectedTrack2 = function() return nil end
        _G.reaper.TrackFX_GetCount = function() return #fx end
        _G.reaper.TrackFX_GetFXGUID = function(_, idx) return fx[idx + 1].guid end
        _G.reaper.TrackFX_GetFXName = function(_, idx)
            if not idx then return "" end
            return fx[idx + 1].name
        end


        local GetSelectedTrack2 = spy.on(_G.reaper, "GetSelectedTrack2")
        local TrackFX_GetCount = spy.on(_G.reaper, "TrackFX_GetCount")
        local TrackFX_GetFXGUID = spy.on(_G.reaper, "TrackFX_GetFXGUID")
        local TrackFX_GetFXName = spy.on(_G.reaper, "TrackFX_GetFXName")


        state:update():getTrackFx()

        assert.spy(GetSelectedTrack2).was.called(1)
        assert.spy(TrackFX_GetCount).was.called(1)
        assert.spy(TrackFX_GetFXGUID).was.called(1)
        assert.spy(TrackFX_GetFXName).was.called(1)
        assert.are.same(state.Track.fx_count, #fx, #state.Track.fx_list)
        assert.are.same(state.Track.fx_list[1].guid, fx[1])
    end)
end)
describe("Busted unit testing framework", function()
    describe("should be awesome", function()
        it("should be easy to use", function()
            assert.truthy("Yup.")
        end)

        it("should have lots of features", function()
            -- deep check comparisons!
            assert.are.same({ table = "great" }, { table = "great" })

            -- or check by reference!
            assert.are_not.equal({ table = "great" }, { table = "great" })

            assert.truthy("this is a string") -- truthy: not false or nil

            assert.True(1 == 1)
            assert.is_true(1 == 1)

            assert.falsy(nil)
            assert.has_error(function() error("Wat") end, "Wat")
        end)

        it("should provide some shortcuts to common functions", function()
            assert.are.unique({ { thing = 1 }, { thing = 2 }, { thing = 3 } })
        end)
    end)
end)

describe("busted pending tests", function()
    pending("I should finish this test later")
end)
