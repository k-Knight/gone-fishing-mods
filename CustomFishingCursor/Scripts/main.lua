ExecuteInGameThread(function()
    local cur_path = tostring(debug.getinfo(1).source):gsub("^@", ""):gsub("\\", "/"):gsub("/Scripts/main.lua$", "")
    local dll_path = cur_path .. "/CustomFishingCursor.dll"
    print("[CustomFishingCursor] loading dll at :: " .. dll_path .. "\n")

    local loader, err = package.loadlib(dll_path, "start_CustomFishingCursor")

    if loader then
        print("[CustomFishingCursor] dll function found, executing ...\n")
        loader()
    else
        print("[CustomFishingCursor] failed to load dll :: " .. tostring(err) .. "\n")
    end
end)