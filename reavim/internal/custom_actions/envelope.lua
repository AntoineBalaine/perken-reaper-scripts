local envelope = {}

function envelope.setTimeSelectionToSelectedEnvelopePoints()
  local startPos, endPos = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if startPos ~= 0 and endPos ~= 0 then
    return
  end

  envelope = reaper.GetSelectedEnvelope(0)
  if envelope then
    local count = reaper.CountEnvelopePoints(envelope)
    -- get those of the points that are selected
    -- find the first one and the last one
    -- set time selection to their positions
    local first, last = nil, nil

    for i = 0, count - 1 do
      local _, time, _, _, _, selected = reaper.GetEnvelopePoint(envelope, i)
      if selected then
        if not first then
          first = time
        end
        last = time
      end
    end

    reaper.GetSet_LoopTimeRange(true, false, first, last, false)
  end
end

function envelope.SelectPointsCrossingTimeSelection()
  local startPos, endPos = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if startPos == 0 and endPos == 0 then
    return
  end

  envelope = reaper.GetSelectedEnvelope(0)
  if envelope then
    local count = reaper.CountEnvelopePoints(envelope)
    for i = 0, count - 1 do
      local _, time, _, _, _, selected = reaper.GetEnvelopePoint(envelope, i)
      if time >= startPos and time <= endPos then
        reaper.SetEnvelopePoint(envelope, i, time, nil, nil, nil, true, true)
      end
    end
  end
end

return envelope
