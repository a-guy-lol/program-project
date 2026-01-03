-- v0.1
local MoveModule = {}

MoveModule.Config = {
	minSpeed = 18.5,
	maxSpeed = 80,
	brakeStart = 35,
	arrivalDist = 0.9,
	lockRotation = true,
	faceOrigin = false,
	smoothRate = 14,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

MoveModule._renderConnection = nil
MoveModule._bodyVelocity = nil
MoveModule._diedConnection = nil
MoveModule._characterAddedConnection = nil

MoveModule._humanoid = nil
MoveModule._humanoidRootPart = nil
MoveModule._active = false
MoveModule._targetPosition = nil
MoveModule._rotationOnlyCFrame = nil
MoveModule._originalHumanoidProperties = nil

local function Vector3Lerp(fromVector, toVector, alpha)
	return fromVector + (toVector - fromVector) * alpha
end

local function SuppressWalkAnimations(humanoid)
	for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
		local trackName = (track.Name or ""):lower()
		local animationId = ""
		if track.Animation and type(track.Animation.AnimationId) == "string" then
			animationId = track.Animation.AnimationId:lower()
		end
		if trackName:match("walk") or trackName:match("run") or animationId:match("walk") or animationId:match("run") then
			track:Stop(0.05)
		end
	end
end

function MoveModule:_RestoreHumanoid()
	if not self._humanoid or not self._originalHumanoidProperties then
		return
	end
	self._humanoid.WalkSpeed = self._originalHumanoidProperties.WalkSpeed
	self._humanoid.JumpPower = self._originalHumanoidProperties.JumpPower
	self._humanoid.AutoRotate = self._originalHumanoidProperties.AutoRotate
	self._originalHumanoidProperties = nil
end

function MoveModule:_StopMovement(restoreHumanoid)
	self._active = false
	self._targetPosition = nil
	self._rotationOnlyCFrame = nil

	if self._renderConnection then
		self._renderConnection:Disconnect()
		self._renderConnection = nil
	end

	if self._bodyVelocity then
		self._bodyVelocity:Destroy()
		self._bodyVelocity = nil
	end

	if restoreHumanoid then
		self:_RestoreHumanoid()
	end
end

function MoveModule:_UnbindCharacter()
	self:_StopMovement(false)

	if self._diedConnection then
		self._diedConnection:Disconnect()
		self._diedConnection = nil
	end

	self._humanoid = nil
	self._humanoidRootPart = nil
	self._originalHumanoidProperties = nil
end

function MoveModule:_BindCharacter(character)
	self:_UnbindCharacter()

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoidRootPart or not humanoid then
		return
	end

	self._humanoidRootPart = humanoidRootPart
	self._humanoid = humanoid

	self._diedConnection = humanoid.Died:Connect(function()
		self:_UnbindCharacter()
	end)
end

function MoveModule:_EnsureBound()
	local character = LocalPlayer.Character
	if character and character.Parent then
		if not self._humanoid or not self._humanoidRootPart then
			self:_BindCharacter(character)
		end
	end

	if not self._characterAddedConnection then
		self._characterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(newCharacter)
			self:_BindCharacter(newCharacter)
		end)
	end
end

function MoveModule:SetConfig(configurationTable)
	self:_EnsureBound()
	if type(configurationTable) ~= "table" then
		return
	end
	for key, value in pairs(configurationTable) do
		if self.Config[key] ~= nil then
			self.Config[key] = value
		end
	end
end

function MoveModule:Stop()
	self:_StopMovement(true)
end

function MoveModule:Goto(targetPosition)
	self:_EnsureBound()
	if typeof(targetPosition) ~= "Vector3" then
		return false
	end
	if not self._humanoid or not self._humanoidRootPart then
		return false
	end

	self:_StopMovement(true)

	self._active = true
	self._targetPosition = targetPosition

	local humanoid = self._humanoid
	local humanoidRootPart = self._humanoidRootPart
	local configuration = self.Config

	self._originalHumanoidProperties = {
		WalkSpeed = humanoid.WalkSpeed,
		JumpPower = humanoid.JumpPower,
		AutoRotate = humanoid.AutoRotate,
	}

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false

	if configuration.lockRotation then
		local currentCFrame = humanoidRootPart.CFrame
		self._rotationOnlyCFrame = currentCFrame - currentCFrame.Position
	end

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.P = 1250
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	bodyVelocity.Parent = humanoidRootPart
	self._bodyVelocity = bodyVelocity

	self._renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if not self._active then
			return
		end
		if not humanoidRootPart.Parent or not humanoid.Parent then
			self:_StopMovement(true)
			return
		end

		deltaTime = math.max(deltaTime, 1 / 120)

		if configuration.faceOrigin then
			local lookTarget = Vector3.new(0, humanoidRootPart.Position.Y, 0)
			humanoidRootPart.CFrame = CFrame.lookAt(humanoidRootPart.Position, lookTarget)
			humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		elseif configuration.lockRotation and self._rotationOnlyCFrame then
			humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position) * self._rotationOnlyCFrame
			humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end

		local toTarget = self._targetPosition - humanoidRootPart.Position
		local distance = toTarget.Magnitude

		local desiredSpeed
		if distance >= configuration.brakeStart then
			desiredSpeed = configuration.maxSpeed
		else
			local t = math.clamp(distance / math.max(configuration.brakeStart, 0.0001), 0, 1)
			desiredSpeed = configuration.minSpeed + (configuration.maxSpeed - configuration.minSpeed) * t
		end

		local direction = (distance > 0.0001) and toTarget.Unit or Vector3.new(0, 0, 0)
		local targetVelocity = direction * desiredSpeed

		local lerpAlpha = math.clamp(configuration.smoothRate * deltaTime, 0, 1)
		bodyVelocity.Velocity = Vector3Lerp(bodyVelocity.Velocity, targetVelocity, lerpAlpha)

		SuppressWalkAnimations(humanoid)

		if distance <= configuration.arrivalDist then
			self:_StopMovement(true)
		end
	end)

	return true
end

return MoveModule
