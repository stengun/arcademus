---
--- Controller interface prototype.
--- All controllers must be initialized from this table using the .new(modulename) method.
---
--- A proper controller must export those methods:
---     init(self)
---     play_raw(self, value)
---     stop_raw(self)
---
--- Also, if controller populates the field tracklist, it will enable a playlist
--- driven control from the interface. see arcademus/structures/tracklist.lua for
--- more information on tracklists.
---

local tracklist = require("arcademus/structures/tracklist")

local controller = {}
controller.prototype = {
    current_track = 1,
    playing = false,
    tracklist = tracklist.new({}),
    --- "virtual" methods to override.
    init = function(self)  end,
    stop_raw = function(self) end,
    play_raw = function(self, raw_index)  end,
    --- normal methods
    stop = function(self)
        if manager.machine.sound.recording then
            manager.machine.sound:stop_recording()
        end
        self:stop_raw()
        rawset(self, "playing", false)
    end,
    play = function(self, track)
        if self.playing then
            self:stop()
        end
        if #self.tracklist > 0 then
            self:play_raw(self.tracklist[track].value)
        else
            self:play_raw(track)
        end
        rawset(self, "playing", true)
        rawset(self, "current_track", track)
    end,
    record = function(self, track, path)
        self:play(track)
        local file_name = string.format("%s/%s_%d.wav", path, manager.machine.system.name, track)
        manager.machine.sound:start_recording(file_name)
    end,
    track_info = function(self, trackindex)
        return self.tracklist[trackindex]
    end,
    track_total = function(self)
        if #self.tracklist > 0 then
            return #self.tracklist
        end
        return 256
    end
}

controller.mt = {
    __index = controller.prototype,
    __newindex = function (t, k, v) end
}

function controller.new(s)
    if type(s) == "string" then
        tb = require("arcademus/controllers/" .. s)
        tb:init()
        setmetatable(tb, controller.mt)
        tb:stop()
        return tb
    elseif type(s) == "table" then
        setmetatable(s, controller.mt)
        return s
    end
end

return controller
