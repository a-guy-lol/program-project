local uilibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/zexonMain/zexonUI.lua"))()
local windowz = uilibrary:CreateWindow("                                                              Zexon V1", "(SEWH Edition)", true)

-- #########################################################
-- ######################## Info Page ######################
-- #########################################################

local infoPage = windowz:CreatePage("Info")
local infoSection = infoPage:CreateSection("Zexon - Info")
infoSection:CreateParagraph("welcome to zexon!", [[how's it going!

   Zexon is just a simple lightweight script hub that helps you gain access to many features 😄.
   oh btw use Z key to close and open the UI
]], 5)
infoSection:CreateParagraph("Discontinue Note", [[
   Zexon Script will be discontinued forever. The only updates I will provide are loadstring fixes so the script executes and is usable.
]], 4)

-- #########################################################
-- ######################## SEWH / Farm Page ######################
-- #########################################################

local sewhPage = windowz:CreatePage("SEWH")
local farmSection = sewhPage:CreateSection("SEWH - Farm")

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Workspace   = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player      = Players.LocalPlayer

local farmEnabled = false
local connections = {}
local currentTargetPosition
local threatTimer = 0
local lastHealth

local baseY = -400
local teleportPositions = {
    Vector3.new(93, baseY, 105),
    Vector3.new(-78, baseY, -195),
    Vector3.new(217, baseY, -206),
    Vector3.new(215, baseY, -438)
}

local teleportInterval      = 0.5
local minY, maxY            = -480, -350
local platformSize          = Vector3.new(6,1,6)
local safeRadius            = 40
local detectionRadius       = 45
local threatCheckInterval   = 0.1

local function getValidFilterList()
    local list = {}
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if char then table.insert(list, char) end
    if hrp  then table.insert(list, hrp)  end
    return list
end

local scanParams = OverlapParams.new()
scanParams.FilterType = Enum.RaycastFilterType.Blacklist

-- Create platform under player
local function createPlatform(pos)
    local p = Instance.new("Part")
    p.Size         = platformSize
    p.Position     = pos - Vector3.new(0,4,0)
    p.Anchored     = true
    p.Transparency = 0.3
    p.BrickColor   = BrickColor.new("Dark stone grey")
    p.Name         = "TempPlatform"
    p.Parent       = Workspace
    task.delay(1.5, function() if p.Parent then p:Destroy() end end)
end

-- Teleport player
local function teleportTo(pos)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(pos)
    createPlatform(pos)
    currentTargetPosition = pos
end

-- Detect incoming threats
local function isThreatApproaching()
    scanParams.FilterDescendantsInstances = getValidFilterList()
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local hrpPos = hrp.Position
    local parts  = Workspace:GetPartBoundsInRadius(hrpPos, detectionRadius, scanParams)
    for _, part in ipairs(parts) do
        if part.Name ~= "TempPlatform" and not part:IsDescendantOf(char) then
            local v = part.Velocity
            if v.Magnitude > 1 then
                local dirToPlayer = (hrpPos - part.Position).Unit
                if dirToPlayer:Dot(v.Unit) > 0.7 then return true end
            end
        end
    end
    return false
end

-- Check if teleport position is clear
local function isPositionClear(pos)
    local boxParams = OverlapParams.new()
    boxParams.FilterType = Enum.RaycastFilterType.Blacklist
    boxParams.FilterDescendantsInstances = getValidFilterList()
    local size = Vector3.new(4,6,4)
    local parts = Workspace:GetPartBoundsInBox(CFrame.new(pos), size, boxParams)
    for _, part in ipairs(parts) do
        if part.Name ~= "TempPlatform"
        and not part:IsDescendantOf(player.Character)
        and not Players:GetPlayerFromCharacter(part.Parent) then
            return false
        end
    end
    return true
end

-- Heartbeat: stray, damage, threat
local function onHeartbeat(dt)
    if not farmEnabled then return end
    local char = player.Character
    if not char then return end

    local humanoid = char:FindFirstChild("Humanoid")
    local hrp      = char:FindFirstChild("HumanoidRootPart")

    -- Stray check
    if hrp and currentTargetPosition and (hrp.Position - currentTargetPosition).Magnitude > safeRadius then
        teleportTo(currentTargetPosition)
    end

    -- Damage check
    if humanoid and lastHealth and humanoid.Health < lastHealth then
        teleportTo(currentTargetPosition or teleportPositions[1])
    end
    lastHealth = humanoid and humanoid.Health or lastHealth

    -- Threat check (throttled)
    threatTimer += dt
    if threatTimer >= threatCheckInterval then
        threatTimer = 0
        if isThreatApproaching() then
            teleportTo(currentTargetPosition or teleportPositions[1])
        end
    end
end

-- Teleport cycle
local function startTeleportLoop()
    spawn(function()
        while farmEnabled do
            for _, basePos in ipairs(teleportPositions) do
                if not farmEnabled then break end
                local ok
                for i=1,5 do
                    local test = Vector3.new(basePos.X, math.random(minY, maxY), basePos.Z)
                    if isPositionClear(test) then ok = test break end
                end
                if ok then teleportTo(ok) end
                task.wait(teleportInterval)
            end
        end
    end)
end

-- Simulate a key press using VirtualInputManager
local function simulateKeyPress(key)
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    task.wait(0.1) -- Simulate key hold duration
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function startAntiIdle()
    spawn(function()
        local actions = {
            function() simulateKeyPress(Enum.KeyCode.W) end,   
            function() simulateKeyPress(Enum.KeyCode.A) end,   
            function() simulateKeyPress(Enum.KeyCode.S) end,   
            function() simulateKeyPress(Enum.KeyCode.D) end,   
            function() simulateKeyPress(Enum.KeyCode.Space) end 
        }
        while farmEnabled do
            local action = actions[math.random(1, #actions)] 
            action()
            task.wait(math.random(2, 5) / 10)
        end
    end)
end

-- Start farm
local function startFarm()
    farmEnabled = true

    -- Disable 3D rendering every 0.5s
    spawn(function()
        while farmEnabled do
            RunService:Set3dRenderingEnabled(false)
            task.wait(0.5)
        end
    end)

    lastHealth = player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health
    currentTargetPosition = teleportPositions[1]
    threatTimer = 0

    table.insert(connections, RunService.Heartbeat:Connect(onHeartbeat))
    table.insert(connections, player.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        lastHealth = char:FindFirstChild("Humanoid") and char.Humanoid.Health
        teleportTo(teleportPositions[1])
    end))

    startTeleportLoop()
    startAntiIdle()
end

local function stopFarm()
    farmEnabled = false

    RunService:Set3dRenderingEnabled(true)

    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    connections = {}

    for _, p in ipairs(Workspace:GetChildren()) do
        if p.Name == "TempPlatform" then p:Destroy() end
    end
end

farmSection:CreateParagraph("Warning", [[
        Script is in beta. Many errors can occur.
]], 5)

-- UI Toggles
farmSection:CreateToggle("   Enable AFK-Farm", {Toggled = false, Description = "Teleports to a hidden and safe location"}, function(on)
    if on then startFarm() else stopFarm() end
end)
farmSection:CreateToggle("   Serverhop on admin join", {Toggled = false, Description = "(DOESNT WORK) To avoid admins, it teleports to a new server"}, function(on) end)

-- #########################################################
-- ######################## Settings ######################
-- #########################################################

local settingsPage = windowz:CreatePage("Settings")
local settingsTerminateSection = settingsPage:CreateSection("Zexon - Terminate")
settingsTerminateSection:CreateButton("      Terminate | Zexon Script", function()
    stopFarm()
    for _, gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if gui.Name == "ZexonUI" then gui:Destroy() end
    end
    print("[zexon] script has been terminated.")
end)
