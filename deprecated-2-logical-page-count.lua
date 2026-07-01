local ReaderPageMap = require("apps/reader/modules/readerpagemap")
local postInit_orig = ReaderPageMap._postInit

ReaderPageMap._postInit = function(self)
    self.ui.document:buildSyntheticPageMapIfNoneDocumentProvided(1818)

    -- Run original code
    postInit_orig(self)
end
