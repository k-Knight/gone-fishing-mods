ExecuteInGameThread(function()
    ForceEnablePerks = ForceEnablePerks or {}

    ForceEnablePerks.CurrentFishingClient = nil

    ForceEnablePerks.GetLocalPlayerFishingClient = function()
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

                    if my_fishing_client ~= ForceEnablePerks.CurrentFishingClient then
                        ForceEnablePerks.CurrentFishingClient = my_fishing_client
                    end
                    break
                end
            end
        end

        if not my_fishing_client then
            print("[ForceEnablePerks] cannot find player's fishing client !!!\n")
        end

        return my_fishing_client
    end

    ForceEnablePerks.GetAssetOrInstance = function(AssetPath)
        local instance = StaticFindObject(AssetPath)
    
        if instance then
            return instance
        end
    
        print("no instances found\n")
        return nil
    end

    ForceEnablePerks.CheckPlayer = function()
        local my_fish_client = ForceEnablePerks.GetLocalPlayerFishingClient()

        if my_fish_client and my_fish_client:IsValid() then
            local player_character = my_fish_client.PlayerCharacter
            local player_perks = player_character.AC_Perks

            if player_perks and player_perks:IsValid() then
                player_perks.SetStickyHook(true, player_character)
                player_perks.SetSprintSpeed(750, player_character)
                player_perks.SetHasFishWhisperer(true, player_character)
            end
        end
    end

    if not ForceEnablePerks.LoopStarted then
        ForceEnablePerks.LoopStarted = true
        LoopInGameThreadWithDelay(3333, ForceEnablePerks.CheckPlayer)
    end
end)
-- Function /Game/ThirdPerson/Blueprints/AC_Perks.AC_Perks_C:SetSprintSpeed