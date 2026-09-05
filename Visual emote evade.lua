local WindUI

do
    local ok, result = pcall(function()
        return require("./src/Init")
    end)
    
    if ok then
        WindUI = result
    else 
        local success, linkResult = pcall(function()
            return game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua")
        end)
        if success then
            WindUI = loadstring(linkResult)()
        end
    end
end

if not WindUI then return end

WindUI.TransparencyValue = 0.2
WindUI:SetTheme("Dark")

local Window = WindUI:CreateWindow({
    Title = "Visual Emote Changer",
    Author = "By Pnsdg (Evade Overhaul)",
    Folder = "DaraHub",
    Size = UDim2.fromOffset(580, 490),
    Theme = "Dark",
    HidePanelBackground = false,
    Acrylic = false,
    HideSearchBar = false,
    SideBarWidth = 200
})

Window:SetIconSize(48)

Window:CreateTopbarButton("theme-switcher", "moon", function()
    WindUI:SetTheme(WindUI:GetCurrentTheme() == "Dark" and "Light" or "Dark")
end, 990)

local FeatureSection = Window:Section({ Title = "Idk", Opened = true })
local Tabs = {
    EmoteChanger = FeatureSection:Tab({ Title = "EmoteChanger", Icon = "smile" })
}

Tabs.EmoteChanger:Section({ Title = "Overhaul remote function hooks"})

local player = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = ReplicatedStorage:WaitForChild("Events", 10)
local CharacterFolder = Events and Events:WaitForChild("Character", 10)
local EmoteRemote = CharacterFolder and CharacterFolder:WaitForChild("Emote", 10)
local PassCharacterInfo = CharacterFolder and CharacterFolder:WaitForChild("PassCharacterInfo", 10)

local remoteSignal = PassCharacterInfo and PassCharacterInfo.OnClientEvent
local currentTag = nil
local currentEmotes = table.create(12, "")
local selectEmotes = table.create(12, "")
local emoteEnabled = table.create(12, false)

local currentEmoteInputs = {}
local selectEmoteInputs = {}
local pendingSlot = nil
local blockOriginalEmote = false

local function readTagFromFolder(f)
    if not f then return nil end
    local a = f:GetAttribute("Tag")
    if a ~= nil then 
        return a 
    end
    local o = f:FindFirstChild("Tag")
    if o and o:IsA("ValueBase") then 
        return o.Value 
    end
    return nil
end

local function onRespawn()
    currentTag = nil
    pendingSlot = nil
    
    task.spawn(function()
        local startTime = tick()
        while tick() - startTime < 10 do
            if workspace:FindFirstChild("Game") and workspace.Game:FindFirstChild("Players") then
                local pf = workspace.Game.Players:FindFirstChild(player.Name)
                if pf then
                    currentTag = readTagFromFolder(pf)
                    if currentTag then
                        local b = tonumber(currentTag)
                        if b and b >= 0 and b <= 255 then
                            break
                        else
                            currentTag = nil
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

local function fireSelect(slot)
    if not currentTag then return end
    
    local b = tonumber(currentTag)
    if not b or b < 0 or b > 255 then return end
    if not selectEmotes[slot] or selectEmotes[slot] == "" then return end
    
    local buf = buffer.create(2)
    buffer.writeu8(buf, 0, b)
    buffer.writeu8(buf, 1, 17)
    
    if remoteSignal then
        firesignal(remoteSignal, buf, {selectEmotes[slot]})
    end
end

if PassCharacterInfo and EmoteRemote then
    PassCharacterInfo.OnClientEvent:Connect(function(...)
        if not pendingSlot then return end
        local slot = pendingSlot
        pendingSlot = nil
        task.wait(0.1)
        fireSelect(slot)
    end)

    local success, oldNamecall
    success, oldNamecall = pcall(function()
        return hookmetamethod(game, "__namecall", function(self, ...)
            local args = {...}
            local method = getnamecallmethod()

            if not checkcaller() and method == "FireServer" and self == EmoteRemote and type(args[1]) == "string" then
                for i = 1, 12 do
                    if emoteEnabled[i] and currentEmotes[i] ~= "" and args[1] == currentEmotes[i] then
                        pendingSlot = i
                        blockOriginalEmote = true
                        task.delay(0.1, function()
                            blockOriginalEmote = false
                            if pendingSlot == i then
                                pendingSlot = nil
                                fireSelect(i)
                            end
                        end)
                        return nil
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end)

    if not success then        
        WindUI:Notify({
            Title = "Executor Incompatible",
            Content = "Your executor is not supported for Namecall hooking.",
            Duration = 5
        })
    end
    
    if player.Character then
        task.spawn(onRespawn)
    end
    
    player.CharacterAdded:Connect(function()
        task.wait(1)
        onRespawn()
    end)
end

Tabs.EmoteChanger:Section({ Title = "Emote Changer", TextSize = 20 })
Tabs.EmoteChanger:Divider()

for i = 1, 12 do
   currentEmoteInputs[i] = Tabs.EmoteChanger:Input({
        Title = "Current Emote " .. i,
        Placeholder = "Enter current emote name",
        Value = currentEmotes[i],
        Callback = function(v) 
            currentEmotes[i] = v:gsub("%s+", "")
        end
    })
end

Tabs.EmoteChanger:Divider()

for i = 1, 12 do
   selectEmoteInputs[i] = Tabs.EmoteChanger:Input({
        Title = "Select Emote " .. i,
        Placeholder = "Enter select emote name",
        Value = selectEmotes[i],
        Callback = function(v) 
            selectEmotes[i] = v:gsub("%s+", "")
        end
    })
end

local emoteOptionValue = 1
local function updateEmoteNum(character)
    if character then
        character:SetAttribute("EmoteNum", emoteOptionValue)
    end
end

Tabs.EmoteChanger:Input({
    Title = "Emote Possible option",
    Desc = "Higher Value may Broke emote animation recommend Use 1-3",
    Placeholder = "1",
    Callback = function(v)
        emoteOptionValue = tonumber(v) or 1
        if player.Character then
            updateEmoteNum(player.Character)
        end
    end
})

player.CharacterAdded:Connect(function(character)
    task.wait(1)
    updateEmoteNum(character)
end)

task.spawn(function()
    while true do
        task.wait(2)
        if player.Character and player.Character:GetAttribute("EmoteNum") ~= emoteOptionValue then
            updateEmoteNum(player.Character)
        end
    end
end)

EmoteChangerEmoteApply = Tabs.EmoteChanger:Button({
    Title="Apply Emote Mappings",
    Icon="check",
    Callback=function()
        local hasAnyEmote = false
        for i=1,12 do
            if currentEmotes[i] ~= "" or selectEmotes[i] ~= "" then
                hasAnyEmote = true
                break
            end
        end
        
        if not hasAnyEmote then
            WindUI:Notify({Title="Emote Changer", Content="Please enter your emote", Duration=3})
            return
        end
        
        local function normalizeEmoteName(name)
            return name:gsub("%s+", ""):lower()
        end
        
        local function isValidEmote(emoteName)
            if emoteName == "" then return false, "" end
            local normalizedInput = normalizeEmoteName(emoteName)
            local emotesFolder = ReplicatedStorage:FindFirstChild("Items")
            if emotesFolder then
                emotesFolder = emotesFolder:FindFirstChild("Emotes")
                if emotesFolder then
                    for _, emoteModule in ipairs(emotesFolder:GetChildren()) do
                        if emoteModule:IsA("ModuleScript") then
                            if normalizeEmoteName(emoteModule.Name) == normalizedInput then
                                return true, emoteModule.Name
                            end
                        end
                    end
                end
            end
            return false, ""
        end
        
        for i=1,12 do
            local currentValid = isValidEmote(currentEmotes[i])
            local selectValid = isValidEmote(selectEmotes[i])
            emoteEnabled[i] = (currentValid and selectValid and currentEmotes[i]:lower() ~= selectEmotes[i]:lower())
        end
        
        WindUI:Notify({
            Title="Emote Changer",
            Content="Emote mappings updated!",
            Duration=5
        })
    end
})

EmoteChangerEmoteReset = Tabs.EmoteChanger:Button({
    Title = "Reset All Emotes",
    Icon = "trash-2",
    Callback = function()
        for i = 1, 12 do
            currentEmotes[i] = ""
            selectEmotes[i] = ""
            emoteEnabled[i] = false
            if currentEmoteInputs[i] and currentEmoteInputs[i].Set then currentEmoteInputs[i]:Set("") end
            if selectEmoteInputs[i] and selectEmoteInputs[i].Set then selectEmoteInputs[i]:Set("") end
        end
        WindUI:Notify({Title = "Emote Changer", Content = "All emotes have been reset!"})
    end
})

Tabs.EmoteChanger:Section({ Title = "Legacy remote function hooks"})
local yaneedtobeinlegacymodetousethis = Tabs.EmoteChanger:Paragraph({ Title = "ya need to be in legacy mode to use this"})

if game.PlaceId == 96537472072550 then
    local originalEmotes = {}
    local pendingEmoteChanges = {}
    local blockRemote = false
    local hookInstalled = false
    
    for i = 1, 8 do
        originalEmotes[i] = player:GetAttribute("Emote" .. i) or ""
    end
    
    local function InstallHook()
        local Event = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Emote")
        if not Event or hookInstalled then return end
        
        local success, err = pcall(function()
            local mt = getrawmetatable(game)
            local old = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                if method == "FireServer" and self == Event then
                    local emoteNum = tonumber(args[1])
                    if blockRemote and emoteNum and emoteNum >= 1 and emoteNum <= 8 then
                        local tag = player.Character and player.Character:GetAttribute("Tag")
                        local name = pendingEmoteChanges[emoteNum] or player:GetAttribute("Emote" .. emoteNum)
                        if tag and name then
                            firesignal(ReplicatedStorage.Events.Character.Emote.OnClientEvent, tag, name)
                        end
                        return nil
                    end
                end
                return old(self, ...)
            end
            setreadonly(mt, true)
            hookInstalled = true
        end)
    end

    local emoteValues = {}
    local items = ReplicatedStorage:FindFirstChild("Items")
    if items and items:FindFirstChild("Emotes") then
        for _, v in pairs(items.Emotes:GetChildren()) do table.insert(emoteValues, v.Name) end
    end

    local legacyDropdowns = {}
    for i = 1, 8 do
        legacyDropdowns[i] = Tabs.EmoteChanger:Dropdown({
            Title = "Emote Slot " .. i,
            Values = emoteValues,
            Callback = function(v) pendingEmoteChanges[i] = v end
        })
    end

    Tabs.EmoteChanger:Button({
        Title = "Apply All Emotes",
        Callback = function()
            blockRemote = true
            for i, v in pairs(pendingEmoteChanges) do
                player:SetAttribute("Emote" .. i, v)
            end
            InstallHook()
            WindUI:Notify({Title = "Legacy", Content = "Applied"})
        end
    })
end

Tabs.EmoteChanger:Section({ Title = "Swapping mode (Global)"})

local EmoteSwapper = {
    SwappedPairs = {},
    CurrentEmotes = table.create(12, ""),
    SelectedEmotes = table.create(12, "")
}

for i = 1, 12 do
    Tabs.EmoteChanger:Input({
        Title = "Swap Current " .. i,
        Callback = function(v) EmoteSwapper.CurrentEmotes[i] = v end
    })
    Tabs.EmoteChanger:Input({
        Title = "Swap Target " .. i,
        Callback = function(v) EmoteSwapper.SelectedEmotes[i] = v end
    })
end

local function performSwap(cur, sel)
    local folder = ReplicatedStorage:FindFirstChild("Items") and ReplicatedStorage.Items:FindFirstChild("Emotes")
    if not folder then return end
    local obj1 = folder:FindFirstChild(cur)
    local obj2 = folder:FindFirstChild(sel)
    if obj1 and obj2 then
        local temp = "TEMP_" .. tick()
        obj1.Name = temp
        obj2.Name = cur
        obj1.Name = sel
        return true
    end
    return false
end

Tabs.EmoteChanger:Button({
    Title = "Apply Emote Swap",
    Icon = "refresh-cw",
    Callback = function()
        for i = 1, 12 do
            if EmoteSwapper.CurrentEmotes[i] ~= "" and EmoteSwapper.SelectedEmotes[i] ~= "" then
                if performSwap(EmoteSwapper.CurrentEmotes[i], EmoteSwapper.SelectedEmotes[i]) then
                    EmoteSwapper.SwappedPairs[EmoteSwapper.CurrentEmotes[i]] = EmoteSwapper.SelectedEmotes[i]
                end
            end
        end
        WindUI:Notify({Title = "Swapper", Content = "Swapped successfully"})
    end
})
