local ReaderUI = require("apps/reader/readerui")
local jit = require("jit")

local orig_onReaderReady = ReaderUI.onReaderReady
ReaderUI.onReaderReady = function(self, ...)
    local res
    if orig_onReaderReady then
        res = orig_onReaderReady(self, ...)
    end

    -- 1. Clean up memory from the garbage created while opening the book
    collectgarbage("collect")
    collectgarbage("collect")

    -- Flush JIT trace cache filled with book init objects,
    -- so the next page actions will complile without old side-traces.
    jit.flush()

    return res
end

