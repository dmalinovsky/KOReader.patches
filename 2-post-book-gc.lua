local ReaderUI = require("apps/reader/readerui")

local orig_onReaderReady = ReaderUI.onReaderReady
ReaderUI.onReaderReady = function(self, ...)
    local res
    if orig_onReaderReady then
        res = orig_onReaderReady(self, ...)
    end
    collectgarbage("collect")
    collectgarbage("collect")
    return res
end
