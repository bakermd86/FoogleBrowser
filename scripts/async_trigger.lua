function onInit()
    self.onMove = moveTrigger
    self.onSizeChanged = sizeTrigger
    activate()
end
function activate()
    AsyncLib.setAsyncActive(true)
    setSize(math.random(100,200),math.random(100,200))
    setPosition(math.random(1000,2000),math.random(1000,2000))
end
function moveTrigger()
    if not AsyncLib.eventLoop() then
        self.onSizeChanged = closeSafe
    end
    local x, y = getSize()
    setSize(math.fmod(x+1,100),math.fmod(y+1,100))
end
function sizeTrigger()
    if not AsyncLib.eventLoop() then
        self.onMove = closeSafe
    end
    local x, y = getPosition()
    setPosition(math.fmod(x+1,1000),math.fmod(y+1,1000))
end
function closeSafe()
    AsyncLib.toggleStatus(false)
    AsyncLib.setAsyncActive(false)
    close()
end