local rastan = {}

--- this little asm program initializes hardware and plays audio tracks on taito PC060H devices.
--- it will read data from a known ram location and changes audio track when data is present.
local injected_opcodes = {
    0x43F9, 0x003E, 0x0001, -- lea $3e0001.l, A1    ; address for MASTER port
    0x45F9, 0x003E, 0x0003, -- lea $3e0003.l, A2    ; address for COMM port
    0x41F9, 0x0010, 0xD13C, -- lea $10d13c.l, A0    ; here we put the ram address to observe
--  here starts the init routine
    0x12BC, 0x0004,         -- move.b #$4, (A1)
    0x14BC, 0x0001,         -- move.b #$1, (A2)
    0x12BC, 0x0004,         -- move.b #$4, (A1)
    0x14BC, 0x0000,         -- move.b #$0, (A2)
    0x10BC, 0x00EF,         -- move.b #$ef, (A0)
    0x707F,                 -- moveq #$7F, D0
    0x5300,                 -- subq #$1, D0
    0x66FC,                 -- bne -1
-- here starts the track play routine
    0x4A50,                 -- tst.w (A0)
    0x67FC,                 -- beq #$-1
    0x12BC, 0x0000,         -- move.b #$0, (A1)
    0x1010,                 -- move.b (A0), D0
    0x0200, 0x000F,         -- andi.b #$f, D0
    0x1480,                 -- move.b D0, (A2)
    0x12BC, 0x0001,         -- move.b #$1, (A1)
    0x1010,                 -- move.b (A0), D0
    0xE808,                 -- lsr.b #4, D0
    0x0200, 0x000F,         -- andi.b #$f, D0
    0x1480,                 -- move.b D0, (A2)
    0x4250,                 -- clr.w (A0)
    0x60DE,                 -- bra #-32
}

--- Jumping is a bootleg that doesn't use the PC060H device. This was replaced by a normal latch
--- this asm program works like the other one, waiting for the track on a specific ram address.
local jumping_injected_opcodes = {
    0x6004, 0x0000, 0x0000,
    0x45F9, 0x0000, 0x0000,
    0x41F9, 0x0000, 0x0000,
--
    0x4A50, -- tst.w (A0)
    0x67FC, -- beq #$-1
    0x1490, -- move.b (A0) (A2)
    0x4250, -- clr.w (A0)
    0x60F6, -- bra #$-8
}

local games = {}

games.rbisland = { 0x3E0001, 0x3E0003, 0x10D13C }
games.rbislande = { 0x3E0001, 0x3E0003, 0x10D13C }
games.rastan = { 0x3E0001, 0x3E0003, 0x10D13C }
games.jumping = { 0x10C000, 0x400007, 0x10D13C, jumping_injected_opcodes }
games.jumpinga = games.jumping
games.jumpingi = games.jumping

local maincpu
local memory
local game

local function inject()
    local master_address = game[1]
    local comm_address = game[2]
    local ram_address = game[3]
    local opcodes = game[4]
    if opcodes == nil then
        opcodes = injected_opcodes
    end
    local progrom = manager.machine.memory.regions[":maincpu"]
    local base_address = (progrom:read_i16(0x0004) & 0xFFFF) << 16 | progrom:read_i16(0x0006) & 0xFFFF
    for _, v in pairs(opcodes) do
        local offset = (_ - 1) * 2
        local value = v
        if offset == 2 then
            value = master_address >> 16 & 0xFFFF
        elseif offset == 4 then
            value = master_address & 0xFFFF
        elseif offset == 8 then
            value = comm_address >> 16 & 0xFFFF
        elseif offset == 10 then
            value = comm_address & 0xFFFF
        elseif offset == 14 then
            value = ram_address >> 16 & 0xFFFF
        elseif offset == 16 then
            value = ram_address & 0xFFFF
        end
        progrom:write_i16(base_address + offset, value)
    end
end

--- ===============================
function rastan:play_raw(num)
    memory:write_i16(game[3], (num << 8) & 0xFF00)
end

function rastan:stop_raw()
    memory:write_i16(game[3], 0x0001)
end

function rastan:init()
    game = games[self.running_system_name]
    if game == nil then
        game = games[self.parent_system_name]
    end
    maincpu = manager.machine.devices[":maincpu"]
    memory = maincpu.spaces["program"]
    inject()
end

return rastan
