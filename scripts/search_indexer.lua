local _indexLogicVer = 5
local indexAgeLimit = 5
local _forwardSearchIndex = {}
local _reverseSearchIndex = {}
local _indexedModules = {}
local _moduleIndexingData = {}
local MODULE_IDX_DATA = "moduleIndexingData"
-- local INDEX_MODULES = "INDEX_MODULES"
local INDEX_FMT_TEXT = "INDEX_FMT_TEXT"
local INDEX_NON_TEXT = "INDEX_NON_TEXT"
local INDEX_SIMPLE = "INDEX_SIMPLE"
local INDEX_TIMEOUT = "INDEX_TIMEOUT"
-- local INDEX_PERSIST = "INDEX_PERSIST"
local _indexFmt = nil
local _indexSimple = nil
local _indexStartTime = nil

function onInit()
    OptionsManager.registerButton("label_option_rebuild_index", "reindex_search", "")
    OptionsManager.registerButton("label_option_module_selection", "module_selection", "")
    for _, o in ipairs({INDEX_SIMPLE, INDEX_FMT_TEXT}) do
        OptionsManager.registerOption2(o, true, "option_header_search_options", "label_option_"..o, "option_entry_cycler",
        { labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "on" })
    end
    for _, o in ipairs({INDEX_NON_TEXT}) do
        OptionsManager.registerOption2(o, true, "option_header_search_options", "label_option_"..o, "option_entry_cycler",
        { labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" })
    end
--     CampaignRegistry["storedSearchIndex"] = nil
    Interface.onDesktopInit = loadIndex;
--     loadIndex()
end


function loadIndex()
    if (CampaignRegistry[MODULE_IDX_DATA] or "") ~= "" then _moduleIndexingData = CampaignRegistry[MODULE_IDX_DATA] end
    buildIndex()
    connectDBListeners()
	Module.addEventHandler("onModuleLoad", onModuleLoad);
	Module.addEventHandler("onModuleUnload", onModuleUnload);
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

function processNodeAsync(nodeDef)
    local nodeStr = nodeDef['recordNode']
    local recordType = nodeDef['recordType']
    local recordNode = DB.findNode(nodeStr)
    for mVal, tokens in pairs(indexRecord(recordNode)) do
        if (_forwardSearchIndex[mVal] == nil) then _forwardSearchIndex[mVal] = {} end
        _forwardSearchIndex[mVal][nodeStr] = { ["recordType"] = recordType, ["weight"] = tokens["weight"] }
        if (_reverseSearchIndex[nodeStr] == nil) then _reverseSearchIndex[nodeStr] = {} end
        table.insert(_reverseSearchIndex[nodeStr], mVal)
    end
end

function processNode(recordNode, recordType)
    local nodeStr = DB.getPath(recordNode)
    for mVal, tokens in pairs(indexRecord(recordNode)) do
        if (_forwardSearchIndex[mVal] == nil) then _forwardSearchIndex[mVal] = {} end
        _forwardSearchIndex[mVal][nodeStr] = { ["recordType"] = recordType, ["weight"] = tokens["weight"] }
        if (_reverseSearchIndex[nodeStr] == nil) then _reverseSearchIndex[nodeStr] = {} end
        table.insert(_reverseSearchIndex[nodeStr], mVal)
    end
end

function saveIndex()
    CampaignRegistry["indexedModules"] = nil
    CampaignRegistry["storedSearchIndex"] = nil
    CampaignRegistry["reverseSearchIndex"] = nil
    CampaignRegistry["indexAge"] = nil
    CampaignRegistry["indexVer"] = nil
end

function buildIndex()
    _indexFmt = OptionsManager.getOption(INDEX_FMT_TEXT) == "on"
    _indexSimple = OptionsManager.getOption(INDEX_SIMPLE) == "on"
    _forwardSearchIndex = {}
    _reverseSearchIndex = {}
    _indexedModules = {}
    _indexStartTime = os.clock()

--     buildCampaignIndex()
--     local recordIdxTime = os.clock()

    buildLibraryReferenceIndex()
    local refIdxTime = os.clock()

--     buildModuleIndex()
--     local buildTime = os.clock()
--     saveIndex()
    local nodesToIndex = getIndexNodesAsync()
    local modulesToIndex = getModuleNodesAsync()
    AsyncLib.scheduleAsync("campaignNodesIndex", processNodeAsync, nodesToIndex, handleModuleIndexRes)
    for module, moduleNodes in pairs(modulesToIndex) do
        AsyncLib.scheduleAsync(module .. "NodesIndex", processNodeAsync, moduleNodes, handleModuleIndexRes)
    end

--     Debug.console("SearchIndexer.recordIdxTime: " .. recordIdxTime - _indexStartTime)
--     Debug.console("SearchIndexer.refIdxTime" .. refIdxTime - recordIdxTime)
--     Debug.console("SearchIndexer.moduleIdxTime" .. buildTime - refIdxTime)
--     Debug.console("SearchIndexer.buildIndexTotal: " .. buildTime - _indexStartTime)
--     Debug.console("SearchIndexer.buildIndex: " .. os.clock() - _indexStartTime)
end

function handleModuleIndexRes(callName, asyncResults, asyncCount, asyncTime)
    Debug.chat("Indexing job " .. callName .. " took " .. asyncTime .. " seconds to index " .. asyncCount .. " records")
end

function getIndexNodesAsync()
    local nodesToIndex = {}
    for _, recordType in pairs(LibraryData.getRecordTypes()) do
        for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
            for name, recordNode  in pairs(DB.getChildren(recordMapping)) do
                table.insert(nodesToIndex, {["recordNode"] = DB.getPath(recordNode), ["recordType"] = recordType})
--                 Debug.chat(DB.getPath(recordNode), #nodesToIndex)
             end
        end
    end
    return nodesToIndex
end

function getModuleNodesAsync()
    local modulesToIndex = {}
    for _, module in ipairs(Module.getModules()) do
        if Module.getModuleInfo(module)["loaded"] then
            if (moduleIndexed(module)) and not (_indexedModules[module]) then
                local moduleNodes = {}
                for _, recordType in pairs(LibraryData.getRecordTypes()) do
                    for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
                        for _, recordNode in pairs(DB.getChildren(recordMapping .. "@" .. module)) do
                            table.insert(moduleNodes, {["recordNode"] = DB.getPath(recordNode), ["recordType"] = recordType})
--                             Debug.chat(DB.getPath(recordNode), #nodesToIndex)
                        end
                    end
                end
                modulesToIndex[module] = moduleNodes
            end
        end
    end
    return modulesToIndex
end

function buildCampaignIndex()
    for _, recordType in pairs(LibraryData.getRecordTypes()) do
        for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
            for name, recordNode  in pairs(DB.getChildren(recordMapping)) do
                processNode(recordNode, recordType)
             end
        end
    end
end

function buildLibraryReferenceIndex()
    for libraryNode, _  in pairs(SearchManager.getAllFromModules("library")) do
        for mVal, tokens in pairs(indexLibraryNode(libraryNode)) do
            local mLibNode = tokens["mVal"]
            if (_forwardSearchIndex[mVal] == nil) then _forwardSearchIndex[mVal] = {} end
            local matchClass, _ = DB.getValue(mLibNode, "librarylink")
            _forwardSearchIndex[mVal][mLibNode] = { ["recordType"] = matchClass, ["weight"] = tokens["weight"] }
        end
    end
end

function buildModuleIndex()
    _indexFmt = OptionsManager.getOption(INDEX_FMT_TEXT) == "on"
    _indexSimple = OptionsManager.getOption(INDEX_SIMPLE) == "on"
    for _, module in ipairs(Module.getModules()) do
        if Module.getModuleInfo(module)["loaded"] then
            Debug.console("Loaded module: " .. module, _)
            onModuleLoad(module)
        end
    end
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
    local sTime = os.clock()
    local recordCount = 0
    for _, recordType in pairs(LibraryData.getRecordTypes()) do
        for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
            for _, recordNode in pairs(DB.getChildren(recordMapping .. "@" .. module)) do
                processNode(recordNode, recordType)
                recordCount = recordCount + 1
            end
        end
    end
    _indexedModules[module] = true
    saveIndex()
    setModuleData(module, 1, os.clock() - sTime, recordCount)
    Debug.console("Indexing module " .. module .. " took " .. os.clock() - sTime)
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
    saveIndex()
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
        DB.addHandler(nodeStr, "onChildUpdate", reindexNode)
    end
end

function indexNewNode(nodeParent, newNode)
    reindexNode(newNode)
    connectNodeListener(DB.getPath(newNode), false)
end

function reindexNode(nodeChanged)
    _indexFmt = OptionsManager.getOption(INDEX_FMT_TEXT) == "on"
    _indexSimple = OptionsManager.getOption(INDEX_SIMPLE) == "on"
    local sTime = os.clock()
    local nodeStr = DB.getPath(nodeChanged)
    local recordType = LibraryData.getRecordTypeFromRecordPath(nodeStr)
    local newIdx = indexRecord(nodeChanged)
    local c = 0
    if (_reverseSearchIndex[nodeStr] or "") ~= "" then
        for _, mVal in ipairs(_reverseSearchIndex[nodeStr]) do
            if not newIdx[mVal] then
                _forwardSearchIndex[mVal][nodeStr] = nil
            end
        end
    end
    _reverseSearchIndex[nodeStr] = {}
    for mVal, tokens in pairs(newIdx) do
        if (_forwardSearchIndex[mVal] == nil) then _forwardSearchIndex[mVal] = {} end
        if not _forwardSearchIndex[mVal][nodeStr] then
            _forwardSearchIndex[mVal][nodeStr] = { ["recordType"] = recordType, ["weight"] = tokens["weight"] }
        end
        c = c + 1
        table.insert(_reverseSearchIndex[nodeStr], mVal)
    end
    saveIndex()
end

function indexLibraryNode(libraryNode)
    return indexNode(libraryNode, true)
end

function getLibraryDocParent(libraryNode)
    local parentNode = DB.getParent(libraryNode)
    while (parentNode or "") ~= "" do
        if DB.getValue(parentNode, "librarylink") then return DB.getPath(parentNode) end
        parentNode = DB.getParent(parentNode)
    end
end

function indexRecord(node)
    return indexNode(node, false)
end

function indexNode(node, isLibrary)
    if DB.getType(node) == "node" then
        local node_results = {}
        for _, childNode in pairs(DB.getChildren(node)) do
            local childPath = DB.getPath(childNode)
            for mVal, _ in pairs(indexNode(childNode, isLibrary)) do
                node_results[mVal] = _
            end
        end
        return node_results
    else
        return indexEndNode(node, isLibrary)
    end
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