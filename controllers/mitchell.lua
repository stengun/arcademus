local mitchell = {}

---
--- This list contains a custom program used to call the routines that initialize and play custom tracks for OPLL.
--- This is needed because the Z80 also drives the OPLL chip. This patch needs some parameters that vary from
--- game to game (which are SP value, INIT call routine and PLAY call routine).
--- 
--- ld sp, $sp        ; sp is different between machines
--- ld a, $num        ; loads the track number
--- call $opll_init   ; calls the routine to init OPLL chip
--- call $opll_play   ; calls the routine to play the track number in A with OPLL
--- ld bc, $16FF      ; loads the song timing value. the higher the value, the slower the playback.
--- ldir              ; consumes cycles doinc BC - 1 until BC becomes 0
--- jr $-5            ; jump back to play routine.
--- 
local injected_opcodes = {
    0x31, 0x00, 0x00, 0x3E,  0x00, 0xCD, 0x00, 0x00,  0xCD, 0x00, 0x00, 0x01,
    0xFF, 0x17, 0xED, 0xB0,  0x18, 0xF6, 0x00, 0x00,
}

local games = {}
-- note: this format can be simplified to omit the first two params, mgakuen is the only reason they were added.
--- format: memory_space, offset, opll_init, opll_play, sp, stop_track, tracklist
games.pang      = { "opcodes", 0xF000, 0x7803, 0x7800, 0x0000, 63, }
games.spang     = { "opcodes", 0xF000, 0x7803, 0x7800, 0x0000, 64  }

games.mgakuen   = { "program", 0xEFE0, 0x7803, 0x7800, 0xEE40, 41   } -- this does not work properly

games.mgakuen2  = { "opcodes", 0xF000, 0x7803, 0x7800, 0xFC80, 0   }
games.pkladies  = games.mgakuen2
games.dokaben   = games.mgakuen2

games.block     = { "opcodes", 0xF000, 0x2AC2, 0x2ABF, 0xF880, 62  }
games.hatena    = { "opcodes", 0xF000, 0x76AD, 0x76AA, 0x0000, 95  }
games.cworld    = { "opcodes", 0xF000, 0x700C, 0x7009, 0xFAFF, 111 }
games.marukin   = { "opcodes", 0xF000, 0x7629, 0x7626, 0xF880, 0   }
games.qtono1    = { "opcodes", 0xF000, 0x7235, 0x7232, 0xFAC0, 63  }
games.qsangoku  = { "opcodes", 0xF000, 0x75CD, 0x75CA, 0xFAC0, 79  }


local tracklist = require("arcademus/structures/tracklist")
local memory
local cpu
local io
local program_counter_base
local game

local function inject()
    -- inject custom opcodes in a safe location inside ram.
    for _, val in pairs(injected_opcodes) do
        memory:write_i8((_ - 1) + program_counter_base, val)
    end
    --- populate custom parameters for the injected code
    local opll_init = game[3]
    local opll_play = game[4]
    local sp = game[5]
    memory:write_i8(program_counter_base + 0x0001, sp & 0xFF)
    memory:write_i8(program_counter_base + 0x0002, sp >> 8)
    memory:write_i8(program_counter_base + 0x0006, opll_init & 0xFF)
    memory:write_i8(program_counter_base + 0x0007, opll_init >> 8)
    memory:write_i8(program_counter_base + 0x0009, opll_play & 0xFF)
    memory:write_i8(program_counter_base + 0x000A, opll_play >> 8)
    ---
end

--- =================== Controller interface
function mitchell:play_raw(num)
    if(num >= 0x80) then
        io:write_i8(0x05, 0x40)
        io:write_i8(0x05, 0x80|(num & 0x7F))
        io:write_i8(0x05, 0x80)
    else
        memory:write_i8(program_counter_base + 0x0004, num & 0x7F)
        cpu.state["PC"].value = program_counter_base
    end
end

function mitchell:stop_raw()
    self:play_raw(game[6])
    self:play_raw(0x80)
end

function mitchell:init()
    game = games[self.running_system_name]
    if game == nil then
        game = games[self.parent_system_name]
    end
    cpu = manager.machine.devices[":maincpu"]
    memory = cpu.spaces[game[1]]
    io = cpu.spaces["io"]
    program_counter_base = game[2]

    inject()
end

return mitchell
