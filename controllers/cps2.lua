local cps2 = {}

--- Technically, the method used in CPS2 to play music works the same as in CPS1+QSound,
--- but since main cpu opcodes are encrypted I can't reuse that method.
--- Instead of injecting our code we directly write in the shared ram of the Z80. 
--- To do this, we leverage our tick function to initialize qsound.
--- Also, since the main cpu cannot have any code injected, 
--- I overwrite its program counter every frame in a tick function.
--- All of this sucks, but it's the only way to make it work.
--- 
--- Also, the script's funcionality is present in the system's service mode.

local maincpu
local audiocpu
local audiocpu_memory
local maincpu_memory

local initialized = false
local qram_address = 0xc000

----- ==========
function cps2:init()
    maincpu = manager.machine.devices[":maincpu"]
    audiocpu = manager.machine.devices[":audiocpu"]
    audiocpu_memory = audiocpu.spaces["program"]
    maincpu_memory = maincpu.spaces["program"]
end

function cps2:play_raw(num)
    audiocpu_memory:write_i8(qram_address, (num >> 8) & 0xFF)
    audiocpu_memory:write_i8(qram_address + 0x01, num & 0xFF)
    audiocpu_memory:write_i8(qram_address + 0x07, 0x10) -- panpot center
    audiocpu_memory:write_i8(qram_address + 0x0F, 0x00)
    maincpu.state["PC"].value = 0x200
end

function cps2:stop_raw()
    cps2:play_raw(0xFF00)
end

function cps2:tick_impl()
    if not initialized and (audiocpu_memory:read_i8(qram_address + 0x0FFF) == 0x77 ) then
        audiocpu_memory:write_i8(qram_address + 0x0FFD, 0x88)
        audiocpu_memory:write_i8(qram_address + 0x0FFE, 0xFF)
        audiocpu_memory:write_i8(qram_address + 0x0FFF, 0xFF)
        initialized = true
    end
    if initialized then
        maincpu.state["PC"].value = 0x200
    end
end

return cps2
