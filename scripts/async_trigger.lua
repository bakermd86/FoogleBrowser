local _lastx = 0
local _lasty = 0

function onInit()
    self.onSizeChanged = sizeTrigger
    activate()
end

function activate()
    AsyncLib.setAsyncActive(true)
    setSize(25, 25)
end
function sizeTrigger()
    if not AsyncLib.eventLoop() then
        self.onSizeChanged = closeSafe
    end
    setSize(25, 25)
end

function closeSafe()
    _running = false
    AsyncLib.toggleStatus(false)
    AsyncLib.setAsyncActive(false)
    close()
end