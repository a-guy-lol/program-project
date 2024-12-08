local blacklistedGames = {
    [16732694052] = true, -- Fisch
    [4111023553] = true, -- Deepwoken
    [9938675423] = true, -- Oaklands
    [6403373529] = true, -- Slap Battles
    [2768379856] = true, -- 3008
    [13772394625] = true, -- Bladeball
    [2788229376] = true, -- Da Hood
    [9872472334] = true, -- Evade
    [185655149] = true, -- Bloxburg
}

local placeId = game.PlaceId
if blacklistedGames[placeId] then
    local player = game:GetService("Players").LocalPlayer
    player:Kick("We care about you, so Zexon has prevented you from using the script because there's a critical anti-cheat in this game. <3")
    while true do
        task.wait()
    end
end






loadstring(game:HttpGet('https://pastebin.com/raw/XQp2bfhe'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local angle = 1
local radius = 1
local angleSpeed = 1
local points = 1
local blackHoleActive = false
local blackHolePoints = {}
local humanoidRootPart, Attachment1
local nodeStrength = 25000
local nodeSpeed = 2500

local settingsFile = "zexon-settings.json"
local defaultSettings = {
    nodeResponse = 2500,
    nodeTorque = 25000,
    speed = 10,
    range = 10,
    nodes = 1
}

local settings = {}


local function saveSettings()
    local json = HttpService:JSONEncode(settings)
    writefile(settingsFile, json)
end

local function loadSettings()
    if isfile(settingsFile) then
        local json = readfile(settingsFile)
        settings = HttpService:JSONDecode(json)
    else
        settings = defaultSettings
        saveSettings()
    end
end



local targetPlayer = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or nil

if not getgenv().Network then
    getgenv().Network = {
        BaseParts = {},
        Velocity = Vector3.new(14.46262424, 14.46262424, 14.46262424)
    }

    Network.RetainPart = function(part)
        if typeof(part) == "Instance" and part:IsA("BasePart") and part:IsDescendantOf(Workspace) then
            table.insert(Network.BaseParts, part)
            part.CustomPhysicalProperties = PhysicalProperties.new(0.001, 0, 0, 0, 0)
            part.CanCollide = false
        end
    end

    local function EnablePartControl()
        LocalPlayer.ReplicationFocus = Workspace
        RunService.Heartbeat:Connect(function()
            sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
            for _, part in pairs(Network.BaseParts) do
                if part:IsDescendantOf(Workspace) then
                    part.Velocity = Network.Velocity
                end
            end
        end)
    end

    EnablePartControl()
end

local function setupPlayer()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return nil, nil, nil
    end

    -- Ensure CycloneNodes folder exists
    local Folder = Workspace:FindFirstChild("CycloneNodes")
    if not Folder then
        Folder = Instance.new("Folder", Workspace)
        Folder.Name = "CycloneNodes"
    end

    -- Create an attachment part (optional logic)
    local Part = Instance.new("Part", Folder)
    local Attachment = Instance.new("Attachment", Part)
    Part.Anchored = true
    Part.CanCollide = false
    Part.Transparency = 0
    Part.Size = Vector3.new(1, 1, 1)

    return humanoidRootPart, Attachment, Folder
end

local function updateBlackHolePoints(count)
    -- Destroy old points
    for _, part in pairs(blackHolePoints) do
        if part.Parent then
            part.Parent:Destroy()
        end
    end
    blackHolePoints = {}

    for i = 1, count do
        local Part = Instance.new("Part", Workspace.CycloneNodes)
        local Attachment = Instance.new("Attachment", Part)
        Part.Anchored = true
        Part.CanCollide = false
        Part.Transparency = 0.5
        Part.Size = Vector3.new(1, 1, 1)
        table.insert(blackHolePoints, Attachment)
    end
end

local function ForcePart(v)
    if v:IsA("Part") and not v.Anchored and not v.Parent:FindFirstChild("Humanoid") and not v.Parent:FindFirstChild("Head") and v.Name ~= "Handle" then
        for _, x in next, v:GetChildren() do
            if x:IsA("BodyAngularVelocity") or x:IsA("BodyForce") or x:IsA("BodyGyro") or x:IsA("BodyPosition") or x:IsA("BodyThrust") or x:IsA("BodyVelocity") or x:IsA("RocketPropulsion") then
                x:Destroy()
            end
        end
        if v:FindFirstChild("Attachment") then
            v:FindFirstChild("Attachment"):Destroy()
        end
        if v:FindFirstChild("AlignPosition") then
            v:FindFirstChild("AlignPosition"):Destroy()
        end
        if v:FindFirstChild("Torque") then
            v:FindFirstChild("Torque"):Destroy()
        end
        v.CanCollide = false

        Network.RetainPart(v)
        local Torque = Instance.new("Torque", v)
        Torque.Torque = Vector3.new(nodeStrength, nodeStrength, nodeStrength)
        local AlignPosition = Instance.new("AlignPosition", v)
        local Attachment2 = Instance.new("Attachment", v)
        Torque.Attachment0 = Attachment2
        AlignPosition.MaxForce = math.huge
        AlignPosition.MaxVelocity = math.huge
        AlignPosition.Responsiveness = nodeSpeed
        AlignPosition.Attachment0 = Attachment2

        if #blackHolePoints > 0 then
            local pointIndex = math.random(1, #blackHolePoints)
            AlignPosition.Attachment1 = blackHolePoints[pointIndex]
        end
    end
end

local function toggleBlackHole()
    blackHoleActive = not blackHoleActive
    if blackHoleActive then
        for _, v in next, Workspace:GetDescendants() do
            ForcePart(v)
        end

        Workspace.DescendantAdded:Connect(function(v)
            if blackHoleActive then
                ForcePart(v)
            end
        end)
        spawn(function()
            while blackHoleActive and RunService.RenderStepped:Wait() do
                angle = angle + math.rad(angleSpeed)
                local targetCFrame = (targetPlayer and targetPlayer.CFrame) or humanoidRootPart.CFrame

                for i, attachment in pairs(blackHolePoints) do
                    local angleOffset = (math.pi * 2 / #blackHolePoints) * (i - 1)
                    local offsetX = math.cos(angle + angleOffset) * radius
                    local offsetZ = math.sin(angle + angleOffset) * radius

                    attachment.WorldCFrame = targetCFrame * CFrame.new(offsetX, 0, offsetZ)
                end
            end
        end)
    else
        for _, part in pairs(Network.BaseParts) do
            if part:IsDescendantOf(Workspace) then
                part.CustomPhysicalProperties = nil
                part.CanCollide = true
                part.Velocity = Vector3.new(0, 0, 0)
                part.RotVelocity = Vector3.new(0, 0, 0)

                for _, child in pairs(part:GetChildren()) do
                    if child:IsA("Attachment") or child:IsA("AlignPosition") or child:IsA("Torque") then
                        child:Destroy()
                    end
                end

                part.Position = Vector3.new(0, -1000, 0)
            end
        end

        Network.BaseParts = {}

        for _, attachment in pairs(blackHolePoints) do
            attachment.WorldCFrame = CFrame.new(0, -1000, 0)
        end
    end
end

local function applySettings()
    nodeSpeed = settings.nodeResponse
    nodeStrength = settings.nodeTorque
    angleSpeed = settings.speed
    radius = settings.range
    points = settings.nodes
    settings.autosaveEnabled = settings.autosaveEnabled or false
    settings.autosaveNotifications = settings.autosaveNotifications or false
    updateBlackHolePoints(points)
end

LocalPlayer.CharacterAdded:Connect(function()
    humanoidRootPart, Attachment1 = setupPlayer()
end)

humanoidRootPart, Attachment1, Folder = setupPlayer()
updateBlackHolePoints(points)
loadSettings()
applySettings()

blackHoleActive = false

-- UI Library
local uilibrary = loadstring(game:HttpGet("https://pastebin.com/raw/1Qg7Lmad"))()
local windowz = uilibrary:CreateWindow("                                                              Zexon", "Script Menu", true)

local infoPage = windowz:CreatePage("Info")
local mainPage = windowz:CreatePage("Main")
local mainSection = mainPage:CreateSection("Main - FE")

-- execute infinite yield
mainSection:CreateButton("   Execute | Inf Yield", function ()
   loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
end)


-- inf yield's WalkSpeed changer
mainSection:CreateSlider("   Change WalkSpeed", {Min = 16, Max = 150, DefaultValue = 16}, function(Value)
        local speaker = game.Players.LocalPlayer
        local Char = speaker.Character or workspace:FindFirstChild(speaker.Name)
        local Human = Char and Char:FindFirstChildWhichIsA("Humanoid")

        if Char and Human then
            Human.WalkSpeed = Value
        end
        HumanModCons = HumanModCons or {}
        HumanModCons.wsLoop = (HumanModCons.wsLoop and HumanModCons.wsLoop:Disconnect() and false) or Human:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if Human then
                Human.WalkSpeed = Value
            end
        end)
        HumanModCons.wsCA = (HumanModCons.wsCA and HumanModCons.wsCA:Disconnect() and false) or speaker.CharacterAdded:Connect(function(nChar)
            Char, Human = nChar, nChar:WaitForChild("Humanoid")
            Human.WalkSpeed = Value
            HumanModCons.wsLoop = (HumanModCons.wsLoop and HumanModCons.wsLoop:Disconnect() and false) or Human:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if Human then
                    Human.WalkSpeed = Value
                end
            end)
        end)
end)



-- ####### FLING PLAYERS #########
local bugFling = {
    [189707] = true,
    [606849621] = true
}
local targetDropdown, targetCharacter
local placeId = game.PlaceId
local flingSection = mainPage:CreateSection("Fling Players - FE")
local function updateTargetDropdown()
    local playerOptions = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerOptions, player.Name)
        end
    end

    if targetDropdown then
        targetDropdown:Clear()
        targetDropdown:Add(playerOptions)
    end
end
targetDropdown = flingSection:CreateDropdown("Select a Target", {
    List = {},
    Default = nil
}, function(selectedPlayerName)
    local selectedPlayer = Players:FindFirstChild(selectedPlayerName)
    if selectedPlayer and selectedPlayer.Character then
        targetCharacter = selectedPlayer.Character
    else
        targetCharacter = nil
    end
end)
Players.PlayerAdded:Connect(updateTargetDropdown)
Players.PlayerRemoving:Connect(updateTargetDropdown)
updateTargetDropdown()

local function isTargetMoving(TargetRootPart)
    return TargetRootPart.Velocity.Magnitude > 0.5
end

local function randomDecimal(min, max)
    return min + math.random() * (max - min) -- Generate a random decimal between min and max
end

local function SkidFling(TargetPlayer)
    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart

    local TCharacter = TargetPlayer.Character
    local THumanoid = TCharacter and TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter and TCharacter:FindFirstChild("Head")

    if not (Character and Humanoid and RootPart) then
        return false -- Return false if fling fails
    end

    if not (TCharacter and THumanoid and TRootPart) then
        return false -- Return false if fling fails
    end

    -- Save the original position of the local player
    if not getgenv().OldPos then
        getgenv().OldPos = RootPart.CFrame
    end

    -- Save the original position of the target
    local TargetStartPos = TRootPart.Position

    -- Track fling duration
    local StartTime = tick()
    local MaxFlingTime = 10 -- Max fling duration in seconds

    local FPos = function(BasePart, Pos, Ang)
        RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
        Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
        RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
        RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    local SFBasePart = function(BasePart)
        local Angle = 0

        repeat
            if (TRootPart.Position - TargetStartPos).Magnitude > 100 then
                return true
            end

            -- Stop if local player dies
            if not Humanoid or Humanoid.Health <= 0 then
                return false
            end

            -- Stop if fling exceeds max allowed time
            if tick() - StartTime > MaxFlingTime then
                uilibrary:AddNoti("Anti-fling detected", "Target has antifling", 3, true)
                return false
            end

            -- Adjust local player's position around the target
            Angle = Angle + 0
            local moveDirection = TRootPart.Velocity.Unit
            local offset
            if isTargetMoving(TRootPart) then
                -- Generate random offset using randomDecimal for decimal precision
                local forwardOffset = moveDirection * randomDecimal(-10, 10)
                offset = forwardOffset
            else
                offset = Vector3.new(0, 1, 0)
            end

            FPos(BasePart, CFrame.new(offset) + Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)), CFrame.Angles(math.rad(Angle), 0, 0))
            task.wait()
        until BasePart.Parent ~= TargetPlayer.Character
    end

    -- Prevent falling through the void
    workspace.FallenPartsDestroyHeight = math.huge

    -- Apply high velocity to fling
    local BV = Instance.new("BodyVelocity")
    BV.Name = "FlingVelocity"
    BV.Parent = RootPart
    BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
    BV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)

    local success = false
    if TRootPart then
        success = SFBasePart(TRootPart)
    elseif THead then
        success = SFBasePart(THead)
    else
        success = false
    end

    -- Cleanup after fling
    BV:Destroy()
    RootPart.Velocity = Vector3.zero
    RootPart.RotVelocity = Vector3.zero
    workspace.FallenPartsDestroyHeight = -500

    -- Ensure the local player returns to their original position
    RootPart.CFrame = getgenv().OldPos
    task.wait(0.1) -- Allow physics engine to settle

    return success
end

-- Fling all players in sequence and stop if local player dies
local function FlingAll()
    local players = Players:GetPlayers()
    local totalPlayers = #players - 1 -- Exclude LocalPlayer
    local flungCount = 0

    for _, player in ipairs(players) do
        if player ~= LocalPlayer then
            -- Stop if the local player dies during Fling All
            if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChildOfClass("Humanoid") or LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
                uilibrary:AddNoti("Fling All Stopped", "You died during the flinging process.", 3, true)
                break
            end

            -- Attempt to fling the player and update the counter
            if SkidFling(player) then
                flungCount = flungCount + 1
                -- Show notification with progress
                uilibrary:AddNoti(
                    "Flung Player.",
                    string.format("%d/%d Players flung", flungCount, totalPlayers),
                    3,
                    true
                )
            end
        end
    end

    -- Final reset for local player after Fling All
    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart

    if RootPart then
        RootPart.Velocity = Vector3.zero
        RootPart.RotVelocity = Vector3.zero
        RootPart.CFrame = getgenv().OldPos -- Restore to original position
    end
end


if bugFling[placeId] then
flingSection:CreateButton('   Fling Target   -    Might not work', function()
    if targetCharacter then
        local TargetPlayer = Players:FindFirstChild(targetCharacter.Name)
        if TargetPlayer then
            SkidFling(TargetPlayer)
        end
    end
end)
flingSection:CreateButton('   Fling All     -      Might not work ', function()
    FlingAll()
end)

else
flingSection:CreateButton("   Fling All", function()
    FlingAll()
end)
flingSection:CreateButton("   Fling Target", function()
    if targetCharacter then
        local TargetPlayer = Players:FindFirstChild(targetCharacter.Name)
        if TargetPlayer then
            SkidFling(TargetPlayer)
        end
    end
end)
end


local CyclonePage = windowz:CreatePage("Cyclone")
local CycloneSection = CyclonePage:CreateSection("Cyclone - Settings")

CycloneSection:CreateSlider("   Speed        - Orbit speed", {Min = 1, Max = 100, DefaultValue = settings.speed}, function(Value)
    settings.speed = Value
    angleSpeed = Value
end)

CycloneSection:CreateSlider("   Range        - Distance between the player", {Min = 1, Max = 100, DefaultValue = settings.range}, function(Value)
    settings.range = Value
    radius = Value
end)

CycloneSection:CreateSlider("   Nodes        - Amount of cyclones", {Min = 1, Max = 10, DefaultValue = settings.nodes}, function(Value)
    settings.nodes = Value
    points = Value
    updateBlackHolePoints(points)
end)

CycloneSection:CreateToggle("   Enable Cyclone", {Toggled = false, Description = false}, function(Value)
    if Value then
        toggleBlackHole()
        uilibrary:AddNoti("Cyclone Enabled", "If you die, this will automatically disable.", 10, true)
    else
        blackHoleActive = false
    end
end)

local CycloneMiscSection = CyclonePage:CreateSection("Misc - Settings")

CycloneMiscSection:CreateSlider("   Node Response        - Reaction speed of nodes", {Min = 1, Max = 5000, DefaultValue = settings.nodeResponse}, function(Value)
    settings.nodeResponse = Value
    nodeSpeed = Value
end)

CycloneMiscSection:CreateSlider("   Node Torque              - Strength speed of nodes", {Min = 1, Max = 50000, DefaultValue = settings.nodeTorque}, function(Value)
    settings.nodeTorque = Value
    nodeStrength = Value
end)

local playerDropdown

local function refreshPlayerDropdown()
    local playerNames = {}
    for _, player in pairs(Players:GetPlayers()) do
        table.insert(playerNames, player.Name)
    end

    if playerDropdown then
        playerDropdown:Clear()
        playerDropdown:Add(playerNames)
    end
end

playerDropdown = CycloneMiscSection:CreateDropdown("   Select Player", {
    List = {},
    Default = LocalPlayer.Name 
}, function(selectedPlayerName)
    local player = Players:FindFirstChild(selectedPlayerName)
    if player and player.Character then
        targetPlayer = player.Character:FindFirstChild("HumanoidRootPart")
    else
        targetPlayer = nil
    end
end)


Players.PlayerAdded:Connect(refreshPlayerDropdown)
Players.PlayerRemoving:Connect(refreshPlayerDropdown)
refreshPlayerDropdown()

local player = game.Players.LocalPlayer
local function onCharacterAdded(character)
    uilibrary:AddNoti("Respawn Detected", "Cyclone reset to prevent issues. (Dropdown must be changed)", 15, true)
    blackHoleActive = false
end
player.CharacterAdded:Connect(onCharacterAdded)


local settingsPage = windowz:CreatePage("Settings")
local settingsSection = settingsPage:CreateSection("Zexon - Settings")

function loadGetServiceV95()
    local serviceV96 = windowz:CreatePage("ServiceTab - FE")
    local serviceSectionV98 = serviceV96:CreateSection("Service - Settings")
    serviceSectionV98:CreateButton("   Unpack | ServiceV6", function ()
    loadstring(game:HttpGet('https://pastebin.com/raw/c3b0rWf1'))()
    end)
    serviceSectionV98:CreateButton("   Unpack | ServiceV15", function ()
    loadstring(game:HttpGet('https://pastebin.com/raw/2Xk8Tm8r'))()
    end)
end
if getgenv().syLaBgQEIxLMqjOuVhNop3AUXlcDG3 == "3mgSJ9XjIBEmIsFmAdrukvtLWnMQoc6z" then
    loadGetServiceV95()
end


settingsSection:CreateToggle("   Autosave Notifications", {Toggled = settings.autosaveNotifications, Description = "Toggle autosave notifications on/off"}, function(Value)
    settings.autosaveNotifications = Value
    autosaveNotifications = Value
    saveSettings()

end)

settingsSection:CreateToggle("   Enable Autosave", {Toggled = settings.autosaveEnabled, Description = "Enable or disable autosaving configurations"}, function(Value)
    settings.autosaveEnabled = Value 
    saveSettings()

end)



spawn(function()
    while true do
        task.wait(15)
        if settings.autosaveEnabled then
            saveSettings()
            if autosaveNotifications then
                uilibrary:AddNoti("Settings Autosaved.", "Zexon has successfully autosaved your settings.", 5, true)
            end
        end
        
    end
end)

spawn(function()
    task.wait(1)
    uilibrary:AddNoti("UI loaded.", "Zexon has successfully loaded your settings.", 5, true)
end)





local infoSection = infoPage:CreateSection("Zexon - Info")

infoSection:CreateParagraph("welcome to zexon!", [[
   hi there ]] .. LocalPlayer.Name .. [[, how's it going!

   Zexon is just a simple lightweight script hub that helps you gain access to many features 😄.
   
   oh btw use Z key to close and open the UI
   
   even though exploiting is fun, we decided to blacklist these games due to their anticheats:
   
   Blacklisted Games:
   - Fisch
   - Deepwoken
   - Oaklands
   - Slap Battles
   - 3008
   - Bladeball
   - Da Hood
   - Evade
   - Bloxburg
   
   we just want to keep you safe from these evil anti cheats 😔.
]], 22) -- The message will be displayed with a height for 8 lines

local infoSection = infoPage:CreateSection("Zexon - Latest Update")
infoSection:CreateParagraph("Zexon Release V1.2.4 - 2024 Dec 8", [[
   + Added Cyclone loader for seamless setup.
   + Cyclone now saves configs automatically.
   + New Fling feature for players. 💀
   + Anti-cheat callback added for safety.
   + New Releases and settings tabs!.
   Note: Fixing Cyclone Playerlist dropdown bug soon. 🧐
]], 3)


local releasePage = windowz:CreatePage("Releases")



local releasesSection = releasePage:CreateSection("Zexon - Releases")
releasesSection:CreateParagraph("Devlogs", [[
   hey there. 
   Zexon consists of 2 developers. 
   The identities of the developers will be kept private.
   
   this is here to show you what we are working on.
   ~ We are majorly working on fixing Playerlist dropdown for Cyclone - FE. Improving this will remove the need to select the player over and over just to enable it.
   ~ We're also looking to add a universal car speed changer if possible and other much unique features.
   
]], 10)





local releaseV124 = releasePage:CreateSection("Zexon Release V1.2.4 - 2024 Dec 8")
releaseV124:CreateParagraph("Cyclone Updates", [[
   + Added Cyclone loader for seamless setup.
   + Cyclone now saves configs automatically.
   + New Fling feature for players. 💀
   + Anti-cheat callback added for safety.
   + New Releases and settings tabs!.
   Note: Fixing Cyclone Playerlist dropdown bug soon. 🧐
]], 5)

local releaseV123 = releasePage:CreateSection("Zexon Release V1.2.3 - 2024 Dec 4")
releaseV123:CreateParagraph("Bug Fixes and Features", [[
   + Notifications added for responses. 😎
   + Playerlist reintroduced (buggy).
]], 3)

local releaseV122 = releasePage:CreateSection("Zexon Release V1.2.2 - 2024 Dec 2")
releaseV122:CreateParagraph("UI hotfix", [[
   + 'Z' keybind toggles menu UI.
   - Removed Playerlist targeting cause buggy.
   Note: No mobile support yet. 😥
]], 3)

local releaseV121 = releasePage:CreateSection("Zexon Release V1.2.1 - 2024 Dec 1")
releaseV121:CreateParagraph("Execution Fix", [[
   + Fixed execution issues. 🦾
]], 2)

local releaseV120 = releasePage:CreateSection("Zexon Release V1.2 - 2024 Nov 30")
releaseV120:CreateParagraph("Cyclone Improvements", [[
   + Playerlist targeting added.
   + Cyclone advanced settings added.
   + Fixed Cyclone node issues.
   + Defined toggles and sliders for dummies. 🤓
]], 5)

local releaseV110 = releasePage:CreateSection("Zexon Release V1.1 - 2024 Nov 27")
releaseV110:CreateParagraph("UI and Stability", [[
   + New Lightweight and responsive UI. 🤩
   + Cyclone now stable after respawn.
   Note: Cyclone updates in progress.
]], 3)

local releaseV101 = releasePage:CreateSection("Zexon Release V1.0.1 - 2024 Nov 26")
releaseV101:CreateParagraph("New Rayfield Theme", [[
   + Cool new Rayfield theme added! 😎
]], 2)

local releaseV1 = releasePage:CreateSection("Zexon Release V1 - 2024 Nov 21")
releaseV1:CreateParagraph("Zexon Release", [[
   + Added WalkSpeed slider feature.
   + Infinite Yield button added.
   + Cyclone - FE introduced!
   Note: The Release of this script. How amusing! 🥳
]], 4)


