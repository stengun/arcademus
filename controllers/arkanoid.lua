local arkanoid = {}
--- TODO: find clones routines to init and play audio.
--- TODO: merge mitchell and arkanoid in a common controller.
--- Arkanoid and mitchell boards share the fact that the main cpu also drives the audio chip. Due to this, the code is basically the same.
--- 
--- ================= Injected code
--- di                ; disable interrupts
--- ld sp, $C0C0      ; this sp value is needed. otherwise ram reset in vblank will destroy the program
--- ld a, $00         ; loads the track number in a
--- call $67AE        ; calls the routine to init OPLL chip
--- ei                ; enable interrupts
--- jr $-1            ; jump back to ei

local injected_opcodes = {
    0xF3,                         -- di
    0x31, 0xC0, 0xC0,             -- sp init
    0x3E, 0x00,                   -- ld track number in A
    0xCD, 0xAE, 0x67,             -- call audio_init routine
    0xFB,                         -- ei
    0x18, 0xFD                    -- go back to ei
}

local tracklist = require("arcademus/structures/tracklist")
local base_ram_address = 0xE840
local memory
local cpu

local function inject()
    for _, val in pairs(injected_opcodes) do
        memory:write_i8((_ - 1) + base_ram_address, val)
    end
end

--- ======
function arkanoid:init()
    cpu = manager.machine.devices[":maincpu"]
    memory = cpu.spaces["program"]
    inject()
    cpu.state["PC"].value = base_ram_address
end


function arkanoid:play_raw(num)
    memory:write_i8(base_ram_address + 0x0005, num & 0x7F)
    cpu.state["PC"].value = base_ram_address
end

function arkanoid:stop_raw()
    memory:write_i8(base_ram_address + 0x0005, 0x00)
    cpu.state["PC"].value = base_ram_address
end

return arkanoid
