-- [[ MM2 Game State Module ]] --
local MM2Data = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Internal Variables
local CurrentRoundClient = nil

-- Attempt to load the game's internal round data
pcall(function()
    CurrentRoundClient = require(ReplicatedStorage.Modules.CurrentRoundClient)
end)

-- Helper: Check if a player has a specific tool (Fallback method)
local function HasTool(player, toolName)
    if not player then return false end
    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character
    
    if backpack and backpack:FindFirstChild(toolName) then return true end
    if character and character:FindFirstChild(toolName) then return true end
    return false
end

local function IsLikelyMap(instance)
    if not instance or instance.Parent ~= Workspace then
        return false
    end
    local mapId = instance:GetAttribute("MapID")
    return type(mapId) == "string" and mapId ~= ""
end

local function GetRootPositionFromSource(source)
    if typeof(source) == "Vector3" then
        return source
    end

    local player = source
    if not player then
        player = LocalPlayer
    end

    if typeof(player) == "Instance" and player:IsA("Player") and player.Character then
        local root = player.Character:FindFirstChild("HumanoidRootPart")
            or player.Character:FindFirstChild("Head")
            or player.Character.PrimaryPart
        if root and root:IsA("BasePart") then
            return root.Position
        end
    end

    return nil
end

-- [[ PUBLIC FUNCTIONS ]] --

-- 1. Check if the round is currently active
function MM2Data:IsRoundActive()
    if CurrentRoundClient and CurrentRoundClient.PlayerData then
        -- If the game's internal table has data, the round is likely active
        for _, _ in pairs(CurrentRoundClient.PlayerData) do
            return true
        end
    end
    
    -- Fallback: If anyone has a gun/knife, round is active
    for _, p in ipairs(Players:GetPlayers()) do
        if HasTool(p, "Knife") or HasTool(p, "Gun") then
            return true
        end
    end
    
    return false
end

-- 2. Get the full list of roles for the current round
function MM2Data:GetRoundRoles()
    local roleData = {
        Murderer = nil,
        Sheriff = nil,
        Innocents = {}
    }

    -- Method A: Use Game's Internal Data (Fastest/Most Accurate)
    if CurrentRoundClient and CurrentRoundClient.PlayerData then
        for name, data in pairs(CurrentRoundClient.PlayerData) do
            local p = Players:FindFirstChild(name)
            if p and not data.Dead then
                if data.Role == "Murderer" then
                    roleData.Murderer = p
                elseif data.Role == "Sheriff" then
                    roleData.Sheriff = p
                else
                    table.insert(roleData.Innocents, p)
                end
            end
        end
    end

    -- Method B: Physical Inventory Scan (Fallback if Method A fails)
    -- Only runs if Method A didn't find the critical roles
    if not roleData.Murderer or not roleData.Sheriff then
        for _, p in ipairs(Players:GetPlayers()) do
            if not p.Character then continue end
            
            -- Check Murderer
            if not roleData.Murderer and HasTool(p, "Knife") then
                roleData.Murderer = p
            end
            
            -- Check Sheriff
            if not roleData.Sheriff and HasTool(p, "Gun") then
                roleData.Sheriff = p
            end
        end
    end

    return roleData
end

-- 3. Check if a specific player (or LocalPlayer) is alive in the round
function MM2Data:IsPlayerInRound(player)
    if not player then player = LocalPlayer end -- Default to LocalPlayer
    
    if CurrentRoundClient and CurrentRoundClient.PlayerData then
        local data = CurrentRoundClient.PlayerData[player.Name]
        if data and not data.Dead then
            return true
        end
    end
    
    -- Fallback: If they are in the map area (usually not in lobby)
    -- or simply if they have a role-based weapon.
    if HasTool(player, "Knife") or HasTool(player, "Gun") then
        return true
    end
    
    return false
end

-- 4. Get current round map (direct child of workspace with MapID attribute)
function MM2Data:GetMap()
    local fallbackMap = nil

    for _, child in ipairs(Workspace:GetChildren()) do
        if IsLikelyMap(child) then
            -- Prefer an active map that already has coin state objects.
            if child:FindFirstChild("CoinContainer") then
                return child
            end
            if child:FindFirstChild("CoinAreas") or child:FindFirstChild("Spawns") then
                fallbackMap = fallbackMap or child
            else
                fallbackMap = fallbackMap or child
            end
        end
    end

    return fallbackMap
end

-- 5. Get nearest coin in active map's CoinContainer
-- Returns: coinInstance, coinPath, distance
function MM2Data:GetNearestCoin(fromSource)
    local map = self:GetMap()
    if not map then
        return nil, nil, nil
    end

    local coinContainer = map:FindFirstChild("CoinContainer")
    if not coinContainer then
        return nil, nil, nil
    end

    local origin = GetRootPositionFromSource(fromSource)
    if not origin then
        return nil, nil, nil
    end

    local nearestCoin = nil
    local nearestDistance = math.huge

    for _, coin in ipairs(coinContainer:GetChildren()) do
        local coinPart = coin
        if not coinPart:IsA("BasePart") then
            coinPart = coin:FindFirstChildWhichIsA("BasePart")
        end

        if coinPart and coinPart:IsA("BasePart") then
            local dist = (coinPart.Position - origin).Magnitude
            if dist < nearestDistance then
                nearestCoin = coin
                nearestDistance = dist
            end
        end
    end

    if not nearestCoin then
        return nil, nil, nil
    end

    return nearestCoin, nearestCoin:GetFullName(), nearestDistance
end

return MM2Data
