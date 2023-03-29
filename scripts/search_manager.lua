function searchRecords(searchString)
    local matchedRecords = {}
    for _, recordType in pairs(LibraryData.getRecordTypes()) do
--         matchedRecords[recordType] = searchRecordType(LibraryData.getRootMapping(recordType), string.lower(searchString))
        local recordMatches = {}
        for _, recordMapping in ipairs(LibraryData.getMappings(recordType)) do
             for _, resultNode in ipairs(searchRecordType(recordMapping, string.lower(searchString))) do
                recordMatches[DB.getPath(resultNode)] = resultNode
             end
        end
        matchedRecords[recordType] = recordMatches
    end
    for recordType, recordMatches in pairs(searchLibraryRecords(string.lower(searchString))) do
        if (matchedRecords[recordType] or "") == "" then
            matchedRecords[recordType] = recordMatches
        else
            for _, recordMatch in ipairs(recordMatches) do
                table.insert(matchedRecords[recordType], recordMatch)
            end
        end
    end
    return matchedRecords
end

function searchLibraryRecords(searchString)
    local libraryMatches = {}
    for _, libraryNode in ipairs(getAllFromModules("library")) do
        for matchedNode, matched in pairs(walkLibrary(libraryNode, searchString)) do
            if matched then
                local matchClass, _ = DB.getValue(matchedNode, "librarylink")
                if (matchClass or "") ~= "" then
                    libraryMatches[matchedNode]=matchClass
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
        for _, childNode in pairs(DB.getChildrenGlobal(libraryNode)) do
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
    for _, recordNode in ipairs(getAllFromModules(recordType)) do
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
        for _, childNode in pairs(DB.getChildrenGlobal(node)) do
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
        table.insert(nodes, node)
    end
    for _, module in ipairs(Module.getModules()) do
        for name, node in pairs(DB.getChildren(recordType .. "@" .. module)) do
            table.insert(nodes, node)
        end
    end
    return nodes
end