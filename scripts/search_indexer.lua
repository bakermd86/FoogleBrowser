local _forwardSearchIndex = {}
local _reverseSearchIndex = {}
local _indexedModules = {}
local _moduleIndexingData = {}
local MODULE_IDX_DATA = "moduleIndexingData"
local INDEX_ON_LOAD = "INDEX_ON_LOAD"
local INDEX_FMT_TEXT = "INDEX_FMT_TEXT"
local INDEX_NON_TEXT = "INDEX_NON_TEXT"
local INDEX_SIMPLE = "INDEX_SIMPLE"
local INDEX_SHOW_STATUS = "INDEX_SHOW_STATUS"
local _indexFmt = nil
local _indexSimple = nil
local _indexNonText = nil
local _indexShowStatus = nil
local _indexOnLoad = nil
local _indexLoaded = false

function onInit()
    Comm.registerSlashHandler("indexMode", setIndexMode, "/indexMode <min|low|normal|high|max>")
    OptionsManager.registerButton("label_option_rebuild_index", "reindex_search", "")
    OptionsManager.registerButton("label_option_module_selection", "module_selection", "")
    for _, o in ipairs({INDEX_FMT_TEXT, INDEX_SHOW_STATUS, INDEX_ON_LOAD}) do
        OptionsManager.registerOption2(o, true, "option_header_search_options", "label_option_"..o, "option_entry_cycler",
        { labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "on" })
    end
    for _, o in ipairs({INDEX_NON_TEXT, INDEX_SIMPLE}) do
        OptionsManager.registerOption2(o, true, "option_header_search_options", "label_option_"..o, "option_entry_cycler",
        { labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" })
    end
    if (CampaignRegistry[MODULE_IDX_DATA] or "") ~= "" then _moduleIndexingData = CampaignRegistry[MODULE_IDX_DATA] end
    loadSettings()
    if _indexOnLoad then
        if User.isHost() or User.isLocal() then
            Interface.onDesktopInit = loadIndex;
        else
            User.getRemoteIdentities("charsheet", GameSystem.requestCharSelectDetailClient(), afterIdHook);
        end
    end
end

-- INDEX_SIMPLE, INDEX_ON_LOAD, ASYNC_PRIORITY, INDEX_FMT_TEXT, INDEX_NON_TEXT, INDEX_ALL_MODULES, INDEX_NO_MODULES

local _modeMap = {
    min = {"on", "off", "-3", "off", "off", false, true},
    low = {"on", "on", "-1", "off", "off", false, false},
    normal = {"off", "on", "auto", "on", "off", false, false},
    high = {"off", "on", "3", "on", "off", false, false},
    max = {"off", "on", "5", "on", "on", true, false},
}

function setIndexMode(sCommand, indexMode)
    if (_modeMap[indexMode] or "") == "" then
        Debug.chat('Unrecognized index mode "' .. indexMode .. '"')
        return
    end
    local idxSimple, idxLoad, asyncPrio, indexFmt, indexNTxt, indexAllMod, indexNoMod = unpack(_modeMap[indexMode])
    OptionsManager.setOption(INDEX_SIMPLE, idxSimple)
    OptionsManager.setOption(INDEX_ON_LOAD, idxLoad)
    OptionsManager.setOption(AsyncLib.ASYNC_PRIORITY, asyncPrio)
    OptionsManager.setOption(INDEX_FMT_TEXT, indexFmt)
    OptionsManager.setOption(INDEX_NON_TEXT, indexNTxt)
    if (indexAllMod or indexNoMod) then
        local _idxSet = indexAllMod and 1 or 0
        for _, module in ipairs(Module.getModules()) do
            if  (_moduleIndexingData[module] or "") ~= "" then
                _moduleIndexingData[module]["isIndexed"] = _idxSet
            end
            CampaignRegistry[MODULE_IDX_DATA] = _moduleIndexingData
        end
    end
end

local _clientHooked = false

function afterIdHook()
    if _clientHooked then return end
    _clientHooked = true
    loadIndex()
end

function loadIndex()
    buildIndex()
    saveIndex()
    if not _indexLoaded then
        connectDBListeners()
        Module.addEventHandler("onModuleLoad", onModuleLoad);
        Module.addEventHandler("onModuleUnload", onModuleUnload);
        _indexLoaded = true
    end
end

function updateSearchByWord(word, weightMod, searchResults)
    local results = 0
    local hits = _forwardSearchIndex[word]
    if (hits or "") == "" then return results end
    for nodeStr, indexData in pairs(hits) do
        local matchClass = indexData["recordType"]
        local weight = indexData["weight"] * weightMod * -1
        if searchResults[matchClass] == nil then searchResults[matchClass] = {} end
        if searchResults[matchClass][nodeStr] == nil then
            searchResults[matchClass][nodeStr] = 0
            results = results + 1
        end
        local nameVal = DB.getValue(DB.findNode(nodeStr), "name", "")
        if string.find(string.lower(nameVal), word) then weight = weight * 2 end
        searchResults[matchClass][nodeStr] = searchResults[matchClass][nodeStr] + weight
    end
    return results
end

function saveIndex()
    CampaignRegistry["indexedModules"] = nil
    CampaignRegistry["storedSearchIndex"] = nil
    CampaignRegistry["reverseSearchIndex"] = nil
    CampaignRegistry["indexAge"] = nil
    CampaignRegistry["indexVer"] = nil
end

function loadSettings()
    _indexFmt = OptionsManager.getOption(INDEX_FMT_TEXT) == "on"
    _indexSimple = OptionsManager.getOption(INDEX_SIMPLE) == "on"
    _indexNonText = OptionsManager.getOption(INDEX_NON_TEXT) == "on"
    _indexShowStatus = OptionsManager.getOption(INDEX_SHOW_STATUS) == "on"
    _indexOnLoad = OptionsManager.getOption(INDEX_ON_LOAD) == "on"
    AsyncLib.setShowStatus(_indexShowStatus)
end

function buildIndex()
    loadSettings()
    _forwardSearchIndex = {}
    _reverseSearchIndex = {}
    _indexedModules = {}
    local nodesToIndex = getIndexNodesAsync()
    local libraryNodesToIndex = getLibraryNodesAsync()
    AsyncLib.scheduleAsync("campaignNodesIndex", runIndexer, nodesToIndex)
    AsyncLib.scheduleAsync("libraryNodesIndex", runIndexer, libraryNodesToIndex)
    getModuleNodesAsync()
    AsyncLib.startAsync()
end

function handleModuleIndexRes(callName, asyncResults, asyncCount, asyncTime)
    local moduleName = callName:sub(1,-11)
    Debug.console("Indexing module " .. moduleName .. " took " .. asyncTime .. " seconds to index " .. asyncCount .. " records")
    _indexedModules[moduleName] = true
    setModuleData(moduleName, 1, asyncTime, asyncCount)
end

function getIndexNodesAsync()
    local nodesToIndex = {}
    for _, recordType in pairs(LibraryData.getRecordTypes()) do
        for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
            for name, recordNode  in pairs(DB.getChildren(recordMapping)) do
                local nIdx = newIndexer(recordNode, recordType, false)
                table.insert(nodesToIndex, nIdx)
             end
        end
    end
    return nodesToIndex
end

function getModuleNodesAsync()
    for _, module in ipairs(Module.getModules()) do
        if Module.getModuleInfo(module)["loaded"] then
            onModuleLoad(module)
        end
    end
end

function getLibraryNodesAsync()
    local libraryNodes = {}
    for libraryNode, _  in pairs(SearchManager.getAllFromModules("library")) do
        local nIdx = newIndexer(libraryNode, nil, true)
        table.insert(libraryNodes, nIdx)
    end
    return libraryNodes
end

function getModuleData(module)
    if _moduleIndexingData[module] then return _moduleIndexingData[module]
    else return {} end
end

function moduleIndexed(module)
    local moduleData = getModuleData(module)
    if (moduleData or "") == "" then return false end
    return moduleData['isIndexed'] == 1
end

function setModuleData(module, isIndexed, lastIdxTime, lastIdxRecords)
    _moduleIndexingData[module] = {
        ['isIndexed'] =  isIndexed,
        ['lastIdxTime'] = lastIdxTime,
        ['lastIdxRecords'] = lastIdxRecords
    }
    CampaignRegistry[MODULE_IDX_DATA] = _moduleIndexingData
end

function onModuleLoad(module)
    if (not moduleIndexed(module)) or (_indexedModules[module]) then return end
    local moduleNodes = {}
    for _, recordType in pairs(LibraryData.getRecordTypes()) do
        for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
            for _, recordNode in pairs(DB.getChildren(recordMapping .. "@" .. module)) do
                local nIdx = newIndexer(recordNode, recordType, false)
                table.insert(moduleNodes, nIdx)
            end
        end
    end
    AsyncLib.scheduleAsync(module .. "NodesIndex", runIndexer, moduleNodes, handleModuleIndexRes)
end

function onModuleUnload(module)
    if not _indexedModules[module] then return end
    local sTime = os.clock()
    for _, recordType in pairs(LibraryData.getRecordTypes()) do
        for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
            for _, recordNode in pairs(DB.getChildren(recordMapping .. "@" .. module)) do
                local nodeStr = DB.getPath(recordNode)
                if _reverseSearchIndex[nodeStr] then
                    for _, mVal in ipairs(_reverseSearchIndex[nodeStr]) do
                        _forwardSearchIndex[mVal][nodeStr] = nil
                    end
                end
                _reverseSearchIndex[nodeStr] = nil
            end
        end
    end
    _indexedModules[module] = nil
    Debug.console("Clearing index for module " .. module .. " took " .. os.clock() - sTime)
end

function connectDBListeners()
    for _, recordType in pairs(LibraryData.getRecordTypes()) do
        for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
            connectRecordTypeListener(recordMapping)
            for _, recordNode  in pairs(DB.getChildren(recordMapping)) do
                connectNodeListener(DB.getPath(recordNode), false)
            end
        end
    end
end

function connectRecordTypeListener(recordMapping)
    DB.addHandler(recordMapping, "onChildAdded", indexNewNode)
end

function connectNodeListener(nodeStr, isModule)
    if isModule then
        DB.addHandler(nodeStr, "onIntegrityChange", reindexNode)
    else
        if (not (User.isHost() or User.isLocal())) and (DB.getParent(nodeStr).getName() == "charsheet") then return end
        DB.addHandler(nodeStr, "onChildUpdate", reindexNode)
    end
end

function indexNewNode(nodeParent, newNode)
    reindexNode(newNode)
    connectNodeListener(DB.getPath(newNode), false)
end

function reindexNode(nodeChanged)
    loadSettings()
    local recordType = LibraryData.getRecordTypeFromRecordPath(DB.getPath(nodeChanged))
    local indexer = newIndexer(nodeChanged, recordType, false)
    indexer.isReindex = true
    local wasActive = AsyncLib.isActive()
    AsyncLib.scheduleAsync("nodeChanged"..indexer.nodeStr, runIndexer, {indexer}, nil, true)
    AsyncLib.startAsync()
    if not wasActive then AsyncLib.toggleStatus(false) end
    saveIndex()
end

function getLibraryDocParent(libraryNode)
    local parentNode = DB.getParent(libraryNode)
    while (parentNode or "") ~= "" do
        if DB.getValue(parentNode, "librarylink") then return DB.getPath(parentNode) end
        parentNode = DB.getParent(parentNode)
    end
end

function typeChecked(nodeType)
    if nodeType == "string" then
        return true
    elseif nodeType == "formattedtext" then
        return _indexFmt and not _indexSimple
    else
        return _indexNonText and not _indexSimple
    end
end

function walkChildren(node)
    local children = {}
    if (node or "") == "" then return children end
    for _, childNode in pairs(DB.getChildren(node)) do
        local nodeType = DB.getType(childNode)
        if nodeType == "node" then
            for _, innerChild in ipairs(walkChildren(childNode)) do
                table.insert(children, innerChild)
            end
        elseif typeChecked(nodeType) then
            table.insert(children, childNode)
        end
    end
    return children
end

function initIndexer(indexer)
    indexer.childNodes = walkChildren(indexer.node)
    indexer.isStarted = true
    indexer.isActive = true
end

function indexNextChild(indexer)
    local nextChild = table.remove(indexer.childNodes)
    for mVal, tokens in pairs(indexEndNode(nextChild, indexer.isLibrary)) do
        if (indexer.node_results[mVal] or "") ~= "" then
            indexer.node_results[mVal]["weight"] = indexer.node_results[mVal]["weight"] + tokens["weight"]
        else
            indexer.node_results[mVal] = tokens
        end
    end
    indexer.isActive = true
end

function clearIndex(indexer)
    if (_reverseSearchIndex[indexer.nodeStr] or "") ~= "" then
        for _, mVal in ipairs(_reverseSearchIndex[indexer.nodeStr]) do
            _forwardSearchIndex[mVal][indexer.nodeStr] = nil
        end
    end
    _reverseSearchIndex[indexer.nodeStr] = {}
end

function updateOnIndex(indexer)
    if indexer.isReindex then
        clearIndex(indexer)
    end
    for mVal, tokens in pairs(indexer.node_results) do
        if (_forwardSearchIndex[mVal] == nil) then _forwardSearchIndex[mVal] = {} end
        local recordType = indexer.recordType
        if indexer.isLibrary then
            local mLibNode = tokens["mVal"]
            recordType, _ = DB.getValue(mLibNode, "librarylink")
        end
        _forwardSearchIndex[mVal][indexer.nodeStr] = { ["recordType"] = recordType, ["weight"] = tokens["weight"] }
        if not indexer.isLibrary then
            if (_reverseSearchIndex[indexer.nodeStr] == nil) then _reverseSearchIndex[indexer.nodeStr] = {} end
            table.insert(_reverseSearchIndex[indexer.nodeStr], mVal)
        end
    end
    indexer.isActive = false
end

function runIndexer(indexer)
    if not indexer.isStarted then
        initIndexer(indexer)
    elseif #indexer.childNodes == 0 then
        updateOnIndex(indexer)
    else
        indexNextChild(indexer)
    end
end

function newIndexer(node, recordType, isLibrary)
    local indexer = {}
    indexer.node = node or ""
    indexer.recordType = recordType or ""
    indexer.nodeType = DB.getType(node)
    indexer.nodeStr = DB.getPath(indexer.node)
    indexer.isActive = false
    indexer.isStarted = false
    indexer.isLibrary = isLibrary or false
    indexer.isReindex = false
    indexer.node_results = {}
    indexer.childNodes = {}
    return indexer
end


local wordMatchPat = "[a-z0-9'`]+"
local subWordPat = "[a-z]+"
local lexicalSuffixes = {
    ["ing"] = {"e", "ed"},
    ["ling"] = {},
    ["ed"] = {"ing", "e"},
    ["s"] = {},
    ["ly"] = {"e"},
    ["ion"] = {"ious"}
}
local lexicalPrefixes = {
    ["un"] = {},
    ["re"] = {},
    ["im"] = {},
    ["in"] = {},
    ["pre"] = {},
    ["post"] = {}
}

function updateWeight(word, weight, tokens)
    if tokens[word] == nil then tokens[word] = 0 end
    tokens[word] = tokens[word] + weight
end

function tokenizeStr(inStr)
    local tokens = {}
    for word in inStr:gmatch(wordMatchPat) do
        tokens[word] = 4
        if not _indexSimple then
            for subWord in word:gmatch(subWordPat) do
                if subWord ~= word then tokens[subWord] = 2 end
            end
            for suffix, alternates in pairs(lexicalSuffixes) do
                local stem = word:gsub(suffix.."$", "")
                if stem ~= word then
                    tokens[stem] = 1
                    for _, newSuf in ipairs(alternates) do
                        tokens[stem..newSuf] = 1
                    end
                end
            end
            for prefix, alternates in pairs(lexicalPrefixes) do
                local tail = word:gsub("^"..prefix, "")
                if tail ~= word then
                    tokens[tail] = 1
                    for _, newPre in ipairs(alternates) do
                        tokens[newPre..stem] = 1
                    end
                end
            end
        end
    end
    return tokens
end

function weightString(inStr)
    local tokenWeights = {}
    for word, baseWeight in pairs(tokenizeStr(inStr)) do
        updateWeight(word, baseWeight, tokenWeights)
    end
    return tokenWeights
end

function indexEndNode(endNode, isLibrary)
    local indexVals = {}
    local mVal = true
    if isLibrary then mVal = getLibraryDocParent(endNode) end
    if (mVal or "") == "" then
        Debug.console("Unable to find library record for node, ", endNode)
        return indexVals
    end
    local nodeType = DB.getType(endNode)
    if (nodeType == "formattedtext") and not _indexFmt then return indexVals
    elseif _indexSimple and (nodeType ~= "string") then
        return indexVals
    elseif (not _indexNonText) and (not (nodeType == "string" or nodeType == "formattedtext")) then
        return indexVals
    end

    local nameMult = 1
    if endNode.getName() == "name" then nameMult = 50
    elseif nodeType == "string" then nameMult = 10
    elseif nodeType == "formattedtext" then nameMult = 0.5
    end

    local nodeVal = SearchManager.getValueOfType(nodeType, endNode)
    for m, weight in pairs(weightString(string.lower(nodeVal))) do
        indexVals[m] = {["mVal"] = mVal, ["weight"] = weight * nameMult}
    end
    return indexVals
end