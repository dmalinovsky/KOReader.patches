local ReaderUI = require("apps/reader/readerui")
local jit = require("jit")

local orig_onReaderReady = ReaderUI.onReaderReady
ReaderUI.onReaderReady = function(self, ...)
    local res
    if orig_onReaderReady then
        res = orig_onReaderReady(self, ...)
    end

    -- First reset init traces
    jit.flush()
    
    -- Clean up memory from the garbage created while opening the book
    -- including dead traces
    collectgarbage("collect")
    collectgarbage("collect")

    return res
end

