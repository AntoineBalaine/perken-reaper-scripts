local function loop()
    reaper.set_action_options(4) -- toggle state ON

    reaper.defer(loop)
    -- atExit()
    reaper.set_action_options(4) -- toggle state OFF
end

return loop()
