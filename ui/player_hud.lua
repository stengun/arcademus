---
--- User interface drawer. The exported table has to be initialized with a controller
--- to be fully functional using the :init(controller) method.
--- Register method :draw_frame() inside your drawing tick function to draw it.
---

require("arcademus/keyboard_events")

local hud = {
    controller = nil,
    list_hovered = 1,
    base_wave_directory = nil
}

local screen
-- =====
local raw_value = 0
local raw_mode = false
local listmin = 1
local listmax = 1

-- text draw helpers
local function draw_text_hovered(x, y, text, color)
    if not color then
        color = 0xFFFFFFFF
    end
    screen:draw_text(x, y, text, color, 0x88FFFF00)
end

local function draw_text(x, y, text, color)
    if not color then
        color = 0xFFFFFFFF
    end
    screen:draw_text(x, y, text, color, 0x00000000)
end

local function draw_titled_box(x, y, x_end, y_end, title)
    screen:draw_box(x, y, x_end, y_end)
    draw_text(x + 0.01, y + 0.01, title)
end

-- ================

local function draw_raw_selector()
    local x, y, x_end, y_end = 0.51, 0.05, 0.95, 0.46
    local margin_x, margin_y = 0.01, 0.01
    draw_titled_box(x, y, x_end, y_end, "Raw value selector")

    local entry_string = "%s hex: 0x%02X - dec: %d"
    local symbol = "-"
    local text_color
    if raw_value == hud.controller.current_track then
        if manager.machine.sound.recording then
            symbol = "●"
            text_color = 0xFFFF0000
        elseif hud.controller.playing then
            symbol = "►"
            text_color = 0xFF00FF00
        end
    end
    draw_text(x + margin_x, y + margin_y + manager.ui.line_height, string.format(entry_string, symbol, raw_value, raw_value), text_color)
    draw_text(x + margin_x, y_end - margin_y - manager.ui.line_height, "+16 ▲▼ -16  -1 ◄► +1", 0xFF888888) -- grayed out text
end

local function draw_tracklist()
    local x, y, x_end, y_end = 0.51, 0.05, 0.95, 0.46
    local margin_x, margin_y = 0.01, 0.01
    draw_titled_box(x, y, x_end, y_end, "Track List")

    local current_track = hud.controller.current_track
    local total = hud.controller:track_total()
    local playing = hud.controller.playing
    local recording = manager.machine.sound.recording
    local line_height = manager.ui.line_height
    local char_width = manager.ui:get_string_width("▲", 1.0)
    local navigation_text = string.format("%2.2d/%d", hud.list_hovered, total)
    draw_text(x_end - margin_x - manager.ui:get_string_width(navigation_text, 1.0), y + margin_y, navigation_text)

    local list_entries = math.floor((y_end - y) / line_height) - 2
    if hud.list_hovered > listmax then
	   listmax = hud.list_hovered
	   listmin = listmax - list_entries
    elseif hud.list_hovered <= listmin then
       listmin = hud.list_hovered
       listmax = listmin + list_entries
    end
    -- scrollbar
    if listmin > 1 then
        draw_text(x_end - margin_x - char_width, y + margin_y + line_height, "▲")
    end
    if listmax < total then
        draw_text(x_end - margin_x - char_width, y_end - margin_y - line_height, "▼")
    end
    local scrollbar_start_y = y + margin_y + line_height * 2
    local scrollbar_end_y = y_end - margin_y - line_height
    local scrollbar_len = scrollbar_end_y - scrollbar_start_y
    screen:draw_box(x_end - margin_x - char_width, scrollbar_start_y, x_end - margin_x, scrollbar_end_y) -- empty box
    if listmax <= total then
        screen:draw_box(
            x_end - margin_x - char_width,
            scrollbar_start_y + ((listmin - 1) / (total - 1)) * scrollbar_len,
            x_end - margin_x,
            scrollbar_start_y + ((listmax - 1) / (total - 1)) * scrollbar_len,
            0xFFFFFFFF,
            0xFFFFFFFF)
    end
    -- ==============
    for idx, track in pairs(hud.controller.tracklist) do
        if idx >= listmin and idx <= listmax then
            local cury = y + margin_y + ((idx - listmin + 1) * line_height)
            screen:draw_line(x + margin_x, cury, x_end - margin_x * 2 - char_width, cury)

            local entry_string = "%2.2d %s %s"
            local symbol = "-"
            local text_color
            if idx == current_track then
                if recording then
                    symbol = "●"
                    text_color = 0xFFFF0000
                elseif playing then
                    symbol = "►"
                    text_color = 0xFF00FF00
                end
            end
            entry_string = string.format(entry_string, idx, symbol, track.name)
            if idx == hud.list_hovered then
                draw_text_hovered(x + margin_x, cury, entry_string, text_color)
            else
                draw_text(x + margin_x, cury, entry_string, text_color)
            end
        end
    end
end

local function draw_info()
    if not hud.controller then
        return
    end
    local x, y, x_end, y_end = 0.05, 0.05, 0.49, 0.46
    draw_titled_box(x, y, x_end, y_end, "Track info:")
    local margin_x, margin_y = 0.01, 0.01
    local text_height = manager.ui.line_height
    local current_track = hud.controller.current_track
    local playing = hud.controller.playing

    if not raw_mode then
        local trackinfo = hud.controller:track_info(playing and current_track or hud.list_hovered)
        draw_text(x + margin_x,
                    y + margin_y + text_height,
                    string.format(
                        "Title: %s\nhex: 0x%02X - dec: %d",
                        trackinfo.name,
                        trackinfo.value,
                        trackinfo.value))
    else
        draw_text(x + margin_x, y + margin_y + text_height, string.format("\nhex: 0x%02X - dec: %d", current_track, current_track))
    end
    if manager.machine.sound.recording then
        draw_text(x + margin_x, y + margin_y + text_height * 3, "Recording", 0xFFFF0000)
    elseif playing then
        draw_text(x + margin_x, y + margin_y + text_height * 3, "Playing", 0xFF00FF00)
    end
    local info_format = "Controls:\
    S - Stop track\
    Enter - Play track\
    R - Record track\
    Arrows - Move Cursor"
    draw_text(x + margin_x, y_end - margin_y - text_height * 5, info_format, 0xFF888800)
end

-- =================== external interface
function hud:init(controller)
    self.controller = controller
    raw_mode = not self.controller.tracklist or #self.controller.tracklist == 0
    screen = manager.machine.render.ui_container
    -- Register callbacks for UI input
    keyboard_events.register_key_event_callback(
            "KEYCODE_UP", -- scroll list up / sub 16 to raw alue
            function(event)
                if event == "pressed" or event == "pressed_repeat" then
                    if not raw_mode then
                        hud.list_hovered = math.max(1, hud.list_hovered - 1)
                    else
                        raw_value = math.max(0, raw_value + 16) & 0xFF
                    end
                end end)
    keyboard_events.register_key_event_callback(
            "KEYCODE_DOWN", -- scroll list down / add 16 to raw value
            function(event)
                if event == "pressed" or event == "pressed_repeat" then
                    if not raw_mode then
                        hud.list_hovered = math.min(hud.controller:track_total(), hud.list_hovered + 1)
                    else
                        raw_value = math.min(0xFF, raw_value - 16) & 0xFF
                    end
                end end)
    keyboard_events.register_key_event_callback(
            "KEYCODE_LEFT", -- sub 1 to raw value
            function(event)
                if event == "pressed"  or event == "pressed_repeat" then
                    raw_value = math.max(0, raw_value - 1) & 0xFF
                end end)
    keyboard_events.register_key_event_callback(
            "KEYCODE_RIGHT", -- add 1 to raw value
            function(event)
                if event == "pressed" or event == "pressed_repeat" then
                    raw_value = math.min(0xFF, raw_value + 1) & 0xFF
                end end)
    keyboard_events.register_key_event_callback(
            "KEYCODE_ENTER", -- Play current track
            function(event)
                if event == "pressed" then
                    if raw_mode then
                        hud.controller:play(raw_value)
                    else
                        hud.controller:play(hud.list_hovered)
                    end
                end end)
    keyboard_events.register_key_event_callback(
            "KEYCODE_S", -- Stop current track (and stop recording too)
            function(event)
                if event == "pressed" then
                    hud.controller:stop()
                end end)
    keyboard_events.register_key_event_callback(
            "KEYCODE_R", -- Play and record wav
            function(event)
                if event == "pressed" then
                    if not self.base_wave_directory then
                        return
                    end
                    if raw_mode then
                        hud.controller:record(raw_value, self.base_wave_directory)
                    else
                        hud.controller:record(hud.list_hovered, self.base_wave_directory)
                    end
                end end)
end

function hud:draw_frame()
    if not self.controller or manager.ui.menu_active then
        return
    end

    if raw_mode then
        draw_raw_selector()
    else
        draw_tracklist()
    end
    draw_info()
end

return hud
