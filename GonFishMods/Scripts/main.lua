ExecuteInGameThread(function()
    print("\n")
    print("\n")
    print("\n")
    print("[GonFishMods] starting intialization ...\n")
    require("GonFishModAPI")
    
    LoopAsync(500, function()
        if GonFishModAPI and  GonFishModAPI.initialized then
            local status, err = pcall(function()
                GonFishModAPI.LoadConfig()

                for k, v in pairs(GonFishModAPI.ModConfig) do
                    if v.enabled then
                        print("[GonFishMods] loading mod :: " .. tostring(k) .. " ...\n")
                        require(k)(v)
                    end
                end
            end)

            if not status then
                print("[GonFishMods] loading mods error :: " .. tostring(err) .. "\n")
            end

            return true
        elseif GonFishModAPI then
            print("[GonFishMods] GonFishModAPI is not ready yet!\n")
        end

        return false
    end)
end)
