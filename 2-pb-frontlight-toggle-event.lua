local Device = require("device")
if not Device:isPocketBook() or not Device:hasFrontlight() then
    return
end

local ffi = require("ffi")
local C = ffi.C
local inkview = require("ffi/inkview")
local util = require("ffi/util")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local powerd = Device:getPowerDevice()
local pb_input = Device.input and Device.input.input

if not pb_input or not pb_input.waitForEvent then
    logger.warn("PB Frontlight Patch: pb_input.waitForEvent not found")
    return
end

local function now_us()
    local s, u = util.gettime()
    return tonumber(s) * 1000000.0 + u
end

local function isActiveAndUnlocked()
    return inkview.IsTaskActive() ~= 0 and inkview.hw_get_keylock() == 0
end

local function isLifecycleMiscEvent(e)
    if not e or e.type ~= C.EV_MSC then
        return false
    end
    local c = e.code
    return c == C.EVT_HIDE or c == C.EVT_BACKGROUND
        or c == C.EVT_SHOW or c == C.EVT_FOREGROUND
        or c == C.EVT_EXIT
end

local function hasLifecycleEvent(ev)
    if type(ev) ~= "table" then
        return false
    end
    if ev.type then
        return isLifecycleMiscEvent(ev)
    end
    for i = 1, #ev do
        if isLifecycleMiscEvent(ev[i]) then
            return true
        end
    end
    return false
end

-- Initial frontlight state
local last_fl_on = powerd:isFrontlightOn()
local last_fl_intensity = powerd:frontlightIntensityHW()
local skip_poll_until = 0
local need_resync = false

-- Quick check of frontlight and brightness status
local function checkFrontlightState()
    if not isActiveAndUnlocked() or now_us() < skip_poll_until then
        return false
    end

    local current_fl_on = powerd:isFrontlightOn()
    local current_fl_intensity = powerd:frontlightIntensityHW()

    if need_resync then
        need_resync = false
        last_fl_on = current_fl_on
        last_fl_intensity = current_fl_intensity
        powerd.is_fl_on = current_fl_on
        return false
    end

    if current_fl_on ~= last_fl_on or current_fl_intensity ~= last_fl_intensity then
        last_fl_on = current_fl_on
        last_fl_intensity = current_fl_intensity
        powerd.is_fl_on = current_fl_on

        logger.info("PB Frontlight Patch: frontlight changed -> on:", current_fl_on, "intensity:", current_fl_intensity)

        if UIManager then
            UIManager:scheduleIn(0.15, function()
                if isActiveAndUnlocked() and now_us() >= skip_poll_until then
                    powerd:stateChanged()
                end
            end)
        end
        return true
    end
    return false
end

local orig_waitForEvent = pb_input.waitForEvent
local POLL_SLICE_US = 250000 -- 250 ms

pb_input.waitForEvent = function(sec, usec)
    if not isActiveAndUnlocked() then
        skip_poll_until = now_us() + 2000000
        need_resync = true
        return orig_waitForEvent(sec, usec)
    end

    local total_timeout_us = sec and math.floor(sec * 1000000 + (usec or 0) + 0.5) or 2000000
    local expire = now_us() + total_timeout_us

    while true do
        local remain = expire - now_us()
        if remain <= 0 then
            return false, C.ETIME
        end

        local slice_us = math.min(remain, POLL_SLICE_US)
        local slice_sec = math.floor(slice_us / 1000000)
        local slice_rem_us = slice_us % 1000000

        local ok, ev = orig_waitForEvent(slice_sec, slice_rem_us)

        if not isActiveAndUnlocked() or (ok and hasLifecycleEvent(ev)) then
            skip_poll_until = now_us() + 2000000
            need_resync = true
            return ok, ev
        end

        if ok then
            checkFrontlightState()
            return ok, ev
        end

        if checkFrontlightState() then
            return false, C.ETIME
        end
        if ev ~= C.ETIME then
            return ok, ev
        end
    end
end

logger.info("PB Frontlight Patch: waitForEvent hook installed (initial on:", last_fl_on, "intensity:", last_fl_intensity, ")")
