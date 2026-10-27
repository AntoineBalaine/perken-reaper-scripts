-- @noindex
-- Fuzzy matching for the patch table, in the spirit of fzf and the same rules as the action palette
-- of reaziglib's `fuzzy` module (src/fuzzy.zig): the letters of a query must appear in the text in order, not
-- next to each other, and the score favours the matches that look intended.
--
-- A query is split into words on whitespace, and every word must match (so "org dec" finds "Decibel
-- Organ"). Each word is scored by the best way of laying its letters over the text:
--
--   * every matched letter earns a base score;
--   * a letter right after the previous matched one earns a bonus, because whole fragments are what
--     people mean;
--   * a letter at the start of a word (after a space, punctuation, or a lowercase-to-uppercase step)
--     earns a bonus, and the first letter of the text a larger one;
--   * each skipped letter between matches costs a little.
--
-- The letters are compared ignoring case. Only the first MAX_TEXT bytes of the text and MAX_WORD bytes
-- of a word take part. Positions count from 1.
local M = {}

M.MAX_TEXT = 256
M.MAX_WORD = 64

local BASE_SCORE = 16
local CONSECUTIVE_BONUS = 24
local BOUNDARY_BONUS = 20
local FIRST_LETTER_BONUS = 12
local GAP_PENALTY = 2
local LEAD_PENALTY = 1
local LEAD_PENALTY_CAP = 8
local IMPOSSIBLE = -(1 << 30)

-- Because penalties keep being subtracted from IMPOSSIBLE, it drifts below its starting value;
-- anything below half of it still counts as impossible.
local function possible(s)
  return s > IMPOSSIBLE // 2
end

-- Whether the byte at `i` begins a word of `text`.
local function is_boundary(text, i)
  if i == 1 then return true end
  local prev = text:sub(i - 1, i - 1)
  if not prev:match("%w") then return true end
  return prev:match("%l") ~= nil and text:sub(i, i):match("%u") ~= nil
end

-- The best score of laying `word` over `text` as an ordered subsequence, or nil when it does not fit.
function M.score_word(word, text_full)
  if #word == 0 then return 0 end
  local text = text_full:sub(1, M.MAX_TEXT)
  local w = word:sub(1, M.MAX_WORD)
  if #w > #text then return nil end
  local lower_text, lower_word = text:lower(), w:lower()

  -- Because most texts fail a plain subsequence test, it runs first: it is linear, while the scoring
  -- below is not.
  local at = 1
  for j = 1, #lower_text do
    if at <= #lower_word and lower_text:byte(j) == lower_word:byte(at) then at = at + 1 end
  end
  if at <= #lower_word then return nil end

  -- prev[j]: the best score with the previous letter of the word matched at text[j]; cur[j] likewise
  -- for the current letter.
  local prev, cur = {}, {}
  for i = 1, #lower_word do
    local want = lower_word:byte(i)
    -- gap_best: the best prev[k] - GAP_PENALTY * (j - 1 - k) over every earlier match that is not
    -- directly adjacent.
    local gap_best = IMPOSSIBLE
    for j = 1, #lower_text do
      cur[j] = IMPOSSIBLE
      if i > 1 and j >= 3 then
        gap_best = math.max(gap_best - GAP_PENALTY, prev[j - 2] - GAP_PENALTY)
      end
      if lower_text:byte(j) == want then
        local gain = BASE_SCORE
        if is_boundary(text, j) then gain = gain + BOUNDARY_BONUS end
        if j == 1 then gain = gain + FIRST_LETTER_BONUS end
        if i == 1 then
          cur[j] = gain - math.min((j - 1) * LEAD_PENALTY, LEAD_PENALTY_CAP)
        else
          local best = IMPOSSIBLE
          if j >= 2 and possible(prev[j - 1]) then best = prev[j - 1] + CONSECUTIVE_BONUS end
          if possible(gap_best) then best = math.max(best, gap_best) end
          if possible(best) then cur[j] = best + gain end
        end
      end
    end
    prev, cur = cur, prev
  end

  local best = IMPOSSIBLE
  for j = 1, #lower_text do best = math.max(best, prev[j]) end
  if possible(best) then return best end
  return nil
end

-- The score of a whole query: the sum over its words, or nil when any word does not match. An empty
-- query matches everything with score 0.
function M.score(query, text)
  local total = 0
  for word in query:gmatch("%S+") do
    local s = M.score_word(word, text)
    if not s then return nil end
    total = total + s
  end
  return total
end

-- Whether candidate `a` ranks above `b`: higher score first, then shorter text, then the earlier index,
-- so the order never depends on the order of arrival.
function M.ranked_before(a, b)
  if a.score ~= b.score then return a.score > b.score end
  if a.len ~= b.len then return a.len < b.len end
  return a.index < b.index
end

-- The items that match `query`, best first. `texts[i]` is the text that item i is matched against.
-- Returns the indices of the items.
function M.rank(query, texts)
  local ranked = {}
  for i, text in ipairs(texts) do
    local s = M.score(query, text)
    if s then ranked[#ranked + 1] = { index = i, score = s, len = #text } end
  end
  table.sort(ranked, M.ranked_before)
  local indices = {}
  for k, r in ipairs(ranked) do indices[k] = r.index end
  return indices
end

return M
