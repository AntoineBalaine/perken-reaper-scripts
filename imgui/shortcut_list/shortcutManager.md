# Shortcut Manager, an ImGui utility to keep track of shortcuts.

ShortcutManager is structured as a class with methods to create, delete, and save shortcuts in the ImGui context.

### Usage:
```lua
local shortcuts = ShortcutManager(ctx, { "quit" }, "/path/to/shortcuts/file") -- initiate, and ask ShortcutManager to create a "quit" action, it will assign `ESC` by default. If a config file is provided, it will load the shortcuts from it. Don't put this in your `loop()` funtion
local programRun = true
if shortcuts:Read("quit") then -- will return true if the shortcut for this action has been pressed
  programRun = false -- then tell the program to quit or whatever else you need to do
end
shortcuts:Create("save", { [reaper.ImGui_Key_S() .. ""] = true }) -- will create a shortcut for this action, and assign `s` to it.
---note that the key must be a string, and that the value must be `true`. ShortcutManager uses key-indices internally.
shortcuts:Delete("quit") -- will delete the shortcut for this action
```

### If you want to display the actions list to the user:
```lua
shortcuts:Create("display action list") .. ""] = true })
-- in your loop() function:
if shortcuts:Read("display action list") or shortcuts.isShortcutListOpen() then
  shortcuts:DisplayShortcutList()-- open a pop-up window that contains the action list, and its corresponding shortcuts
end
```

### In case you'd like to create a table of shortcuts from the caller script, you can do:
```lua
local shortcuts = ShortcutManager(ctx) -- initiate, but don't pass anything.
local actions = {"quit" = reaper.ImGui_Key_Escape(), "save" = reaper.ImGui_Key_S()} -- your list of actions
for k, v in pairs(actions) do
  shortcuts:Create(k, {[v .. ""] = true})
end
```

# TO DO: 
- allow passing a config file. Just passing a config file that contains the list of shortcuts - so the caller-application won't have to deal with it. I dunno when I'll be able to get to it, though. PRs welcome!
 
