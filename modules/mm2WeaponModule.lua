local MM2WeaponModule = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local CurrentRoundClient = nil

pcall(function()
	CurrentRoundClient = require(ReplicatedStorage.Modules.CurrentRoundClient)
end)

MM2WeaponModule.Prediction = {
	Enabled = false,
	HistorySize = 6,
	MaxVelocity = 45,
	BaseHorizon = 0.09,
	SpeedScale = 0.0035,
	DistanceScale = 0.0009,
	MinHorizon = 0.06,
	MaxHorizon = 0.24,
	CurrentVelocityWeight = 0.6,
	MoveDirectionWeight = 0.2,
	AccelerationWeight = 0.5,
	MinTurnDamping = 0.5,
}
MM2WeaponModule._predictionState = {}

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
	if tool.Parent == character then
		return true
	end

	local deadline = os.clock() + 0.35
	while os.clock() < deadline do
		if tool.Parent == character then
			return true
		end
		task.wait(0.03)
	end

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
		return nil, nil
	end

	local targetPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		or targetPlayer.Character:FindFirstChild("Head")
		or targetPlayer.Character:FindFirstChildWhichIsA("BasePart")

	if not targetPart then
		return nil, nil
	end

	return targetPart.CFrame, targetPart
end

local function ClampVelocity(velocity, maxVelocity)
	if velocity.Magnitude > maxVelocity then
		return velocity.Unit * maxVelocity
	end
	return velocity
end

local function PushSample(self, targetPlayer, targetPart, prediction)
	local id = targetPlayer.UserId or targetPlayer.Name
	local state = self._predictionState[id]
	if not state then
		state = { Samples = {} }
		self._predictionState[id] = state
	end

	local samples = state.Samples
	samples[#samples + 1] = {
		t = os.clock(),
		pos = targetPart.Position,
		vel = targetPart.AssemblyLinearVelocity,
	}

	while #samples > prediction.HistorySize do
		table.remove(samples, 1)
	end

	return state
end

local function EstimateSmoothedVelocity(samples, maxVelocity)
	local totalWeight = 0
	local sum = Vector3.new()

	for i = 1, #samples do
		local age = (#samples - i)
		local weight = 1 / (age + 1)
		sum = sum + (ClampVelocity(samples[i].vel, maxVelocity) * weight)
		totalWeight = totalWeight + weight
	end

	if totalWeight <= 0 then
		return Vector3.new()
	end

	return sum / totalWeight
end

local function EstimateAcceleration(samples, maxVelocity)
	if #samples < 2 then
		return Vector3.new()
	end

	local totalWeight = 0
	local sum = Vector3.new()

	for i = 2, #samples do
		local dt = samples[i].t - samples[i - 1].t
		if dt > 0 then
			local vNow = ClampVelocity(samples[i].vel, maxVelocity)
			local vPrev = ClampVelocity(samples[i - 1].vel, maxVelocity)
			local accel = (vNow - vPrev) / dt
			local weight = i / #samples
			sum = sum + (accel * weight)
			totalWeight = totalWeight + weight
		end
	end

	if totalWeight <= 0 then
		return Vector3.new()
	end

	return sum / totalWeight
end

local function ComputeTurnDamping(samples, prediction)
	if #samples < 2 then
		return 1
	end

	local v1 = samples[#samples - 1].vel
	local v2 = samples[#samples].vel
	if v1.Magnitude < 0.5 or v2.Magnitude < 0.5 then
		return 1
	end

	local dot = math.clamp(v1.Unit:Dot(v2.Unit), -1, 1)
	local stability = (dot + 1) * 0.5
	return prediction.MinTurnDamping + ((1 - prediction.MinTurnDamping) * stability)
end

local function IsTargetVisible(targetPart, targetCharacter)
	local localCharacter = GetCharacter()
	if not localCharacter or not targetPart then
		return false
	end

	local originPart = localCharacter:FindFirstChild("Head")
		or localCharacter:FindFirstChild("HumanoidRootPart")
		or localCharacter.PrimaryPart
	if not originPart then
		return false
	end

	local direction = targetPart.Position - originPart.Position
	if direction.Magnitude <= 0.01 then
		return true
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = { localCharacter }

	local hit = Workspace:Raycast(originPart.Position, direction, rayParams)
	if not hit then
		return true
	end
	return hit.Instance and targetCharacter and hit.Instance:IsDescendantOf(targetCharacter)
end

local function BuildPredictedCFrame(self, targetPlayer, targetPart, prediction)
	local localCharacter = GetCharacter()
	local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
	local shooterPos = localRoot and localRoot.Position or targetPart.Position

	local state = PushSample(self, targetPlayer, targetPart, prediction)
	local samples = state.Samples

	local currentVelocity = ClampVelocity(targetPart.AssemblyLinearVelocity, prediction.MaxVelocity)
	local smoothedVelocity = EstimateSmoothedVelocity(samples, prediction.MaxVelocity)
	local acceleration = EstimateAcceleration(samples, prediction.MaxVelocity)

	local velocity = (currentVelocity * prediction.CurrentVelocityWeight)
		+ (smoothedVelocity * (1 - prediction.CurrentVelocityWeight))

	local hum = targetPart.Parent and targetPart.Parent:FindFirstChildOfClass("Humanoid")
	if hum and hum.MoveDirection.Magnitude > 0.01 then
		local moveVelocity = hum.MoveDirection.Unit * hum.WalkSpeed
		velocity = (velocity * (1 - prediction.MoveDirectionWeight)) + (moveVelocity * prediction.MoveDirectionWeight)
	end

	velocity = ClampVelocity(velocity, prediction.MaxVelocity)

	local speed = velocity.Magnitude
	local distance = (targetPart.Position - shooterPos).Magnitude
	local horizon = prediction.BaseHorizon + (speed * prediction.SpeedScale) + (distance * prediction.DistanceScale)
	horizon = math.clamp(horizon, prediction.MinHorizon, prediction.MaxHorizon)
	horizon = horizon * ComputeTurnDamping(samples, prediction)

	local predictedPos = targetPart.Position
		+ (velocity * horizon)
		+ (acceleration * (0.5 * horizon * horizon * prediction.AccelerationWeight))

	return CFrame.new(predictedPos)
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

	local hrp = character:FindFirstChild("HumanoidRootPart")
	local raycastAttachment = hrp and hrp:FindFirstChild("GunRaycastAttachment")
	local originCFrame = (raycastAttachment and raycastAttachment:IsA("Attachment")) and raycastAttachment.WorldCFrame or nil

	local targetCFrame, targetPart = ResolveTargetCFrame(targetPlayer)
	if not targetCFrame then
		return false, "target_no_character"
	end
	if not IsTargetVisible(targetPart, targetPlayer.Character) then
		return false, "not_visible"
	end

	if self.Prediction.Enabled then
		targetCFrame = BuildPredictedCFrame(self, targetPlayer, targetPart, self.Prediction)
	end

	-- This bypasses local CantShoot UI logic because we call the remote directly.
	shootRemote:FireServer(originCFrame, targetCFrame)
	return true
end

function MM2WeaponModule:TogglePrediction(enabled)
	if enabled == nil then
		self.Prediction.Enabled = not self.Prediction.Enabled
	elseif type(enabled) == "boolean" then
		self.Prediction.Enabled = enabled
	end
	return self.Prediction.Enabled
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
