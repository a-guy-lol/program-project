local MoveModule = {}

MoveModule.Config = {
	minSpeed = 18.5,
	maxSpeed = 80,
	brakeStart = 35,
	arrivalDist = 0.9,
	faceOrigin = false,
	smoothRate = 14,
	lockRotation = true,
}

MoveModule._conn = nil
MoveModule._bv = nil
MoveModule._humDied = nil
MoveModule._charAdded = nil
MoveModule._hum = nil
MoveModule._hrp = nil
MoveModule._active = false
MoveModule._target = nil
MoveModule._rotCF = nil
MoveModule._orig = nil

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

function MoveModule:_restoreHumanoid()
	if not self._hum or not self._orig then
		return
	end
	self._hum.WalkSpeed = self._orig.WalkSpeed
	self._hum.JumpPower = self._orig.JumpPower
	self._hum.AutoRotate = self._orig.AutoRotate
	self._orig = nil
end

function MoveModule:_cleanup(restore)
	self._active = false
	self._target = nil
	self._rotCF = nil

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end

	if self._bv then
		self._bv:Destroy()
		self._bv = nil
	end

	if restore then
		self:_restoreHumanoid()
	end

	if self._humDied then
		self._humDied:Disconnect()
		self._humDied = nil
	end

	self._hum = nil
	self._hrp = nil
end

function MoveModule:_bindCharacter(char)
	self:_cleanup(false)

	local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
	if not hrp or not hum then
		return
	end

	self._hrp = hrp
	self._hum = hum

	self._humDied = hum.Died:Connect(function()
		self:_cleanup(false)
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
	self:_cleanup(true)
end

function MoveModule:Goto(pos)
	self:_ensure()
	if not self._hrp or not self._hum then
		return false
	end
	if typeof(pos) ~= "Vector3" then
		return false
	end

	self:Stop()

	self._target = pos
	self._active = true

	local hum = self._hum
	local hrp = self._hrp
	local cfg = self.Config

	self._orig = {
		WalkSpeed = hum.WalkSpeed,
		JumpPower = hum.JumpPower,
		AutoRotate = hum.AutoRotate,
	}

	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.AutoRotate = false

	if cfg.lockRotation then
		self._rotCF = hrp.CFrame - hrp.CFrame.Position
	end

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.P = 1250
	bv.Velocity = Vector3.new(0, 0, 0)
	bv.Parent = hrp
	self._bv = bv

	self._conn = RunService.RenderStepped:Connect(function(dt)
		if not self._active or not hrp.Parent or not hum.Parent then
			self:_cleanup(false)
			return
		end

		dt = math.max(dt, 1 / 120)

		if cfg.faceOrigin then
			local looktgt = Vector3.new(0, hrp.Position.Y, 0)
			hrp.CFrame = CFrame.lookAt(hrp.Position, looktgt)
		elseif cfg.lockRotation and self._rotCF then
			hrp.CFrame = CFrame.new(hrp.Position) * self._rotCF
			hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end

		local toTarget = self._target - hrp.Position
		local dist = toTarget.Magnitude

		local desiredSpeed
		if dist >= cfg.brakeStart then
			desiredSpeed = cfg.maxSpeed
		else
			local t = math.clamp(dist / math.max(cfg.brakeStart, 0.0001), 0, 1)
			desiredSpeed = cfg.minSpeed + (cfg.maxSpeed - cfg.minSpeed) * t
		end

		local dir = (dist > 0.0001) and toTarget.Unit or Vector3.new(0, 0, 0)
		local targetVel = dir * desiredSpeed

		local lerpT = math.clamp(cfg.smoothRate * dt, 0, 1)
		bv.Velocity = v3_lerp(bv.Velocity, targetVel, lerpT)

		suppressWalk(hum)

		if dist <= cfg.arrivalDist then
			self:Stop()
		end
	end)

	return true
end

return MoveModule
