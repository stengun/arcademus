local cps1 = {}

--- CPS-1 games use a simple soundlatch mechanism.
--- all games have the latch tied to 0x8000180 with only one exceptions: sf2m3 uses 0x800190

--- In Qsound boards communication is done by writing song value in the qsound shared ram (0xf18001, 0xf18003) and confirm read setting 0 in (0xf1801f).
--- To make QSound work, we must inject a special program in the maincpu that initializes the audiocpu.
local qsound_injected_opcodes = {
--- initialization routine for qsound
    0x43F9, 0x00F1, 0x9FFB, -- lea $f19ffb.l, A1        ; put in A1 our base address for comms with audiocpu.
    0x7077,                 -- moveq #$77, D0
    0xB039, 0x00F1, 0x9FFF, -- cmp.b #$f19fff.l, D0       ; wait until audiocpu signals ready in comm. port with 77
    0x66F8,                 -- bne #$-1
    0x12BC, 0x0088,         -- move.b #$88, (A1)        ; init sequence
    0x137C, 0x00FF, 0x0002, -- move.b #$FF, ($2, A1)    ; 
    0x137C, 0x00FF, 0x0004, -- move.b #$FF, ($4, A1)    ; set FF for command sent
    0x60FE,                 -- bra #$0
}

local maincpu
local memory
local qsound = false

local function inject()
    local progrom = manager.machine.memory.regions[":maincpu"]
    local base_address = (progrom:read_i16(0x0004) & 0xFFFF) << 16 | progrom:read_i16(0x0006) & 0xFFFF
    if qsound then
        memory:write_i8(0x00F1800F, 0x10) -- panpot center
        for _, v in pairs(qsound_injected_opcodes) do
            local offset = (_ - 1) * 2
            progrom:write_i16(base_address + offset, v)
        end
    else
        progrom:write_i16(base_address, 0x60FE) --- bra #$0
    end
end

---- ===============
function cps1:init()
    maincpu = manager.machine.devices[":maincpu"]
    memory = maincpu.spaces["program"]
    qsound = manager.machine.devices[":qsound"] ~= nil
    inject()
end

function cps1:play_raw(num)
    if qsound then
        memory:write_i8(0x00F18001, (num >> 8) & 0xFF)
        memory:write_i8(0x00F18003, num & 0xFF)
        memory:write_i8(0x00F1801F, 0x00)
    else
        if manager.machine.system.name == "sf2m3" then
            memory:write_i16(0x800190, num & 0xFF)
        else
            memory:write_i16(0x800180, num & 0xFF)
        end
    end
end

function cps1:stop_raw()
    if qsound then
        self:play_raw(0xFF00)
    else
        self:play_raw(0xF0)
    end
end

return cps1
