local cmdqueue = {}

local function concat_tables(t1, t2)
    for i = 1, #t2 do
        t1[#t1 + 1] = t2[i]
    end
    return t1
end

cmdqueue.prototype = {
    postfix = {},
    prefix = {},
    command = {},
    index = 1,
    prefixed = true,
    postfixed = true,
    ended = true,
    _internal_seq = nil,
    get_next = function (self)
        if self.ended then
            return nil
        end
        if self._internal_seq == nil then
            rawset(self, "_internal_seq", {})
            if self.prefixed then
                concat_tables(self._internal_seq, self.prefix)
            end
            concat_tables(self._internal_seq, self.command)
            if self.postfixed then
                concat_tables(self._internal_seq, self.postfix)
            end
        end
        local retval = self._internal_seq[self.index]
        rawset(self, "index", self.index + 1)
        if not retval then
            rawset(self, "ended", true)
        end
        return retval
    end,
    
    push_command = function (self, cmd)
        table.insert(self.command, cmd)
    end,
    
    reset_queue = function (self, is_prefixed, is_postfixed)
        rawset(self, "_internal_seq", nil)
        rawset(self, "command", {})
        rawset(self, "prefixed", is_prefixed == nil or is_prefixed)
        rawset(self, "postfixed", is_postfixed == nil or is_postfixed)
        rawset(self, "index", 1)
        rawset(self, "ended", false)
    end
}

cmdqueue.mt = {
    __index = cmdqueue.prototype,
    __newindex = function (t, k, v) 
        if k == "prefix" or k == "postfix" then
            return rawset(t, k, v)
        end
    end
}

function cmdqueue.new(o)
    o = o or {}
    setmetatable(o, cmdqueue.mt)
    return o
end

return cmdqueue
