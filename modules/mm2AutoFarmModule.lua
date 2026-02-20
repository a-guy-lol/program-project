local MM2AutoFarmModule = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

MM2AutoFarmModule.Config = {
	FocusRange = 50,
	OtherPlayerNearCoinDist = 3,
	NearDangerPenalty = 12,
	FarCoinPenalty = 2.5,
	RetargetMargin = 1.25,
	CommitDistance = 2,
	OtherTouchIgnoreTime = 1.0,
	MissingCoinIgnoreTime = 0.75,
	ConfirmTimeout = 0.25,
	StepInterval = 0.045,
	MoveMinSpeed = 17.5,
	MoveMaxSpeed = 17.5,
	MoveBrakeStart = 10,
	MoveArrivalDist = 0,
	MoveSnapDist = 0,
	MoveSnapEpsilon = 0,
	MoveSmoothRate = 18,
	CenterEpsilon = 0.01,
}

MM2AutoFarmModule.State = {
	Enabled = false,
	Collecting = false,
	RoundActive = false,
	LocalInRound = false,
	BagCurrent = 0,
	BagMax = 0,
	BagFull = false,
	Map = nil,
	CoinContainer = nil,
	TargetCoin = nil,
	TargetPosition = nil,
	LastReason = "idle",
}

MM2AutoFarmModule.RoundClient = nil
MM2AutoFarmModule.MoveClient = nil
MM2AutoFarmModule.LocalPlayer = LocalPlayer

MM2AutoFarmModule._stepConnection = nil
MM2AutoFarmModule._stepAccumulator = 0

MM2AutoFarmModule._coinConnections = {}
MM2AutoFarmModule._coinTouchInfo = {}
MM2AutoFarmModule._coinIgnoreUntil = {}

MM2AutoFarmModule._targetCoin = nil
MM2AutoFarmModule._targetPosition = nil
MM2AutoFarmModule._targetAssignedAt = 0
MM2AutoFarmModule._targetBagAtStart = 0
MM2AutoFarmModule._targetMoveToken = 0
MM2AutoFarmModule._targetMoveActive = false
MM2AutoFarmModule._targetConfirmAt = nil

MM2AutoFarmModule._moveEnabled = false

local function getRoot(player)
	if not player or not player.Character then
		return nil
	end
	return player.Character:FindFirstChild("HumanoidRootPart")
		or player.Character:FindFirstChild("Head")
		or player.Character.PrimaryPart
end

local function isAlive(player)
	if not player or not player.Character then
		return false
	end
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function safeCall(fn, defaultValue)
	local ok, result = pcall(fn)
	if ok then
		return result
	end
	return defaultValue
end

function MM2AutoFarmModule:Bind(options)
	options = options or {}
	if options.RoundClient then
		self.RoundClient = options.RoundClient
	end
	if options.MoveClient then
		self.MoveClient = options.MoveClient
	end
	if options.LocalPlayer then
		self.LocalPlayer = options.LocalPlayer
	end
	return (self.RoundClient ~= nil) and (self.MoveClient ~= nil)
end

function MM2AutoFarmModule:SetConfig(config)
	if type(config) ~= "table" then
		return
	end
	for key, value in pairs(config) do
		if self.Config[key] ~= nil then
			self.Config[key] = value
		end
	end
	self:_applyMoveConfig()
end

function MM2AutoFarmModule:SetBag(current, max)
	if type(current) == "number" then
		self.State.BagCurrent = current
	end
	if type(max) == "number" then
		self.State.BagMax = max
	end
	self.State.BagFull = self.State.BagMax > 0 and self.State.BagCurrent >= self.State.BagMax
end

function MM2AutoFarmModule:IsEnabled()
	return self.State.Enabled
end

function MM2AutoFarmModule:IsCollecting()
	return self.State.Collecting
end

function MM2AutoFarmModule:IsBagFull()
	return self.State.BagFull
end

function MM2AutoFarmModule:GetStatus()
	return self.State
end

function MM2AutoFarmModule:GetTargetCoin()
	return self._targetCoin
end

function MM2AutoFarmModule:_applyMoveConfig()
	if not self.MoveClient then
		return
	end
	pcall(function()
		self.MoveClient:SetConfig({
			minSpeed = self.Config.MoveMinSpeed,
			maxSpeed = self.Config.MoveMaxSpeed,
			brakeStart = self.Config.MoveBrakeStart,
			arrivalDist = self.Config.MoveArrivalDist,
			smoothRate = self.Config.MoveSmoothRate,
			snapDist = self.Config.MoveSnapDist,
			snapEpsilon = self.Config.MoveSnapEpsilon,
		})
	end)
end

function MM2AutoFarmModule:_ensureMoveEnabled()
	if self._moveEnabled then
		return true
	end
	if not self.MoveClient then
		return false
	end

	self:_applyMoveConfig()
	local ok = safeCall(function()
		return self.MoveClient:Enable()
	end, false)
	self._moveEnabled = ok == true
	return self._moveEnabled
end

function MM2AutoFarmModule:_disableMove()
	if not self._moveEnabled or not self.MoveClient then
		return
	end
	self._moveEnabled = false
	pcall(function()
		self.MoveClient:Disable()
	end)
end

function MM2AutoFarmModule:_stopGotoOnly()
	if not self.MoveClient then
		return
	end
	pcall(function()
		self.MoveClient:StopGoto()
	end)
end

function MM2AutoFarmModule:_disconnectCoinConnection(coin)
	local entry = self._coinConnections[coin]
	if not entry then
		return
	end
	if entry.touchConnection then
		entry.touchConnection:Disconnect()
		entry.touchConnection = nil
	end
	self._coinConnections[coin] = nil
	self._coinTouchInfo[coin] = nil
	if coin == self._targetCoin then
		self:_clearTarget("target_removed", self.Config.MissingCoinIgnoreTime)
	end
end

function MM2AutoFarmModule:_clearCoinConnections()
	for coin in pairs(self._coinConnections) do
		self:_disconnectCoinConnection(coin)
	end
end

function MM2AutoFarmModule:_getCoinPart(coin)
	if not coin then
		return nil
	end
	if coin:IsA("BasePart") then
		return coin
	end

	local firstPart = nil
	for _, desc in ipairs(coin:GetDescendants()) do
		if desc:IsA("BasePart") then
			if desc:FindFirstChild("TouchInterest") or desc:FindFirstChildOfClass("TouchTransmitter") then
				return desc
			end
			firstPart = firstPart or desc
		end
	end
	return firstPart
end

function MM2AutoFarmModule:_coinHasTouch(coin)
	local part = self:_getCoinPart(coin)
	if not part then
		return false
	end
	if part:FindFirstChild("TouchInterest") then
		return true
	end
	return part:FindFirstChildOfClass("TouchTransmitter") ~= nil
end

function MM2AutoFarmModule:_coinPosition(coin)
	local part = self:_getCoinPart(coin)
	return part and part.Position or nil
end

function MM2AutoFarmModule:_markCoinIgnore(coin, duration)
	if not coin then
		return
	end
	self._coinIgnoreUntil[coin] = os.clock() + math.max(duration or 0, 0)
end

function MM2AutoFarmModule:_isIgnored(coin, now)
	local ignoreUntil = self._coinIgnoreUntil[coin]
	if not ignoreUntil then
		return false
	end
	if ignoreUntil <= now then
		self._coinIgnoreUntil[coin] = nil
		return false
	end
	return true
end

function MM2AutoFarmModule:_coinTouchedByOtherRecently(coin, now)
	local info = self._coinTouchInfo[coin]
	if not info or info.Player == self.LocalPlayer then
		return false
	end
	return (now - info.At) <= self.Config.OtherTouchIgnoreTime
end

function MM2AutoFarmModule:_coinTouchedByLocalRecently(coin, now)
	local info = self._coinTouchInfo[coin]
	if not info or info.Player ~= self.LocalPlayer then
		return false
	end
	return (now - info.At) <= self.Config.ConfirmTimeout
end

function MM2AutoFarmModule:_isCoinValid(coin, coinContainer)
	if not coin or not coin.Parent then
		return false
	end
	if coinContainer and not coin:IsDescendantOf(coinContainer) then
		return false
	end
	if not self:_coinHasTouch(coin) then
		return false
	end
	return self:_coinPosition(coin) ~= nil
end

function MM2AutoFarmModule:_connectCoinTouched(coin)
	local part = self:_getCoinPart(coin)
	if not part then
		return
	end

	local existing = self._coinConnections[coin]
	if existing and existing.part == part and existing.touchConnection then
		return
	end
	if existing then
		self:_disconnectCoinConnection(coin)
	end

	local touchConnection = part.Touched:Connect(function(hitPart)
		local hitModel = hitPart and hitPart:FindFirstAncestorOfClass("Model")
		local toucher = hitModel and Players:GetPlayerFromCharacter(hitModel) or nil
		if not toucher then
			return
		end

		local now = os.clock()
		self._coinTouchInfo[coin] = {
			Player = toucher,
			At = now,
		}

		if toucher ~= self.LocalPlayer then
			self:_markCoinIgnore(coin, self.Config.OtherTouchIgnoreTime)
			if coin == self._targetCoin then
				self:_clearTarget("coin_touched_by_other", self.Config.OtherTouchIgnoreTime)
			end
		end
	end)

	self._coinConnections[coin] = {
		part = part,
		touchConnection = touchConnection,
	}
end

function MM2AutoFarmModule:_syncCoinConnections(coinContainer)
	local aliveCoins = {}

	for _, coin in ipairs(coinContainer:GetChildren()) do
		aliveCoins[coin] = true
		self:_connectCoinTouched(coin)
	end

	for coin in pairs(self._coinConnections) do
		if (not aliveCoins[coin]) or (not coin.Parent) or (not coin:IsDescendantOf(coinContainer)) then
			self:_disconnectCoinConnection(coin)
		end
	end
end

function MM2AutoFarmModule:_collectOpponentRoots()
	local roots = {}
	local seen = {}

	local function addPlayer(player)
		if not player or player == self.LocalPlayer or seen[player] or not isAlive(player) then
			return
		end
		local root = getRoot(player)
		if not root then
			return
		end
		seen[player] = true
		roots[#roots + 1] = root
	end

	local roleData = safeCall(function()
		return self.RoundClient:GetRoundRoles()
	end, nil)

	if type(roleData) == "table" then
		addPlayer(roleData.Murderer)
		addPlayer(roleData.Sheriff)
		for _, p in ipairs(roleData.Innocents or {}) do
			addPlayer(p)
		end
	end

	if #roots == 0 then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= self.LocalPlayer then
				local inRound = safeCall(function()
					return self.RoundClient:IsPlayerInRound(p)
				end, false)
				if inRound then
					addPlayer(p)
				end
			end
		end
	end

	return roots
end

function MM2AutoFarmModule:_nearestOpponentDistance(coinPos, opponentRoots)
	local best = math.huge
	for _, root in ipairs(opponentRoots) do
		local dist = (root.Position - coinPos).Magnitude
		if dist < best then
			best = dist
		end
	end
	return best
end

function MM2AutoFarmModule:_selectBestCoin(coinContainer, myPosition, now)
	local opponentRoots = self:_collectOpponentRoots()

	local bestCoin = nil
	local bestPos = nil
	local bestDist = math.huge
	local bestScore = math.huge

	for _, coin in ipairs(coinContainer:GetChildren()) do
		if self:_isCoinValid(coin, coinContainer) and (not self:_isIgnored(coin, now)) then
			if self:_coinTouchedByOtherRecently(coin, now) then
				self:_markCoinIgnore(coin, self.Config.OtherTouchIgnoreTime)
			else
				local coinPos = self:_coinPosition(coin)
				if coinPos then
					local dist = (myPosition - coinPos).Magnitude
					local score = dist
					if dist <= self.Config.FocusRange then
						local nearestOpponent = self:_nearestOpponentDistance(coinPos, opponentRoots)
						if nearestOpponent <= self.Config.OtherPlayerNearCoinDist then
							local penaltyScale = (self.Config.OtherPlayerNearCoinDist - nearestOpponent) + 1
							score = score + (self.Config.NearDangerPenalty * penaltyScale)
						end
					else
						score = score + self.Config.FarCoinPenalty
					end

					if score < bestScore then
						bestScore = score
						bestCoin = coin
						bestPos = coinPos
						bestDist = dist
					end
				end
			end
		end
	end

	return bestCoin, bestPos, bestDist
end

function MM2AutoFarmModule:_clearTarget(reason, ignoreDuration)
	local oldTarget = self._targetCoin
	if oldTarget and ignoreDuration and ignoreDuration > 0 then
		self:_markCoinIgnore(oldTarget, ignoreDuration)
	end

	self._targetMoveToken = self._targetMoveToken + 1
	self._targetMoveActive = false
	self._targetConfirmAt = nil
	self._targetCoin = nil
	self._targetPosition = nil
	self._targetAssignedAt = 0
	self._targetBagAtStart = self.State.BagCurrent

	self.State.TargetCoin = nil
	self.State.TargetPosition = nil
	if reason then
		self.State.LastReason = reason
	end

	self:_stopGotoOnly()
end

function MM2AutoFarmModule:_startTarget(coin, position)
	self:_clearTarget(nil, nil)

	self._targetCoin = coin
	self._targetPosition = position
	self._targetAssignedAt = os.clock()
	self._targetBagAtStart = self.State.BagCurrent
	self._targetConfirmAt = nil
	self._targetMoveActive = true

	self.State.TargetCoin = coin
	self.State.TargetPosition = position
	self.State.LastReason = "moving"

	self._targetMoveToken = self._targetMoveToken + 1
	local token = self._targetMoveToken

	task.spawn(function()
		local ok = safeCall(function()
			return self.MoveClient:Goto(position)
		end, false)
		if token ~= self._targetMoveToken then
			return
		end
		self._targetMoveActive = false
		if ok and not self._targetConfirmAt then
			self._targetConfirmAt = os.clock()
		end
	end)
end

function MM2AutoFarmModule:_updateCurrentTarget(myPosition, coinContainer, now)
	if not self._targetCoin then
		return
	end

	if not self:_isCoinValid(self._targetCoin, coinContainer) then
		self:_clearTarget("target_invalid", self.Config.MissingCoinIgnoreTime)
		return
	end
	if self:_coinTouchedByOtherRecently(self._targetCoin, now) then
		self:_clearTarget("target_taken", self.Config.OtherTouchIgnoreTime)
		return
	end

	local currentPos = self:_coinPosition(self._targetCoin)
	if not currentPos then
		self:_clearTarget("target_no_pos", self.Config.MissingCoinIgnoreTime)
		return
	end

	self._targetPosition = currentPos
	self.State.TargetPosition = currentPos

	local distance = (myPosition - currentPos).Magnitude
	if distance <= self.Config.CenterEpsilon then
		if not self._targetConfirmAt then
			self._targetConfirmAt = now
			self._targetMoveActive = false
			self:_stopGotoOnly()
		end
	end

	if self.State.BagCurrent > self._targetBagAtStart then
		self:_clearTarget("coin_collected", 0.05)
		return
	end

	if self:_coinTouchedByLocalRecently(self._targetCoin, now) and not self._targetConfirmAt then
		self._targetConfirmAt = now
	end

	if self._targetConfirmAt and (now - self._targetConfirmAt) >= self.Config.ConfirmTimeout then
		if not self:_isCoinValid(self._targetCoin, coinContainer) then
			self:_clearTarget("coin_removed_after_touch", 0.05)
		else
			self:_clearTarget("confirm_timeout", 0.2)
		end
	end
end

function MM2AutoFarmModule:_shouldRetarget(bestCoin, bestDistance, myPosition)
	if not bestCoin then
		return false
	end
	if not self._targetCoin then
		return true
	end
	if bestCoin == self._targetCoin then
		return false
	end
	if self._targetConfirmAt then
		return false
	end

	local targetPos = self._targetPosition
	if not targetPos then
		return true
	end

	local currentDistance = (myPosition - targetPos).Magnitude
	if currentDistance <= self.Config.CommitDistance then
		return false
	end

	if currentDistance > self.Config.FocusRange and bestDistance <= self.Config.FocusRange then
		return true
	end
	return bestDistance + self.Config.RetargetMargin < currentDistance
end

function MM2AutoFarmModule:_step()
	local roundActive = safeCall(function()
		return self.RoundClient:IsRoundActive()
	end, false)
	local localInRound = false
	if roundActive then
		local inRoundFlag = safeCall(function()
			return self.RoundClient:IsPlayerInRound(self.LocalPlayer)
		end, false)
		localInRound = inRoundFlag and isAlive(self.LocalPlayer)
	end

	local map = safeCall(function()
		return self.RoundClient:GetMap()
	end, nil)
	local coinContainer = map and map:FindFirstChild("CoinContainer") or nil

	self.State.RoundActive = roundActive
	self.State.LocalInRound = localInRound
	self.State.Map = map
	self.State.CoinContainer = coinContainer
	self.State.BagFull = self.State.BagMax > 0 and self.State.BagCurrent >= self.State.BagMax

	if (not roundActive) or (not localInRound) or (not coinContainer) then
		self.State.Collecting = false
		self:_clearTarget("round_not_collectable", nil)
		self:_clearCoinConnections()
		self:_disableMove()
		return
	end

	if self.State.BagFull then
		self.State.Collecting = false
		self:_clearTarget("bag_full", nil)
		self:_clearCoinConnections()
		self:_disableMove()
		return
	end

	if not self:_ensureMoveEnabled() then
		self.State.Collecting = false
		self.State.LastReason = "move_enable_failed"
		return
	end

	self:_syncCoinConnections(coinContainer)

	local myRoot = getRoot(self.LocalPlayer)
	if not myRoot then
		self.State.Collecting = false
		self.State.LastReason = "no_local_root"
		self:_clearTarget("no_local_root", nil)
		return
	end

	local now = os.clock()
	local myPos = myRoot.Position

	self:_updateCurrentTarget(myPos, coinContainer, now)

	local bestCoin, bestPos, bestDist = self:_selectBestCoin(coinContainer, myPos, now)
	if self:_shouldRetarget(bestCoin, bestDist, myPos) then
		self:_startTarget(bestCoin, bestPos)
	end

	self.State.Collecting = self._targetCoin ~= nil or self._targetMoveActive
end

function MM2AutoFarmModule:Enable()
	if not self.RoundClient or not self.MoveClient then
		return false, "missing_dependencies"
	end
	if self.State.Enabled then
		return true
	end

	self.State.Enabled = true
	self.State.LastReason = "enabled"
	self._stepAccumulator = 0
	self:_applyMoveConfig()

	self._stepConnection = RunService.Heartbeat:Connect(function(dt)
		self._stepAccumulator = self._stepAccumulator + dt
		if self._stepAccumulator < self.Config.StepInterval then
			return
		end
		self._stepAccumulator = 0
		self:_step()
	end)

	return true
end

function MM2AutoFarmModule:Disable()
	if not self.State.Enabled then
		return
	end

	self.State.Enabled = false
	self.State.Collecting = false
	self.State.LastReason = "disabled"

	if self._stepConnection then
		self._stepConnection:Disconnect()
		self._stepConnection = nil
	end

	self:_clearTarget("disabled", nil)
	self:_clearCoinConnections()
	self:_disableMove()
end

return MM2AutoFarmModule
