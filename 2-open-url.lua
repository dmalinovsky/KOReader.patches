local Device = require("device")
local ReaderHighlight = require("apps/reader/modules/readerhighlight")
local util = require("util")

local init_orig = ReaderHighlight.init

ReaderHighlight.init = function(self)
  init_orig(self)
  
  self:addToHighlightDialog("08_open_url", function(this)
            return {
                text = "Open as URL",
                callback = function()
                    local text = util.cleanupSelectedText(this.selected_text.text)
                    this:onClose()
                    Device:openLink(text)
                end,
            }
        end)
end
