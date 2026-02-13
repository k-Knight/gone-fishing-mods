ExecuteInGameThread(function()
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
        local cur_path = tostring(debug.getinfo(1).source):gsub("^@", ""):gsub("\\Scripts\\main.lua$", ""):gsub("/Scripts/main.lua$", "")
        local configPath = cur_path .. "\\settings.lua"
        print(configPath .. "\n")
        local success, result = pcall(dofile, configPath)

        if success then
            for k, v in pairs(result) do
                print("[LuckierFishBite] settings " .. k .. " :: " .. tostring(v) .. "\n")
                LuckierFishBite[k] = v
            end
            for k, v in pairs(LuckierFishBite.DefaultConfig) do
                if type(LuckierFishBite[k]) ~= type(v) then
                    print("[LuckierFishBite] settings " .. k .. " :: " .. tostring(v) .. "\n")
                    LuckierFishBite[k] = v
                end
            end
        else
            print("[LuckierFishBite] config error :: " .. tostring(result) .. "\n")
        end
    end
    LuckierFishBite.LoadConfig()

    LuckierFishBite.LuckMult = 1
    LuckierFishBite.ForceEnableHotsport = false

    RegisterKeyBind(Key[LuckierFishBite.LuckyPullHotkey], function()
        local my_fishing_client = LuckierFishBite.GetLocalPlayerFishingClient()

        if my_fishing_client and my_fishing_client:IsValid() then
            LuckierFishBite.LuckMult = LuckierFishBite.LuckyPullLuckMult
            LuckierFishBite.SendLocalChatMessage(my_fishing_client, "LuckierFishBite", "next pull will be extra lucky (" .. tostring(LuckierFishBite.LuckMult * LuckierFishBite.LuckFactor) .. " rerolls)", {R=0.3, G=0.4, B=0.45, A=1.0})
        end
    end)

    RegisterKeyBind(Key[LuckierFishBite.RarePullHotkey], function()
        local my_fishing_client = LuckierFishBite.GetLocalPlayerFishingClient()

        if my_fishing_client and my_fishing_client:IsValid() then
            LuckierFishBite.LuckMult = LuckierFishBite.RarePullLuckMult
            LuckierFishBite.SendLocalChatMessage(my_fishing_client, "LuckierFishBite", "next pull will be a rare one (" .. tostring(LuckierFishBite.LuckMult * LuckierFishBite.LuckFactor) .. " rerolls)", {R=0.3, G=0.4, B=0.45, A=1.0})
        end
    end)

    RegisterKeyBind(Key[LuckierFishBite.MythicPullHotkey], function()
        local my_fishing_client = LuckierFishBite.GetLocalPlayerFishingClient()

        if my_fishing_client and my_fishing_client:IsValid() then
            LuckierFishBite.LuckMult = LuckierFishBite.MythicPullLuckMult
            LuckierFishBite.SendLocalChatMessage(my_fishing_client, "LuckierFishBite", "next pull will be mythical (" .. tostring(LuckierFishBite.LuckMult * LuckierFishBite.LuckFactor) .. " rerolls)", {R=0.3, G=0.4, B=0.45, A=1.0})
        end
    end)

    RegisterKeyBind(Key[LuckierFishBite.ToggleHotspotHotkey], function()
        local my_fishing_client = LuckierFishBite.GetLocalPlayerFishingClient()

        if my_fishing_client and my_fishing_client:IsValid() then
            LuckierFishBite.ForceEnableHotsport = not LuckierFishBite.ForceEnableHotsport
    
    
            if LuckierFishBite.ForceEnableHotsport then
                LuckierFishBite.SendLocalChatMessage(my_fishing_client, "LuckierFishBite", "force hotspot enabled", {R=0.3, G=0.4, B=0.45, A=1.0})
            else
                LuckierFishBite.SendLocalChatMessage(my_fishing_client, "LuckierFishBite", "force hotspot disabled", {R=0.3, G=0.4, B=0.45, A=1.0})
            end
        end
    end)

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

    LuckierFishBite.MySpecialMsgType = 31

    LuckierFishBite.OnExecuteUbergraph_Message = function(self, ...)
        if LuckierFishBite.OnExecuteUbergraph_Message_Reroll then
            return
        end
        LuckierFishBite.OnExecuteUbergraph_Message_Reroll = true

        local status, error = pcall(function()
            local self = self:Get()

            local msg_type = self["Message Type"]

            if msg_type == LuckierFishBite.MySpecialMsgType then
                if not LuckierFishBite.HidingChatMessage then
                    local text = self.Name:ToString()
                    local color = self.NameColor
                    local msg_text = self.MessageText

                    self["Message Type"] = 0
                    self:Message()
                    self["Message Type"] = LuckierFishBite.MySpecialMsgType

                    local MyColor = {
                        SpecifiedColor = {R=color.R, G=color.G, B=color.B, A=color.A},
                        ColorUseRule = 0
                    }

                    msg_text.SetDefaultColorAndOpacity(MyColor)
                    msg_text:SetText(FText(text))
                else
                    LuckierFishBite.HidingChatMessage = false
                end
            end
        end)

        LuckierFishBite.OnExecuteUbergraph_Message_Reroll = false

        if not status then
            print(error .. "\n")
        end
    end

    if not LuckierFishBite.RegisteredHookOnExecuteUbergraph_Message then
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:ExecuteUbergraph_Message", function(self, ...)
            LuckierFishBite.OnExecuteUbergraph_Message(self, ...)
        end)

        LuckierFishBite.RegisteredHookOnExecuteUbergraph_Message = true
    end

    LuckierFishBite.OnHideMessage = function(self, ...)
        local self = self:Get()

        local msg_type = self["Message Type"]

        if msg_type == LuckierFishBite.MySpecialMsgType then
            LuckierFishBite.HidingChatMessage = true
        end
    end

    if not LuckierFishBite.RegisteredHookOnHideMessage then
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:HideMessage", function(self, ...)
            LuckierFishBite.OnHideMessage(self, ...)
        end)
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:HideBackground", function(self, ...)
            LuckierFishBite.OnHideMessage(self, ...)
        end)
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:HideMessageAfterTimer", function(self, ...)
            LuckierFishBite.OnHideMessage(self, ...)
        end)
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:HidebackgroundAfterTimer", function(self, ...)
            LuckierFishBite.OnHideMessage(self, ...)
        end)

        LuckierFishBite.RegisteredHookOnHideMessage = true
    end

    LuckierFishBite.SendLocalChatMessage = function(my_fish_client, src, msg, color)
        if my_fish_client then
            local player_character = my_fish_client.PlayerCharacter
            local PC = player_character.PlayerController
            local chat = PC.MultiplayerChat_C

            if chat and chat:IsValid() then

                local MessageType = 0
                local MyText = FText("")
                local MyPlayerName = FName("[".. src .. "] " .. msg)
                local Channel = 0

                chat["Enter Text Function"](chat, MessageType, MyText, MyPlayerName, color, Channel)

                local chat_internal = chat["Chat Ref"]
                if not (chat_internal and chat_internal:IsValid()) then
                    print("[LuckierFishBite] no Chat Ref !!!\n")
                    return
                end

                local chat_scroll = chat_internal.GeneralChatScrollBox
                if not (chat_scroll and chat_scroll:IsValid()) then
                    print("[LuckierFishBite] no GeneralChatScrollBox !!!\n")
                    return
                end

                local msg_slot = chat_scroll.Slots[1]
                if not (msg_slot and msg_slot:IsValid()) then
                    print("[LuckierFishBite] no Slots[1] !!!\n")
                    return
                end

                local chat_msg = msg_slot.Content
                if not (chat_msg and chat_msg:IsValid()) then
                    print("[LuckierFishBite] no Content !!!\n")
                    return
                end

                local msg_text = chat_msg.MessageText
                if not (msg_text and msg_text:IsValid()) then
                    print("[LuckierFishBite] no MessageText !!!\n")
                    return
                end

                chat_msg["Message Type"] = LuckierFishBite.MySpecialMsgType
                chat_msg.NameColor = color
                chat_msg:ShowMessage()
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

                LuckierFishBite.SendLocalChatMessage(my_fishing_client, "Fish Bite", fish_name .. "\n                    weighing " .. fish_weight_str .. "\n                    " .. bait_score_str .. " bait score", {R=0.3, G=0.4, B=0.45, A=1.0})
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

        RetriggerableExecuteInGameThreadWithDelay(316, 100, function()
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

