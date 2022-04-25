local neogeo = {}

--- NEOGEO games use a straightforward method to play music:
--- writing to 0x320000 will latch the command for the sound cpu.
--- Some games also use their own sound driver for the z80 cpu
--- which could mean they can change what the sound CPU expects to be a sound command.
--- Three commands are "reserved":
--- 0x01 (which prepares the z80cpu for driver swap)
--- 0x02 (which plays the eyecatch jingle)
--- 0x03 (Which soft resets the audio cpu)

local injected_opcodes = {
    0x13C0, 0x0030, 0x0001, -- move.b D0, ($300001.l)   ; give food to watchdog
    0x60F8,                 -- beq -1                   ; back to give food
}

local games = {}
-- Some games works with no prefix to the sound CPU.
-- They are not listed here.
-- mslug, mslug2, mslugx, mslug3 can change "bank" using 0x10, 0x11
-- Vast majority use 0x07 prefix (I think it's standard SNK sound driver)
games.pbobblen = {0x07}
games.kof94 = games.pbobblen
games.kof95 = games.pbobblen
games.kof96 = games.pbobblen
games.kof97 = games.pbobblen
games.kof98 = games.pbobblen
games.kof99 = games.pbobblen
games.kof2000 = games.pbobblen
games.kof2001 = games.pbobblen
games.kof2002 = games.pbobblen
games.kof2003 = games.pbobblen
games.socbrawl = games.pbobblen
games.ssideki = games.pbobblen
games.ssideki2 = games.pbobblen
games.ssideki3 = games.pbobblen
games.ssideki4 = games.pbobblen
games.ssideki = games.pbobblen
games.neocup98 = games.pbobblen
games.spinmast = games.pbobblen
games.magdrop3 = games.pbobblen
games.androdun = games.pbobblen
games.zupapa = games.pbobblen
games.zedblade = games.pbobblen
games.minasan = games.pbobblen
games.mslug5 = games.pbobblen
games.nam1975 = games.pbobblen
games.aof2 = games.pbobblen
games.jockeygp = games.pbobblen
games.irrmaze = games.pbobblen
games.cyberlip = games.pbobblen
games.breakers = games.pbobblen
games.roboarmy = games.pbobblen
games.rotd = games.pbobblen
games.gpilots = games.pbobblen
games.pspikes2 = games.pbobblen
games.eightman = games.pbobblen
games.samsh5sp = games.pbobblen
games.pulstar = games.pbobblen
games.joyjoy = games.pbobblen
games.blazstar = games.pbobblen
games.b2b = games.pbobblen
games.shocktr2 = games.pbobblen
games.fbfrenzy = games.pbobblen
games.samsho = games.pbobblen
games.fatfury1 = games.pbobblen
games.samsho4 = games.pbobblen
games.superspy = games.pbobblen
games.aof3 = games.pbobblen
games.kotm2 = games.pbobblen
games.neobombe = games.pbobblen
games.sengoku2 = games.pbobblen
games.sengoku = games.pbobblen
games.shocktro = games.pbobblen
games.svc = games.pbobblen
games.samsho5 = games.pbobblen
games.rbffspec = games.pbobblen
games.ragnagrd = games.pbobblen
games.flipshot = games.pbobblen
games.lastbld2 = games.pbobblen
games.sengoku3 = games.pbobblen
games.matrim = games.pbobblen
games.burningf = games.pbobblen
games.ganryu = games.pbobblen
games.fatfury3 = games.pbobblen
games.rbff2 = games.pbobblen
games.quizkof = games.pbobblen
games.lastblad = games.pbobblen
games.miexchng = games.pbobblen
games.pgoal = games.pbobblen
games.bakatono = games.pbobblen
games.viewpoin = games.pbobblen
games.bstars2 = games.pbobblen
games.lresort = games.pbobblen
games.galaxyfg = games.pbobblen
games.ironclad = games.pbobblen
games.neomrdo = games.pbobblen
games.kizuna = games.pbobblen
games.lbowling = games.pbobblen
games.janshin = games.pbobblen
games.mahretsu = games.pbobblen
games.diggerma = games.pbobblen
games.ctomaday = games.pbobblen
games.legendos = games.pbobblen
games.marukodq = games.pbobblen
games.s1945p = games.pbobblen
games.tpgolf = games.pbobblen
games.ridhero = games.pbobblen
games.tophuntr = games.pbobblen
games.fatfury2 = games.pbobblen
games.quizdai2 = games.pbobblen
games.panicbom = games.pbobblen
games.rbff1 = games.pbobblen
games.puzzledp = games.pbobblen
games.samsho3 = games.pbobblen
games.wakuwak7 = games.pbobblen
games.stakwin = games.pbobblen
games.fatfursp = games.pbobblen
games.bstars = games.pbobblen
games.pnyaa = games.pbobblen
games.preisle2 = games.pbobblen
games.vliner = games.pbobblen
games.neodrift = games.pbobblen
games.kabukikl = games.pbobblen
games.quizdais = games.pbobblen
games["3countb"] = games.pbobblen
games.savagere = games.pbobblen
games.gowcaizr = games.pbobblen
games.garou = games.pbobblen
games.mutnat = games.pbobblen
games.bangbead = games.pbobblen
games.kotm = games.pbobblen
games.nitd = games.pbobblen
games["2020bb"] = games.pbobblen
games.aof = games.pbobblen
games.goalx3 = games.pbobblen
games.stakwin2 = games.pbobblen
games.alpham2 = games.pbobblen
games.samsho2 = games.pbobblen
games.breakrev = games.pbobblen
games.fightfev = games.pbobblen
-- Without any prefix, this game plays sound effects.
-- Using 0xFC or 0xFD will play music instead.
games.wh2j = {0x03, 0xFC}
games.wh2 = games.wh2j
games.whp = games.wh2j
games.moshougi = games.wh2j
games.overtop = games.wh2j
games.ninjamas = games.wh2j
games.aodk = games.wh2j
games.twinspri = games.wh2j
--- This game uses two codes to change the type of sounds:
--- 0x16 will play music, 0x18 will play sound effects.
--- To make things easier, I put soft reset into the command prefix.
games.strhoop = {0x03, 0x16}
games.wjammers = games.strhoop
games.magdrop2 = games.strhoop
games.karnovr = games.strhoop
games.ghostlop = games.strhoop
--- pbobbl2n uses a strange command sequence:
--- first you send 0x07 when the z80 is ready to accept commands
--- after that the music commands are prefixed with 0x19 and audio effects are prefixed with 0x1A.
--- Also, 0x07 is sent only after a soft reset of the audiocpu, not with every command.
--- To simplify the logic, I send a softreset + 0x07 as part of the prefix.
games.pbobbl2n = {0x03, 0x07, 0x19}

local cmdqueue = {}
local initialized = false
local ram_address = 0x10F300
local user_subroutine_address = 0x800
local maincpu
local maincpu_memory
local rom_mem

local function inject()
    rom_mem:write_i8(0x0114, 0x02) -- Disable eyecatch
    rom_mem:write_i16(0x0122, 0x4EF8) -- tell to jump to 0x800 (were we inject our subroutine)
    rom_mem:write_i16(0x0124, user_subroutine_address)
    rom_mem:write_i16(0x0126, 0x4E71)
    
    for _, v in pairs(injected_opcodes) do
        local offset = (_ - 1) * 2
        rom_mem:write_i16(user_subroutine_address + offset, v)
    end
    
end
---- ========
function neogeo:tick_impl()
    if initialized then
        local cmd = cmdqueue:get_next()
        if cmd then
            maincpu_memory:write_i8(0x320000, cmd) -- latch memory address
        end
        return
    end
    initialized = (maincpu.state["PC"].value >= user_subroutine_address) and (maincpu.state["PC"].value < user_subroutine_address + 0x08)
    if initialized then
        manager.machine:popmessage("Machine Initialized!")
    end
end

function neogeo:init()
    maincpu = manager.machine.devices[":maincpu"]
    maincpu_memory = maincpu.spaces["program"]
    rom_mem = manager.machine.memory.regions[":cslot1:maincpu"]
    inject()
    cmdqueue = require("arcademus/structures/cmdqueue").new(cmdqueue)
    local game = games[manager.machine.system.name]
    if game ~= nil then
        cmdqueue.prefix = game
    end
    self.vgmlogger:add_chip(manager.machine.devices["ymsnd"], 0, manager.machine.devices[":audiocpu"].spaces["io"], 0x04, 0x07)
    manager.machine:popmessage("Machine is Initializing...")
end

function neogeo:play_raw(num)
    cmdqueue:reset_queue()
    cmdqueue:push_command(num & 0xFF)
end

function neogeo:stop_raw()
    if initialized then
        cmdqueue:reset_queue(false)
        cmdqueue:push_command(0x03)
    end
end

return neogeo
