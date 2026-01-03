local MoveModule = {}

MoveModule.Config = {
	minSpeed = 20,
	maxSpeed = 50,
	brakeStart = 50,
	arrivalDist = 0.9,
	smoothRate = 14,
	snapDist = 1.25,
	snapEpsilon = 0.02,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

MoveModule._characterAddedConnection = nil
MoveModule._diedConnection = nil
MoveModule._stepConnection = nil

MoveModule._humanoid = nil
MoveModule._humanoidRootPart = nil

MoveModule._bodyVelocity = nil
MoveModule._enabled = false
MoveModule._targetPosition = nil

MoveModule._originalHumanoidProperties = nil

MoveModule._noclipConnection = nil
MoveModule._noclipOriginal = {}

local function Vector3Lerp(a, b, t)
	return a + (b - a) * t
end

local function SuppressWalkAnimations(h)
	for _, tr in ipairs(h:GetPlayingAnimationTracks()) do
		local n = (tr.Name or ""):lower()
		local id = ""
		if tr.Animation and type(tr.Animation.AnimationId) == "string" then
			id = tr.Animation.AnimationId:lower()
		end
		if n:match("walk") or n:match("run") or id:match("walk") or id:match("run") then
			tr:Stop(0.05)
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

	local function Apply()
		local c = LocalPlayer.Character
		if not c then
			return
		end
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.CanCollide == true then
					if self._noclipOriginal[d] == nil then
						self._noclipOriginal[d] = true
					end
					d.CanCollide = false
				end
			end
		end
	end

	Apply()
	self._noclipConnection = RunService.Stepped:Connect(Apply)
end

function MoveModule:_StopNoclip()
	if self._noclipConnection then
		self._noclipConnection:Disconnect()
		self._noclipConnection = nil
	end

	for p, w in pairs(self._noclipOriginal) do
		if typeof(p) == "Instance" and p and p.Parent and p:IsA("BasePart") then
			if w then
				p.CanCollide = true
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

function MoveModule:_StopMovement(restore)
	if self._stepConnection then
		self._stepConnection:Disconnect()
		self._stepConnection = nil
	end

	if self._bodyVelocity then
		self._bodyVelocity:Destroy()
		self._bodyVelocity = nil
	end

	if restore then
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

function MoveModule:_BindCharacter(c)
	self:_UnbindCharacter()

	local hrp = c:FindFirstChild("HumanoidRootPart") or c:WaitForChild("HumanoidRootPart", 5)
	local h = c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid", 5)
	if not hrp or not h then
		return
	end

	self._humanoidRootPart = hrp
	self._humanoid = h

	self._diedConnection = h.Died:Connect(function()
		self:Disable()
		self:_UnbindCharacter()
	end)
end

function MoveModule:_EnsureBound()
	local c = LocalPlayer.Character
	if c and c.Parent then
		if not self._humanoid or not self._humanoidRootPart then
			self:_BindCharacter(c)
		end
	end

	if not self._characterAddedConnection then
		self._characterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(nc)
			self:_BindCharacter(nc)
		end)
	end
end

function MoveModule:SetConfig(t)
	self:_EnsureBound()
	if type(t) ~= "table" then
		return
	end
	for k, v in pairs(t) do
		if self.Config[k] ~= nil then
			self.Config[k] = v
		end
	end
end

function MoveModule:Enable()
	self:_EnsureBound()

	if self._enabled and self._bodyVelocity and self._bodyVelocity.Parent then
		return true
	end

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

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.P = 1250
	bv.Velocity = Vector3.new(0, 0, 0)
	bv.Parent = self._humanoidRootPart
	self._bodyVelocity = bv

	self._enabled = true

	self._stepConnection = RunService.Heartbeat:Connect(function(dt)
		if not self._enabled or not self._bodyVelocity or not self._humanoidRootPart or not self._humanoid then
			return
		end
		if not self._humanoidRootPart.Parent or not self._humanoid.Parent then
			self:Disable()
			return
		end

		dt = math.max(dt, 1 / 240)

		self:_LockRotation()
		SuppressWalkAnimations(self._humanoid)

		local tgt = self._targetPosition
		if not tgt then
			self._bodyVelocity.Velocity = Vector3.new(0, 0, 0)
			return
		end

		local pos = self._humanoidRootPart.Position
		local to = tgt - pos
		local dist = to.Magnitude

		if dist <= self.Config.snapDist then
			self._humanoidRootPart.CFrame = CFrame.new(tgt)
			self._bodyVelocity.Velocity = Vector3.new(0, 0, 0)
			if (self._humanoidRootPart.Position - tgt).Magnitude <= self.Config.snapEpsilon then
				self._targetPosition = nil
			end
			return
		end

		local spd
		if dist >= self.Config.brakeStart then
			spd = self.Config.maxSpeed
		else
			local t = math.clamp(dist / math.max(self.Config.brakeStart, 0.0001), 0, 1)
			spd = self.Config.minSpeed + (self.Config.maxSpeed - self.Config.minSpeed) * t
		end

		local dir = (dist > 0.0001) and to.Unit or Vector3.new(0, 0, 0)
		local tv = dir * spd

		local a = math.clamp(self.Config.smoothRate * dt, 0, 1)
		self._bodyVelocity.Velocity = Vector3Lerp(self._bodyVelocity.Velocity, tv, a)

		if dist <= self.Config.arrivalDist then
			self._targetPosition = nil
			self._bodyVelocity.Velocity = Vector3.new(0, 0, 0)
		end
	end)

	return true
end

function MoveModule:Goto(p)
	self:_EnsureBound()
	if not self._enabled or not self._bodyVelocity or not self._bodyVelocity.Parent then
		return false, "disabled"
	end
	if typeof(p) ~= "Vector3" then
		return false, "bad_pos"
	end

	self._targetPosition = p
	local want = p

	while true do
		if not self._enabled then
			return false, "disabled"
		end

		if self._targetPosition == nil then
			if (self._humanoidRootPart.Position - want).Magnitude <= self.Config.snapEpsilon then
				return true
			end
			return false, "stopped"
		end

		if self._targetPosition ~= want then
			return false, "retargeted"
		end

		RunService.Heartbeat:Wait()
	end
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
