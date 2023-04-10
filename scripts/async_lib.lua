local _pendingCalls = {}
local _asyncFunctions = {}
local _activeAsyncArgs = {}
local _resultCallbacks = {}
local _activeAsyncResults = {}
local _asyncCallCount = {}
local _hookedWindows = {}
local _asyncStartTimes = {}
local _asyncActive = false
local _asyncBase = "ASYNC_BASE_"

function onInit()
    math.randomseed(os.time() - os.clock() * 1000);
    Interface.onDesktopInit = self.onDesktopInit
end

function onDesktopInit()
    if not _asyncActive then return end
    unHookDesktop()
    hookDesktop()
end

function hookDesktop()
    if _asyncActive then return end
    local w = Interface.openWindow("async_trigger", "")
    _asyncActive = true
    if (w or "") ~= "" then
        w.setPosition(math.random(200,1000),math.random(200,1000))
    end
end

function unHookDesktop()
    _asyncActive = false
    local w = Interface.findWindow("async_trigger", "")
    if (w or "") ~= "" then
        w.close()
    end
end

function isActive()
    return _asyncActive
end

function eventLoop()
    local sTime = os.clock()
    while os.clock() - sTime < 0.010 do
        local finishedJobs = {}
        local asyncCount = 0
        for callName, callArgs in pairs(_activeAsyncArgs) do
            if handleAsyncOOB(callName, callArgs) then
                asyncCount = asyncCount + 1
            else
                table.insert(finishedJobs, callName)
            end
        end
        for _, callName in ipairs(finishedJobs) do
            asyncCallComplete(callName)
        end
        if asyncCount == 0 then
            unHookDesktop()
            return false
        end
    end
    return true
end

function asyncCallComplete(callName)
    _activeAsyncArgs[callName] = nil
    _asyncFunctions[callName] = nil
    local asyncResults = _activeAsyncResults[callName]
    local callbackFn = _resultCallbacks[callName]
    local sTime = _asyncStartTimes[callName]
    local asyncCount = _asyncCallCount[callName]
    if (callbackFn or "") ~= "" then callbackFn(callName, asyncResults, asyncCount, os.clock() - sTime) end
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
--     local callName = _asyncBase..math.random(10000, 99999)
    if (callArgs or "") == "" then return end
    Debug.chat("Scheduling async call: ".. callName, #callArgs)
    _asyncFunctions[callName] = targetFn
    _activeAsyncArgs[callName] = callArgs
    _resultCallbacks[callName] = callbackFn
    _asyncStartTimes[callName] = os.clock()
    _asyncCallCount[callName] = #callArgs
    _activeAsyncResults[callName] = {}
    hookDesktop()
end