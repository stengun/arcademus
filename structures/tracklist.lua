local track = {}
track.prototype = { name = "", value = -1 }
track.prototype.mt = {
    __newindex = function(t, k, v)  end
    }
setmetatable(track.prototype, track.prototype.mt)
track.mt = {
    __index = track.prototype,
    __newindex = track.prototype
    }

function track.new(o)
    setmetatable(o, track.mt)
    return o
end

local tracklist = {}
tracklist.mt = {
    __index = function(t, k)
        if type(k) ~= "number" then
            return nil
        end
        return rawget(t, k)
    end,
    __newindex = function (t, k, v)
        if type(k) ~= "number" then
            return
        end
        return rawset(t, k, v)
    end
}

function tracklist.new(name)
    if name and type(name) == "string" then
        local tlist = {}
        function Track(o)
            table.insert(tlist, track.new({name = o[1], value = o[2]}))
        end
        dofile("plugins/arcademus/controllers_data/" .. name)
        setmetatable(tlist, tracklist.mt)
        return tlist
    elseif name and type(name) == "table" then
        setmetatable(name, tracklist.mt)
        return name
    end
    return nil
end

return tracklist
