local _recordNode = ""
local _recordClass = ""
local _tabCallback = nil

function registerCallback(tabCallback)
    _tabCallback = tabCallback
    registerMenuItem("Edit Title", "hotkeyedit", 2)
end

function onMenuSelection(selectNum)
    if selectNum == 2 then
        editTitle()
    end
end

function setRecord(recordNode, recordClass)
    _recordNode = recordNode
    _recordClass = recordClass
end

function onButtonPress()
    if (_tabCallback or "") == "" then return
    elseif (_recordNode or "") == "" then return
    elseif (_recordClass or "") == "" then return
    end
    _tabCallback(_recordClass, _recordNode, false)
end

function clear()
    if (_tabCallback or "") == "" then return end
    _tabCallback(_recordClass, _recordNode, true)
end

function onClickRelease(button, x, y)
    if button == 1 then return
    elseif button == 2 then window.delete()
    end
end

function editTitle()
    self.setVisible(false)
    self.setEnabled(false)
    window.name.setVisible(true)
    window.name.setEnabled(true)
    window.name.setFocus(true)
    window.name.setCursorPosition(1)
    window.name.setSelectionPosition(string.len(window.name.getValue())+1)
end

function onDoubleClick()
    editTitle()
    return true
end
