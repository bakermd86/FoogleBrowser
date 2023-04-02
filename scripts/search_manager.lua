local OOB_SEARCH = "OOB_SEARCH"
local _activeSearchesMap = {}

local _sTime = nil
local _commTime = nil

function searchRecords(searchString, searchResultNode)
    local searchResults = {}
    local startTime = os.clock()
    for word, _ in pairs(SearchIndexer.tokenizeStr(searchString)) do
       SearchIndexer.updateSearchByWord(word, searchResults)
    end

    local librarySearchTime = os.clock()
    updateSearchDisplay(searchResults, searchResultNode, searchString)
    local endTime = os.clock()
    Debug.console("Lib search time: ", librarySearchTime - startTime)
    Debug.console("result update time: ", endTime - librarySearchTime)
    Debug.console("Total time: ", endTime - startTime)
--     return searchResults
end

function updateSearchDisplay(searchResults, searchResultNode, searchString)
    for recordType, recordNodes in pairs(searchResults) do
        for recordPath, weight in pairs(recordNodes) do
            local recordNode = DB.findNode(recordPath)
            local outputNode = DB.createChild(searchResultNode)
            local displayType = LibraryData.getDisplayText(recordType)
            if (displayType or "") == "" then
                DB.setValue(outputNode, "class", "string", recordType)
            else
                DB.setValue(outputNode, "class", "string", displayType)
            end
            local nameVal = DB.getValue(recordNode, "name", "unknown")
            DB.setValue(outputNode, "name", "string", nameVal)
            local linkClass = LibraryData.getRecordDisplayClass(recordType, recordPath)
            if (linkClass or "") == "" then
                DB.setValue(outputNode, "link", "windowreference", recordType, recordPath)
            else
                DB.setValue(outputNode, "link", "windowreference", linkClass, recordPath)
            end
            if string.find(string.lower(nameVal), searchString) then weight = weight*5 end
            DB.setValue(outputNode, "weight", "number", weight*-1)
            local mIdx = string.find(recordPath, "@")
            if mIdx then
                DB.setValue(outputNode, "moduleSrc", "string", recordPath:sub(mIdx+1))
            else
                DB.setValue(outputNode, "moduleSrc", "string", "Campaign")
            end
        end
    end
    return true
end

function searchLibraryRecords(searchString)
    local libraryMatches = {}
    for libraryNode, _ in pairs(getAllFromModules("library")) do
        for matchedNode, matched in pairs(walkLibrary(libraryNode, searchString)) do
            if matched then
                local matchClass, _ = DB.getValue(matchedNode, "librarylink")
                if (matchClass or "") ~= "" then
                    libraryMatches[DB.getPath(matchedNode)]=matchClass
                end
            end
        end
    end
    local matchedRecords = {}
    for matchNode, matchClass in pairs(libraryMatches) do
        if (matchedRecords[matchClass] or "") == "" then
            matchedRecords[matchClass] = {}
        end
        table.insert(matchedRecords[matchClass], matchNode)
    end
    return matchedRecords
end

function walkLibrary(libraryNode, searchString)
    if DB.getType(libraryNode) == "node" then
        local nodeHits = {}
        for _, childNode in pairs(DB.getChildren(libraryNode)) do
            for matchedNode, matched in pairs(walkLibrary(childNode, searchString)) do
                if matched then
                    nodeHits[matchedNode] = matched
                end
            end
        end
        return nodeHits
    else
        return {[DB.getParent(libraryNode)]=searchEndNode(libraryNode, searchString)}
    end
end
function getValueOfType(nodeType, node)
    if nodeType == "string" or nodeType == "number" or nodeType == "formattedtext" then
        return DB.getText(node)
    elseif nodeType == "image" then
        local imageTable = DB.getValue(node)
        if (imageTable or "") == "" then return "" end
        local imagePath = imageTable["image"]
        if (imagePath or "") == "" then return "" end
        return imagePath
    elseif nodeType == "dice" then
        return StringManager.convertDiceToString(DB.getValue(node))
    end
    return ""
end

function searchRecordType(recordType, searchString)
    local matchedNodes = {}
    for recordNode, _  in pairs(getAllFromModules(recordType)) do
        if searchNode(recordNode, searchString) then
            table.insert(matchedNodes, recordNode)
        end
    end
    return matchedNodes
end

function searchEndNode(endNode, searchString)
    local nodeType = DB.getType(endNode)
    local nodeVal = getValueOfType(nodeType, endNode)
    if (nodeVal or "") == "" then return false
    else return string.find(string.lower(nodeVal), searchString)
    end
end

function searchNode(node, searchString)
    if DB.getType(node) == "node" then
        for _, childNode in pairs(DB.getChildren(node)) do
             if searchNode(childNode, searchString) then
                return true
            end
        end
    else
        return searchEndNode(node, searchString)
    end
    return false
end

function getAllFromModules(recordType)
    local nodes = {}
    if (recordType or "") == "" then return nodes end
    for name, node in pairs(DB.getChildren(recordType)) do
        nodes[node] = ""
    end
    for _, module in ipairs(Module.getModules()) do
        if Module.getModuleInfo(module)["loaded"] then
            for name, node in pairs(DB.getChildren(recordType .. "@" .. module)) do
                nodes[node] = module
            end
        end
    end
    return nodes
end