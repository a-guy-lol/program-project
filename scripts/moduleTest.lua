local MoveModule = {}

MoveModule.Config = {
	minSpeed = 18.5,
	maxSpeed = 80,
	brakeStart = 35,
	arrivalDist = 0.9,
	faceOrigin = false,
	smoothRate = 14,
}

MoveModule._conn = nil
MoveModule._bv = nil
MoveModule._humDied = nil
MoveModule._charAdded = nil
MoveModule._hum = nil
MoveModule._hrp = nil
MoveModule._active = false
MoveModule._target = nil

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

local function v3_lerp(a, b, t)
	return a + (b - a) * t
end

local function suppressWalk(humanoid)
	for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
		local name = (track.Name or ""):lower()
		local animId = ""
		if track.Animation and type(track.Animation.AnimationId) == "string" then
			animId = track.Animation.AnimationId:lower()
		end
		if name:match("walk") or name:match("run") or animId:match("walk") or animId:match("run") then
			track:Stop(0.05)
		end
	end
end

function MoveModule:_cleanup()
	self._active = false
	self._target = nil

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end

	if self._bv then
		self._bv:Destroy()
		self._bv = nil
	end

	if self._humDied then
		self._humDied:Disconnect()
		self._humDied = nil
	end

	self._hum = nil
	self._hrp = nil
end

function MoveModule:_bindCharacter(char)
	self:_cleanup()

	local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
	if not hrp or not hum then
		return
	end

	self._hrp = hrp
	self._hum = hum

	self._humDied = hum.Died:Connect(function()
		self:_cleanup()
	end)
end

function MoveModule:_ensure()
	local char = lp.Character
	if char and char.Parent then
		if not self._hrp or not self._hum then
			self:_bindCharacter(char)
		end
	end

	if not self._charAdded then
		self._charAdded = lp.CharacterAdded:Connect(function(c)
			self:_bindCharacter(c)
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

function MoveModule:Stop()
	self:_cleanup()
end

function MoveModule:Goto(pos)
	self:_ensure()
	if not self._hrp or not self._hum then
		return false
	end
	if typeof(pos) ~= "Vector3" then
		return false
	end

	self._target = pos
	self._active = true

	local hum = self._hum
	local hrp = self._hrp
	local cfg = self.Config

	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.AutoRotate = false

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.P = 1250
	bv.Velocity = Vector3.new(0, 0, 0)
	bv.Parent = hrp
	self._bv = bv

	if self._conn then
		self._conn:Disconnect()
	end

	self._conn = RunService.RenderStepped:Connect(function(dt)
		if not self._active or not hrp.Parent or not hum.Parent then
			self:Stop()
			return
		end

		dt = math.max(dt, 1 / 120)

		if cfg.faceOrigin then
			local looktgt = Vector3.new(0, hrp.Position.Y, 0)
			hrp.CFrame = CFrame.lookAt(hrp.Position, looktgt)
		end

		local to3 = self._target - hrp.Position
		local toXZ = Vector3.new(to3.X, 0, to3.Z)
		local dist = toXZ.Magnitude

		local desiredSpeed
		if dist >= cfg.brakeStart then
			desiredSpeed = cfg.maxSpeed
		else
			local t = math.clamp(dist / math.max(cfg.brakeStart, 0.0001), 0, 1)
			desiredSpeed = cfg.minSpeed + (cfg.maxSpeed - cfg.minSpeed) * t
		end

		local vel = hrp.AssemblyLinearVelocity
		local hVel = Vector3.new(vel.X, 0, vel.Z)
		local dir = (dist > 0.0001) and toXZ.Unit or Vector3.new(0, 0, 0)
		local targetHVel = dir * desiredSpeed

		local lerpT = math.clamp(cfg.smoothRate * dt, 0, 1)
		local newHVel = v3_lerp(hVel, targetHVel, lerpT)

		bv.Velocity = Vector3.new(newHVel.X, vel.Y, newHVel.Z)

		suppressWalk(hum)

		if dist <= cfg.arrivalDist then
			self:Stop()
			hum.WalkSpeed = 16
			hum.JumpPower = 50
			hum.AutoRotate = true
		end
	end)

	return true
end

return MoveModule
