function onInit()
    Debug.console("onInit")
    self.onMove = moveTrigger
    self.onSizeChanged = sizeTrigger
    activate()
end

function newXY(oldX, oldY)
    local newX = oldX
    local newY = oldY
    while (newX == oldX) do newX = math.random(5, 30) end
    while (newY == oldY) do newY = math.random(5, 30) end
    return newX, newY
end

function resizeRand()
    local x, y = getSize()
    local newX, newY = newXY(x, y)
    setSize(newX, newY)
end

function moveRand()
    local x, y = getPosition()
    local newX, newY = newXY(x, y)
    setPosition(newX, newY)
end

function activate()
    Debug.console("activate")
    AsyncLib.setAsyncActive(true)
    resizeRand()
    moveRand()
end

function moveTrigger()
    Debug.console("moveTrigger")
    if not AsyncLib.eventLoop() then
        self.onSizeChanged = closeSafe
    end
    resizeRand()
end

function sizeTrigger()
    Debug.console("sizeTrigger")
    if not AsyncLib.eventLoop() then
        self.onMove = closeSafe
    end
    moveRand()
end

function closeSafe()
    _running = false
    AsyncLib.toggleStatus(false)
    AsyncLib.setAsyncActive(false)
    close()
end