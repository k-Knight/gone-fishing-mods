return function(mod_settings)
    CrazeirGambles = CrazeirGambles or {}

    CrazeirGambles.DefaultConfig = {
        ["GuaranteeMaxWinHotkey"] = "F1",
    }

    CrazeirGambles.LoadConfig = function()
        for k, v in pairs(mod_settings) do
            print("[CrazeirGambles] setting " .. k .. " :: " .. tostring(v) .. "\n")
            CrazeirGambles[k] = v
        end
        for k, v in pairs(CrazeirGambles.DefaultConfig) do
            if type(CrazeirGambles[k]) ~= type(v) then
                print("[CrazeirGambles] setting defaults to " .. k .. " :: " .. tostring(v) .. "\n")
                CrazeirGambles[k] = v
            end
        end
    end
    CrazeirGambles.LoadConfig()

    CrazeirGambles.latest_bloodpool_instance = nil
    CrazeirGambles.do_max_win = false;

    RegisterKeyBind(Key[CrazeirGambles.GuaranteeMaxWinHotkey], function()
        if not (GonFishModAPI and GonFishModAPI.initialized) then
            print("[CrazeirGambles] no GonFishModAPI mod found !!\n")
            return
        end

        local my_fishing_client = GonFishModAPI.GetLocalPlayerFishingClient()

        if my_fishing_client and my_fishing_client:IsValid() then
            CrazeirGambles.do_max_win = not CrazeirGambles.do_max_win

            if CrazeirGambles.do_max_win then
                print("[CrazeirGambles] next is max win\n")
                GonFishModAPI.SendLocalChatMessage("CrazeirGambles", "next gamble will be a guaranteed max win", {R=0.3, G=0.4, B=0.45, A=1.0})
            else
                print("[CrazeirGambles] next max win is cancelled\n")
                GonFishModAPI.SendLocalChatMessage("CrazeirGambles", "guaranteed max win on next gamble was canceled", {R=0.3, G=0.4, B=0.45, A=1.0})
            end
        end
    end)

    CrazeirGambles.ScaleFishCompeteServer_Pre = function(object_name)
        print("[CrazeirGambles] in ScaleFishCompeteServer_Pre() !!!\n")

        if object_name then
            print("[CrazeirGambles] object name :: " .. tostring(object_name) .. "\n")

            local self = StaticFindObject(object_name)

            if self then
                CrazeirGambles.latest_bloodpool_instance = self
            else
                print("[CrazeirGambles] blood pool object is invalid !!!\n")
            end
        else
            print("[CrazeirGambles] missing self uobject !!!\n")
        end
    end

    CrazeirGambles.RandomFloatInRange_Post = function(min, max, res)
        if CrazeirGambles.latest_bloodpool_instance and min and max and res then
            if CrazeirGambles.do_max_win then
                return (max - (math.random() * 0.25))
            end

            print("min :: " .. tostring(min) .. " ,   max :: " .. tostring(max) .. " ,   res :: " .. tostring(res) .. "\n")

            if (math.abs(min - 1.0) < 0.01 and math.abs(max - 6.5) < 0.01) then
                print("[CrazeirGambles] gambling positive\n")

                if math.random(1, 4) <= 2 then
                    res = (res + max) / 2.0

                    if math.random(1, 4) <= 2 then
                        res = (res + max) / 2.0

                        if math.random(1, 4) <= 2 then
                            res = (res + max) / 2.0
                        end
                    end
                end

                return res;
            elseif (math.abs(min - 0.15) < 0.01 and math.abs(max - 1.0) < 0.01) then
                print("[CrazeirGambles] gambling negative\n")

                if math.random(1, 4) <= 2 then
                    res = (res + min) / 2.0

                    if math.random(1, 4) <= 2 then
                        res = (res + min) / 2.0

                        if math.random(1, 4) <= 2 then
                            res = (res + min) / 2.0
                        end
                    end
                end

                return res;
            end
        end
    end

    CrazeirGambles.targer_function = "/Game/PaulosCreations/DemonicAltar_HellGate_BloodPool/BloodPool/BluePrints/BP_BloodPool.BP_BloodPool_C:ScaleFishCompeteServer"
    CrazeirGambles.BloodPoolFunctionInstances = {}

    CrazeirGambles.TryFindBloodpoolScaleFishCompeteServer = function()
        if not (GonFishModAPI.AddFunctionPrehook and GonFishModAPI.AddRandomFloatInRangePosthook) then
            print("[CrazeirGambles] missing necesary hooking functions, exiting\n")
            return
        end

        local TargetFunction = StaticFindObject(CrazeirGambles.targer_function)

        if TargetFunction:IsValid() then
            local addr_hex = string.format("%X", TargetFunction:GetAddress())

            if not CrazeirGambles.BloodPoolFunctionInstances[addr_hex] then
                CrazeirGambles.BloodPoolFunctionInstances[addr_hex] = true
                print("[CrazeirGambles] found target function ...\n")
    
                GonFishModAPI.AddTask(7500, function()
                    print("[CrazeirGambles]  registering hooks ...\n")
    
                    GonFishModAPI.AddFunctionPrehook("ScaleFishCompeteServer", addr_hex, CrazeirGambles.ScaleFishCompeteServer_Pre)
    
                    RegisterHook(CrazeirGambles.targer_function, function(self, ...)
                        print("[CrazeirGambles] exiting ScaleFishCompeteServer() !!\n")
        
                        if CrazeirGambles.latest_bloodpool_instance then
                            print("[CrazeirGambles] latest blood pool instance :: " .. tostring(CrazeirGambles.latest_bloodpool_instance) .. "\n")
                        end
                        
                        CrazeirGambles.latest_bloodpool_instance = nil
                        CrazeirGambles.do_max_win = false
                    end)
                end)
            end
        end

        GonFishModAPI.AddTask(500, CrazeirGambles.TryFindBloodpoolScaleFishCompeteServer)
    end

    GonFishModAPI.AddRandomFloatInRangePosthook(CrazeirGambles.RandomFloatInRange_Post)
    print("[CrazeirGambles] starting a bloodpoolfinder loop\n")
    GonFishModAPI.AddTask(500, CrazeirGambles.TryFindBloodpoolScaleFishCompeteServer)
end