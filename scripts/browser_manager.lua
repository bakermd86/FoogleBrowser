local _lastTabList = nil
local OOB_BROWSE_NODE_REQ = "OOB_BROWSE_NODE_REQ"
local OOB_BROWSE_NODE_RESP = "OOB_BROWSE_NODE_RESP"

new_gmRecords = {
	["record_browser"] = {
		bExport = true,
		aDataMap = { "record_browser", "reference.record_browser" }
	}
}
new_playerRecords = {
	["player_record_browser"] = {
		bNoCategories = true,
		sEditMode = "play",
		sRecordDisplayClass = "record_browser",
		sSidebarCategory = "player",
		aDataMap = { "player_record_browser", "reference.player_record_browser" }
	}
}

function onInit()
    if User.isHost() then
        for kRecordType,vRecordType in pairs(new_gmRecords) do
            LibraryData.setRecordTypeInfo(kRecordType, vRecordType);
        end
        local playerTemp = DB.createNode("player_temp_browsers")
        playerTemp.setPublic(true)
        DB.deleteChildren("temp_browsers")
        DB.deleteChildren("player_temp_browsers")
        OOBManager.registerOOBMsgHandler(OOB_BROWSE_NODE_REQ, self.handleBrowseNodeReq)
    end
    for kRecordType,vRecordType in pairs(new_playerRecords) do
        LibraryData.setRecordTypeInfo(kRecordType, vRecordType);
        OOBManager.registerOOBMsgHandler(OOB_BROWSE_NODE_RESP, self.handleBrowseNodeResp)
    end
    Comm.registerSlashHandler("foogle", showBrowser, "/foogle <search string>")
end


function registerLastTabList(lastTabList)
    _lastTabList = lastTabList
end

function lastUsedTabList()
    return _lastTabList
end

function handleBrowseNodeReq(oobMsg)
    if User.isHost() then
        local newNode = DB.createChild(oobMsg.nodeSource).getNodeName()
        if (oobMsg.tempNode or "") ~= "" then
            DB.copyNode(oobMsg.tempNode, newNode)
        end
        local oobResp = {
            ["type"]=OOB_BROWSE_NODE_RESP,
            ["user"]=oobMsg.user,
            ["nodeName"] = newNode,
            ["searchVal"] = oobMsg.searchVal
        }
        DB.setOwner(newNode, oobMsg.user)
        Comm.deliverOOBMessage(oobResp, oobMsg.User)
    end
end

function handleBrowseNodeResp(oobMsg)
    if User.isHost() then return end
    openBrowser(oobMsg.nodeName, oobMsg.searchVal)
end

function newTempBrowser()
    return DB.createChild("temp_browsers")
end

function persistBrowser(tempNode)
    if User.isHost() then
        local newNode = DB.createChild("record_browser")
        DB.copyNode(tempNode, newNode)
        Interface.openWindow("record_browser", newNode)
        DB.deleteNode(tempNode)
    else
        local oobMsg = {
            ["type"]=OOB_BROWSE_NODE_REQ,
            ["user"]=User.getUsername(),
            ["nodeSource"]="player_record_browser",
            ["tempNode"]=tempNode.getNodeName()
        }
        Comm.deliverOOBMessage(oobMsg, "")
    end
end

function showBrowser(sCommands, sParams)
    if User.isHost() then
        openBrowser(newTempBrowser(), sParams)
    else
        local oobMsg = {
            ["type"]=OOB_BROWSE_NODE_REQ,
            ["user"]=User.getUsername(),
            ["searchVal"]=sParams,
            ["nodeSource"]="player_temp_browsers"
        }
        Comm.deliverOOBMessage(oobMsg, "")
    end
end

function openBrowser(nodeName, searchVal)
    w = Interface.openWindow("record_browser", nodeName)
    if (searchVal or "") ~= "" then
        w.activeTab.subwindow.searchBox.setValue(searchVal)
        w.activeTab.subwindow.searchBox.onEnter()
    end
end