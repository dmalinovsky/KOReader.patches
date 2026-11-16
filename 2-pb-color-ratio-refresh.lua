-- User patch: Block-ratio HQ color threshold for PocketBook Color devices.
-- Place in koreader/patches/2-pb-color-ratio-refresh.lua
-- Boosts saturation for any color (even on PartialUpdate), while triggering
-- flashing PartialUpdateHQ only when colored 32x32 tiles cover >= 7.5% of the rect.

local Device = require("device")
if not Device:isPocketBook() or not Device:hasColorScreen() then
    return
end

local ffi = require("ffi")
local inkview = ffi.load("inkview")
require("ffi/inkview_h")

local min = math.min
local uint8pt_rodata = ffi.typeof("const uint8_t*")

local COLOR_BLOCK_SIZE = 32
local COLOR_HQ_MIN_RATIO = 0.075

local Screen = Device.screen

local function _getPhysicalRect(fb, x, y, w, h)
    local bb = fb.full_bb or fb.bb
    x, y, w, h = bb:getBoundedRect(x, y, w, h)
    return bb:getPhysicalRect(x, y, w, h)
end

local function _analyzeColorInPhysicalRect(bb, px, py, pw, ph)
    if not bb or pw <= 0 or ph <= 0 then
        return false, false
    end
    local bpp = bb:getBytesPerPixel()
    if bpp ~= 3 and bpp ~= 4 then
        return false, false
    end

    local base = ffi.cast(uint8pt_rodata, bb.data)
    local stride = tonumber(bb.stride)
    local threshold_area = (pw * ph) * COLOR_HQ_MIN_RATIO
    local color_area = 0
    local has_any_color = false

    local step_x = bpp * 2
    local step_y = stride * 2
    local x_limit = px + pw
    local y_limit = py + ph

    for by = py, y_limit - 1, COLOR_BLOCK_SIZE do
        local bh = min(COLOR_BLOCK_SIZE, y_limit - by)
        for bx = px, x_limit - 1, COLOR_BLOCK_SIZE do
            local bw = min(COLOR_BLOCK_SIZE, x_limit - bx)
            local row_start = by * stride + bx * bpp
            local row_span = (bw - 1) * bpp
            local toggle = bw > 1 and bpp or 0
            local shift = 0
            local block_has_color = false

            for _ = 1, bh, 2 do
                for idx = row_start + shift, row_start + row_span, step_x do
                    local r = base[idx]
                    if r ~= base[idx + 1] or r ~= base[idx + 2] then
                        block_has_color = true
                        break
                    end
                end
                if block_has_color then
                    break
                end
                shift = toggle - shift
                row_start = row_start + step_y
            end

            if block_has_color then
                has_any_color = true
                color_area = color_area + bw * bh
                if color_area >= threshold_area then
                    return true, true
                end
            end
        end
    end

    return has_any_color, false
end

local function _shouldUseColorRefresh(fb, px, py, pw, ph, is_full)
    local bb = fb.full_bb or fb.bb
    local has_any_color, has_hq_color = _analyzeColorInPhysicalRect(bb, px, py, pw, ph)
    local is_page_sized = is_full or (pw * ph * 2) >= (fb._vinfo.width * fb._vinfo.height)

    local use_hq = fb.panel_has_color or (is_full and has_any_color or has_hq_color)

    if is_page_sized then
        fb.panel_has_color = has_hq_color
    elseif has_hq_color then
        fb.panel_has_color = true
    end

    return use_hq, has_any_color
end

local function _adjustAreaColours(fb)
    fb.debug("adjusting image color saturation")
    inkview.adjustAreaDefault(fb.data, fb._finfo.line_length, fb._vinfo.width, fb._vinfo.height)
end

local function _updatePartial(fb, x, y, w, h, dither)
    x, y, w, h = _getPhysicalRect(fb, x, y, w, h)
    if w <= 0 or h <= 0 then
        return
    end

    fb.debug("refresh: inkview partial", x, y, w, h, dither)

    local use_hq, has_any_color = _shouldUseColorRefresh(fb, x, y, w, h, false)
    if has_any_color then
        fb:saveCurrentBB()
        _adjustAreaColours(fb)
    end
    if use_hq then
        inkview.PartialUpdateHQ(x, y, w, h)
    else
        inkview.PartialUpdate(x, y, w, h)
    end
    if has_any_color then
        fb:restoreFromSavedBB()
    end
end

local function _updateFull(fb, x, y, w, h, dither)
    fb.debug("refresh: inkview full", x, y, w, h, dither)

    local use_hq, has_any_color = _shouldUseColorRefresh(
        fb, 0, 0, fb._vinfo.width, fb._vinfo.height, true
    )
    if use_hq then
        if has_any_color then
            fb:saveCurrentBB()
            _adjustAreaColours(fb)
        end
        inkview.FullUpdateHQ()
        if has_any_color then
            fb:restoreFromSavedBB()
        end
        return
    end

    inkview.FullUpdate()
end

function Screen:refreshPartialImp(x, y, w, h, dither)
    _updatePartial(self, x, y, w, h, dither)
end

function Screen:refreshFlashPartialImp(x, y, w, h, dither)
    _updatePartial(self, x, y, w, h, dither)
end

function Screen:refreshUIImp(x, y, w, h, dither)
    _updatePartial(self, x, y, w, h, dither)
end

function Screen:refreshFlashUIImp(x, y, w, h, dither)
    _updatePartial(self, x, y, w, h, dither)
end

function Screen:refreshFullImp(x, y, w, h, dither)
    _updateFull(self, x, y, w, h, dither)
end
