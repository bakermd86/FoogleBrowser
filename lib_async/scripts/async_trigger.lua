local emptyRuns = 0

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
        emptyRuns = emptyRuns + 1
        if emptyRuns > 15 then
            self.onSizeChanged = closeSafe
        end
    end
    setSize(25, 25)
end

function closeSafe()
    AsyncLib.toggleStatus(false)
    AsyncLib.setAsyncActive(false)
    close()
end