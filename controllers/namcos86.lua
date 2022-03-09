--- This board is pretty simple, it uses shared memory to communicate with music mcu.
--- To play BGM, main cpu writes in 0x1380. To play sound effects, maincpu writes 1 or 0 starting from 0x1285 + sound effect number (8 bit data).
--- This effectively makes the shared ram a flag vector 0x20 - 0x40 long.
--- To have a common convention, we consider all track numbers above 0x100 as sound effect values, the effective value will be the its last 8 bits.

local namcos86 = {}

local memory

function namcos86:init()
    local cpu1_memory = manager.machine.memory.regions[":cpu1"]
    --- Borrowed from latched cpu hanger for m6809e. TODO write a common cpu hang lib.
    local entrypoint = 0xFFFF & (cpu1_memory:read_i8(0xFFFE) << 8 | cpu1_memory:read_i8(0xFFFF) & 0xFF)
    --- Put a JMP $entry_point instruction in $entry_point, effectively hanging the cpu.
    cpu1_memory:write_i8(entrypoint, 0x7E)
    cpu1_memory:write_i8(entrypoint + 0x01, cpu1_memory:read_i8(0xFFFE))
    cpu1_memory:write_i8(entrypoint + 0x02, cpu1_memory:read_i8(0xFFFF))
    ---
    memory = manager.machine.devices[":mcu"].spaces["program"]
end

function namcos86:play_raw(num)
    if num >= 0x100 then
        --- we play a sound effect.
        memory:write_i8(0x1285 + (num & 0xFF), 1)
        return
    end
    memory:write_i8(0x1380, num & 0xFF)
end

function namcos86:stop_raw()
    if self.current_track >= 0x100 then
        memory:write_i8(0x1285 + (self.current_track & 0xFF), 0) 
        return
    end
    self:play_raw(0x00)
end

return namcos86
