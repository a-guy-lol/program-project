local MoveModule = {}

MoveModule.Config = {
	minSpeed = 20,
	maxSpeed = 50,
	brakeStart = 50,
	arrivalDist = 0.9,
	smoothRate = 14,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

MoveModule._characterAddedConnection = nil
MoveModule._diedConnection = nil
MoveModule._renderConnection = nil

MoveModule._humanoid = nil
MoveModule._humanoidRootPart = nil

MoveModule._bodyVelocity = nil
MoveModule._enabled = false
MoveModule._targetPosition = nil

MoveModule._originalHumanoidProperties = nil

MoveModule._noclipConnection = nil
MoveModule._noclipOriginal = {}

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

function MoveModule:_LockRotation()
	if not self._humanoidRootPart then
		return
	end
	local p = self._humanoidRootPart.Position
	self._humanoidRootPart.CFrame = CFrame.new(p)
	self._humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

function MoveModule:_StartNoclip()
	self:_StopNoclip()
	self._noclipOriginal = {}

	local function ApplyNoclip()
		local character = LocalPlayer.Character
		if not character then
			return
		end
		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") then
				if descendant.CanCollide == true then
					if self._noclipOriginal[descendant] == nil then
						self._noclipOriginal[descendant] = true
					end
					descendant.CanCollide = false
				end
			end
		end
	end

	ApplyNoclip()
	self._noclipConnection = RunService.Stepped:Connect(ApplyNoclip)
end

function MoveModule:_StopNoclip()
	if self._noclipConnection then
		self._noclipConnection:Disconnect()
		self._noclipConnection = nil
	end

	for part, wasCollidable in pairs(self._noclipOriginal) do
		if typeof(part) == "Instance" and part and part.Parent and part:IsA("BasePart") then
			if wasCollidable then
				part.CanCollide = true
			end
		end
	end
	self._noclipOriginal = {}
end

function MoveModule:_RestoreHumanoid()
	if not self._humanoid or not self._originalHumanoidProperties then
		self._originalHumanoidProperties = nil
		return
	end
	self._humanoid.WalkSpeed = self._originalHumanoidProperties.WalkSpeed
	self._humanoid.JumpPower = self._originalHumanoidProperties.JumpPower
	self._humanoid.AutoRotate = self._originalHumanoidProperties.AutoRotate
	self._originalHumanoidProperties = nil
end

function MoveModule:_StopMovement(restoreHumanoid)
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
	self:StopGoto()
	self:_StopMovement(false)
	self:_StopNoclip()

	if self._diedConnection then
		self._diedConnection:Disconnect()
		self._diedConnection = nil
	end

	self._humanoid = nil
	self._humanoidRootPart = nil
	self._originalHumanoidProperties = nil
	self._enabled = false
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
		self:Disable()
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

function MoveModule:Enable()
	self:_EnsureBound()

	-- If already enabled and BV exists, do nothing
	if self._enabled and self._bodyVelocity and self._bodyVelocity.Parent then
		return true
	end

	-- If enabled flag is true but BV is missing, rebuild it
	self._enabled = false
	self:_StopMovement(false)

	if not self._humanoid or not self._humanoidRootPart then
		return false
	end

	self._originalHumanoidProperties = {
		WalkSpeed = self._humanoid.WalkSpeed,
		JumpPower = self._humanoid.JumpPower,
		AutoRotate = self._humanoid.AutoRotate,
	}

	self._humanoid.WalkSpeed = 0
	self._humanoid.JumpPower = 0
	self._humanoid.AutoRotate = false

	self:_LockRotation()
	self:_StartNoclip()

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.P = 1250
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	bodyVelocity.Parent = self._humanoidRootPart
	self._bodyVelocity = bodyVelocity

	self._enabled = true

	self._renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if not self._enabled or not self._bodyVelocity or not self._humanoidRootPart or not self._humanoid then
			return
		end
		if not self._humanoidRootPart.Parent or not self._humanoid.Parent then
			self:Disable()
			return
		end

		deltaTime = math.max(deltaTime, 1 / 120)

		self:_LockRotation()
		SuppressWalkAnimations(self._humanoid)

		if not self._targetPosition then
			self._bodyVelocity.Velocity = Vector3.new(0, 0, 0)
			return
		end

		local toTarget = self._targetPosition - self._humanoidRootPart.Position
		local distance = toTarget.Magnitude

		local desiredSpeed
		if distance >= self.Config.brakeStart then
			desiredSpeed = self.Config.maxSpeed
		else
			local t = math.clamp(distance / math.max(self.Config.brakeStart, 0.0001), 0, 1)
			desiredSpeed = self.Config.minSpeed + (self.Config.maxSpeed - self.Config.minSpeed) * t
		end

		local direction = (distance > 0.0001) and toTarget.Unit or Vector3.new(0, 0, 0)
		local targetVelocity = direction * desiredSpeed

		local lerpAlpha = math.clamp(self.Config.smoothRate * deltaTime, 0, 1)
		self._bodyVelocity.Velocity = Vector3Lerp(self._bodyVelocity.Velocity, targetVelocity, lerpAlpha)

		if distance <= self.Config.arrivalDist then
			self._targetPosition = nil
			self._bodyVelocity.Velocity = Vector3.new(0, 0, 0)
		end
	end)

	return true
end

function MoveModule:Goto(targetPosition)
	self:_EnsureBound()
	if not self._enabled or not self._bodyVelocity or not self._bodyVelocity.Parent then
		return false
	end
	if typeof(targetPosition) ~= "Vector3" then
		return false
	end
	self._targetPosition = targetPosition
	return true
end

function MoveModule:StopGoto()
	self._targetPosition = nil
	if self._enabled and self._bodyVelocity and self._bodyVelocity.Parent then
		self._bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	end
end

function MoveModule:Disable()
	if not self._enabled then
		return
	end
	self._enabled = false
	self:StopGoto()
	self:_StopMovement(true)
	self:_StopNoclip()
end

return MoveModule
