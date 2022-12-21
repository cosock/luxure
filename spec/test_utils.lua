local cosock = require "cosock"
local m = {}

m.wrap = function(cb)
    return function()
        cosock.spawn(cb)
        cosock.run()
    end
end

return m
