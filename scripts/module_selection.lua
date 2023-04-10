function onInit()
    modules.closeAll()
    for _, module in ipairs(Module.getModules()) do
        if Module.getModuleInfo(module)["loaded"] then
            local w = modules.createWindow()
            local moduleData = SearchIndexer.getModuleData(module)
            local isIndexed = 0
            local lastIndexTime = 0
            local lastIndexRecords = 0
            if moduleData['isIndexed'] then isIndexed = moduleData['isIndexed'] end
            if moduleData['lastIdxTime'] then lastIndexTime = moduleData['lastIdxTime'] end
            if moduleData['lastIdxRecords'] then lastIndexRecords = moduleData['lastIdxRecords'] end
            w.moduleName.setValue(module)
            w.selected.setValue(isIndexed)
            w.lastIndexTime.setValue(string.sub(lastIndexTime, 1, 5)..'s')
            w.lastIndexRecords.setValue(lastIndexRecords)
        end
    end
end

function saveAndClose()
    local sTime = os.clock()
    for _, w in ipairs(modules.getWindows()) do
        local moduleName = w.moduleName.getValue()
        local selected = w.selected.getValue()
        local lastIndexTime = w.lastIndexTime.getValue()
        local lastIndexRecords = w.lastIndexRecords.getValue()
        SearchIndexer.onModuleUnload(moduleName)
        SearchIndexer.setModuleData(moduleName, selected, lastIndexTime, lastIndexRecords)
    end
    SearchIndexer.getModuleNodesAsync()
    AsyncLib.startAsync()
    self.close()
end