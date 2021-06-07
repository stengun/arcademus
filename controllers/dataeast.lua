local dataeast = {}

local tracklist = require("arcademus/structures/tracklist")
local cpu
local memory
local cpu_space
local game

local function mos6502_hang()
    --- Startup sequence responds to RESET instruction which will load
    --- the vector $FFFC/$FFFD in the program counter. We fetch that vector
    --- and put an invalid opcode in the entrypoint address to halt the cpu
    --- after it responds to RESET interrupts.
    local entry_point = 0xFFFF & (memory:read_i8(0xFFFD) << 8 | memory:read_i8(0xFFFC) & 0xFF)
    memory:write_i8(entry_point, 0x22)
end

local function mc6809E_hang()
    --- cpu entrypoint is fetched from $FFFE/$FFFF, the addres for the RESET interrupt routine
    local entrypoint = 0xFFFF & (memory:read_i8(0xFFFE) << 8 | memory:read_i8(0xFFFF) & 0xFF)
    --- Put a JMP $entry_point instruction in $entry_point, effectively hanging the cpu.
    memory:write_i8(entrypoint, 0x7E)
    memory:write_i8(entrypoint + 0x01, memory:read_i8(0xFFFE))
    memory:write_i8(entrypoint + 0x02, memory:read_i8(0xFFFF))
end

local function mc68000_hang()
    --- cpu entrypoint is fetched from $0004/$0006, the addres for the RESET interrupt routine
    local entrypoint = 0xFFFFFFFF & (memory:read_i16(0x004) << 16 | memory:read_i16(0x006) & 0xFFFF)
    --- Put a JMP $entry_point instruction in $entry_point, effectively hanging the cpu.
    memory:write_i16(entrypoint, 0x4EF9)
    memory:write_i16(entrypoint + 0x02, memory:read_i16(0x004))
    memory:write_i16(entrypoint + 0x04, memory:read_i16(0x006))
end

local games = {}
-- format: cpu_tag, cpu_space, hang_function, sound_w_address, stop_track_index, (opt) tracklist_file
games.pcktgal = { ":maincpu", "program", mos6502_hang, 0x1A00, 50, "dataeast/pcktgal.dat" }
games.sidepckt = { ":maincpu", "program", mc6809E_hang, 0x3004, 29, }
games.karnov = { ":maincpu", "program", mc68000_hang, 0xc0003, 28, }
games.robocop = { ":maincpu", "program", mc68000_hang, 0x30c015, 0, }

--- ================ Controller interface
function dataeast:init()
    game = games[self.running_system_name]
    if game == nil then
        game = games[self.parent_system_name]
    end
    cpu = manager.machine.devices[game[1]]
    memory = manager.machine.memory.regions[game[1]]
    cpu_space = cpu.spaces[game[2]]
    game[3]()
    self.tracklist = tracklist.new(game[6])
end

function dataeast:play_raw(num)
    cpu_space:write_i8(game[4], num & 0x7F)
end

function dataeast:stop_raw()
    self:play_raw(game[5])
end

return dataeast
