local taito = {}

--- Taito games have a watchdog, this watchdog needs to be refreshed to avoid a complete machine reset.
--- The base address used to inject the "loop" code is chosen by detecting when the machine has ended its
--- initialization, so we have all the cpus ready to be used.
--- This code is not injected into ram because we need to initialize the entire machine before
--- we stuck the main cpu, so the best way to do it is modifying the main program rom region.
--- ===== injected code
--- ld ($watchdog_addr), a    ; we reset the watchdog
--- jr $-4                    ; jump to watchdog reset (4 bits back)

local games = {}
-- format:  base_address  watchdog_address  main_to_sound_address  tracklist_file(optional)
games.bublbobl = { 0x01AA, 0xFA80, 0xFA00, "taito/bublbobl.dat"}
games.tokio    = { 0x003E, 0xFA00, 0xFC00}

local tracklist = require("arcademus/structures/tracklist")
local maincpu
local memory
local game

local function inject()
    local base_addr = game[1]
    local watchdog_addr = game[2]
    manager.machine.memory.regions[":maincpu"]:write_i8(base_addr, 0x32) -- LD (nn) a
    manager.machine.memory.regions[":maincpu"]:write_i8(base_addr + 0x0001,  watchdog_addr & 0xFF)
    manager.machine.memory.regions[":maincpu"]:write_i8(base_addr + 0x0002, (watchdog_addr >> 8) & 0xFF)
    manager.machine.memory.regions[":maincpu"]:write_i8(base_addr + 0x0003, 0x18) -- JR -4
    manager.machine.memory.regions[":maincpu"]:write_i8(base_addr + 0x0004, 0xFB)
end

--- ===================================
function taito:play_raw(num)
    memory:write_i8(game[3], num)
end

function taito:stop_raw()
    memory:write_i8(game[3], 00)
end

function taito:init()
    game = games[self.running_system_name]
    if game == nil then
        game = games[self.parent_system_name]
    end
    maincpu = manager.machine.devices[":maincpu"]
    memory = maincpu.spaces["program"]
    inject()
    self.tracklist = tracklist.new(game[4])
end

return taito
