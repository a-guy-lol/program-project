local customGame = windowz:CreatePage("Game")
local customGameSection = customGame:CreateSection("Murder Mystery 2")
    local function killAllMurder()
    local function findMurderer()
        return LocalPlayer
    end
    if findMurderer() ~= LocalPlayer then
        uilibrary:AddNoti("Murder Error", "You aren't the murder.", 3, true)
        return
    end

    if not LocalPlayer.Character:FindFirstChild("Knife") then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if LocalPlayer.Backpack:FindFirstChild("Knife") then
            hum:EquipTool(LocalPlayer.Backpack:FindFirstChild("Knife"))
        else
            uilibrary:AddNoti("Murder Error", "No knife has been detected.", 3, true)
            return
        end
    end

    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player ~= LocalPlayer then
            player.Character:FindFirstChild("HumanoidRootPart").Anchored = true
            player.Character:FindFirstChild("HumanoidRootPart").CFrame =
                LocalPlayer.Character:FindFirstChild("HumanoidRootPart").CFrame +
                LocalPlayer.Character:FindFirstChild("HumanoidRootPart").CFrame.LookVector * 1
        end
    end

    local args = {
        [1] = "Slash"
    }

    -- Trigger the stab action
    LocalPlayer.Character.Knife.Stab:FireServer(unpack(args))
    end
    customGameSection:CreateButton("   Murder | Kill All | Keybind: Q", function()
killAllMurder()
end)

local function shootMurderer()
        local LocalPlayer = game:GetService("Players").LocalPlayer

        local function findMurderer()
            for _, i in ipairs(game.Players:GetPlayers()) do
                if i.Backpack:FindFirstChild("Knife") then
                    return i
                end
            end

            for _, i in ipairs(game.Players:GetPlayers()) do
                if not i.Character then continue end
                if i.Character:FindFirstChild("Knife") then
                    return i
                end
            end
            return nil
        end

        local function findSheriff()
            for _, i in ipairs(game.Players:GetPlayers()) do
                if i.Backpack:FindFirstChild("Gun") then
                    return i
                end
            end

            for _, i in ipairs(game.Players:GetPlayers()) do
                if not i.Character then continue end
                if i.Character:FindFirstChild("Gun") then
                    return i
                end
            end
            return nil
        end

        local function getPredictedPosition(target, shootOffset)
            local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local targetHum = target.Character:FindFirstChild("Humanoid")
            if not targetHRP or not targetHum then
                uilibrary:AddNoti("Sheriff Error", "Could not find required parts of the target.", 3, true)
                return Vector3.new(0, 0, 0)
            end

            local targetVelocity = targetHRP.AssemblyLinearVelocity
            local predictedPosition = targetHRP.Position + (targetVelocity * Vector3.new(0, 0.5, 0)) * (shootOffset / 15)
            return predictedPosition
        end

        if findSheriff() ~= LocalPlayer then
            uilibrary:AddNoti("Sheriff Error", "No gun detected.", 3, true)
            return
        end

        local murderer = findMurderer()
        if not murderer then
            uilibrary:AddNoti("Sheriff Error", "Murder has died or left.", 3, true)
            return
        end

        if not LocalPlayer.Character:FindFirstChild("Gun") then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if LocalPlayer.Backpack:FindFirstChild("Gun") then
                hum:EquipTool(LocalPlayer.Backpack:FindFirstChild("Gun"))
            else
                uilibrary:AddNoti("Murder Error", "You don't have the gun.", 3, true)
                return
            end
        end

        local murdererHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
        if not murdererHRP then
            uilibrary:AddNoti("Murder Error", "Could not find the murderer's HumanoidRootPart.", 3, true)
            return
        end

        local shootOffset = 2.8 -- Adjust if needed
        local predictedPosition = getPredictedPosition(murderer, shootOffset)

        local args = {
            [1] = 1,
            [2] = predictedPosition,
            [3] = "AH2"
        }

        LocalPlayer.Character.Gun.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(unpack(args))
    end
    
function shootMurderButton()
    local function shootMurderer()
    local LocalPlayer = game:GetService("Players").LocalPlayer

    local function findMurderer()
        for _, i in ipairs(game.Players:GetPlayers()) do
            if i.Backpack:FindFirstChild("Knife") then
                return i
            end
        end

        for _, i in ipairs(game.Players:GetPlayers()) do
            if not i.Character then continue end
            if i.Character:FindFirstChild("Knife") then
                return i
            end
        end
        return nil
    end

    local function findSheriff()
        for _, i in ipairs(game.Players:GetPlayers()) do
            if i.Backpack:FindFirstChild("Gun") then
                return i
            end
        end

        for _, i in ipairs(game.Players:GetPlayers()) do
            if not i.Character then continue end
            if i.Character:FindFirstChild("Gun") then
                return i
            end
        end
        return nil
    end

    local function getPredictedPosition(target, shootOffset)
        local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
        local targetHum = target.Character:FindFirstChild("Humanoid")
        if not targetHRP or not targetHum then return Vector3.new(0, 0, 0), "Missing parts" end

        local targetVelocity = targetHRP.AssemblyLinearVelocity
        local predictedPosition = targetHRP.Position + (targetVelocity * Vector3.new(0, 0.5, 0)) * (shootOffset / 15)
        return predictedPosition
    end

    if findSheriff() ~= LocalPlayer then
        warn("You're not the sheriff/hero.")
        return
    end

    local murderer = findMurderer()
    if not murderer then
        warn("No murderer found.")
        return
    end

    if not LocalPlayer.Character:FindFirstChild("Gun") then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if LocalPlayer.Backpack:FindFirstChild("Gun") then
            hum:EquipTool(LocalPlayer.Backpack:FindFirstChild("Gun"))
        else
            warn("You don't have the gun.")
            return
        end
    end

    local murdererHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
    if not murdererHRP then
        
        return
    end

    local shootOffset = 2.8 -- Adjust if needed
    local predictedPosition = getPredictedPosition(murderer, shootOffset)

    local args = {
        [1] = 1,
        [2] = predictedPosition,
        [3] = "AH2"
    }

    LocalPlayer.Character.Gun.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(unpack(args))
end

-- Call the function to execute
shootMurderer()
end
customGameSection:CreateButton("   Sheriff | Shoot Murder | Keybind: E", function()
    shootMurderer()
end)

local sheriffKey = "e"
local murderKey = "q"
UserInputService.InputBegan:Connect(function(input, gameProcessed)

    local keyPressed = input.KeyCode.Name:lower()

    if keyPressed == sheriffKey then
        -- Call the function for the sheriff keybind
        shootMurderer()
    elseif keyPressed == murderKey then
        -- Call the function for the murder keybind
        -- Replace shootMurderer() with the relevant function for murderKey
        killAllMurder()
    end
end)
-- #########################################################
-- #################### Autofarm Logic #####################
-- #########################################################
-- > Declarations < --

local roles = {}
local globalMurderer = nil
local globalSheriff = nil
local espConnection = nil -- To store the RenderStepped connection

-- > Functions < --

-- Function to check if a player is alive
local function IsAlive(Player)
    for i, v in pairs(roles) do
        if Player.Name == i then
            return not v.Killed and not v.Dead
        end
    end
    return false
end

-- Function to create highlights for players
local function CreateHighlights()
    for _, player in pairs(Players:GetChildren()) do
        if player ~= LocalPlayer and player.Character and not player.Character:FindFirstChild("Highlight") then
            local highlight = Instance.new("Highlight", player.Character)
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0.5
        end
    end
end

-- Function to update highlights based on player roles
local function UpdateHighlights()
    for _, player in pairs(Players:GetChildren()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Highlight") then
            local highlight = player.Character:FindFirstChild("Highlight")
            if player.Name == globalSheriff and IsAlive(player) then
                highlight.FillColor = Color3.fromRGB(0, 0, 255) -- Blue for Sheriff
            elseif player.Name == globalMurderer and IsAlive(player) then
                highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Red for Murderer
            else
                highlight.FillColor = Color3.fromRGB(0, 255, 0) -- Green for Innocent
            end
        end
    end
end

-- Function to remove all highlights
local function RemoveHighlights()
    for _, player in pairs(Players:GetChildren()) do
        if player.Character and player.Character:FindFirstChild("Highlight") then
            player.Character:FindFirstChild("Highlight"):Destroy()
        end
    end
end

-- Function to retrieve player roles
local function UpdateRoles()
    local success, result = pcall(function()
        return ReplicatedStorage:FindFirstChild("GetPlayerData", true):InvokeServer()
    end)

    if success and result then
        roles = result
        for playerName, roleData in pairs(roles) do
            if roleData.Role == "Murderer" then
                globalMurderer = playerName
            elseif roleData.Role == "Sheriff" then
                globalSheriff = playerName
            end
        end
    else
    end
end

-- > UI Integration < --
customGameSection:CreateToggle("   Roles ESP", {Toggled = false, Description = "Toggle Roles ESP On/Off"}, function(Toggled)
    if Toggled then
        -- Enable Roles ESP
        espConnection = RunService.RenderStepped:Connect(function()
            UpdateRoles()
            CreateHighlights()
            UpdateHighlights()
        end)
    else
        -- Disable Roles ESP and cleanup
        if espConnection then
            espConnection:Disconnect()
            espConnection = nil
        end
        RemoveHighlights()
    end
end)