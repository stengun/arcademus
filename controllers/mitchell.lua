local mitchell = {}

---
--- On mitchell boards the main z80 cpu also drives the OPLL audio chip.
--- To make sure that audio chip data feed routine gets called at the right rate we inject a small program into ram that
--- initializes the OPLL chip and loops, while enabling cpu interrupts.
--- The interrupt routine calls vblank stuff and also opll data feed routine.
--- To send a specific track we modify the injected program to call $opll_init with the chosen track number, then
--- we reset cpu program counter to the start of this small program.
--- Every game has a different $opll_init address and stop_track.

--- Injected assembly:
--- di
--- ld a, $track_num
--- call $opll_init
--- ei
--- jr $-1

local injected_opcodes = {
    0xF3, 0x3E, 0x00, 0xCD, 0x00, 0x00, 0xFB, 0x18, 0xFD
}

local games = {}

--- format:     opll_init, stop_track

games.pang      = { 0x7803, 63, }
games.spang     = { 0x7803, 64  }

games.mgakuen   = { 0x7803, 0   }
games.mgakuen2  = games.mgakuen
games.pkladies  = games.mgakuen
games.dokaben   = games.mgakuen

games.block     = { 0x2AC2, 62  }
games.hatena    = { 0x76AD, 95  }
games.cworld    = { 0x700C, 111 }
games.marukin   = { 0x7629, 0   }
games.qtono1    = { 0x7235, 63  }
games.qsangoku  = { 0x75CD, 79  }


local tracklist = require("arcademus/structures/tracklist")
local memory
local cpu
local io
local program_counter_base = 0xF200
local game

local function inject()
    -- inject custom opcodes in a safe location inside ram.
    for _, val in pairs(injected_opcodes) do
        memory:write_i8((_ - 1) + program_counter_base, val)
    end
    --- populate custom parameters for the injected code
    local opll_init = game[1]
    memory:write_i8(program_counter_base + 0x0004, opll_init & 0xFF)
    memory:write_i8(program_counter_base + 0x0005, opll_init >> 8)
    ---
end

--- =================== Controller interface
function mitchell:play_raw(num)
    if(num >= 0x80) then
        io:write_i8(0x05, 0x40)
        io:write_i8(0x05, num)
        io:write_i8(0x05, 0x80)
    else
        memory:write_i8(program_counter_base + 0x0002, num & 0x7F)
        cpu.state["PC"].value = program_counter_base
    end
end

function mitchell:stop_raw()
    self:play_raw(game[2])
    self:play_raw(0x80)
end

function mitchell:init()
    game = games[self.running_system_name]
    if game == nil then
        game = games[self.parent_system_name]
    end
    cpu = manager.machine.devices[":maincpu"]
    memory = cpu.spaces["program"]
    io = cpu.spaces["io"]

    inject()
    self.vgmlogger:add_chip(manager.machine.devices[":ymsnd"], 0, io, 0x03, 0x04)
    -- self.vgmlogger:add_chip(manager.machine.devices[":oki"], io, 0x05, 0x05) -- This oki is driven by the lua script, logger will not work properly.
end

return mitchell
