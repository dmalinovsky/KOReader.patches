local Device = require("device")
if not Device:isPocketBook() or not Device:hasFrontlight() then
    return
end

local ffi = require("ffi")
local C = ffi.C
local util = require("ffi/util")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local powerd = Device:getPowerDevice()
local pb_input = Device.input and Device.input.input

if not pb_input or not pb_input.waitForEvent then
    logger.warn("PB Frontlight Patch: pb_input.waitForEvent not found")
    return
end

-- Initial frontlight state
local last_fl_on = powerd:isFrontlightOn()
local last_fl_intensity = powerd:frontlightIntensityHW()

-- Quick check of frontlight and brightness status
local function checkFrontlightState()
    local current_fl_on = powerd:isFrontlightOn()
    local current_fl_intensity = powerd:frontlightIntensityHW()

    if current_fl_on ~= last_fl_on or current_fl_intensity ~= last_fl_intensity then
        last_fl_on = current_fl_on
        last_fl_intensity = current_fl_intensity
        powerd.is_fl_on = current_fl_on

        logger.info("PB Frontlight Patch: frontlight changed -> on:", current_fl_on, "intensity:", current_fl_intensity)

        if UIManager then
            UIManager:scheduleIn(0, function()
                powerd:stateChanged()
            end)
        end
        return true
    end
    return false
end

local function now_us()
    local s, u = util.gettime()
    return tonumber(s) * 1000000.0 + u
end

local orig_waitForEvent = pb_input.waitForEvent
local POLL_SLICE_US = 250000 -- 250 ms

pb_input.waitForEvent = function(sec, usec)
    local total_timeout_us = sec and math.floor(sec * 1000000 + (usec or 0) + 0.5) or 2000000
    local expire = now_us() + total_timeout_us

    while true do
        local remain = expire - now_us()
        if remain <= 0 then
            checkFrontlightState()
            return false, C.ETIME
        end

        local slice_us = math.min(remain, POLL_SLICE_US)
        local slice_sec = math.floor(slice_us / 1000000)
        local slice_rem_us = slice_us % 1000000

        local ok, ev = orig_waitForEvent(slice_sec, slice_rem_us)
        local fl_changed = checkFrontlightState()

        if ok then
            return ok, ev
        end
        -- If frontlight was toggled, exit the waiting loop,
        -- so UIManager could run scheduled powerd:stateChanged() and refresh the screen
        if fl_changed then
            return false, C.ETIME
        end
        if ev ~= C.ETIME then
            return ok, ev
        end
    end
end

logger.info("PB Frontlight Patch: waitForEvent hook installed (initial on:", last_fl_on, "intensity:", last_fl_intensity, ")")
