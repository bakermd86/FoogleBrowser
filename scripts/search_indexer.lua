local _indexLogicVer = 4
local indexAgeLimit = 5
local _forwardSearchIndex = {}
local _reverseSearchIndex = {}
local _indexedModules = {}
local INDEX_MODULES = "INDEX_MODULES"
local INDEX_REFERENCE = "INDEX_REFERENCE"
local INDEX_FMT_TEXT = "INDEX_FMT_TEXT"
local _indexFmt = nil

function onInit()
    OptionsManager.registerButton("label_option_rebuild_index", "reindex_search", "")
    for _, o in ipairs({INDEX_MODULES, INDEX_REFERENCE, INDEX_FMT_TEXT}) do
        OptionsManager.registerOption2(o, true, "option_header_search_options", "label_option_"..o, "option_entry_cycler",
        { labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "on" })
    end
--     CampaignRegistry["storedSearchIndex"] = nil
--     Interface.onDesktopInit = loadIndex;
    loadIndex()
end

function loadIndex()
    local sTime = os.clock()
    _forwardSearchIndex = CampaignRegistry["storedSearchIndex"]
    _reverseSearchIndex = CampaignRegistry["reverseSearchIndex"]
    _indexedModules = CampaignRegistry["indexedModules"]
    local indexAge = CampaignRegistry["indexAge"]
    local indexVer = CampaignRegistry["indexVer"]
    if (indexAge or "") == "" then indexAge = 1 end
    if ((_forwardSearchIndex or "") == "") or (indexAge > indexAgeLimit) or (_indexLogicVer ~= indexVer) then
        buildIndex()
        indexAge = 1
        CampaignRegistry["indexVer"] = _indexLogicVer
    else
        indexAge = indexAge + 1
    end
    connectDBListeners()
    Debug.console("Loading index took: ", os.clock() - sTime)
    CampaignRegistry["indexAge"] = indexAge
	Module.addEventHandler("onModuleLoad", onModuleLoad);
	Module.addEventHandler("onModuleUnload", onModuleUnload);
end

function updateSearchByWord(word, searchResults)
    local results = 0
    local hits = _forwardSearchIndex[word]
    if (hits or "") == "" then return results end
    for nodeStr, indexData in pairs(hits) do
        local matchClass = indexData["recordType"]
        local weight = indexData["weight"] * -1
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
function getRecords(recordMapping)
    if (recordMapping or "") == "" then return {} end
    if OptionsManager.getOption(INDEX_MODULES) == "on" then
        return SearchManager.getAllFromModules(recordMapping)
    else
        local nodes = {}
        for name, node in pairs(DB.getChildren(recordMapping)) do
            nodes[node] = ""
        end
        return nodes
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
    CampaignRegistry["indexedModules"] = _indexedModules
    CampaignRegistry["storedSearchIndex"] = _forwardSearchIndex
    CampaignRegistry["reverseSearchIndex"] = _reverseSearchIndex
end

function buildIndex()
    _indexFmt = OptionsManager.getOption(INDEX_FMT_TEXT) == "on"
    _forwardSearchIndex = {}
    _reverseSearchIndex = {}
    _indexedModules = {}
    local sTime = os.clock()
    for _, recordType in pairs(LibraryData.getRecordTypes()) do
        for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
            for recordNode, module  in pairs(getRecords(recordMapping)) do
                processNode(recordNode, recordType)
             end
        end
    end
    if OptionsManager.getOption(INDEX_REFERENCE) == "on" then
        for libraryNode, _  in pairs(SearchManager.getAllFromModules("library")) do
            for mVal, tokens in pairs(indexLibraryNode(libraryNode)) do
                local mLibNode = tokens["mVal"]
                if (_forwardSearchIndex[mVal] == nil) then _forwardSearchIndex[mVal] = {} end
                local matchClass, _ = DB.getValue(mLibNode, "librarylink")
                _forwardSearchIndex[mVal][mLibNode] = { ["recordType"] = matchClass, ["weight"] = tokens["weight"] }
            end
        end
    end
    if OptionsManager.getOption(INDEX_MODULES) == "on" then
        for _, module in ipairs(Module.getModules()) do
            Debug.console("Loaded module: ", module, _)
            _indexedModules[module] = Module.getModuleInfo(module)["loaded"]
        end
    end
    saveIndex()
    Debug.console("SearchIndexer.buildIndex: ", os.clock() - sTime)
end

function onModuleLoad(module)
    if (OptionsManager.getOption(INDEX_MODULES) == "off") or (_indexedModules[module]) then return end
    local sTime = os.clock()
    for _, recordType in pairs(LibraryData.getRecordTypes()) do
        for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
            for _, recordNode in pairs(DB.getChildren(recordMapping .. "@" .. module)) do
                processNode(recordNode, recordType)
            end
        end
    end
    _indexedModules[module] = true
    saveIndex()
    Debug.console("Indexing module " .. module .. " took ", os.clock() - sTime)
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
    Debug.console("Clearing index for module " .. module .. " took ", os.clock() - sTime)
end

function connectDBListeners()
    for _, recordType in pairs(LibraryData.getRecordTypes()) do
        for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
            connectRecordTypeListener(recordMapping)
            for recordNode, module  in pairs(getRecords(recordMapping)) do
                local isModule = module ~= ""
                connectNodeListener(DB.getPath(recordNode), isModule)
            end
        end
    end
end

function connectRecordTypeListener(recordMapping)
    Debug.console(recordMapping)
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

function updateWeight(word, weight, tokens)
    if tokens[word] == nil then tokens[word] = 0 end
    tokens[word] = tokens[word] + weight
end

function tokenizeStr(inStr)
    local tokens = {}
    for word in inStr:gmatch(wordMatchPat) do
        updateWeight(word, 4, tokens)
        for subWord in word:gmatch(subWordPat) do
            updateWeight(subWord, 2, tokens)
        end
        if word:sub(-3) == "ing" then
            updateWeight(word:sub(1,-4), 1, tokens)
            updateWeight(word:sub(1,-4)..'e', 1, tokens)
        elseif word:sub(-1)  == "s" then
            updateWeight(word:sub(1,-2), 1, tokens)
        elseif word:sub(-2)  == "ed" then
            updateWeight(word:sub(1,-3), 1, tokens)
        elseif word:sub(-2)  == "ly" then
            updateWeight(word:sub(1,-3), 1, tokens)
            updateWeight(word:sub(1,-2).."e", 1, tokens)
        end
    end
    return tokens
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
    if (nodeType == "formattedtext") and not _indexFmt then return indexVals end

    local nameMult = 1
    if endNode.getName() == "name" then nameMult = 50
    elseif nodeType == "string" then nameMult = 10
    elseif nodeType == "formattedtext" then nameMult = 0.5
    end

    local nodeVal = SearchManager.getValueOfType(nodeType, endNode)
    for m, weight in pairs(tokenizeStr(string.lower(nodeVal))) do
        indexVals[m] = {["mVal"] = mVal, ["weight"] = weight * nameMult}
    end
    return indexVals
end