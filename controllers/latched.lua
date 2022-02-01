local latched = {}

local tracklist = require("arcademus/structures/tracklist")
local memory
local game
local audiocpu
local soundlatch

local cpu_hang = {}

cpu_hang["z80"] = function(base_address, watchdog_address)
    if base_address == nil then
        base_address = 0x0000
    end
    if watchdog_address ~= nil then
        -- when watchdog is present, we feed it so the machine will think we're working as expected.
        -- code injected:
        -- ld ($watchdog_address), a
        -- jp $base_address
        memory:write_i8(base_address, 0x32) -- LD (nn) a
        memory:write_i8(base_address + 1,  watchdog_address & 0xFF)
        memory:write_i8(base_address + 2, (watchdog_address >> 8) & 0xFF)
        memory:write_i8(base_address + 3, 0xC3)
        memory:write_i8(base_address + 4, base_address & 0xFF)
        memory:write_i8(base_address + 5, base_address >> 8)
    else
        -- code injected
        -- jp $base_address
        memory:write_i8(base_address, 0xC3)
        memory:write_i8(base_address + 1, base_address & 0xFF)
        memory:write_i8(base_address + 2, base_address >> 8)
    end
end

cpu_hang["m6502"] = function()
    --- Startup sequence responds to RESET instruction which will load
    --- the vector $FFFC/$FFFD in the program counter. We fetch that vector
    --- and put an invalid opcode in the entrypoint address to halt the cpu
    --- after it responds to RESET interrupts.
    local entry_point = 0xFFFF & (memory:read_i8(0xFFFD) << 8 | memory:read_i8(0xFFFC) & 0xFF)
    memory:write_i8(entry_point, 0x22)
end

cpu_hang["mc6809e"] = function()
    --- cpu entrypoint is fetched from $FFFE/$FFFF, the addres for the RESET interrupt routine
    local entrypoint = 0xFFFF & (memory:read_i8(0xFFFE) << 8 | memory:read_i8(0xFFFF) & 0xFF)
    --- Put a JMP $entry_point instruction in $entry_point, effectively hanging the cpu.
    memory:write_i8(entrypoint, 0x7E)
    memory:write_i8(entrypoint + 0x01, memory:read_i8(0xFFFE))
    memory:write_i8(entrypoint + 0x02, memory:read_i8(0xFFFF))
end

cpu_hang["m68000"] = function()
    --- cpu entrypoint is fetched from $0004/$0006, the addres for the RESET interrupt routine
    local entrypoint = 0xFFFFFFFF & (memory:read_i16(0x004) << 16 | memory:read_i16(0x006) & 0xFFFF)
    --- Put a JMP $entry_point instruction in $entry_point, effectively hanging the cpu.
    memory:write_i16(entrypoint, 0x4EF9)
    memory:write_i16(entrypoint + 0x02, memory:read_i16(0x004))
    memory:write_i16(entrypoint + 0x04, memory:read_i16(0x006))
end

local function set_audiocpu_nmi_pending()
    if audiocpu.shortname == "z80" then
        emu.item(audiocpu.items["0/m_nmi_pending"]):write(0x00, 0x01)
    elseif audiocpu.shortname == "deco222" then
        emu.item(audiocpu.items["0/nmi_pending"]):write(0x00, 0x01)
    end
end

local games = {}
-- format: stop_track_index, (opt) latch device name, base address for cpu_hang, watchdog_address for cpu_hang
games["1942"] = { 0x10 } -- two kinds of stop track here. 0x00 for sound effects, 0x10 for music.
games["1943"] = { 0x00 }
games["1943kai"] = games["1943"]
games.pcktgal = { 50 }
games.sidepckt = { 29 }
games.karnov = { 28 }
games.robocop = { 0 }
games.commando = { 0xFC, nil, 0x0005 }
games.congo = { 0x00 }
games.bublbobl = { 0x00, ":main_to_sound", 0x01AA, 0xFA80 }
games.tokio = { 0x00, ":main_to_sound", 0x003E, 0xFA00 }
-- games.ixion = { ":maincpu", "program", z80_hang, 0xe03c, 0x00 }

--- ================ Controller interface
function latched:init()
    game = games[self.running_system_name]
    if game == nil then
        game = games[self.parent_system_name]
    end
    memory = manager.machine.memory.regions[":maincpu"]
    if game == nil then
        cpu_hang[manager.machine.devices[":maincpu"].shortname]()
        soundlatch = manager.machine.devices[":soundlatch" ]
    else
        local base_address = game[3] == nil and nil or game[3]
        local watchdog_address = game[4] == nil and nil or game[4]
        cpu_hang[manager.machine.devices[":maincpu"].shortname](base_address, watchdog_address)
        soundlatch = manager.machine.devices[game[2] == nil and ":soundlatch" or game[2]]
    end
    audiocpu = manager.machine.devices[":audiocpu"]
end

function latched:play_raw(num)
    emu.item(soundlatch.items["0/m_latched_value"]):write(0x00, num & 0x7F)
    set_audiocpu_nmi_pending()
end

function latched:stop_raw()
    self:play_raw(game ~= nil and game[1] or 0x00)
end

return latched
