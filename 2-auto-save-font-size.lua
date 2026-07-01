local ReaderFont = require("apps/reader/modules/readerfont")
local onSetFontSize_orig = ReaderFont.onSetFontSize

ReaderFont.onSetFontSize = function(self, size)
    -- Run original code
    res = onSetFontSize_orig(self, size)
  
    G_reader_settings:saveSetting("copt_font_size", size)
    return res
end
