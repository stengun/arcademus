local btoads = {}

--- data is
--- len, rom_ptr
local track_data = {
    0x9b5, 0x7708f8,
    0x1464, 0x7712b4,
    0x76c, 0x77271a,
    0x100d, 0x772e88,
    0x11d1, 0x773e9c,
    0x1072, 0x775070,
    0x1072, 0x775070,
    0x1072, 0x775070,
    0x1072, 0x775070,
}

local initialized = false
local cmdqueue = require("arcademus/structures/cmdqueue").new()
local maincpu
local maincpu_memory
local rom

local function hex_to_string(n)
    return string.format("0x%02X", n)
end
----- ==================
function btoads:tick_impl()
    if initialized then
        local cmd = cmdqueue:get_next()
        if cmd then
            -- print(string.format("0x%02X", cmd))
            -- maincpu_memory:write_i8(0x20000380, cmd) -- latch memory address
            emu.item(manager.machine.devices[":"].items["0/m_main_to_sound_data"]):write(0x00, cmd & 0xF0 >> 8)
            emu.item(manager.machine.devices[":"].items["0/m_main_to_sound_ready"]):write(0x00, 0x01)
            emu.item(manager.machine.devices[":"].items["0/m_main_to_sound_data"]):write(0x00, cmd & 0x0F)
            emu.item(manager.machine.devices[":"].items["0/m_main_to_sound_ready"]):write(0x00, 0x01)
        end
        emu.item(manager.machine.devices[":"].items["0/m_main_to_sound_ready"]):write(0x00, 0x00)
        emu.item(manager.machine.devices[":"].items["0/m_main_to_sound_ready"]):write(0x00, 0x01)
        maincpu.state["PC"].value = 0xFFFFFFFF
    end
end

function btoads:play_raw(num)
    cmdqueue:reset_queue()
    if num > 9 or num < 1 then
        return
    end
    local len = track_data[num * 2 - 1] + 1
    local ptr = track_data[num * 2]
    for i = 0, len do
        local word = (rom:read_i8(ptr + i) & 0xFF) | (rom:read_i8(ptr + i + 1) & 0xFF) << 8
        cmdqueue:push_command(word)
    end
    cmdqueue.postfix = {0x0001, 0x0300, 0x0003, 0x0100, 0x0101, 0x0101, 0x0101, 0x0001}
    if num == 7 then
        table.insert(cmdqueue.postfix, 0x0701)
        table.insert(cmdqueue.postfix, 0x0007)
    end
    
    if num == 8 then
        table.insert(cmdqueue.postfix, 0x1001)
        table.insert(cmdqueue.postfix, 0x0010)
    end
    
    if num == 9 then
        table.insert(cmdqueue.postfix, 0x0B01)
        table.insert(cmdqueue.postfix, 0x000B)
    end
end

function btoads:stop_raw()
end

function btoads:init()
    cmdqueue.prefix = {0x0052, 0x0061, 0x0072, 0x0065, 0x0004, 0x0005, 0x000A, 0x0112, 0x000D, 0x0000}
    maincpu = manager.machine.devices[":maincpu"]
    maincpu_memory = maincpu.spaces["program"]
    rom = manager.machine.memory.regions[":user1"]
    initialized = true
end 

return btoads
