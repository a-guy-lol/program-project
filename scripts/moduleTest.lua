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

MoveModule._charAdded = nil
MoveModule._died = nil
MoveModule._rs = nil

MoveModule._hum = nil
MoveModule._hrp = nil

MoveModule._bv = nil
MoveModule._enabled = false
MoveModule._target = nil

MoveModule._orig = nil

local function v3_lerp(a, b, t)
	return a + (b - a) * t
end

local function suppressWalk(h)
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

function MoveModule:_bind(c)
	self:_unbind()

	local hrp = c:FindFirstChild("HumanoidRootPart") or c:WaitForChild("HumanoidRootPart", 5)
	local hum = c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid", 5)
	if not hrp or not hum then
		return
	end

	self._hrp = hrp
	self._hum = hum

	self._died = hum.Died:Connect(function()
		self:Disable()
		self:_unbind()
	end)
end

function MoveModule:_unbind()
	if self._died then
		self._died:Disconnect()
		self._died = nil
	end
	self._hum = nil
	self._hrp = nil
end

function MoveModule:_ensure()
	local c = LocalPlayer.Character
	if c and c.Parent then
		if not self._hrp or not self._hum then
			self:_bind(c)
		end
	end

	if not self._charAdded then
		self._charAdded = LocalPlayer.CharacterAdded:Connect(function(nc)
			self:_bind(nc)
		end)
	end
end

function MoveModule:SetConfig(cfg)
	self:_ensure()
	if type(cfg) ~= "table" then
		return
	end
	for k, v in pairs(cfg) do
		if self.Config[k] ~= nil then
			self.Config[k] = v
		end
	end
end

function MoveModule:_restoreHum()
	if not self._hum or not self._orig then
		self._orig = nil
		return
	end
	self._hum.WalkSpeed = self._orig.WalkSpeed
	self._hum.JumpPower = self._orig.JumpPower
	self._hum.AutoRotate = self._orig.AutoRotate
	self._orig = nil
end

function MoveModule:_lockRot()
	if not self._hrp then
		return
	end
	local p = self._hrp.Position
	self._hrp.CFrame = CFrame.new(p)
	self._hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

function MoveModule:Enable()
	self:_ensure()
	if self._enabled then
		return true
	end
	if not self._hrp or not self._hum then
		return false
	end

	-- Save humanoid defaults, then disable controller movement
	self._orig = {
		WalkSpeed = self._hum.WalkSpeed,
		JumpPower = self._hum.JumpPower,
		AutoRotate = self._hum.AutoRotate,
	}

	self._hum.WalkSpeed = 0
	self._hum.JumpPower = 0
	self._hum.AutoRotate = false

	-- Create BV; starts frozen if no target is set
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.P = 1250
	bv.Velocity = Vector3.new(0, 0, 0)
	bv.Parent = self._hrp
	self._bv = bv

	self._enabled = true
	self._target = nil

	-- Keep rotation at 0,0,0 and drive velocity toward target (or hold still)
	self._rs = RunService.RenderStepped:Connect(function(dt)
		if not self._enabled or not self._bv or not self._hrp or not self._hum then
			return
		end
		if not self._hrp.Parent or not self._hum.Parent then
			self:Disable()
			return
		end

		dt = math.max(dt, 1/120)

		self:_lockRot()
		suppressWalk(self._hum)

		if not self._target then
			self._bv.Velocity = Vector3.new(0, 0, 0)
			return
		end

		local to = self._target - self._hrp.Position
		local dist = to.Magnitude

		local sp
		if dist >= self.Config.brakeStart then
			sp = self.Config.maxSpeed
		else
			local t = math.clamp(dist / math.max(self.Config.brakeStart, 0.0001), 0, 1)
			sp = self.Config.minSpeed + (self.Config.maxSpeed - self.Config.minSpeed) * t
		end

		local dir = (dist > 0.0001) and to.Unit or Vector3.new(0, 0, 0)
		local tv = dir * sp

		local a = math.clamp(self.Config.smoothRate * dt, 0, 1)
		self._bv.Velocity = v3_lerp(self._bv.Velocity, tv, a)

		if dist <= self.Config.arrivalDist then
			self._target = nil
			self._bv.Velocity = Vector3.new(0, 0, 0)
		end
	end)

	return true
end

function MoveModule:Goto(pos)
	self:_ensure()
	if not self._enabled then
		return false
	end
	if typeof(pos) ~= "Vector3" then
		return false
	end
	self._target = pos
	return true
end

function MoveModule:Disable()
	if not self._enabled then
		return
	end

	self._enabled = false
	self._target = nil

	if self._rs then
		self._rs:Disconnect()
		self._rs = nil
	end

	if self._bv then
		self._bv:Destroy()
		self._bv = nil
	end

	self:_restoreHum()
end

return MoveModule
