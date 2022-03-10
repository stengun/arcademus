-- Arcade music player, inspired by the program m1 from Richard Bannister.
-- This software is free software, licensed under the terms of the GPL License v3.
-- Author: stengun <robenfatto@covolunablu.org>
--
local arcademus = {
    name = "arcademus",
    version = "0.0.2",
    description = "Game music player",
    license = "GPLv3",
    author = { name = "stengun", email = "robenfatto@covolunablu.org" },
}

local function get_save_path()
    return emu.subst_env(manager.options.entries.homepath:value():match('([^;]+)')) .. '/arcademus'
end

-- MAME plugin interface
function arcademus.startplugin()
    local save_path = get_save_path()
    local attr = lfs.attributes(save_path)
    if not attr then
        lfs.mkdir(save_path)
    elseif attr.mode ~= "directory" then
        emu:print_info("Cannot open save path, recording will not work.")
        save_path = nil
    end

    require("arcademus/keyboard_events")
    local player = require("arcademus/ui/player_hud")
    player.base_wave_directory = save_path
    local controller
    local dat_filename = "arcademus.dat"

    local function machine_start()
        if manager.machine.system.name == "___empty" then
            return
        end
        local ancestor_system = manager.machine.system
        while ancestor_system.parent ~= "0" do
            ancestor_system = emu.driver_find(ancestor_system.parent)
        end
        -- parsing kinda borrowed from hiscore plugin. Thanks
        local file = io.open( manager.plugins[arcademus.name].directory .. "/" .. dat_filename, "r" );
        if file then
            local current_is_match = false;
            repeat
                line = file:read("*l");
                if line then
                    -- remove comments
                    line = line:gsub( '[ \t\r\n]*;.+$', '' );
                    -- handle lines
                    if current_is_match and string.find(line, '^@') then -- data line
                        local modulename = string.match(line, '^@([^,]+)')
                        controller = require("arcademus/structures/controller").new(modulename)
                        break;
                    elseif string.match(line, ancestor_system.name .. ':') then --- match this game
                        current_is_match = true;
                    end
                end
            until not line;
            file:close();
        end

        if not controller then
            if manager.machine.devices[":soundlatch"] ~= nil then
                controller = require("arcademus/structures/controller").new("latched")
                player:init(controller)
                return
            end
            return
        end
        player:init(controller)
    end

    local function tick()
        if controller then
            controller:tick()
        end
        keyboard_events.poll()
    end

    local function frame_done()
        player:draw_frame()
    end

    local function pre_reset()
        keyboard_events.reset_bindings()
    end
    
    emu.register_start(machine_start)
    emu.register_frame(tick)
    emu.register_frame_done(frame_done, "frame")
    emu.register_prestart(pre_reset)
end

return arcademus
