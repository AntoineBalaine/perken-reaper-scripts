dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
local text_helpers = {}

--- Center text with word wrap,
--- both horizontally and vertically.
--- Credit to Sexan! He did it again!
---@param ctx ImGui_Context context
---@param text string text to draw
---@param width number width of the text box
---@param height number height of the text box
function text_helpers.TextSplitByWidth(ctx, text, width, height)
    local str_tbl = {}
    local str = {}
    local total = 0
    for word in text:gmatch("%S+") do
        local w = reaper.ImGui_CalcTextSize(ctx, word .. " ")
        if total + w < width then
            str[#str + 1] = word
            total = total + w
        else
            str_tbl[#str_tbl + 1] = table.concat(str, " ")
            str = {}
            str[#str + 1] = word
            total = reaper.ImGui_CalcTextSize(ctx, word .. " ")
        end
    end

    if #str ~= 0 then
        str_tbl[#str_tbl + 1] = table.concat(str, " ")
    end

    local box_width, box_height = reaper.ImGui_GetItemRectSize(ctx)
    local x_start, y_start = reaper.ImGui_GetItemRectMin(ctx)
    local x_end, y_end = reaper.ImGui_GetItemRectMax(ctx)

    local _, txt_height = reaper.ImGui_CalcTextSize(ctx, text)
    local font_size = reaper.ImGui_GetFontSize(ctx)
    reaper.ImGui_PushClipRect(ctx, x_start, y_start, x_end, y_end, false)

    local h_cnt = 0
    for i = 1, #str_tbl do
        if (txt_height * i) < height then
            h_cnt = h_cnt + 1
        end
    end
    for i = 1, #str_tbl do
        local str_w = reaper.ImGui_CalcTextSize(ctx, str_tbl[i])
        local x_pos = x_start + box_width / 2 - str_w / 2
        local y_pos = y_start + (box_height / 2) - (txt_height * (h_cnt - (i - 1))) + (h_cnt * txt_height) / 2
        reaper.ImGui_SetCursorScreenPos(ctx,
            x_pos,
            y_pos)

        if (txt_height * i - 1) + font_size < height then
            reaper.ImGui_Text(ctx, str_tbl[i])
        end
    end
    reaper.ImGui_PopClipRect(ctx)
end

--- Center text with word wrap - but start from the top of the box.
---@param ctx ImGui_Context context
---@param text string text to draw
---@param line_width number width of the text box
---@param lines number height of the text box
function text_helpers.centerText(ctx, text, line_width, lines)
    local total = 0

    local line_H = reaper.ImGui_GetTextLineHeightWithSpacing(ctx)
    local box_width, _ = reaper.ImGui_GetItemRectSize(ctx)
    local x_start, y_start = reaper.ImGui_GetItemRectMin(ctx)
    local x_end, y_end = reaper.ImGui_GetItemRectMax(ctx)

    reaper.ImGui_PushClipRect(ctx, x_start, y_start, x_end, y_end, false)

    local cur_str = ""
    local count = 0
    local cur_y = y_start
    for word in text:gmatch("%S+") do
        local word_width = reaper.ImGui_CalcTextSize(ctx, word .. " ")
        if total + word_width < line_width then
            if cur_str == "" then
                cur_str = word
            else
                cur_str = cur_str .. " " .. word
            end
            total = total + word_width
        else
            count = count + 1
            local str_w = reaper.ImGui_CalcTextSize(ctx, cur_str)
            local x_pos = x_start + box_width / 2 - str_w / 2
            reaper.ImGui_SetCursorScreenPos(ctx,
                x_pos,
                cur_y)

            cur_y = cur_y + line_H

            if count <= lines then
                reaper.ImGui_Text(ctx, cur_str)
            else
                break
            end
            cur_str = word
            total = reaper.ImGui_CalcTextSize(ctx, word .. " ")
        end
    end

    count = count + 1
    if cur_str ~= "" and count <= lines then
        local str_w = reaper.ImGui_CalcTextSize(ctx, cur_str)
        local x_pos = x_start + box_width / 2 - str_w / 2
        reaper.ImGui_SetCursorScreenPos(ctx,
            x_pos,
            cur_y)
        cur_y = cur_y + line_H
        reaper.ImGui_Text(ctx, cur_str)
    end
    reaper.ImGui_PopClipRect(ctx)
    return cur_y - y_start
end

function text_helpers.demo()
    local text =
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    local ctx = reaper.ImGui_CreateContext("wordwrap demo")
    reaper.ImGui_SetNextWindowSize(ctx, 1000, 400, reaper.ImGui_Cond_FirstUseEver())

    local window_flags =
        reaper.ImGui_WindowFlags_NoScrollWithMouse()
        + reaper.ImGui_WindowFlags_NoScrollbar()
        + reaper.ImGui_WindowFlags_NoCollapse()
        + reaper.ImGui_WindowFlags_NoNav()
    local function main()
        local visible, open = reaper.ImGui_Begin(ctx, "demo", true, window_flags)
        open = open
        if visible then
            reaper.ImGui_BeginChild(ctx, "child", 400, 200, false)
            local lines = 3
            local line_H = reaper.ImGui_GetTextLineHeight(ctx) * lines
            -- local line_H = reaper.ImGui_GetTextLineHeightWithSpacing(ctx) * lines
            local item_spacing = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
            reaper.ImGui_Button(ctx, "##btn", 200, line_H + item_spacing * (lines - 1))

            text_helpers.centerText(ctx, text, 200, lines)
            -- reaper.ShowConsoleMsg(line_H .. " " .. item_spacing .. "\n")
            reaper.ImGui_EndChild(ctx)
            reaper.ImGui_End(ctx)
        end

        if open then
            reaper.defer(function() main() end)
        end
    end
    main()
end

text_helpers.demo()
-- return text_helpers
