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

local _dumpCount = 0

function sizeTrigger()
    if not AsyncLib.eventLoop() then
        self.onSizeChanged = closeSafe
    end
    local x, y = getSize()
    if _dumpCount < 10 then
        Debug.console(x, y)
        Debug.printstack()
    end
    Debug.console("sizeTrigger", x, y)
    _dumpCount = _dumpCount + 1
    setSize(25, 25)
end

function closeSafe()
    _running = false
    AsyncLib.toggleStatus(false)
    AsyncLib.setAsyncActive(false)
    close()
end