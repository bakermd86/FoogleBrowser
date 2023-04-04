
function performSearch()
    local searchString = string.lower(searchBox.getValue())
    if not searchString then return end
    -- local searchResultNode = DB.createChild(window.getDatabaseNode(), "searchResult")
    -- DB.deleteChildren(searchResultNode)
    local resultCount, offset = SearchManager.searchRecords(searchString, searchResult, DB.getPath(getDatabaseNode()))
    self.activePage.setValue(1)
    self.totalResults.setValue(resultCount)
    self.pageOffset.setValue(offset)
    pageLabel.setValue(SearchManager.formatPageLabel(self))
    togglePageButtons(resultCount ~= 0)
    return true
end

function paginate(pageVal)
    local nextPage = self.activePage.getValue()
    local lastPage = SearchManager.getPageCount(self.totalResults.getValue())
    if pageVal == "-2" then nextPage = 1
    elseif pageVal == "2" then nextPage = lastPage
    else nextPage = math.max(math.min(nextPage + pageVal, lastPage), 1) end
    if nextPage ~= self.activePage.getValue() then
        self.activePage.setValue(nextPage)
        local offset = SearchManager.updateSearchDisplay(DB.getPath(getDatabaseNode()), searchResult, nextPage)
        self.pageOffset.setValue(offset)
        pageLabel.setValue(SearchManager.formatPageLabel(self))
    end
end

function togglePageButtons(enabled)
    for _, control in ipairs({pageNext, pageLast, pagePrev, pageFirst}) do
        control.setEnabled(enabled)
    end
end

function reloadSearch()
    local nextPage = self.activePage.getValue()
    local offset = SearchManager.updateSearchDisplay(DB.getPath(getDatabaseNode()), searchResult, nextPage)
    self.pageOffset.setValue(offset)
    pageLabel.setValue(SearchManager.formatPageLabel(self))
    togglePageButtons(self.totalResults.getValue() ~= 0)
end