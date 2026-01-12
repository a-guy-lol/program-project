-- #########################################################
-- ##################### Core Services #####################
-- #########################################################
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- #########################################################
-- ##################### Logic Variables ###################
-- #########################################################

-- Logic State
local scriptRunning = true 
local CurrentTargetHead = nil 
local LockedTarget = nil 

local EnemiesFolder = Workspace:WaitForChild("enemies")
local BossFolder = Workspace:WaitForChild("BossFolder")
local PowerupsFolder = Workspace:WaitForChild("Powerups")

-- Remotes
local GunRemote = ReplicatedStorage:WaitForChild("Gun")
local KnifeRemote = ReplicatedStorage:WaitForChild("forhackers")

-- #########################################################
-- ##################### Settings System ###################
-- #########################################################

local settings = nil
-- Default Settings (Only used if no save file exists)
local defaultSettings = {
    -- Game Settings
    autoFire = false,
    fireDelay = 0.1,
    sliderValue = 10,
    autoPowerups = false,
    superSpeed = false,
    
    -- Targeting
    targetMode = "Target Closest", 
    targetBoss = true,
    
    -- Visuals
    espEnabled = false,
    healthEspEnabled = false,
    
    -- System
    autosaveEnabled = true,
    autosaveNotifications = true
}

local settingsFolder = "zexon" 
local settingsFile = settingsFolder .. "/zombie-attack-config.json"

local function ensureFolder()
    if not isfolder(settingsFolder) then
        makefolder(settingsFolder)
    end
end

local function saveSettings()
    if not settings then return end
    
    local success, result = pcall(function()
        ensureFolder()
        local json = HttpService:JSONEncode(settings)
        writefile(settingsFile, json)
    end)
    
    if not success then
        warn("Settings save error: " .. tostring(result))
    end
end

local function loadSettings()
    -- 1. If no file exists, use Defaults
    if not isfile(settingsFile) then
        return table.clone(defaultSettings)
    end
    
    -- 2. Try to load the File
    local success, result = pcall(function()
        return HttpService:JSONDecode(readfile(settingsFile))
    end)
    
    -- 3. If file is corrupted, use Defaults
    if not success or type(result) ~= "table" then
        warn("Failed to load settings (Using Defaults):", result)
        return table.clone(defaultSettings)
    end
    
    -- 4. Merge Logic: Take the FILE data, and only add missing keys from Default
    -- This ensures your saved settings are respected.
    local loaded = result
    local changed = false
    
    for key, value in pairs(defaultSettings) do
        if loaded[key] == nil then
            loaded[key] = value
            changed = true
        end
    end
    
    if changed then
        settings = loaded
        saveSettings()
    end
    
    return loaded
end

-- Initialize Settings
settings = loadSettings()

-- #########################################################
-- ################### Combat & Logic Functions ############
-- #########################################################

local function GetEquippedWeapon()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return nil, nil end

    if tool:FindFirstChild("Origin") and (tool:FindFirstChild("GunController") or tool:FindFirstChild("Setting")) then
        return tool, "Gun"
    elseif tool:FindFirstChild("KnifeController") then
        return tool, "Knife"
    elseif tool:FindFirstChild("Origin") then 
        return tool, "Gun" 
    end
    
    return tool, "Unknown"
end

local function GetTargetFromFolder(folder)
    local candidates = {}
    local myPos = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart.Position
    if not myPos then return {} end

    for _, enemy in pairs(folder:GetChildren()) do
        local hum = enemy:FindFirstChild("Humanoid")
        local head = enemy:FindFirstChild("Head")
        
        -- STRICTLY NO VISIBILITY CHECK HERE
        -- It grabs everything alive, even through walls.
        if enemy:IsA("Model") and hum and head and hum.Health > 0 then
            table.insert(candidates, {
                Model = enemy,
                Head = head,
                Hum = hum,
                Dist = (head.Position - myPos).Magnitude
            })
        end
    end
    return candidates
end

local function GetBestTarget()
    -- Lock Logic (High HP Mode)
    if settings.targetMode == "Target High HP" and LockedTarget then
        if LockedTarget.Parent and LockedTarget.Parent:FindFirstChild("Humanoid") and LockedTarget.Parent.Humanoid.Health > 0 then
             if settings.targetBoss and LockedTarget.Parent.Parent ~= BossFolder then
                 local bosses = GetTargetFromFolder(BossFolder)
                 if #bosses > 0 then
                     LockedTarget = nil 
                 else
                     return LockedTarget, false 
                 end
             else
                 return LockedTarget, (LockedTarget.Parent.Parent == BossFolder)
             end
        else
            LockedTarget = nil -- Target dead
        end
    end

    local candidates = {}
    local isBossTargeting = false

    if settings.targetBoss then
        candidates = GetTargetFromFolder(BossFolder)
        if #candidates > 0 then isBossTargeting = true end
    end

    if #candidates == 0 then
        candidates = GetTargetFromFolder(EnemiesFolder)
        isBossTargeting = false
    end

    if #candidates == 0 then 
        LockedTarget = nil
        return nil, false 
    end

    local chosenHead = nil

    if settings.targetMode == "Target Closest" then
        table.sort(candidates, function(a, b) return a.Dist < b.Dist end)
        chosenHead = candidates[1].Head
    
    elseif settings.targetMode == "Target High HP" then
        table.sort(candidates, function(a, b) return a.Hum.Health > b.Hum.Health end)
        chosenHead = candidates[1].Head
        LockedTarget = chosenHead 
        
    elseif settings.targetMode == "Target Random" then
        chosenHead = candidates[math.random(1, #candidates)].Head
    end

    if not chosenHead then chosenHead = candidates[1].Head end
    return chosenHead, isBossTargeting
end

-- #########################################################
-- ################### Optimized Visuals ###################
-- #########################################################

local function CleanupModel(model)
    local h = model:FindFirstChild("AdminHighlight")
    if h then h:Destroy() end
    
    local head = model:FindFirstChild("Head")
    if head then
        if head:FindFirstChild("HealthDisplay") then head.HealthDisplay:Destroy() end
        if head:FindFirstChild("TargetDisplay") then head.TargetDisplay:Destroy() end
    end
end

local function UpdateVisuals()
    local COL_TARGET = Color3.fromRGB(255, 0, 0)   
    local COL_BOSS   = Color3.fromRGB(0, 0, 180)   
    local COL_ZOMBIE = Color3.fromRGB(0, 255, 0)   

    local folders = {EnemiesFolder, BossFolder}

    for _, folder in pairs(folders) do
        for _, model in pairs(folder:GetChildren()) do
            local hum = model:FindFirstChild("Humanoid")
            
            if model:IsA("Model") and hum and hum.Health > 0 then
                
                local isBoss = (folder == BossFolder)
                local isTarget = (model.Head == CurrentTargetHead)

                -- 1. HIGHLIGHTS
                local highlight = model:FindFirstChild("AdminHighlight")
                if settings.espEnabled and scriptRunning then
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "AdminHighlight"
                        highlight.Adornee = model
                        highlight.Parent = model
                        highlight.FillTransparency = 0.5
                        highlight.OutlineTransparency = 0
                    end
                    local targetColor = isTarget and COL_TARGET or (isBoss and COL_BOSS or COL_ZOMBIE)
                    if highlight.FillColor ~= targetColor then
                        highlight.FillColor = targetColor
                        highlight.OutlineColor = targetColor
                    end
                else
                    if highlight then highlight:Destroy() end
                end

                -- 2. TEXT
                local head = model:FindFirstChild("Head")
                if head then
                    
                    -- A. Health GUI (Standard World Scale)
                    local hpBB = head:FindFirstChild("HealthDisplay")
                    if settings.healthEspEnabled and scriptRunning then
                        if not hpBB then
                            hpBB = Instance.new("BillboardGui")
                            hpBB.Name = "HealthDisplay"
                            hpBB.Adornee = head
                            hpBB.Parent = head
                            hpBB.AlwaysOnTop = true
                            hpBB.Size = UDim2.new(5, 0, 1, 0) 
                            hpBB.StudsOffset = Vector3.new(0, 2.5, 0)

                            local hpLbl = Instance.new("TextLabel")
                            hpLbl.Name = "HP"
                            hpLbl.Parent = hpBB
                            hpLbl.Size = UDim2.new(1,0,1,0)
                            hpLbl.BackgroundTransparency = 1
                            hpLbl.Font = Enum.Font.GothamBold
                            hpLbl.TextColor3 = Color3.new(1,1,1)
                            hpLbl.TextScaled = true
                        end
                        hpBB.HP.Text = math.floor(hum.Health) .. " HP"
                    else
                        if hpBB then hpBB:Destroy() end
                    end

                    -- B. Target GUI (Screen Size)
                    local tgtBB = head:FindFirstChild("TargetDisplay")
                    if settings.healthEspEnabled and scriptRunning and isTarget then
                        if not tgtBB then
                            tgtBB = Instance.new("BillboardGui")
                            tgtBB.Name = "TargetDisplay"
                            tgtBB.Adornee = head
                            tgtBB.Parent = head
                            tgtBB.AlwaysOnTop = true
                            -- OFFSET (Pixels) makes it constant size on screen
                            tgtBB.Size = UDim2.new(0, 200, 0, 50) 
                            tgtBB.StudsOffset = Vector3.new(0, 4, 0) 

                            local tgtLbl = Instance.new("TextLabel")
                            tgtLbl.Name = "Target"
                            tgtLbl.Parent = tgtBB
                            tgtLbl.Size = UDim2.new(1,0,1,0)
                            tgtLbl.BackgroundTransparency = 1
                            tgtLbl.Font = Enum.Font.GothamBlack
                            tgtLbl.TextColor3 = COL_TARGET
                            tgtLbl.TextSize = 24 
                            tgtLbl.TextStrokeTransparency = 0
                            tgtLbl.Text = "TARGETING"
                        end
                    else
                        if tgtBB then tgtBB:Destroy() end
                    end
                end
            else
                CleanupModel(model)
            end
        end
    end
end

-- #########################################################
-- ######################## UI Setup #######################
-- #########################################################
local uilibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/zexonUI.lua"))()

local windowz = uilibrary:CreateWindow("                                            Zexon Hub - Zombie Attack", "v1.0", true)

-- #########################################################
-- ######################## Info Page ######################
-- #########################################################
local infoPage = windowz:CreatePage("Info")
local infoSection = infoPage:CreateSection("Information")

infoSection:CreateParagraph("Status", [[
    Script Loaded Successfully.
    Auto-Save is Enabled.
    Wall-Check Removed (Shoot Through Walls).
]], 4)

-- #########################################################
-- ######################## Game Page ######################
-- #########################################################
local gamePage = windowz:CreatePage("Game")
local combatSection = gamePage:CreateSection("Combat Automation")

combatSection:CreateToggle(" Auto Fire / Throw", {Toggled = settings.autoFire, Description = "Automatically uses equipped weapon"}, function(Value)
    settings.autoFire = Value
end)

combatSection:CreateSlider(" Fire Delay %", {Min = 0, Max = 100, DefaultValue = settings.sliderValue}, function(Value)
    settings.sliderValue = Value
    settings.fireDelay = Value / 100 
end)

local miscSection = gamePage:CreateSection("Misc & Movement")

miscSection:CreateToggle(" Auto Collect Powerups", {Toggled = settings.autoPowerups, Description = "Instantly touches spawned powerups"}, function(Value)
    settings.autoPowerups = Value
end)

miscSection:CreateToggle(" Super Speed (25)", {Toggled = settings.superSpeed, Description = "Locks WalkSpeed to 25"}, function(Value)
    settings.superSpeed = Value
end)

local targetSection = gamePage:CreateSection("Targeting Logic")

targetSection:CreateDropdown(" Targeting Mode", {
    List = {"Target Closest", "Target High HP", "Target Random"},
    Default = settings.targetMode
}, function(selectedOption)
    settings.targetMode = selectedOption
    LockedTarget = nil 
end)

targetSection:CreateToggle(" Priority Boss Targeting", {Toggled = settings.targetBoss, Description = "Focus Boss over zombies if alive"}, function(Value)
    settings.targetBoss = Value
end)


-- #########################################################
-- ##################### Visuals Page ######################
-- #########################################################
local vizPage = windowz:CreatePage("Visuals")
local espSection = vizPage:CreateSection("ESP Settings")

espSection:CreateToggle(" Enemy Highlights", {Toggled = settings.espEnabled, Description = "Green: Zombie | Blue: Boss | Red: Target"}, function(Value)
    settings.espEnabled = Value
    if not Value then UpdateVisuals() end 
end)

espSection:CreateToggle(" Health & Status", {Toggled = settings.healthEspEnabled, Description = "Shows HP and Target Text"}, function(Value)
    settings.healthEspEnabled = Value
    if not Value then UpdateVisuals() end 
end)

-- #########################################################
-- ##################### Settings Page #####################
-- #########################################################
local settingsPage = windowz:CreatePage("Settings")
local configSection = settingsPage:CreateSection("Configuration")

configSection:CreateToggle(" Enable Autosave", {Toggled = settings.autosaveEnabled, Description = "Automatically saves settings to file"}, function(Value)
    settings.autosaveEnabled = Value
    saveSettings()
end)

configSection:CreateToggle(" Notifications", {Toggled = settings.autosaveNotifications, Description = "Show notification when saving"}, function(Value)
    settings.autosaveNotifications = Value
    saveSettings()
end)

configSection:CreateButton(" Force Save Settings", function()
    saveSettings()
    uilibrary:AddNoti("Success", "Settings saved manually.", 3, true)
end)

local terminateSection = settingsPage:CreateSection("Unload")

terminateSection:CreateButton(" Terminate Script", function()
    scriptRunning = false
    settings.autoFire = false
    settings.espEnabled = false
    settings.healthEspEnabled = false
    settings.autoPowerups = false
    settings.superSpeed = false
    
    UpdateVisuals() 
    
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = 16
    end
    
    saveSettings()
    
    local coreGui = game:GetService("CoreGui")
    if coreGui:FindFirstChild("ZexonUI") then
        coreGui:FindFirstChild("ZexonUI"):Destroy()
    end
    
    print("Script Terminated.")
end)

-- #########################################################
-- ######################## LOOPS ##########################
-- #########################################################

-- 1. Auto Fire Loop
task.spawn(function()
    while scriptRunning do
        if settings.autoFire then
            local tool, weaponType = GetEquippedWeapon()
            if tool and weaponType ~= "Unknown" then
                local targetHead, isBoss = GetBestTarget()
                CurrentTargetHead = targetHead
                
                if targetHead then
                    local myPos = LocalPlayer.Character.PrimaryPart.Position
                    if weaponType == "Gun" then
                        local originPart = tool:FindFirstChild("Origin")
                        if originPart then
                            -- Raw Remote Fire (No Visuals, No Checks)
                            local args = {
                                ["Normal"] = Vector3.new(0, 1, 0),
                                ["Direction"] = (targetHead.Position - originPart.Position).Unit * 1000,
                                ["Name"] = tool.Name,
                                ["Hit"] = targetHead,
                                ["Origin"] = originPart.Position,
                                ["Pos"] = targetHead.Position
                            }
                            GunRemote:FireServer(args)
                        end
                    elseif weaponType == "Knife" then
                        task.spawn(function()
                            KnifeRemote:InvokeServer("throw", tool.Name, targetHead.CFrame)
                        end)
                    end
                end
            else
                CurrentTargetHead = nil
            end
        else
            CurrentTargetHead = nil
        end
        
        local delay = math.max(0, settings.fireDelay) 
        if delay == 0 then RunService.Heartbeat:Wait() else task.wait(delay) end
    end
end)

-- 2. Visuals & Speed Loop
task.spawn(function()
    while scriptRunning do
        UpdateVisuals()
        
        if settings.superSpeed and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum and hum.WalkSpeed ~= 25 then
                hum.WalkSpeed = 25
            end
        end
        
        task.wait(0.1) 
    end
end)

-- 3. Powerups Loop
task.spawn(function()
    while scriptRunning do
        if settings.autoPowerups then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("Head") then
                local myHead = char.Head
                for _, model in pairs(PowerupsFolder:GetChildren()) do
                    for _, part in pairs(model:GetDescendants()) do
                        if part:IsA("BasePart") and part:FindFirstChild("TouchInterest") then
                            firetouchinterest(myHead, part, 0)
                            firetouchinterest(myHead, part, 1)
                        end
                    end
                end
            end
        end
        task.wait(0.2)
    end
end)

-- 4. Autosave Loop
task.spawn(function()
    while scriptRunning do
        task.wait(15)
        if settings.autosaveEnabled then
            saveSettings()
            if settings.autosaveNotifications then
                uilibrary:AddNoti("Autosave", "Settings saved.", 3, true)
            end
        end
    end
end)

uilibrary:AddNoti("Zexon", "Script Loaded", 5, true)
