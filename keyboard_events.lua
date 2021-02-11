---
--- Global table used to register callbacks for specific keyboard keycodes.
--- The callbacks are fired when pressed and released events are detected.
--- To make this table work, .poll() method has to be called in a proper tick
--- function.
---
--- The callback signature is callback(event).
---
_G.keyboard_events = {}

local event_callbacks = {}

local function fire_callbacks(k, event)
    if not event_callbacks[k] or manager.ui.menu_active then
        return
    end
    for _, f in pairs(event_callbacks[k]) do
        f(event)
    end
end

local last_state = {}
---
--- Checks for status changes of the keys that have at least a callback registered.
--- If no callbacks are registered, this method does nothing.
---
function keyboard_events.poll()
    if manager.machine.system.name == "___empty" then
        return
    end
    local input = manager.machine.input
    for cb_name, _ in pairs(event_callbacks) do
        local is_pressed = input:code_pressed(input:code_from_token(cb_name))
        local was_pressed = last_state[cb_name]
        if was_pressed and not is_pressed then
            fire_callbacks(cb_name, "released")
        elseif not was_pressed and is_pressed then
            fire_callbacks(cb_name, "pressed")
        end
        last_state[cb_name] = is_pressed
    end
end
---
--- Register callback for key keycode. Callback is a function(event) method.
--- Callback's event parameter is a string which can assume the values "pressed" or "released".
---
--- Keycodes are the same as the macros in this file (the ones in the form KEYCODE_*)
--- https://github.com/mamedev/mame/blob/d822e7ec4ad29eeb7724e9249ef97a7220f541e0/src/emu/input.h#L679
---
function keyboard_events.register_key_event_callback(key, cb)
    if not event_callbacks[key] then
        event_callbacks[key] = {}
    end
    local input = manager.machine.input
    last_state[key] = input:code_pressed(input:code_from_token(key))
    table.insert(event_callbacks[key], cb)
end

return keyboard_events
