function onInit()
    self.updateVals()
end

function delete()
    self.tabButton.clear()
--     if self.class == "search_tab" then
--         DB.deleteNode(self.node)
--     end
    if (getDatabaseNode() or "") ~= "" then
        DB.deleteNode(getDatabaseNode());
    else
        self.close()
    end
end

function getNamePath()
    return "name"
end

function configure(node, class)
    local desc = DB.getValue(node, self.getNamePath())
    self.name.setValue(desc)
    self.class.setValue(class)
    self.node.setValue(node.getNodeName())
    self.updateVals()
end

function updateVals()
    self.tabButton.setText(self.name.getValue())
    self.tabButton.setRecord(self.node.getValue(), self.class.getValue())
end
