local _lastTabList = nil

new_aRecords = {
	["record_browser"] = {
		bExport = true,
		aDataMap = { "record_browser", "reference.record_browser" }
	},
}

function onInit()
    if User.isHost() or User.isLocal() then
        for kRecordType,vRecordType in pairs(new_aRecords) do
            LibraryData.setRecordTypeInfo(kRecordType, vRecordType);
        end
    end
    DB.deleteChildren("temp_browsers")
    Comm.registerSlashHandler("foogle", showBrowser, "/foogle <search string>")
end


function registerLastTabList(lastTabList)
    _lastTabList = lastTabList
end

function lastUsedTabList()
    return _lastTabList
end

function newTempBrowser()
    return DB.createChild("temp_browsers")
end

function newPersistentBrowser()
    return DB.createChild("record_browser")
end

function showBrowser(sCommands, sParams)
    w = Interface.openWindow("record_browser", newTempBrowser())
    if (sParams or "") ~= "" then
        w.activeTab.subwindow.searchBox.setValue(sParams)
        w.activeTab.subwindow.searchBox.onEnter()
    end
end