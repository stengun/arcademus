local wpc_flip1  = {}

local memory
local cpu

local function send_command_to_wdc(cmd)
    memory:write_i8(0x3FDC, 0x7E)
    memory:write_i8(0x3FFC, 0x3B)
    memory:write_i8(0x3FD4, 0xFF)
    memory:write_i8(0x3FDC, 0x7D)
    memory:write_i8(0x3FFC, 0x3B)
    memory:write_i8(0x3FD4, 0xFF)
    memory:write_i8(0x3FDC, 0x7F)
    memory:write_i8(0x3FFC, 0x3B)
    memory:write_i8(0x3FD4, 0xFF)
    memory:write_i8(0x3FDC, cmd & 0xFF)
    memory:write_i8(0x3FFC, 0x3B)
    memory:write_i8(0x3FD4, 0xFF)
end

--- ======
function wpc_flip1:init()
    cpu = manager.machine.devices[":maincpu"]
    memory = cpu.spaces["program"]
    local mem = manager.machine.memory.regions[":code"]
    -- TODO use commond hang routines
    --- cpu entrypoint is fetched from $FFFE/$FFFF, the addres for the RESET interrupt routine
    local entrypoint = 0x78000 | (mem:read_u8(0x7FFFE) << 8 | mem:read_u8(0x7FFFF))
    --- Put a JMP $entry_point instruction in $entry_point, effectively hanging the cpu.
    mem:write_u8(entrypoint, 0x7E)
    mem:write_u8(entrypoint + 0x01, (entrypoint >> 8) & 0xFF)
    mem:write_u8(entrypoint + 0x02, entrypoint & 0xFF)
end


function wpc_flip1:play_raw(num)
    send_command_to_wdc(num)
end

function wpc_flip1:stop_raw()
    send_command_to_wdc(0x00)
end

return wpc_flip1
