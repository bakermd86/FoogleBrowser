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
local _showStatus = false
local _asyncPriority = nil
local _priorityCounter = -1
local _priorityMap = {
    ["-3"] = 1,
    ["-2"] = 4,
    ["-1"] = 16,
    ["1"] = 32,
    ["2"] = 64,
    ["3"] = 128,
    ["4"] = 256,
    ["5"] = 512,
    ["block"] = 1000000
}
ASYNC_PRIORITY = "ASYNC_PRIORITY"

function onInit()
    math.randomseed(os.time() - os.clock() * 1000);
    Interface.onDesktopInit = self.onDesktopInit
	OptionsManager.registerOption2(ASYNC_PRIORITY, true, "option_header_async_options", "label_option_SCHEDULE_FACTOR", "option_entry_cycler",
        { labels = "option_val_2|option_val_3|option_val_4|option_val_5|option_val_block|option_val_3n|option_val_2n|option_val_1n", values = "2|3|4|5|block|-3|-2|-1", baselabel = "option_val_1", baseval = "1", default = "1" });
end

function setShowStatus(bStatus)
    _showStatus = bStatus
end

function onDesktopInit()
    toggleStatus(false)
    if not _asyncActive then return end
    hookDesktop()
end

function startAsync()
    if OptionsManager.getOption(ASYNC_PRIORITY) == "block" then _showStatus = false end
    hookDesktop()
end

function toggleStatus(showStatus)
    local statusWin = Interface.findWindow("asyncstatuspanel", "")
    if (statusWin or "") ~= "" then
        statusWin.status.setVisible(showStatus)
    end
end

function hookDesktop()
    local w = Interface.openWindow("async_trigger", "")
    toggleStatus(_showStatus)
end

function setAsyncActive(asyncActive)
    _asyncActive = asyncActive
end

function eventLoop()
    if( #_pendingCalls == 0) and (_activeCall == "") then return false end
    local sTime = os.clock()
    _asyncPriority = OptionsManager.getOption(ASYNC_PRIORITY)
    local lCount = 0
    local lPrio = _priorityMap[_asyncPriority]
    if lPrio < 1 then
        if _priorityCounter >= lPrio then
            lPrio = 1
            _priorityCounter = -1
        else
            _priorityCounter = _priorityCounter - 1
        end
    end
    while lCount < lPrio do
        if (_activeCall or "") == "" then
            _activeCall = table.remove(_pendingCalls, 1)
            Debug.console("eventLoop() start call: ", _activeCall)
            if (_activeCall or "") == "" then return false end
            local callWin = _callWins[_activeCall]
            if (callWin or "") ~= "" then callWin.jobStatus.setValue("Running") end
            _asyncStartTimes[_activeCall] = os.clock()
        end
        local callArgs = _activeAsyncArgs[_activeCall]
        lCount = lCount + 1
        if not handleAsyncOOB(_activeCall, callArgs) then
            if asyncCallComplete(_activeCall) then
                return false
            end
        end
    end
    return true
end

function asyncCallComplete(callName)
    Debug.console("asyncCallComplete() Enter: ".. callName)
    _activeCall = ""
    _activeAsyncArgs[callName] = nil
    _asyncFunctions[callName] = nil
    local asyncResults = _activeAsyncResults[callName]
    local callbackFn = _resultCallbacks[callName]
    local sTime = _asyncStartTimes[callName]
    local asyncCount = _asyncCallCount[callName]
    local callWin = _callWins[callName]
    if (callWin or "") ~= "" then callWin.close() end
    _callWins[callName] = nil
    if (callbackFn or "") ~= "" then callbackFn(callName, asyncResults, asyncCount, os.clock() - sTime) end
    return #_pendingCalls == 0
end

function handleAsyncOOB(callName, callArgs)
    if ((callArgs or "") == "") or (#callArgs == 0) then return false end
    local targetFn = _asyncFunctions[callName]
    local nextArg = callArgs[#callArgs]
    local cRes = targetFn(nextArg)
    if not nextArg.isActive then
        table.remove(callArgs)
    end
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