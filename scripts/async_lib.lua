local _pendingCalls = {}
local _asyncFunctions = {}
local _activeAsyncArgs = {}
local _resultCallbacks = {}
local _activeAsyncResults = {}
local _asyncCallCount = {}
local _asyncStartTimes = {}
local _callWins = {}
local _activeCall = ""
local _asyncActive = false
local _showIndexStatus = false

function onInit()
    math.randomseed(os.time() - os.clock() * 1000);
    Interface.onDesktopInit = self.onDesktopInit
end

function setShowIndex(bStatus)
    _showIndexStatus = bStatus
end

function onDesktopInit()
    if not _asyncActive then return end
    unHookDesktop()
    hookDesktop()
end

function startAsync()
    hookDesktop()
end

function hookDesktop()
    local w = Interface.openWindow("async_trigger", "")
    local statusWin = Interface.findWindow("asyncstatuspanel", "")
    _asyncActive = true
    if (w or "") ~= "" then
        w.setPosition(math.random(200,1000),math.random(200,1000))
    end
    if (statusWin or "") ~= "" then
        statusWin.status.setVisible(_showIndexStatus)
    end
end

function unHookDesktop()
    _asyncActive = false
    local w = Interface.findWindow("async_trigger", "")
    local statusWin = Interface.findWindow("asyncstatuspanel", "")
    if (w or "") ~= "" then
        w.close()
    end
    if (statusWin or "") ~= "" then
        statusWin.status.setVisible(false)
    end
end

function eventLoop()
    local finishedJobs = {}
    local asyncCount = 0
    if (_activeCall or "") == "" then
        _activeCall = table.remove(_pendingCalls, 1)
        local callWin = _callWins[_activeCall]
        callWin.jobStatus.setValue("Running")
        _asyncStartTimes[_activeCall] = os.clock()
    end
    local callArgs = _activeAsyncArgs[_activeCall]
    if not handleAsyncOOB(_activeCall, callArgs) then
        if asyncCallComplete(_activeCall) then
            unHookDesktop()
            return false
        end
    end
    return true
end

function asyncCallComplete(callName)
    _activeCall = ""
    _activeAsyncArgs[callName] = nil
    _asyncFunctions[callName] = nil
    local asyncResults = _activeAsyncResults[callName]
    local callbackFn = _resultCallbacks[callName]
    local sTime = _asyncStartTimes[callName]
    local asyncCount = _asyncCallCount[callName]
    local callWin = _callWins[callName]
    callWin.close()
    _callWins[callName] = nil
    if (callbackFn or "") ~= "" then callbackFn(callName, asyncResults, asyncCount, os.clock() - sTime) end
    return #_pendingCalls == 0
end

function unRegisterAsyncFunction(callName)
    _asyncFunctions[callName] = nil
end

function handleAsyncOOB(callName, callArgs)
    if ((callArgs or "") == "") or (#callArgs == 0) then return false end
    local targetFn = _asyncFunctions[callName]
    local nextArg = table.remove(callArgs)
    local cRes = targetFn(nextArg)
    if (cRes or "") ~= "" then table.insert(_activeAsyncResults[callName], cRes) end
    return true
end

function scheduleAsync(callName, targetFn, callArgs, callbackFn)
    if (callArgs or "") == "" then return end
    Debug.console("Scheduling async call: ".. callName, #callArgs)
    table.insert(_pendingCalls, callName)
    _asyncFunctions[callName] = targetFn
    _activeAsyncArgs[callName] = callArgs
    _resultCallbacks[callName] = callbackFn
    _asyncCallCount[callName] = #callArgs
    _activeAsyncResults[callName] = {}
    local statusWin = Interface.findWindow("asyncstatuspanel", "")
    local callWin = statusWin.status.subwindow.async_tasks.createWindow()
    callWin.jobName.setValue(callName)
    callWin.jobStatus.setValue("Queued")
    _callWins[callName] = callWin
end