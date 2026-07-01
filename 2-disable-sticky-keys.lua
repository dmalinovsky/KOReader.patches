local Device = require("device")
local time = require("ui/time")
local ffi = require("ffi")
local C = ffi.C
local logger = require("logger")

Device.last_key_code = 0
Device.last_key_time = 0

Device.input:registerEventAdjustHook(function(this, ev)
    if ev.type == C.EV_KEY and ev.value == 1 then -- KEY_PRESS = 1
        local now = time.now()
        local time_diff = time.to_ms(now - Device.last_key_time)
        if time_diff <= 500 and ev.code == Device.last_key_code then
            logger.info("Skipping sticky key", ev.code, time_diff)
            ev.value = -1 -- Set to an invalid value that will be ignored
        end
        Device.last_key_code = ev.code
        Device.last_key_time = now
    end
end)
