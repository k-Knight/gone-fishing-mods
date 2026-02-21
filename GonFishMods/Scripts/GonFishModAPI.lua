print("[GonFishModAPI] api init ...\n")
GonFishModAPI = GonFishModAPI or {}

GonFishModAPI.GetLocalPlayerFishingClient = function()
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

                if my_fishing_client ~= GonFishModAPI.CurrentFishingClient then
                    GonFishModAPI.CurrentFishingClient = my_fishing_client
                end
                break
            end
        end
    end

    if not my_fishing_client then
        print("[GonFishModAPI] cannot find player's fishing client !!!\n")
    end

    return my_fishing_client
end

GonFishModAPI.MySpecialMsgType = 31

GonFishModAPI.OnExecuteUbergraph_Message = function(self, ...)
    if GonFishModAPI.OnExecuteUbergraph_Message_Reroll then
        return
    end

    GonFishModAPI.OnExecuteUbergraph_Message_Reroll = true

    local status, error = pcall(function()
        local self = self:Get()

        local msg_type = self["Message Type"]

        if msg_type == GonFishModAPI.MySpecialMsgType then
            if not GonFishModAPI.HidingChatMessage then
                local text = self.Name:ToString()
                local color = self.NameColor
                local msg_text = self.MessageText

                self["Message Type"] = 0
                self:Message()
                self["Message Type"] = GonFishModAPI.MySpecialMsgType

                local MyColor = {
                    SpecifiedColor = {R=color.R, G=color.G, B=color.B, A=color.A},
                    ColorUseRule = 0
                }

                msg_text.SetDefaultColorAndOpacity(MyColor)
                msg_text:SetText(FText(text))
            else
                GonFishModAPI.HidingChatMessage = false
            end
        end
    end)

    GonFishModAPI.OnExecuteUbergraph_Message_Reroll = false

    if not status then
        print(error .. "\n")
    end
end

GonFishModAPI.OnHideMessage = function(self, ...)
    local self = self:Get()

    local msg_type = self["Message Type"]

    if msg_type == GonFishModAPI.MySpecialMsgType then
        GonFishModAPI.HidingChatMessage = true
    end
end

GonFishModAPI.TreadWithDelayID = 312

GonFishModAPI.SendLocalChatMessage = function(src, msg, color)
    local src = src
    local msg = msg
    local color = color

    GonFishModAPI.AddTask(10, function()
        local my_fishing_client = GonFishModAPI.GetLocalPlayerFishingClient()

        if my_fishing_client and my_fishing_client:IsValid() then
            local player_character = my_fishing_client.PlayerCharacter
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
                    print("[GonFishModAPI] no Chat Ref !!!\n")
                    return
                end

                local chat_scroll = chat_internal.GeneralChatScrollBox
                if not (chat_scroll and chat_scroll:IsValid()) then
                    print("[GonFishModAPI] no GeneralChatScrollBox !!!\n")
                    return
                end

                local msg_slot = chat_scroll.Slots[1]
                if not (msg_slot and msg_slot:IsValid()) then
                    print("[GonFishModAPI] no Slots[1] !!!\n")
                    return
                end

                local chat_msg = msg_slot.Content
                if not (chat_msg and chat_msg:IsValid()) then
                    print("[GonFishModAPI] no Content !!!\n")
                    return
                end

                local msg_text = chat_msg.MessageText
                if not (msg_text and msg_text:IsValid()) then
                    print("[GonFishModAPI] no MessageText !!!\n")
                    return
                end

                chat_msg["Message Type"] = GonFishModAPI.MySpecialMsgType
                chat_msg.NameColor = color
                chat_msg:ShowMessage()
            end
        end
    end)
end

GonFishModAPI.ModConfig = {}

GonFishModAPI.LoadConfig = function()
    local cur_path = tostring(debug.getinfo(1).source):gsub("^@", ""):gsub("\\", "/"):gsub("/Scripts/GonFishModAPI.lua$", "")
    local configPath = cur_path .. "/settings.lua"
    local success, result = pcall(dofile, configPath)

    if success then
        for k, v in pairs(result) do
            GonFishModAPI.ModConfig[k] = v
        end
    else
        print("[GonFishModAPI] config error :: " .. tostring(result) .. "\n")
    end
end

GonFishModAPI.TaskCounter = 0
GonFishModAPI.SchedulerTasks = {}
GonFishModAPI.AddTask = function(delay, callback)
    if not (delay and type(callback) == "function") then
        print("GonFishModAPI] wrong parameters to AddTask() !\n")
        print("    delay :: " .. tostring(delay) .. "\n")
        print("    callback :: " .. tostring(callback) .. "\n")
        return
    end

    local time = os.clock() + (delay / 1000.0)

    GonFishModAPI.TaskCounter = GonFishModAPI.TaskCounter + 1
    GonFishModAPI.SchedulerTasks[GonFishModAPI.TaskCounter] = {
        time = time,
        callback = callback
    }
end 

GonFishModAPI.SchedulerRun = function()
    local time = os.clock()

    for key, task in pairs(GonFishModAPI.SchedulerTasks) do
        if task and task.time and task.callback and task.time <= time then
            task.callback()
            GonFishModAPI.SchedulerTasks[key] = nil
            break
        end
    end
end

GonFishModAPI.OnTick = function()
    local status, err = pcall(GonFishModAPI.SchedulerRun)

    if not status then
        print("[GonFishModAPI] lua error :: " .. tostring(err) .. "\n")
    end

    return false
end


print("[GonFishModAPI] delaying hooks and dll loading ...\n")

RetriggerableExecuteInGameThreadWithDelay(GonFishModAPI.TreadWithDelayID, 2000, function()
    print("[GonFishModAPI] hooking and loading dlls ...\n")

    if not GonFishModAPI.RegisteredHookOnExecuteUbergraph_Message then
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:ExecuteUbergraph_Message", function(self, ...)
            GonFishModAPI.OnExecuteUbergraph_Message(self, ...)
        end)

        GonFishModAPI.RegisteredHookOnExecuteUbergraph_Message = true
    end

    if not GonFishModAPI.RegisteredHookOnHideMessage then
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:HideMessage", function(self, ...)
            GonFishModAPI.OnHideMessage(self, ...)
        end)
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:HideBackground", function(self, ...)
            GonFishModAPI.OnHideMessage(self, ...)
        end)
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:HideMessageAfterTimer", function(self, ...)
            GonFishModAPI.OnHideMessage(self, ...)
        end)
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:HidebackgroundAfterTimer", function(self, ...)
            GonFishModAPI.OnHideMessage(self, ...)
        end)

        GonFishModAPI.RegisteredHookOnHideMessage = true
    end

    local cur_path = tostring(debug.getinfo(1).source):gsub("^@", ""):gsub("\\", "/"):gsub("/Scripts/GonFishModAPI.lua$", "")
    local dll_path = cur_path .. "/Lib/ExtendedBPHooker.dll"

    print("[GonFishModAPI] loading dll at :: " .. dll_path .. "\n")

    local add_function_prehook, err = package.loadlib(dll_path, "add_function_prehook")
    if not add_function_prehook then
        print("[GonFishModAPI] DLL Load Error: " .. tostring(err) .. "\n")
    else
        GonFishModAPI.AddFunctionPrehook = add_function_prehook
    end

    local add_random_float_in_range_posthook, err = package.loadlib(dll_path, "add_random_float_in_range_posthook")
    if not add_random_float_in_range_posthook then
        print("[GonFishModAPI] DLL Load Error: " .. tostring(err) .. "\n")
    else
        GonFishModAPI.AddRandomFloatInRangePosthook = add_random_float_in_range_posthook
    end

    local add_random_integer_in_range_posthook, err = package.loadlib(dll_path, "add_random_integer_in_range_posthook")
    if not add_random_integer_in_range_posthook then
        print("[GonFishModAPI] DLL Load Error: " .. tostring(err) .. "\n")
    else
        GonFishModAPI.AddRandomIntegerInRangePosthook = add_random_integer_in_range_posthook
    end

    LoopAsync(10, GonFishModAPI.OnTick)

    GonFishModAPI.initialized = true
end)

return GonFishModAPI