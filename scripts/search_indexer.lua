local _forwardSearchIndex = {}
local _reverseSearchIndex = {}

function onInit()
    Interface.onDesktopInit = onDesktopInit;
end

function onDesktopInit()
    buildIndex()
end

function updateSearchByWord(word, searchResults)
    local hits = _forwardSearchIndex[word]
    if (hits or "") == "" then return searchResults end
    for nodeStr, matchClass in pairs(hits) do
        if searchResults[matchClass] == nil then searchResults[matchClass] = {} end
        searchResults[matchClass][nodeStr] = nodeStr
    end
end

function buildIndex()
    local sTime = os.clock()
    for _, recordType in pairs(LibraryData.getRecordTypes()) do
        for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
            for recordNode, isModule  in pairs(SearchManager.getAllFromModules(recordMapping)) do
                local nodeStr = DB.getPath(recordNode)
                connectDBListener(nodeStr, isModule)
                for mVal, _ in pairs(indexRecord(recordNode)) do
                    if (_forwardSearchIndex[mVal] == nil) then _forwardSearchIndex[mVal] = {} end
                    _forwardSearchIndex[mVal][nodeStr] = recordType
                    if (_reverseSearchIndex[nodeStr] == nil) then _reverseSearchIndex[nodeStr] = {} end
                    table.insert(_reverseSearchIndex[nodeStr], mVal)
                end
             end
        end
    end
    for libraryNode, _  in pairs(SearchManager.getAllFromModules("library")) do
        for mVal, mLibNode in pairs(indexLibraryNode(libraryNode)) do
            if (_forwardSearchIndex[mVal] == nil) then _forwardSearchIndex[mVal] = {} end
            local matchClass, _ = DB.getValue(mLibNode, "librarylink")
            _forwardSearchIndex[mVal][mLibNode] = matchClass
        end
    end
    Debug.console("SearchIndexer.onDesktopInit: ", os.clock() - sTime)
end

function connectDBListener(nodeStr, isModule)
    if isModule then
        DB.addHandler(nodeStr, "onIntegrityChange", reindexNode)
    else
        DB.addHandler(nodeStr, "onChildUpdate", reindexNode)
    end
end

function reindexNode(nodeChanged)
    local sTime = os.clock()
    local nodeStr = DB.getPath(nodeChanged)
    local newIdx = indexRecord(nodeChanged)
    local c = 0
    for _, mVal in ipairs(_reverseSearchIndex[nodeStr]) do
        if not newIdx[mVal] then
            _forwardSearchIndex[mVal][nodeStr] = nil
        end
    end
    _reverseSearchIndex[nodeStr] = {}
    for mVal, _ in pairs(newIdx) do
        if (_forwardSearchIndex[mVal] == nil) then _forwardSearchIndex[mVal] = {} end
        if not _forwardSearchIndex[mVal][nodeStr] then
            _forwardSearchIndex[mVal][nodeStr] = true
        end
        c = c + 1
        table.insert(_reverseSearchIndex[nodeStr], mVal)
    end
    Debug.chat("reindex took: ", os.clock() - sTime)
    Debug.chat("Number of tokens: ", c)
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

function tokenizeStr(inStr)
    local tokens = {}
    for word in inStr:gmatch(wordMatchPat) do
        tokens[word] = true
        for subWord in word:gmatch(subWordPat) do
            tokens[subWord] = true
        end
        if word:sub(-3) == "ing" then
            local pref = word:sub(1,-4)
            tokens[pref] = true
            tokens[pref..'e'] = true
        elseif word:sub(-1)  == "s" then
            tokens[word:sub(1,-2)] = true
        elseif word:sub(-2)  == "ed" then
            tokens[word:sub(1,-3)] = true
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
    local nodeVal = SearchManager.getValueOfType(nodeType, endNode)

    for m, _ in pairs(tokenizeStr(string.lower(nodeVal))) do
        indexVals[m] = mVal
    end
    return indexVals
end