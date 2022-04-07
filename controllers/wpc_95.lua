local wpc_95  = {}

rawset(wpc_95, "screen_path", ":dmd:screen")

local cmdqueue = {}
local memory
local cpu
local initialized = false

local function init_sound()
    memory:write_i8(0x3FDC, 0x00)
    memory:write_i8(0x3FDC, 0x00)
    memory:write_i8(0x3FDC, 0x00)
    memory:write_i8(0x3FDC, 0x00)
    memory:write_i8(0x3FDC, 0x00)
    memory:write_i8(0x3FDC, 0x55)
    memory:write_i8(0x3FDC, 0xAA)
    memory:write_i8(0x3FDC, 0x47)
    memory:write_i8(0x3FDC, 0xB8)
end

local function send_command_to_wdc(cmd)
--     cmdqueue:push_command(0x03)
--     cmdqueue:push_command(0xE7)
--     cmdqueue:push_command(0x03)
--     cmdqueue:push_command(0xE7)
--     cmdqueue:push_command(0x00)
--     cmdqueue:push_command(0x00)
--     cmdqueue:push_command(0x00)
--     cmdqueue:push_command(0x00)
--     cmdqueue:push_command(0x00)
--     cmdqueue:push_command(0x55)
--     cmdqueue:push_command(0xAA)
--     cmdqueue:push_command(0x47)
--     cmdqueue:push_command(0xB8)
--     cmdqueue:push_command(0x03)
--     cmdqueue:push_command(0xE3)
--     cmdqueue:push_command(0x03)
--     cmdqueue:push_command(0xE6)
--     cmdqueue:push_command(0x03)
--     cmdqueue:push_command(0xE5)
--     cmdqueue:push_command(0x03)
--     cmdqueue:push_command(0xE3)
--     cmdqueue:push_command(0x03)
--     cmdqueue:push_command(0xE6)
--     cmdqueue:push_command(0x03)
--     cmdqueue:push_command(0xE5)
    cmdqueue:push_command(0x00)
    cmdqueue:push_command(cmd & 0xFF)
end

--- ======
function wpc_95:tick_impl()
--    local cmdread = memory:read_i8(0x3FDC)
--    if not step1 then
--        step1 = cmdread == 0x79
--        return
--    end
--    print("step1 passed")
--    if not step2 then
--        step2 = cmdread == 0x01
--        return
--    end
--    print("step2 passed")
    local cmd = cmdqueue:get_next()
    if cmd == nil then
        return
    end
    memory:write_u8(0x3FDC, cmd)
end

function wpc_95:init()
    cpu = manager.machine.devices[":maincpu"]
    memory = cpu.spaces["program"]
    cmdqueue = require("arcademus/structures/cmdqueue").new(cmdqueue)
    cmdqueue.prefix = { 0x03, 0xE3, 0x03, 0xE6, 0x03, 0xE5 }
end


function wpc_95:play_raw(num)
    cmdqueue:reset_queue()
    cmdqueue:push_command(0x00)
    cmdqueue:push_command(num & 0xFF)
end

function wpc_95:stop_raw()
    cmdqueue:reset_queue()
    cmdqueue:push_command(0x00)
    cmdqueue:push_command(0x00)
end

return wpc_95
