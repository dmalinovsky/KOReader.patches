-- User patch: Single-stripe color refresh for PocketBook Color devices.
-- Place in koreader/patches/2-pb-color-stripe-refresh.lua
-- Survives KOReader OTA updates without modifying koreader-base files.

local Device = require("device")
if not Device:isPocketBook() or not Device:hasColorScreen() then
    return
end

local ffi = require("ffi")
local inkview = ffi.load("inkview")
require("ffi/inkview_h")

local min, max = math.min, math.max
local uint8pt_rodata = ffi.typeof("const uint8_t*")

local Screen = Device.screen
Screen.color_y = nil
Screen.color_h = nil

local function _getPhysicalRect(fb, x, y, w, h)
    local bb = fb.full_bb or fb.bb
    x, y, w, h = bb:getBoundedRect(x, y, w, h)
    return bb:getPhysicalRect(x, y, w, h)
end

-- Find the minimal horizontal stripe [y, y + h) containing non-grayscale pixels in a physical rect.
-- Uses a staggered 2x2 pixel grid (4x fewer reads, half the DRAM scanlines) with 3px boundary padding.
local function _getColorStripe(bb, px, py, pw, ph)
    if not bb or pw <= 0 or ph <= 0 then
        return nil, nil
    end
    local bpp = bb:getBytesPerPixel()
    if bpp ~= 3 and bpp ~= 4 then
        return nil, nil
    end

    local base = ffi.cast(uint8pt_rodata, bb.data)
    local stride = tonumber(bb.stride)
    local y_end = py + ph - 1
    local x_offset = px * bpp
    local row_span = (pw - 1) * bpp
    local step_x = bpp * 2
    local step_y = stride * 2
    local toggle = pw > 1 and bpp or 0

    -- Scan top-down every 2nd row, alternating horizontal start by 1px to catch thin vertical strokes.
    local min_y
    local shift = 0
    local row_start = py * stride + x_offset
    for y = py, y_end, 2 do
        for idx = row_start + shift, row_start + row_span, step_x do
            local r = base[idx]
            if r ~= base[idx + 1] or r ~= base[idx + 2] then
                min_y = y
                break
            end
        end
        if min_y then
            break
        end
        shift = toggle - shift
        row_start = row_start + step_y
    end

    if not min_y then
        return nil, nil
    end

    -- Scan bottom-up every 2nd row down to min_y + 1 for the last row with color.
    local max_y = min_y
    shift = 0
    row_start = y_end * stride + x_offset
    for y = y_end, min_y + 1, -2 do
        local found = false
        for idx = row_start + shift, row_start + row_span, step_x do
            local r = base[idx]
            if r ~= base[idx + 1] or r ~= base[idx + 2] then
                max_y = y
                found = true
                break
            end
        end
        if found then
            break
        end
        shift = toggle - shift
        row_start = row_start - step_y
    end

    -- Expand by 3 rows to cover skipped odd scanlines, staggered 1px strokes, and CFA 2x2 pairs.
    min_y = max(py, min_y - 3)
    max_y = min(y_end, max_y + 3)
    return min_y, max_y - min_y + 1
end

local function _intersectStripes(ay, ah, by, bh)
    if not ah or not bh then
        return nil, nil
    end
    local y1 = max(ay, by)
    local y2 = min(ay + ah, by + bh)
    if y2 <= y1 then
        return nil, nil
    end
    return y1, y2 - y1
end

local function _unionStripes(ay, ah, by, bh)
    if not ah then
        return by, bh
    end
    if not bh then
        return ay, ah
    end
    local y1 = min(ay, by)
    local y2 = max(ay + ah, by + bh)
    return y1, y2 - y1
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

    local bb = fb.full_bb or fb.bb
    local oy, oh = _intersectStripes(fb.color_y, fb.color_h, y, h)
    local ny, nh = _getColorStripe(bb, x, y, w, h)

    -- Replace stored color stripe on page-sized updates (>= 50% of screen); expand on smaller color UI updates.
    if (w * h * 2) >= (fb._vinfo.width * fb._vinfo.height) then
        fb.color_y, fb.color_h = ny, nh
    elseif nh then
        fb.color_y, fb.color_h = _unionStripes(fb.color_y, fb.color_h, ny, nh)
    end

    local hq_y, hq_h = _unionStripes(oy, oh, ny, nh)
    if not hq_h then
        inkview.PartialUpdate(x, y, w, h)
        return
    end

    -- Refresh the whole frame fast first when the HQ stripe is under half the frame height;
    -- otherwise skip PartialUpdate and refresh the entire frame once with PartialUpdateHQ.
    if hq_h * 2 < h then
        inkview.PartialUpdate(x, y, w, h)
    else
        hq_y, hq_h = y, h
    end

    if nh then
        fb:saveCurrentBB()
        _adjustAreaColours(fb)
    end

    fb.debug("refresh: inkview partial HQ", x, hq_y, w, hq_h)
    inkview.PartialUpdateHQ(x, hq_y, w, hq_h)

    if nh then
        fb:restoreFromSavedBB()
    end
end

local function _updateFull(fb, x, y, w, h, dither)
    fb.debug("refresh: inkview full", x, y, w, h, dither)

    local bb = fb.full_bb or fb.bb
    local had_color = fb.color_h ~= nil
    local ny, nh = _getColorStripe(bb, 0, 0, fb._vinfo.width, fb._vinfo.height)
    fb.color_y, fb.color_h = ny, nh

    if had_color or nh then
        if nh then
            fb:saveCurrentBB()
            _adjustAreaColours(fb)
        end
        inkview.FullUpdateHQ()
        if nh then
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