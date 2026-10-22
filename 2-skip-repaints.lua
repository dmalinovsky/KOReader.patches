-- Keep previous screen visible during initial book loading

local UIManager = require("ui/uimanager")

local start_time = os.time()
local SKIP_SECONDS = 15

UIManager.forceRePaint = (function(orig)
    return function(...)
        if os.time() - start_time >= SKIP_SECONDS then
            return orig(...)
        end
    end
end)(UIManager.forceRePaint)
