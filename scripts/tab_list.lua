local _titleWidth = 150

function onInit()
    for _, w in ipairs(getWindows()) do
        w.updateVals()
        w.tabButton.registerCallback(tabCallback)
    end
end
function onListChanged()
    local curW, curH = window.getSize()
    handleSizeChanged(curW)
    BrowserManager.registerLastTabList(self)
end

function onDrop(x, y, draginfo)
    if not draginfo.isType("shortcut") then return end
    local shortcutClass = draginfo.getShortcutData()
    local dbNode = draginfo.getDatabaseNode()

    if (shortcutClass or "") == "" then return
    elseif (dbNode or "") == "" then return end
    addTab(dbNode, shortcutClass, true)
end

function addTab(dbNode, shortcutClass, activate)
    w = self.createWindow()
    w.configure(dbNode, shortcutClass)
    w.tabButton.registerCallback(tabCallback)
    if activate then
        window.activeTab.setValue(shortcutClass, dbNode)
    end
end

function tabCallback(class, node, clear)
    local _activeClass, _activeNode = window.activeTab.getValue()
    if clear then
        if node == _activeNode then
            window.activeTab.setValue("search_tab", window.getDatabaseNode())
        end
    else
        window.activeTab.setValue(class, node)
    end
end

function handleSizeChanged(curW)
    local colCount = getWindowCount()
    local colWidth = (curW - _titleWidth ) / colCount
    self.setColumnWidth(colWidth)
end
