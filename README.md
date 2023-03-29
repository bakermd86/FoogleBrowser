## FG Browser

This is an extension for Fantasy Grounds Unity that adds a browser-style functionality for the purposes of organizing 
and searching records and reference library data. 

I made it for my own purposes as I was having a hard time managing all of the campaign records in a long-running game 
with a lot of recurring NPCs and other campaign records. 

I also wanted a search feature to be able to perform full-text search of all records and library data in a single place, 
because I would often forget where something was and wanted an easier way to find NPCs based on data in their notes, 
find story records based on their content, or search the library reference data.

The example screenshots below are taken from the 5e ruleset just because that is a very popular game system, 
but the extension should work with pretty much any ruleset based on CoreRPG. I myself use it in my own homebrew ruleset.

## Installation 
Download FGBrowser.ext and place in the Extensions directory of your Fantasy Grounds data folder, or just use the Forge.
I will update here with the forge link when it is approved on the Forge.

## Usage

It can be used in 2 ways, as a campaign record type, or as dynamic browser windows that will not be stored permanently.

To create a persisted browser type campaign record, it is available under the "Browsers" campaign record type on the sidebar. 
You can create a blank browser and add records either by drag/dropping them into the tab list, or by using the search page 
to look up records. Here is an example:

![](doc/5e_manual_example.gif)

When using the search page, you can use the filter field at the bottom to filter the results by record class. You can either 
left-click on search results to open them in a new tab and immediately switch to the tab, or middle-click to open them in 
a new tab without switching to it (like most web browsers). Tabs can be closed via the middle mouse button.

Tabs can also be renamed either by double-clicking the tab, or right-clicking and using the edit option in the radial menu.

You can also use the browser without linking it to a campaign record. To do so, just use the chat command:

/foogle &lt;search string&gt;

The optional search string parameter, if provided, will perform a search automatically when opened.

If you have a dynamic browser window that you want to persist to the campaign data, you can right-click and there is a 
save option in the radial menu which will copy the dynamic browser to a persisted one. Here is an example of a dynamic 
browser:

![](doc/5e_usage_example.gif)
