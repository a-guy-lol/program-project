local MM2WeaponModule = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local CurrentRoundClient = nil

pcall(function()
	CurrentRoundClient = require(ReplicatedStorage.Modules.CurrentRoundClient)
end)

local function IsTool(x)
	return typeof(x) == "Instance" and x:IsA("Tool")
end

local function GetCharacter()
	return LocalPlayer and LocalPlayer.Character or nil
end

local function GetBackpack()
	if not LocalPlayer then
		return nil
	end
	return LocalPlayer:FindFirstChildOfClass("Backpack")
end

local function EnsureToolEquipped(tool)
	if not IsTool(tool) then
		return false
	end
	local character = GetCharacter()
	if not character then
		return false
	end
	if tool.Parent == character then
		return true
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	hum:EquipTool(tool)
	return tool.Parent == character
end

local function FindToolByAttribute(attrName)
	local backpack = GetBackpack()
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if IsTool(item) and item:GetAttribute(attrName) == true then
				return item
			end
		end
	end

	local character = GetCharacter()
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if IsTool(item) and item:GetAttribute(attrName) == true then
				return item
			end
		end
	end

	return nil
end

local function FindPlayerByName(nameOrDisplay)
	if typeof(nameOrDisplay) ~= "string" then
		return nil
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name == nameOrDisplay or p.DisplayName == nameOrDisplay then
			return p
		end
	end
	return nil
end

local function IsAliveInCharacter(character)
	if not character or not character.Parent then
		return false
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function GetRoundPlayersLightweight()
	local result = {}
	local seen = {}

	if CurrentRoundClient and CurrentRoundClient.PlayerData then
		for name, data in pairs(CurrentRoundClient.PlayerData) do
			local p = Players:FindFirstChild(name)
			if p and p ~= LocalPlayer and (not data.Dead) and IsAliveInCharacter(p.Character) then
				result[#result + 1] = p
				seen[p] = true
			end
		end
	end

	if #result == 0 then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and not seen[p] and IsAliveInCharacter(p.Character) then
				result[#result + 1] = p
			end
		end
	end

	return result
end

local function ResolveTargetCFrame(targetPlayer)
	if not targetPlayer or not targetPlayer.Character then
		return nil
	end

	local targetPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		or targetPlayer.Character:FindFirstChild("Head")
		or targetPlayer.Character:FindFirstChildWhichIsA("BasePart")

	if not targetPart then
		return nil
	end

	return targetPart.CFrame
end

function MM2WeaponModule:HasGun()
	return FindToolByAttribute("IsGun") ~= nil
end

function MM2WeaponModule:HasKnife()
	return FindToolByAttribute("IsKnife") ~= nil
end

function MM2WeaponModule:UseGun(target)
	local gun = FindToolByAttribute("IsGun")
	if not gun then
		return false, "no_gun"
	end
	if not EnsureToolEquipped(gun) then
		return false, "equip_failed"
	end

	local shootRemote = gun:FindFirstChild("Shoot")
	if not shootRemote or not shootRemote:IsA("RemoteEvent") then
		return false, "no_shoot_remote"
	end

	local targetPlayer = target
	if typeof(target) == "string" then
		targetPlayer = FindPlayerByName(target)
	end
	if not targetPlayer or not targetPlayer:IsA("Player") then
		return false, "bad_target"
	end

	local character = GetCharacter()
	if not character then
		return false, "no_character"
	end

	local targetCFrame = ResolveTargetCFrame(targetPlayer)
	if not targetCFrame then
		return false, "target_no_character"
	end

	-- Wall-ignore mode: use the target cframe as origin and target.
	-- This bypasses the local CantShoot LOS check path since we do not use that script flow.
	shootRemote:FireServer(targetCFrame, targetCFrame)
	return true
end

function MM2WeaponModule:UseKnife(target)
	local knife = FindToolByAttribute("IsKnife")
	if not knife then
		return false, "no_knife"
	end
	if not EnsureToolEquipped(knife) then
		return false, "equip_failed"
	end

	local targetPlayer = target
	if typeof(target) == "string" then
		targetPlayer = FindPlayerByName(target)
	end
	if not targetPlayer or not targetPlayer:IsA("Player") then
		return false, "bad_target"
	end

	local eventsFolder = knife:FindFirstChild("Events")
	if not eventsFolder then
		return false, "no_events"
	end

	local knifeStabbed = eventsFolder:FindFirstChild("KnifeStabbed")
	local handleTouched = eventsFolder:FindFirstChild("HandleTouched")
	if not knifeStabbed or not knifeStabbed:IsA("RemoteEvent") then
		return false, "no_knifestabbed"
	end
	if not handleTouched or not handleTouched:IsA("RemoteEvent") then
		return false, "no_handletouched"
	end

	knifeStabbed:FireServer()

	local tChar = targetPlayer.Character
	if not tChar then
		return false, "target_no_character"
	end

	local touchedPart = tChar:FindFirstChild("HumanoidRootPart")
		or tChar:FindFirstChild("Head")
		or tChar.PrimaryPart
		or tChar:FindFirstChildWhichIsA("BasePart")
	if not touchedPart then
		return false, "target_no_part"
	end

	handleTouched:FireServer(touchedPart)
	return true
end

function MM2WeaponModule:UseKnifeAll()
	local roundPlayers = GetRoundPlayersLightweight()
	if #roundPlayers == 0 then
		return false, "no_round_players"
	end

	local hitCount = 0
	for _, p in ipairs(roundPlayers) do
		local ok = self:UseKnife(p)
		if ok then
			hitCount = hitCount + 1
		end
	end

	if hitCount == 0 then
		return false, "no_hits"
	end
	return true, hitCount
end

return MM2WeaponModule
