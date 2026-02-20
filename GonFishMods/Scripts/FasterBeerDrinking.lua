return function(mod_settings)

FasterBeerDrinking = FasterBeerDrinking or {}

FasterBeerDrinking.GetLocalPlayerFishingClient = function()
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
                break
            end
        end
    end

    if not my_fishing_client then
        print("[FasterBeerDrinking] cannot find player's fishing client !!!\n")
    end

    return my_fishing_client
end

FasterBeerDrinking.SpeedUpBeerDrinking = function()
    local DrinkAnim = StaticFindObject("/Game/Characters/PlaceHolder/Animations/Idle_DrinkReal.Idle_DrinkReal")
    
    if DrinkAnim:IsValid() then
        DrinkAnim.RateScale = 3.0
        print("[FasterBeerDrinking] Speeding up Idle_DrinkReal to 3x\n")
    else
        print("[FasterBeerDrinking] Could not find Drink animation asset!\n")
    end

    RegisterHook("/Game/Items/Beer/AC_BEERAndalsoUpgradesAndAlsoEmotes.AC_BEERAndalsoUpgradesAndAlsoEmotes_C:DrinkingBeerLogic",
    function(self, ...)
        print("[FasterBeerDrinking] started drinking beer\n")

        GonFishModAPI.AddTask(2550, function()
            local my_fishing_client = FasterBeerDrinking.GetLocalPlayerFishingClient()
            if not (my_fishing_client and my_fishing_client:IsValid()) then
                return
            end
        
            local player_character = my_fishing_client.PlayerCharacter
            if not (player_character and player_character:IsValid()) then
                return
            end
        
            local beer_controller = player_character.AC_BEER
            if not (beer_controller and beer_controller:IsValid()) then
                return
            end

            print("[FasterBeerDrinking] found local beer controller\n")
            if not beer_controller["CanDrink?"] then
                beer_controller.BeerComplete(beer_controller)
            else
                print("[FasterBeerDrinking] not drinking beer currently\n")
            end
        end)
    end)
end

FasterBeerDrinking.SpeedUpBeerDrinking()

end