local Device = require("device")
if not Device:isPocketBook() or not Device:hasFrontlight() then
    return
end

local ffi = require("ffi")
local inkview = require("ffi/inkview")
local UIManager = require("ui/uimanager")
local logger = require("logger")

local powerd = Device:getPowerDevice()

local BLED1_PATH = "/sys/class/backlight/lm3630_bled1/brightness"
local BLED2_PATH = "/sys/class/backlight/lm3630_bled2/brightness"
local POLL_INTERVAL_SEC = 2.0

local function readSysfsInt(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local val = f:read("*n")
    f:close()
    return val
end

local function readBacklightState()
    return readSysfsInt(BLED1_PATH), readSysfsInt(BLED2_PATH)
end

local last_b1, last_b2 = readBacklightState()
if last_b1 == nil and last_b2 == nil then
    logger.warn("PB Frontlight Sysfs Patch: cannot read lm3630 backlight nodes")
    return
end

local function isActiveAndUnlocked()
    return inkview.IsTaskActive() ~= 0 and inkview.hw_get_keylock() == 0
end

local function pollFrontlightSysfs()
    if isActiveAndUnlocked() then
        local b1, b2 = readBacklightState()
        if b1 ~= last_b1 or b2 ~= last_b2 then
            last_b1, last_b2 = b1, b2
            local is_on = powerd:isFrontlightOn()
            local intensity = powerd:frontlightIntensityHW()
            powerd.is_fl_on = is_on
            logger.info("PB Frontlight Sysfs Patch: changed -> bled1:", b1, "bled2:", b2, "on:", is_on, "intensity:", intensity)
            powerd:stateChanged()
        end
    end
    UIManager:scheduleIn(POLL_INTERVAL_SEC, pollFrontlightSysfs)
end

UIManager:scheduleIn(POLL_INTERVAL_SEC, pollFrontlightSysfs)
