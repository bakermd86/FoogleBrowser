local _setCallback = nil
local _getCallback = nil
local _layer_offset = 0
local _rh_head_height = 27

function onInit()
    _getCallback = getSize
    _setCallback = setSize
    self.onSizeChanged = handleSizeChanged
    if DB.getParent(getDatabaseNode()).getNodeName() == "temp_browsers" then
        registerMenuItem("Save Browser", "icon_save", 7)
    end
end

function onMenuSelection(selectNum)
    if selectNum == 7 then
        local tempNode = getDatabaseNode()
        if (tempNode or "") == "" then return end
        local savedNode = BrowserManager.newPersistentBrowser()
        if (savedNode or "") == "" then return end
        DB.copyNode(tempNode, savedNode)
        Interface.openWindow("record_browser", savedNode)
        DB.deleteNode(tempNode)
        self.close()
    end
end

function setRecordSize(sizeClass)
    local curW, curH = getSize()
    local classW = DB.getValue(getDatabaseNode(), "sizes." .. sizeClass.."_w", curW)
    local classH = DB.getValue(getDatabaseNode(), "sizes." .. sizeClass.."_h", curH)
--     if sizeClass == "" or sizeClass == "dummy_tab" then
--         classH = _rh_head_height*2 + _layer_offset
--     elseif sizeClass == "record_browser" then
--         classH = _rh_head_height*3 + _layer_offset
--     elseif sizeClass == "search_tab" and classH < (_rh_head_height * 8) then
--         classH = _rh_head_height * 8
--     elseif classH < _rh_head_height * 3 then
--         classH = _rh_head_height * 3
--     end
    _setCallback(classW, classH)
end

function getLayerOffset()
    return _layer_offset
end

function overrideSizeChange(getCallback, setCallback, base_layer_offset)
    _layer_offset = _rh_head_height + base_layer_offset
    _getCallback = getCallback
    _setCallback = setCallback
end

function handleSizeChanged(source)
    local sizeClass = activeTab.getValue()
    local curW, curH = _getCallback()
    if sizeClass ~= "" and sizeClass ~= "dummy_tab" then
        DB.setValue(getDatabaseNode(), "sizes." .. sizeClass.."_w", "number", curW)
        DB.setValue(getDatabaseNode(), "sizes." .. sizeClass.."_h", "number", curH)
    end
    tabs.handleSizeChanged(curW)
end
