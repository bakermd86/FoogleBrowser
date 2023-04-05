local OOB_SEARCH = "OOB_SEARCH"
local _activeSearchesMap = {}
local _pageLimit = 50
local _sTime = nil
local _commTime = nil

function searchRecords(searchString, searchResultWin, searchSource, filterCriteria)
    local searchResults = {}
    local startTime = os.clock()
    local results = 0
    for word, weightMod in pairs(SearchIndexer.tokenizeStr(searchString)) do
       results = results + SearchIndexer.updateSearchByWord(word, weightMod, searchResults)
    end

    local librarySearchTime = os.clock()
    saveSearchResults(searchSource, searchResults)
    local offset, filterResults = updateSearchDisplay(searchSource, searchResultWin, filterCriteria, 1)
    local endTime = os.clock()
    Debug.console("Lib search time: ", librarySearchTime - startTime)
    Debug.console("result update time: ", endTime - librarySearchTime)
    Debug.console("Total results found: ", results)
    Debug.console("Filtered results found: ", filterResults)
    Debug.console("Total time: ", endTime - startTime)
    return filterResults, offset
end

function saveSearchResults(searchSource, searchResults)
    local resultWeights, recordsByWeight = sortResultsByWeight(searchResults)
    _activeSearchesMap[searchSource] = {["recordsByWeight"] = recordsByWeight, ["resultWeights"] = resultWeights }
end

function loadSearchResults(searchSource)
    local cachedResult = _activeSearchesMap[searchSource]
    if not cachedResult then return {}, {} end
    return cachedResult["resultWeights"], cachedResult["recordsByWeight"]
end

function sortResultsByWeight(searchResults)
    local resultWeights = {}
    local recordsByWeight = {}
    for recordType, recordNodes in pairs(searchResults) do
        for recordPath, weight in pairs(recordNodes) do
            if recordsByWeight[weight] == nil then recordsByWeight[weight] = {} end
            recordsByWeight[weight][recordPath] = recordType
        end
    end
    for weight, _ in pairs(recordsByWeight) do
        table.insert(resultWeights, weight)
    end
    table.sort(resultWeights)
    return resultWeights, recordsByWeight
end

function getPageCount(totalRes)
  local lastP = (totalRes % _pageLimit)
  local trailPage = (lastP > 0 and 1 or 0)
  return ((totalRes - lastP ) / _pageLimit ) + trailPage
end

function formatPageLabel(searchTab)
    local activePage = searchTab.activePage.getValue()
    local totalResults = searchTab.totalResults.getValue()
    local pageOffset = searchTab.pageOffset.getValue()
    return "Showing " .. (((activePage-1) * _pageLimit) + 1) .. " to " .. pageOffset .. " of " .. totalResults
end

function updateSearchDisplay(searchSource, searchResultWin, filterCriteria, page)
    local offset = -1
    local filterResults = 0
    local pageMin = ((page-1) * _pageLimit) + 1
    local pageMax = page * _pageLimit
    searchResultWin.closeAll()
    local resultWeights, recordsByWeight = loadSearchResults(searchSource)
    if not resultWeights then return 0, 0 end
    for _, weight in ipairs(resultWeights) do
        for recordPath, recordType in pairs(recordsByWeight[weight]) do
            local recordNode = DB.findNode(recordPath)

            local displayType = LibraryData.getDisplayText(recordType)
            if (displayType or "") == "" then displayType = recordType end

            local nameVal = DB.getValue(recordNode, "name", "unknown")

            local linkClass = LibraryData.getRecordDisplayClass(recordType, recordPath)
            if (linkClass or "") == "" then linkClass = recordType end

            local mIdx = string.find(recordPath, "@")
            local moduleSrc = "Campaign"
            if mIdx then moduleSrc = recordPath:sub(mIdx+1) end

            if applySearchFilter(nameVal, displayType, moduleSrc, filterCriteria) then
                filterResults = filterResults + 1
                if (pageMin <= filterResults) and (filterResults <= pageMax) then
                    local resultWindow = searchResultWin.createWindow()
                    resultWindow.class.setValue(displayType)
                    resultWindow.name.setValue(nameVal)
                    resultWindow.link.setValue(linkClass, recordPath)
                    resultWindow.weight.setValue(weight)
                    resultWindow.moduleSrc.setValue(moduleSrc)
                    offset = offset + 1
                end
            end
        end
    end
    return pageMin+offset, filterResults
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

function failFilterType(filterCriteria, inVal, filterType)
    return filterCriteria[filterType] and not string.find(string.lower(inVal), filterCriteria[filterType])
end

function applySearchFilter(nameVal, displayType, moduleSrc, filterCriteria)
    if failFilterType(filterCriteria, nameVal, "filterName") then return false
    elseif failFilterType(filterCriteria, displayType, "filterClass") then return false
    elseif failFilterType(filterCriteria, moduleSrc, "filterModuleSrc") then return false
    end
    return true
end