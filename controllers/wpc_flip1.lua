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
end


function wpc_flip1:play_raw(num)
    send_command_to_wdc(num)
end

function wpc_flip1:stop_raw()
    ---send_command_to_wdc(0xFF)
end

return wpc_flip1
