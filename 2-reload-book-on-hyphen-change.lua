-- See https://github.com/koreader/koreader/issues/13462 for the details.

local ReaderUserHyph = require("apps/reader/modules/readeruserhyph")
local Event = require("ui/event")

ReaderUserHyph.loadUserDictionary = function(self, reload)
    self:loadDictionary(self:isAvailable() and self:getDictionaryPath() or "", reload and true or false)
    self.ui:handleEvent(Event:new("UpdatePos", reload))
end
