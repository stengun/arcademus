local arkanoid = {}
--- TODO: find clones routines to init and play audio.
--- Since arkanoid uses the main cpu to also drive audio chips, this injected code is similar to the one used for mitchell games.
--- Unlike mitchell games, arkanoid also has a watchdog that needs to be properly reset every now and then.
--- Watchdog is reset by writing a value in 0xD010
--- Waiting using a magic number is not very accurate since the timing is calculated by hand, but is acceptable.

--- ================= Injected code
--- ld sp, $C0C0      ; this sp value is needed for the call 0x15BE to make it work.
--- ld a, $FF         ; loads the track number in a
--- call $67AE        ; calls the routine to init OPLL chip
--- call $6792        ; calls the routine to play the track number in A with OPLL
--- call $15BE        ; calls a routine that cleans ram and/or video memory. Without this the code works but video will show garbage
--- ld bc, $108D      ; We load a value in bc used to wait for the right amount of cycles before calling audio_play again
--- ld ($D010), bc    ; Reset watchdog
--- ldir              ; consumes cycles doinc BC - 1 until BC becomes 0
--- jr $-16           ; jump back to play routine

local injected_opcodes = {
    0x31, 0xC0, 0xC0,             -- sp init
    0x3E, 0xFF,                   -- ld track number in A
    0xCD, 0xAE, 0x67,             -- call audio_init routine
    0xCD, 0x92, 0x67,             -- call audio_play routine
    0xCD, 0xBE, 0x15,             -- call cleanup routine
    0x01, 0x8D, 0x10,             -- ld 0x108D in BC
    0xED, 0x43, 0x10, 0xD0,       -- watchdog reset
    0xED, 0xB0,                   -- jump in place 108D times, timing to call audio_play tick callback
    0x18, 0xEF                    -- go back -16 bits (audio_play tick)
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
    self.tracklist = tracklist.new("taito/arkanoid.dat")
    cpu.state["PC"].value = base_ram_address
end


function arkanoid:play_raw(num)
    memory:write_i8(base_ram_address + 0x0004, num & 0x7F)
    cpu.state["PC"].value = base_ram_address
end

function arkanoid:stop_raw()
    memory:write_i8(base_ram_address + 0x0004, 0x00)
    cpu.state["PC"].value = base_ram_address
end

return arkanoid
