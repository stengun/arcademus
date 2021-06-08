local cmdqueue = {}

cmdqueue.prototype = {
    prefix = {},
    command = {},
    index = 1,
    prefixed = true,
    ended = true,

    get_next = function (self)
        if self.prefixed then
            local retval = self.prefix[self.index]
            rawset(self, "index", self.index + 1)
            if retval then
                return retval
            end
            retval = self.command[self.index - #self.prefix - 1]
            if not retval then
                rawset(self, "ended", true)
            end
            return retval
        end
        
        local retval = self.command[self.index]
        rawset(self, "index", self.index + 1)
        if not retval then
            rawset(self, "ended", true)
        end
        return retval
    end,
    
    push_command = function (self, cmd)
        table.insert(self.command, cmd)
    end,
    
    reset_queue = function (self, is_prefixed)
        rawset(self, "command", {})
        rawset(self, "prefixed", is_prefixed == nil or is_prefixed)
        rawset(self, "index", 1)
        rawset(self, "ended", false)
    end
}

cmdqueue.mt = {
    __index = cmdqueue.prototype,
    __newindex = function (t, k, v) end
}

function cmdqueue.new(o)
    o = o or {}
    setmetatable(o, cmdqueue.mt)
    return o
end

return cmdqueue
