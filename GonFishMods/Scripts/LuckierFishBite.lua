return function(mod_settings)
    LuckierFishBite = LuckierFishBite or {}

    LuckierFishBite.DefaultConfig = {
        ["LuckFactor"] = 5,
        ["LuckyPullLuckMult"] = 10,
        ["RarePullLuckMult"] = 100,
        ["MythicPullLuckMult"] = 1000,
        ["CatchSpecial"] = true,
    
        ["MythicPullHotkey"] = "F9",
        ["RarePullHotkey"] = "F8",
        ["LuckyPullHotkey"] = "F7",
        ["ToggleHotspotHotkey"] = "F6",
    }

    LuckierFishBite.LoadConfig = function()
        for k, v in pairs(mod_settings) do
            print("[LuckierFishBite] setting " .. k .. " :: " .. tostring(v) .. "\n")
            LuckierFishBite[k] = v
        end
        for k, v in pairs(LuckierFishBite.DefaultConfig) do
            if type(LuckierFishBite[k]) ~= type(v) then
                print("[LuckierFishBite] setting defaults to " .. k .. " :: " .. tostring(v) .. "\n")
                LuckierFishBite[k] = v
            end
        end
    end
    LuckierFishBite.LoadConfig()

    LuckierFishBite.LuckMult = 1
    LuckierFishBite.ForceEnableHotsport = false

    RegisterKeyBind(Key[LuckierFishBite.LuckyPullHotkey], function()
        local my_fishing_client = LuckierFishBite.GetLocalPlayerFishingClient()

        if my_fishing_client and my_fishing_client:IsValid() then
            LuckierFishBite.LuckMult = LuckierFishBite.LuckyPullLuckMult
            LuckierFishBite.SendLocalChatMessage("LuckierFishBite", "next pull will be extra lucky (" .. tostring(LuckierFishBite.LuckMult * LuckierFishBite.LuckFactor) .. " rerolls)", {R=0.3, G=0.4, B=0.45, A=1.0})
        end
    end)

    RegisterKeyBind(Key[LuckierFishBite.RarePullHotkey], function()
        local my_fishing_client = LuckierFishBite.GetLocalPlayerFishingClient()

        if my_fishing_client and my_fishing_client:IsValid() then
            LuckierFishBite.LuckMult = LuckierFishBite.RarePullLuckMult
            LuckierFishBite.SendLocalChatMessage("LuckierFishBite", "next pull will be a rare one (" .. tostring(LuckierFishBite.LuckMult * LuckierFishBite.LuckFactor) .. " rerolls)", {R=0.3, G=0.4, B=0.45, A=1.0})
        end
    end)

    RegisterKeyBind(Key[LuckierFishBite.MythicPullHotkey], function()
        local my_fishing_client = LuckierFishBite.GetLocalPlayerFishingClient()

        if my_fishing_client and my_fishing_client:IsValid() then
            LuckierFishBite.LuckMult = LuckierFishBite.MythicPullLuckMult
            LuckierFishBite.SendLocalChatMessage("LuckierFishBite", "next pull will be mythical (" .. tostring(LuckierFishBite.LuckMult * LuckierFishBite.LuckFactor) .. " rerolls)", {R=0.3, G=0.4, B=0.45, A=1.0})
        end
    end)

    RegisterKeyBind(Key[LuckierFishBite.ToggleHotspotHotkey], function()
        local my_fishing_client = LuckierFishBite.GetLocalPlayerFishingClient()

        if my_fishing_client and my_fishing_client:IsValid() then
            LuckierFishBite.ForceEnableHotsport = not LuckierFishBite.ForceEnableHotsport
    
    
            if LuckierFishBite.ForceEnableHotsport then
                LuckierFishBite.SendLocalChatMessage("LuckierFishBite", "force hotspot enabled", {R=0.3, G=0.4, B=0.45, A=1.0})
            else
                LuckierFishBite.SendLocalChatMessage("LuckierFishBite", "force hotspot disabled", {R=0.3, G=0.4, B=0.45, A=1.0})
            end
        end
    end)

    LuckierFishBite.CurrentFishingClient = nil

    LuckierFishBite.GetLocalPlayerFishingClient = GonFishModAPI.GetLocalPlayerFishingClient

    LuckierFishBite.SendLocalChatMessage = GonFishModAPI.SendLocalChatMessage

    LuckierFishBite.ReportFishBite = function()
        GonFishModAPI.AddTask(100, function()
            local my_fishing_client = LuckierFishBite.GetLocalPlayerFishingClient()

            if not (my_fishing_client and my_fishing_client:IsValid()) then
                return
            end

            if my_fishing_client and my_fishing_client:IsValid() then
                local raw_fish_name = my_fishing_client.CurrentFishName:ToString()
                local fish_name = raw_fish_name:gsub("Fix$", ""):gsub("^Fish_", "")
                local fish_weight = my_fishing_client.FishWeight
                local appendage = fish_weight > 9999.99 and "k lbs" or " lbs"
                local bait_score = my_fishing_client["Bait Score"] or 0

                fish_weight = fish_weight > 9999.99 and fish_weight / 1000 or fish_weight
                local fish_weight_str = string.format("%.2f", fish_weight) .. appendage
                local bait_score_str = string.format("%.2f", bait_score)

                print("[LuckierFishBite] fish type '" .. fish_name .. "' !\n")
                print("[LuckierFishBite] fish weight :: " .. fish_weight_str .. " !\n")
                print("[LuckierFishBite] bait score :: " .. bait_score_str .. " !\n")

                LuckierFishBite.SendLocalChatMessage("Fish Bite", fish_name .. "\n                    weighing " .. fish_weight_str .. "\n                    " .. bait_score_str .. " bait score", {R=0.3, G=0.4, B=0.45, A=1.0})
            end
        end)
    end

    LuckierFishBite.FishDataTable = StaticFindObject("/Game/Fishing/FishInformation/DT_FishWeightScales.DT_FishWeightScales")
    LuckierFishBite.FishDataTableCurveID = "WeightScale_10_D50D86534BC4A3CA5F4B6083DB3B2BB7"
    LuckierFishBite.FishWeightCurves = {}

    LuckierFishBite.FishDataTable:ForEachRow(function(RowName, RowData)
        local fish_name = tostring(RowName):lower()
        local fish_curve = RowData[LuckierFishBite.FishDataTableCurveID]

        if fish_curve and fish_curve:IsValid() then
            print("[LuckierFishBite] found fish curve for :: " .. fish_name .. "\n")
            LuckierFishBite.FishWeightCurves[fish_name] = fish_curve
        end
    end)

    LuckierFishBite.FindFishCurve = function(TargetRowName)
        local target = TargetRowName:lower()

        return LuckierFishBite.FishWeightCurves[target] or nil
    end

    LuckierFishBite.GetCurveVal = function(curve, x)
        local y = curve:GetFloatValue(x)

        return y
    end

    LuckierFishBite.OnFishBite = function(self, IsInCave, IsInHotspot, ActiveFishRank, CurrentFishName)
        local my_fishing_client = LuckierFishBite.GetLocalPlayerFishingClient()
        
        if not (my_fishing_client and my_fishing_client:IsValid()) then
            return
        end

        if LuckierFishBite.LuckFactor == 0 then
            LuckierFishBite.ReportFishBite()
            return
        end

        local rerolls = LuckierFishBite.LuckMult * LuckierFishBite.LuckFactor
        LuckierFishBite.LuckMult = 1

        LuckierFishBite.best_catch = nil
        local myself = self:Get()
        local in_cave = IsInCave:Get() and true or false
        local in_hotspot = IsInHotspot:Get() and true or LuckierFishBite.ForceEnableHotsport

        local orig_hotspot_val = my_fishing_client["HotSpot?"]
        local orig_hotspot_mythic_val = my_fishing_client["hotspotMythic?"]

        if LuckierFishBite.ForceEnableHotsport then
            my_fishing_client["HotSpot?"] = true
            my_fishing_client["hotspotMythic?"] = true
        end

        local OutRank = { ["Active Fish Rank (1-10)"] = 0.0 }
        local OutName = { ["CurrentFishName"] = FName("Empty") }

        local fish_name = my_fishing_client["CurrentFishName"]:ToString() or "Empty"
        local fish_weight_rank = my_fishing_client["Fish Ranking(1-10)(Each Type)"] or 0
        local fish_weight_curve = LuckierFishBite.FindFishCurve(fish_name)
        local calc_weight = fish_weight_curve and LuckierFishBite.GetCurveVal(fish_weight_curve, fish_weight_rank) or 0
        local special_catch = nil

        local best_catch = {
            ["CurrentFishName"] = fish_name,
            ["FishWeight"] = my_fishing_client["FishWeight"],
            ["JeremyWade?"] = my_fishing_client["JeremyWade?"],
            ["Bait Score"] = my_fishing_client["Bait Score"],
            ["Fish Ranking(1-10)(Each Type)"] = fish_weight_rank,
            ["FishBucket"] = my_fishing_client["FishBucket"],
            ["CalcWeight"] = calc_weight
        }

        for i=1,rerolls do
            my_fishing_client["DecideFish (FishBites)"](my_fishing_client, in_cave, in_hotspot, OutRank, OutName)

            fish_name = my_fishing_client["CurrentFishName"]:ToString() or "Empty"
            fish_weight_rank = my_fishing_client["Fish Ranking(1-10)(Each Type)"] or 0
            fish_weight_curve = LuckierFishBite.FindFishCurve(fish_name)
            calc_weight = fish_weight_curve and LuckierFishBite.GetCurveVal(fish_weight_curve, fish_weight_rank) or -1

            if calc_weight < 0 and LuckierFishBite.CatchSpecial then
                special_catch = {
                    ["CurrentFishName"] = fish_name,
                    ["FishWeight"] = my_fishing_client["FishWeight"],
                    ["JeremyWade?"] = my_fishing_client["JeremyWade?"],
                    ["Bait Score"] = my_fishing_client["Bait Score"],
                    ["Fish Ranking(1-10)(Each Type)"] = fish_weight_rank,
                    ["FishBucket"] = my_fishing_client["FishBucket"],
                    ["CalcWeight"] = calc_weight
                }
            end

            if calc_weight > best_catch["CalcWeight"] then
                best_catch = {
                    ["CurrentFishName"] = fish_name,
                    ["FishWeight"] = my_fishing_client["FishWeight"],
                    ["JeremyWade?"] = my_fishing_client["JeremyWade?"],
                    ["Bait Score"] = my_fishing_client["Bait Score"],
                    ["Fish Ranking(1-10)(Each Type)"] = fish_weight_rank,
                    ["FishBucket"] = my_fishing_client["FishBucket"],
                    ["CalcWeight"] = calc_weight
                }
            end
        end

        if special_catch and math.random(1, math.max(math.floor(rerolls), 3)) <= 2 then
            best_catch = special_catch
        end

        GonFishModAPI.AddTask(100, function()
            local my_fishing_client = LuckierFishBite.GetLocalPlayerFishingClient()
        
            if not (my_fishing_client and my_fishing_client:IsValid()) then
                return
            end

            print("[LuckierFishBite] restoring hotspot modifiers\n")
            my_fishing_client["HotSpot?"] = orig_hotspot_val
            my_fishing_client["hotspotMythic?"] = orig_hotspot_mythic_val
        end)

        print("[LuckierFishBite] rerolled " .. tostring(rerolls) .. " times\n")

        my_fishing_client["CurrentFishName"] = FName(best_catch["CurrentFishName"])
        my_fishing_client["FishWeight"] = best_catch["FishWeight"]
        my_fishing_client["JeremyWade?"] = best_catch["JeremyWade?"]
        my_fishing_client["Bait Score"] = best_catch["Bait Score"]
        my_fishing_client["Fish Ranking(1-10)(Each Type)"] = best_catch["Fish Ranking(1-10)(Each Type)"]
        my_fishing_client["FishBucket"] = best_catch["FishBucket"]

        ActiveFishRank:set(best_catch["Fish Ranking(1-10)(Each Type)"])
        CurrentFishName:set(FName(best_catch["CurrentFishName"]))

        LuckierFishBite.ReportFishBite()
    end

    LuckierFishBite.DecideFishHookName = "/Game/Fishing/FishingAlgorithm/ClientSideMagic/AC_FishingonClientWIZARD.AC_FishingonClientWIZARD_C:DecideFish (FishBites)"
    LuckierFishBite.HookDecideFish = function()
        local DecideFishPreHookId, DecideFishPostHookId = RegisterHook(LuckierFishBite.DecideFishHookName, function(self, IsInCave, IsInHotspot, ActiveFishRank, CurrentFishName)
            if LuckierFishBite.IsRerollingOnFishBite then
                return
            end

            LuckierFishBite.IsRerollingOnFishBite = true
            LuckierFishBite.OnFishBite(self, IsInCave, IsInHotspot, ActiveFishRank, CurrentFishName)
            LuckierFishBite.IsRerollingOnFishBite = false
        end)

        LuckierFishBite.DecideFishPreHookId = DecideFishPreHookId
        LuckierFishBite.DecideFishPostHookId = DecideFishPostHookId
    end

    LuckierFishBite.FishOnHookName = "/Game/Fishing/FishingAlgorithm/ClientSideMagic/AC_FishingonClientWIZARD.AC_FishingonClientWIZARD_C:FIshON"
    LuckierFishBite.HookFishOn = function()
        RegisterHook(LuckierFishBite.FishOnHookName, function(self, ActiveFishRank, CurrentFishName)
            print("[LuckierFishBite] CurrentFishName :: " .. tostring(CurrentFishName:Get():ToString()) .. "\n")
            print("[LuckierFishBite] ActiveFishRank :: " .. tostring(ActiveFishRank:Get()) .. "\n")
        end)
    end

    if not LuckierFishBite.RegisteredHooks then
        pcall(function()
            LuckierFishBite.HookDecideFish()
        end)
        pcall(function()
            LuckierFishBite.HookFishOn()
        end)

        LuckierFishBite.RegisteredHooks = true
    end
end

