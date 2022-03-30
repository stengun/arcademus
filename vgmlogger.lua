--- VGM logger class
local last_write_tick = 0
local total_wait_values = 0 -- sum of all wait values
local raw_dump = ""

local function read_okim6295_addr(bank, index)
    return (bank:read_u8(index) << 16) | (bank:read_u8(index + 1) << 8)  | bank:read_u8(index + 2)
end

local function get_as_32le(number)
    return string.char(number & 0xFF, (number >> 8) & 0xFF, (number >> 16) & 0xFF, (number >> 24) & 0xFF)
end

local function insert_delay()
    local ticks = manager.machine.time:as_ticks(44100) - last_write_tick
    last_write_tick = manager.machine.time:as_ticks(44100)
    while ticks > 0 do
        local delay = ticks > 0x0000FFFF and 0xFFFF or ticks
        if delay <= 0x0010 then
            raw_dump = raw_dump .. string.char(0x70 | (ticks - 1))
        elseif ticks == 0x2DF then
            raw_dump = raw_dump .. string.char(0x62)
        elseif ticks == 0x372 then
            raw_dump = raw_dump .. string.char(0x63)
        else
            raw_dump = raw_dump .. string.char(0x61, ticks & 0xFF, ticks >> 8)
        end
        total_wait_values = total_wait_values + delay
        ticks = ticks - delay
    end
end

local tracked_chips = {}

local function ymfm_common(offset, data, device, vgmcommand)
    if offset & 0x1 == 0 then
        tracked_chips[device].register = data
    else
        insert_delay()
        local command = tracked_chips[device].port == 0 and vgmcommand or ((vgmcommand & 0x0F) | 0xA0)
        raw_dump = raw_dump .. string.char(command, tracked_chips[device].register, data)
    end
end

--[[
    Chip dumpers are functions used as callbacks for memory eavesdrop.
    parameters:
    offset - memory offset being accessed
    data - for write accesses, the data being written. For read accesses, data being read
    device - device that owns this callback
]]
local chip_dumpers = {
    ym2203 = function(offset, data, device)
        ymfm_common(offset, data, device, 0x55)
    end,
    ym3812 = function(offset, data, device)
        ymfm_common(offset, data, device, 0x5A)
    end,
    ym2413 = function(offset, data, device)
        ymfm_common(offset, data, device, 0x51)
    end,
    ym2151 = function(offset, data, device)
        ymfm_common(offset, data, device, 0x54)
    end,
    okim6295 = function(offset, data, device)
        insert_delay()
        raw_dump = raw_dump .. string.char(0xB8, tracked_chips[device].port << 7, data)
        if data & 0x80 ~= 0 then
            local command = data & 0x3F
            if tracked_chips[device].samples.used[command] ~= nil then return end
            local ptr_index = command * 8
            local sample_start = read_okim6295_addr(tracked_chips[device].rom, ptr_index)
            local sample_end = read_okim6295_addr(tracked_chips[device].rom, ptr_index + 3)
            if sample_end <= sample_start then return end
            tracked_chips[device].samples.used[command] = {
                    start_ptr = sample_start,
                    end_ptr = sample_end
                }
            tracked_chips[device].samples.length = tracked_chips[device].samples.length + 1
            tracked_chips[device].samples.highest = tracked_chips[device].samples.highest < sample_end and sample_end + 1 or tracked_chips[device].samples.highest
        end
    end,
}

--[[
    VGM file header.
    In this table you put data to write, using its file offset + 1 as key.
    All data should be a char string (use string.char())
]]
local header = {}
header[0x01] = string.char(0x56, 0x67, 0x6D, 0x20) -- 'Vgm ' magic header
header[0x09] = string.char(0x71, 0x01, 0x00, 0x00) -- VGM file version
header[0x35] = string.char(0xCC) -- data offset

local function okim_data_block(port, romsize, rom, start_ptr, end_ptr)
    local retval = string.char(0x67, 0x66, 0x8B)
    local sample_size = (end_ptr - start_ptr) + 1
    local datablock_size = (sample_size + 8) | (port << 31)
    retval = retval .. get_as_32le(datablock_size) .. get_as_32le(romsize) .. get_as_32le(start_ptr)
    for i = start_ptr, end_ptr, 1 do
        retval = retval .. string.char(rom:read_u8(i))
    end
    return retval
end

local function get_data_blocks(self)
    local retval = ""
    if self.samples.length > 0 then
        print("okim6295 used samples " .. self.samples.length)
        retval = retval .. okim_data_block(self.port, self.samples.highest, self.rom, 0x000, 0x3FF) -- okim area for sample pointers
        for _, val in pairs(self.samples.used) do
            retval = retval .. okim_data_block(self.port, self.samples.highest, self.rom, val.start_ptr, val.end_ptr)
        end
        return retval
    end
end

local function write_file(filename)
    -- TODO test path validity
    local logfile = io.open(filename, "wb" )
    -- Writing header
    logfile:write()
    local val = 1
    while val <= 0x100 do
        if header[val] == nil then
            logfile:write(string.char(0x00))
            val = val + 1
        else
            logfile:write(header[val])
            val = val + #header[val]
        end
    end
    logfile:flush()
    -- writing data block
    -- -- writing needed rom data
    for _, chip in pairs(tracked_chips) do
        if chip.get_data_blocks ~= nil then
            logfile:write(chip:get_data_blocks())
            logfile:flush()
        end
    end
    logfile:write(raw_dump)
    logfile:write(string.char(0x66)) -- end of block
    logfile:flush()
    -- TODO write GD3 tag
    -- writing EOF offset
    local size = logfile:seek() - 4
    logfile:seek("set", 0x04)
    logfile:write(get_as_32le(size))
    logfile:flush()
    logfile:close()
end

--- ============================= Logger table
local vgmlogger = {
    initialized = false,
    logging = false,
    logtrack = 0,
    --- ===================== main interface
    init = function(self)
        rawset(self, "initialized", tracked_chips ~= {})
    end,
    add_chip = function(self, device, port, address_space, start_offset, end_offset)
        if port > 1 or chip_dumpers[device.shortname] == nil then return end
        local internal_name = device.shortname .. "_" .. port
        if tracked_chips[internal_name] ~= nil then return end

        local tap = address_space:install_write_tap(
            start_offset,
            end_offset,
            internal_name,
            function(offset, data, mask)
                return chip_dumpers[device.shortname](offset, data, internal_name)
            end)
        tap:remove()
        tracked_chips[internal_name] = { port = port, tap = tap , reset = function(self) end }
        if device.shortname == "ym2203" then
            local clock = emu.item(device.items["0/m_unscaled_clock"]):read()
            header[0x45] = get_as_32le(clock & 0x3FFFFFFF | (port & 0x1) << 30)
            tracked_chips[internal_name].reset = function(self) self.register = 0 end
        end
        if device.shortname == "ym3812" then
            local clock = emu.item(device.items["0/m_unscaled_clock"]):read()
            header[0x51] = get_as_32le(clock & 0x3FFFFFFF | (port & 0x1) << 30)
            tracked_chips[internal_name].reset = function(self) self.register = 0 end
        end
        if device.shortname == "ym2151" then
            local clock = emu.item(device.items["0/m_unscaled_clock"]):read()
            header[0x31] = get_as_32le(clock & 0x3FFFFFFF | (port & 0x1) << 30)
            tracked_chips[internal_name].reset = function(self) self.register = 0 end
        end
        if device.shortname == "ym2413" then
            local clock = emu.item(device.items["0/m_unscaled_clock"]):read()
            header[0x11] = get_as_32le(clock & 0x3FFFFFFF | (port & 0x1) << 30)
            tracked_chips[internal_name].reset = function(self) self.register = 0 end
        end
        if device.shortname == "okim6295" then
            local pin7 = emu.item(device.items["0/m_pin7_state"]):read()
            local clock = emu.item(device.items["0/m_unscaled_clock"]):read()
            header[0x99] = get_as_32le(clock & 0x3FFFFFFF | pin7 << 31 | (port & 0x1) << 30)
            tracked_chips[internal_name].rom = device.spaces["rom"]
            tracked_chips[internal_name].samples = { used = {}, length = 0, highest = 0}
            tracked_chips[internal_name].get_data_blocks = get_data_blocks
            tracked_chips[internal_name].reset = function(self) self.samples = { used = {}, length = 0, highest = 0} end
        end
    end,
    start = function(self, track)
        if tracked_chips == {} or not self.initialized or self.logging then return end
        print("started vgm log")
        for _, chip in pairs(tracked_chips) do
            chip:reset()
            chip.tap:reinstall()
        end
        last_write_tick = manager.machine.time:as_ticks(44100)
        rawset(self, "logging", true)
        rawset(self, "logtrack", track)
        raw_dump = ""
    end,
    stop = function(self)
        if tracked_chips == {} or not self.initialized or not self.logging then return end
        print("stopped vgm log")
        for _, chip in pairs(tracked_chips) do chip.tap:remove() end
        header[0x19] = get_as_32le(total_wait_values)
        local co = coroutine.create(write_file)
        coroutine.resume(co, string.format("arcademus/vgm/%s_%d.vgm", manager.machine.system.name, self.logtrack))
        rawset(self, "logging", false)
        total_wait_values = 0
    end,
    reset = function(self)
        rawset(self, "initialized", false)
        tracked_chips = {}
        total_wait_values = 0
    end,
}

vgmlogger.mt = {
    __newindex = function(t, k, v) end
}

setmetatable(vgmlogger, vgmlogger.mt)
return vgmlogger
