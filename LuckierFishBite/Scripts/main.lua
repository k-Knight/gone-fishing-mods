ExecuteInGameThread(function()
    LuckierFishBite = LuckierFishBite or {}

    LuckierFishBite.LoadConfig = function()
        local cur_path = tostring(debug.getinfo(1).source):gsub("^@", ""):gsub("\\Scripts\\main.lua$", ""):gsub("/Scripts/main.lua$", "")
        local configPath = cur_path .. "\\settings.lua"
        print(configPath .. "\n")
        local success, result = pcall(dofile, configPath)

        if success then
            print(tostring(result) .. "\n")
            LuckierFishBite.LuckFactor = result.LuckFactor or 10
            print("[LuckierFishBite] settings LuckFactor :: " .. tostring(LuckierFishBite.LuckFactor) .. "\n")
            LuckierFishBite.CatchSpecial = result.CatchSpecial == nil and true or result.CatchSpecial
            print("[LuckierFishBite] settings CatchSpecial :: " .. tostring(LuckierFishBite.CatchSpecial) .. "\n")
        else
            print("error :: " .. tostring(result) .. "\n")
        end

    end

    LuckierFishBite.LoadConfig()

    LuckierFishBite.CurrentFishingClient = nil

    LuckierFishBite.GetLocalPlayerFishingClient = function()
        local instances = FindAllOf("AC_FishingonClientWIZARD_C")

        if not instances then
            return nil
        end

        local targetClassName = "BP_ThirdPersonCharacter_C"
        local my_fishing_client

        for _, instance in pairs(instances) do
            local pc_field = instance.PlayerCharacter

            if pc_field:IsValid() then
                local pcClassFullName = pc_field:GetClass():GetFullName()

                if string.find(pcClassFullName, targetClassName) and pc_field.PlayerController:IsValid() then
                    my_fishing_client = instance

                    if my_fishing_client ~= LuckierFishBite.CurrentFishingClient then
                        LuckierFishBite.CurrentFishingClient = my_fishing_client
                    end
                    break
                end
            end
        end

        if not my_fishing_client then
            print("[LuckierFishBite] cannot find player's fishing client !!!\n")
        end

        return my_fishing_client
    end


    LuckierFishBite.SendLocalChatMessage = function(my_fish_client, src, msg)
        if my_fish_client then
            local player_character = my_fish_client.PlayerCharacter
            local PC = player_character.PlayerController
            local chat = PC.MultiplayerChat_C

            if chat and chat:IsValid() then
            
                local MessageType = 0
                local MyText = FText(msg)
                local MyPlayerName = FName(src)
                local MyColor = {R=0.3, G=0.4, B=0.5, A=1.0}
                local Channel = 0
            
                chat["MC_Enter Text"](chat, MessageType, MyText, MyPlayerName, MyColor, Channel)
            end
        end
    end

    LuckierFishBite.ReportFishBite = function()
        RetriggerableExecuteInGameThreadWithDelay(312, 100, function()
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

                LuckierFishBite.SendLocalChatMessage(my_fishing_client, "[Fish Bite]", fish_name .. " weighing " .. fish_weight_str .. "(" .. bait_score_str .. " bait score)")
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
        if LuckierFishBite.LuckFactor == 0 then
            LuckierFishBite.ReportFishBite()
            return
        end

        LuckierFishBite.best_catch = nil
        local myself = self:Get()
        local in_cave = IsInCave:Get() and true or false
        local in_hotspot = IsInHotspot:Get() and true or false

        local my_fishing_client = LuckierFishBite.GetLocalPlayerFishingClient()

        if not (my_fishing_client and my_fishing_client:IsValid()) then
            return
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

        for i=1,LuckierFishBite.LuckFactor do
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

        if special_catch and math.random(1, math.max(math.floor(LuckierFishBite.LuckFactor / 2), 3)) <= 2 then
            best_catch = special_catch
        end

        print("[LuckierFishBite] rerolled " .. tostring(LuckierFishBite.LuckFactor) .. " times\n")

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

    local function GetActiveInventory()
        local Instances = FindAllOf("WBP_InventoryWidget_C")
        if not Instances then
            return nil
        end

        for _, Widget in ipairs(Instances) do
            if Widget:IsInViewport() then
                return Widget
            end
        end
        return nil
    end

    local function InjectTextureToViewport(MyTextureInstance)
        local ImageClass = StaticFindObject("/Script/UMG.Image")
        local PC = FindFirstOf("PlayerController")
        if not PC or not PC:IsValid() then return end

        local MyImage = StaticConstructObject(ImageClass, PC)
        MyImage:SetBrushFromTexture(MyTextureInstance, true)
        MyImage:SetDesiredSizeOverride({X=200.0, Y=200.0})

        local TargetHUD = GetActiveInventory()

        if TargetHUD and TargetHUD:IsValid() then
            local RootContainer = TargetHUD.SlotArray[1]:GetParent()
            if RootContainer and RootContainer:IsValid() then
                print(RootContainer:GetFullName() .. "\n")
            end

            RootContainer:AddChild(MyImage)
            print("[LuckierFishBite] Success: Image added to Inventory Root")
        else
            print("[LuckierFishBite] Error: Could not find WBP_InventoryWidget_C to attach to")
        end
    end

    print("\n")
end)

