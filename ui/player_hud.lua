---
--- User interface drawer. The exported table has to be initialized with a controller
--- to be fully functional using the :init(controller) method.
--- Register method :draw_frame() inside your drawing tick function to draw it.
---

-- there are a lot of magic numbers in this file and that's bad.
-- probably all of this stuff can be reimplemented using mame layouts.

require("arcademus/keyboard_events")

local hud = {
    controller = nil,
    list_hovered = 1,
    base_wave_directory = nil
}

local screen

local listmin = 1
local listmax = 12
local raw_value = 0
local raw_mode = false

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

local function hex_to_string(n)
    return string.format("0x%02X", n)
end
-- ================

local function draw_raw_selector()
    local x, y, x_end, y_end = screen.width * 0.5 + 5, 5, screen.width - 5, screen.height * 0.5 - 5
    screen:draw_box(x, y, x_end, y_end)
    local x_center = x + (x_end - x) * 0.5 - 26
    local y_center = y + (y_end - y) * 0.5 - 26
    draw_text(x + 8, y + 3, "Raw value selector")
    draw_text(x_center, y_center, string.format("\
           -16\
            %s\
 -1 %s %s %s +1\
            %s\
           +16\
    ", "▲", "◄", hex_to_string(raw_value), "►", "▼"))

end

local function draw_tracklist()
    local current_track = hud.controller.current_track
    local total = hud.controller:track_total()
    local playing = hud.controller.playing
    local recording = manager.machine.sound.recording
    local x, y, x_end, y_end = screen.width * 0.5 + 5, 5, screen.width - 5, screen.height * 0.5 - 5
    screen:draw_box(x, y, x_end, y_end)
    -- list header
    draw_text(x + 3, y + 1, "Track List")
    draw_text(x_end - 28, y + 1, string.format("%2.2d/%d", hud.list_hovered, total))
    -- scrollbar
    if listmin > 1 then
        draw_text(x_end - 8, y, "▲")
    end
    if listmax < total then
        draw_text(x_end - 8, y_end - 8, "▼")
    end
    screen:draw_box(x_end - 6, y + 8, x_end - 3, y_end - 8)
    if listmax <= total then
        screen:draw_box(x_end - 6, y + 7 + listmin, x_end - 3, y_end - 8 - (total - listmax), 0xFFFFFFFF, 0xFFFFFFFF)
    end

    for idx, track in pairs(hud.controller.tracklist) do
        if idx >= listmin and idx <= listmax then
            local cury = y + 10 + (idx - listmin) * 8
            screen:draw_line(x + 3, cury, x_end - 10, cury)
            if idx - listmin + 1 > 1 then
            end

            local entry_string = "%2.2d - %s %s"
            local symbol = ""
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
                draw_text_hovered(x + 3, cury, entry_string, text_color)
            else
                draw_text(x + 3, cury, entry_string, text_color)
            end
        end
    end
end

local function draw_info()
    if not hud.controller then
        return
    end
    local x, y, x_end, y_end = 5, 5, screen.width * 0.5 - 5, screen.height * 0.5 - 5
    screen:draw_box(x, y, x_end, y_end)

    local current_track = hud.controller.current_track
    if #hud.controller.tracklist > 0 then
        local trackinfo = hud.controller:track_info(current_track)
        draw_text(x + 3, 8, string.format(
                "Current track: %d - Raw: %d - Total: %d",
                current_track,
                trackinfo.value,
                hud.controller:track_total()))
        draw_text(x + 3, 18, trackinfo.name)
    else
        draw_text(x + 3, 8, "Current track (Raw): " .. current_track)
    end
    if manager.machine.sound.recording then
        draw_text(x + 3, 28, "RECORDING", 0xffff0000)
    end
    local info_format = "Controls:\
    S - Stop track     Enter - Play track\
    R - Record track\
    Up/Down/Left/Right - Move Cursor"
    draw_text(x + 3, y_end - 36, info_format, 0xFF888800)
end

-- =================== external interface
function hud:init(controller)
    self.controller = controller

    raw_mode = not self.controller.tracklist or #self.controller.tracklist == 0
    screen = manager.machine.screens[":screen"]

    -- Register callbacks for UI input
    keyboard_events.register_key_event_callback(
            "KEYCODE_UP", -- scroll list up / sub 16 to raw alue
            function(event)
                if event == "pressed" then
                    if not raw_mode then
                        hud.list_hovered = math.max(1, hud.list_hovered - 1)
                        if hud.list_hovered < listmin then
                            listmin = listmin - 1
                            listmax = listmax - 1
                        end
                    else
                        raw_value = math.max(0, raw_value - 16)
                    end
                end end)
    keyboard_events.register_key_event_callback(
            "KEYCODE_DOWN", -- scroll list down / add 16 to raw value
            function(event)
                if event == "pressed" then
                    if not raw_mode then
                        hud.list_hovered = math.min(hud.controller:track_total(), hud.list_hovered + 1)
                        if hud.list_hovered > listmax then
                            listmin = listmin + 1
                            listmax = listmax + 1
                        end
                    else
                        raw_value = math.min(0xFF, raw_value + 16)
                    end
                end end)
    keyboard_events.register_key_event_callback(
            "KEYCODE_LEFT", -- sub 1 to raw value
            function(event)
                if event == "pressed" then
                    raw_value = math.max(0, raw_value - 1)
                end end)
    keyboard_events.register_key_event_callback(
            "KEYCODE_RIGHT", -- add 1 to raw value
            function(event)
                if event == "pressed" then
                    raw_value = math.min(0xFF, raw_value + 1)
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
    if not self.controller then
        return
    end

    if not screen then
        screen = manager.machine.screens[":screen"]
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
