local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local ZexonUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/zexonUI.lua"))()

-- Requested module names.
local mm2RoundClient = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/MM2-RoundModule.lua"))()
local mm2WeaponClient = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/mm2WeaponModule.lua"))()
local flingClient = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/flingPlayerModule.lua"))()
local mv = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/moveVelocityModule.lua"))()

local PLATFORM_POS = Vector3.new(200, 500, 200)
local PLATFORM_NAME = "MM2And_SafePlatform"

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

local function getRoundRolesSafe()
	local ok, roles = pcall(function()
		return mm2RoundClient:GetRoundRoles()
	end)
	if ok and type(roles) == "table" then
		return roles
	end
	return nil
end

local function isLocalMurderer()
	local roles = getRoundRolesSafe()
	return roles and roles.Murderer == LocalPlayer
end

local function ensureSafePlatform()
	local platform = workspace:FindFirstChild(PLATFORM_NAME)
	if platform and platform:IsA("Part") then
		platform.CFrame = CFrame.new(PLATFORM_POS)
		return platform
	end

	platform = Instance.new("Part")
	platform.Name = PLATFORM_NAME
	platform.Anchored = true
	platform.CanCollide = true
	platform.Size = Vector3.new(36, 1, 36)
	platform.Transparency = 0.2
	platform.Material = Enum.Material.SmoothPlastic
	platform.Color = Color3.fromRGB(30, 30, 30)
	platform.CFrame = CFrame.new(PLATFORM_POS)
	platform.Parent = workspace
	return platform
end

local lastPlatformTeleportAt = 0
local PLATFORM_TP_COOLDOWN = 1.25

local function teleportToPlatform(force)
	local myRoot = getRoot(LocalPlayer)
	if not myRoot then
		return
	end

	ensureSafePlatform()

	local now = os.clock()
	if (not force) and (now - lastPlatformTeleportAt < PLATFORM_TP_COOLDOWN) then
		return
	end

	local target = PLATFORM_POS + Vector3.new(0, 3, 0)
	if (myRoot.Position - target).Magnitude <= 1 then
		return
	end

	myRoot.CFrame = CFrame.new(target)
	lastPlatformTeleportAt = now
end

mv:SetConfig({
	minSpeed = 17.5,
	maxSpeed = 17.5,
	brakeStart = 10,
	arrivalDist = 0,
	smoothRate = 16,
})

local UI = ZexonUI:CreateWindow("<font color=\"#1CB2F5\">MM2 And</font>", "Round + Weapons", false)

local gunPredictionEnabled = false
local nearbyKnifeEnabled = false
local nearbyKnifeRange = 0
local nearbyKnifeCooldown = 0.2
local lastKnifeAt = {}

local optimizedCoinCollectionEnabled = false
local autoKnifeAllEnabled = false
local autoHandleMurderEnabled = false
local autoCollectGunDropEnabled = false
local flingSheriffEndRoundEnabled = false

local coinMoveEnabled = false
local activeTargetCoin = nil
local activeTargetPos = nil
local activeTargetAssignedAt = 0
local activeTargetBagAtStart = 0
local skippedCoins = {}
local coinTouchInfo = {}
local coinTouchConnections = {}

local TARGET_FOCUS_RANGE = 50
local OTHER_PLAYER_NEAR_COIN_DIST = 3
local TARGET_MIN_HOLD_TIME = 0.12
local TARGET_COMMIT_DISTANCE = 1.2
local RETARGET_MARGIN_NEAR = 1.8
local RETARGET_MARGIN_FAR = 3.6
local COIN_TOUCHED_IGNORE_TIME = 1.0
local LOCAL_TOUCH_RETARGET_DELAY = 0.02
local MAX_STUCK_NEAR_TARGET_TIME = 0.9
local FORCED_TOUCH_DISTANCE = 0.95
local clearCoinTouchConnections

local bagCurrent = 0
local bagMax = 0

local lastAutoKnifeAllAt = 0
local lastFlingSheriffAt = 0
local lastFlingMurderAt = 0
local FLING_COOLDOWN = 1.4
local flingingSheriff = false
local flingingMurder = false
local autoHandleInProgress = false
local nextAutoHandleAt = 0
local AUTO_HANDLE_REPOSITION_ATTEMPTS = 3
local AUTO_HANDLE_SHOT_RETRY_ATTEMPTS = 2
local AUTO_HANDLE_PRE_SHOT_WAIT = 0.12
local AUTO_HANDLE_SHOT_WAIT = 0.85
local AUTO_HANDLE_RETRY_COOLDOWN = 1.25
local AUTO_HANDLE_FAIL_COOLDOWN = 1.7
local prevRoundActive = false

local function stopCoinMovement(disableAll)
	mv:StopGoto()
	activeTargetCoin = nil
	activeTargetPos = nil
	activeTargetAssignedAt = 0
	activeTargetBagAtStart = bagCurrent

	if disableAll and coinMoveEnabled then
		mv:Disable()
		coinMoveEnabled = false
	end
	if disableAll then
		clearCoinTouchConnections()
	end
end

local function ensureCoinMovementEnabled()
	if coinMoveEnabled then
		return true
	end
	local ok = mv:Enable()
	if ok then
		coinMoveEnabled = true
	end
	return ok
end

local function setMoveSpeedForDistance(distance)
	local maxSpeed = 17.5
	if distance > 10 then
		maxSpeed = math.clamp(17.5 + ((distance - 10) * 0.5), 17.5, 25)
	end

	mv:SetConfig({
		minSpeed = 17.5,
		maxSpeed = maxSpeed,
		brakeStart = math.max(distance * 0.6, 10),
		arrivalDist = 0,
		smoothRate = 16,
	})
end

local function getRoundAlivePlayers()
	local list = {}
	local seen = {}

	local function addPlayer(p)
		if not p or p == LocalPlayer or seen[p] or not isAlive(p) then
			return
		end
		seen[p] = true
		list[#list + 1] = p
	end

	local roles = getRoundRolesSafe()
	if roles then
		addPlayer(roles.Murderer)
		addPlayer(roles.Sheriff)
		for _, p in ipairs(roles.Innocents or {}) do
			addPlayer(p)
		end
	end

	if #list == 0 then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and mm2RoundClient:IsPlayerInRound(p) then
				addPlayer(p)
			end
		end
	end

	return list
end

local function getCoinTouchParts(coin)
	if not coin then
		return {}
	end

	local allParts = {}
	if coin:IsA("BasePart") then
		allParts[1] = coin
	else
		for _, desc in ipairs(coin:GetDescendants()) do
			if desc:IsA("BasePart") then
				allParts[#allParts + 1] = desc
			end
		end
	end

	local touchParts = {}
	for _, part in ipairs(allParts) do
		if part:FindFirstChild("TouchInterest") or part:FindFirstChildOfClass("TouchTransmitter") then
			touchParts[#touchParts + 1] = part
		end
	end

	if #touchParts > 0 then
		return touchParts
	end
	return allParts
end

local function getCoinPart(coin)
	local parts = getCoinTouchParts(coin)
	return parts[1]
end

local function getCoinTargetPosition(coin)
	if not coin then
		return nil
	end

	if coin:IsA("Model") then
		local part = getCoinPart(coin)
		if part then
			return part.Position
		end
		local cf = coin:GetBoundingBox()
		return cf.Position
	end

	local part = getCoinPart(coin)
	return part and part.Position or nil
end

local function coinHasTouchInterest(coin)
	for _, part in ipairs(getCoinTouchParts(coin)) do
		if part:FindFirstChild("TouchInterest") or part:FindFirstChildOfClass("TouchTransmitter") then
			return true
		end
	end
	return false
end

local function disconnectCoinTouch(coin)
	local entry = coinTouchConnections[coin]
	if not entry then
		return
	end
	if entry.connections then
		for _, conn in ipairs(entry.connections) do
			conn:Disconnect()
		end
	end
	coinTouchConnections[coin] = nil
end

clearCoinTouchConnections = function()
	for coin in pairs(coinTouchConnections) do
		disconnectCoinTouch(coin)
	end
	coinTouchInfo = {}
end

local function watchCoinTouched(coin)
	local parts = getCoinTouchParts(coin)
	if #parts == 0 then
		return
	end

	if coinTouchConnections[coin] then
		return
	end

	local function onTouched(hit)
		local model = hit and hit:FindFirstAncestorOfClass("Model")
		local toucher = model and Players:GetPlayerFromCharacter(model) or nil
		if not toucher then
			return
		end
		coinTouchInfo[coin] = {
			Player = toucher,
			At = os.clock(),
		}
	end

	local connections = {}
	for _, part in ipairs(parts) do
		connections[#connections + 1] = part.Touched:Connect(onTouched)
	end

	coinTouchConnections[coin] = {
		connections = connections,
		partCount = #parts,
	}
end

local function syncCoinTouchWatchers(coinContainer)
	if not coinContainer then
		clearCoinTouchConnections()
		return
	end

	local alive = {}
	for _, coin in ipairs(coinContainer:GetChildren()) do
		alive[coin] = true
		watchCoinTouched(coin)
	end

	for coin in pairs(coinTouchConnections) do
		if (not alive[coin]) or (not coin.Parent) or (not coin:IsDescendantOf(coinContainer)) then
			disconnectCoinTouch(coin)
			coinTouchInfo[coin] = nil
		end
	end
end

local function coinTouchedByOtherRecently(coin, now)
	local info = coinTouchInfo[coin]
	if not info or info.Player == LocalPlayer then
		return false
	end
	return (now - info.At) <= COIN_TOUCHED_IGNORE_TIME
end

local function coinTouchedByLocalRecently(coin, now)
	local info = coinTouchInfo[coin]
	if not info or info.Player ~= LocalPlayer then
		return false
	end
	return (now - info.At) <= 0.35
end

local function tryForceTouchCoin(coin, myRoot)
	if not firetouchinterest or not coin or not myRoot then
		return false
	end

	local touchedAny = false
	for _, part in ipairs(getCoinTouchParts(coin)) do
		if part and part.Parent then
			pcall(firetouchinterest, myRoot, part, 0)
			pcall(firetouchinterest, myRoot, part, 1)
			touchedAny = true
		end
	end

	if touchedAny then
		coinTouchInfo[coin] = {
			Player = LocalPlayer,
			At = os.clock(),
		}
	end
	return touchedAny
end

local function purgeSkippedCoins(coinContainer)
	syncCoinTouchWatchers(coinContainer)

	local now = os.clock()
	for coin, untilAt in pairs(skippedCoins) do
		if (not coin) or (not coin.Parent) or untilAt <= now then
			skippedCoins[coin] = nil
		end
	end

	for coin, info in pairs(coinTouchInfo) do
		if (not coin) or (not coin.Parent) or (not info) or ((now - info.At) > 2.2) then
			coinTouchInfo[coin] = nil
		end
	end
end

local function isCoinSelectable(coin, coinContainer, now)
	if not coin or not coin.Parent then
		return false
	end
	if coinContainer and not coin:IsDescendantOf(coinContainer) then
		return false
	end
	if skippedCoins[coin] and skippedCoins[coin] > os.clock() then
		return false
	end
	if coinTouchedByOtherRecently(coin, now) then
		return false
	end
	if not coinHasTouchInterest(coin) then
		return false
	end
	return getCoinTargetPosition(coin) ~= nil
end

local function getAliveOpponentRoots()
	local roots = {}
	local roles = getRoundRolesSafe()
	local seen = {}

	local function addPlayer(player)
		if not player or player == LocalPlayer or seen[player] then
			return
		end
		seen[player] = true
		if not isAlive(player) then
			return
		end
		local root = getRoot(player)
		if root then
			roots[#roots + 1] = root
		end
	end

	if roles then
		addPlayer(roles.Murderer)
		addPlayer(roles.Sheriff)
		for _, p in ipairs(roles.Innocents or {}) do
			addPlayer(p)
		end
	end

	if #roots == 0 then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and mm2RoundClient:IsPlayerInRound(p) then
				addPlayer(p)
			end
		end
	end

	return roots
end

local function nearestRootDistance(position, roots)
	local best = math.huge
	for _, root in ipairs(roots) do
		local dist = (root.Position - position).Magnitude
		if dist < best then
			best = dist
		end
	end
	return best
end

local function getBestSelectableCoin(coinContainer)
	local myRoot = getRoot(LocalPlayer)
	if not myRoot or not coinContainer then
		return nil, nil, nil
	end

	local now = os.clock()
	local opponentRoots = getAliveOpponentRoots()
	local bestNearCoin, bestNearPos, bestNearDist, bestNearScore = nil, nil, math.huge, math.huge
	local bestFarCoin, bestFarPos, bestFarDist, bestFarScore = nil, nil, math.huge, math.huge

	for _, coin in ipairs(coinContainer:GetChildren()) do
		if isCoinSelectable(coin, coinContainer, now) then
			local pos = getCoinTargetPosition(coin)
			if pos then
				local dist = (myRoot.Position - pos).Magnitude
				if dist <= TARGET_FOCUS_RANGE then
					local score = dist
					local nearestOther = nearestRootDistance(pos, opponentRoots)
					if nearestOther <= OTHER_PLAYER_NEAR_COIN_DIST then
						-- Deprioritize likely-contested near coins without hard ignoring them.
						score = score + ((OTHER_PLAYER_NEAR_COIN_DIST - nearestOther + 1) * 1.25)
					end
					if score < bestNearScore or (score == bestNearScore and dist < bestNearDist) then
						bestNearScore = score
						bestNearCoin = coin
						bestNearPos = pos
						bestNearDist = dist
					end
				else
					local score = dist + 0.65
					if score < bestFarScore or (score == bestFarScore and dist < bestFarDist) then
						bestFarScore = score
						bestFarCoin = coin
						bestFarPos = pos
						bestFarDist = dist
					end
				end
			end
		end
	end

	if bestNearCoin then
		return bestNearCoin, bestNearPos, bestNearDist
	end
	return bestFarCoin, bestFarPos, bestFarDist
end

local function shootMurderer()
	local roles = getRoundRolesSafe()
	local murderer = roles and roles.Murderer
	if not murderer then
		UI:AddNoti("Shoot", "No murderer found.", 2)
		return
	end

	local ok, reason = mm2WeaponClient:UseGun(murderer)
	if not ok then
		UI:AddNoti("Shoot Failed", tostring(reason), 2)
	end
end

local function canFlingTarget(player)
	return player and player ~= LocalPlayer and isAlive(player)
end

local function startFlingTarget(targetPlayer, mode)
	if not canFlingTarget(targetPlayer) then
		return false
	end

	if mode == "sheriff" then
		if flingingSheriff then
			return false
		end
		flingingSheriff = true
	else
		if flingingMurder then
			return false
		end
		flingingMurder = true
	end

	task.spawn(function()
		pcall(function()
			flingClient:Fling(targetPlayer, 4, true)
		end)
		if mode == "sheriff" then
			flingingSheriff = false
		else
			flingingMurder = false
		end
	end)

	return true
end

local function tryAutoHandleMurder()
	if not autoHandleMurderEnabled then
		return false
	end
	if not mm2WeaponClient:HasGun() then
		return false
	end
	if autoHandleInProgress then
		return false
	end

	local now = os.clock()
	if now < nextAutoHandleAt then
		return false
	end

	local roles = getRoundRolesSafe()
	local murderer = roles and roles.Murderer
	if not murderer or murderer == LocalPlayer or not isAlive(murderer) then
		return false
	end

	autoHandleInProgress = true
	task.spawn(function()
		local shotAttempted = false
		local caughtError = false

		local ok = pcall(function()
			local currentMurderer = murderer

			for attempt = 1, AUTO_HANDLE_REPOSITION_ATTEMPTS do
				if not autoHandleMurderEnabled then
					break
				end
				if not mm2RoundClient:IsRoundActive() or not isAlive(currentMurderer) then
					break
				end

				local myRoot = getRoot(LocalPlayer)
				local targetRoot = getRoot(currentMurderer)
				if not myRoot or not targetRoot then
					break
				end

				local backDistance = 4.6 + ((attempt - 1) * 0.4)
				local sideOffset = 0
				if attempt == 2 then
					sideOffset = 1.4
				elseif attempt >= 3 then
					sideOffset = -1.4
				end

				local behindPos = targetRoot.Position
					- (targetRoot.CFrame.LookVector * backDistance)
					+ (targetRoot.CFrame.RightVector * sideOffset)
				myRoot.CFrame = CFrame.new(behindPos, targetRoot.Position)
				task.wait(AUTO_HANDLE_PRE_SHOT_WAIT)

				for _ = 1, AUTO_HANDLE_SHOT_RETRY_ATTEMPTS do
					local fired = select(1, mm2WeaponClient:UseGun(currentMurderer))
					if fired then
						shotAttempted = true
						break
					end
					task.wait(0.12)
				end

				if shotAttempted then
					break
				end
				task.wait(0.2)
			end
		end)

		if not ok then
			caughtError = true
		end

		if shotAttempted then
			task.wait(AUTO_HANDLE_SHOT_WAIT)
		else
			task.wait(0.25)
		end

			teleportToPlatform(true)

		if (not caughtError) and shotAttempted then
			nextAutoHandleAt = os.clock() + AUTO_HANDLE_RETRY_COOLDOWN
		else
			nextAutoHandleAt = os.clock() + AUTO_HANDLE_FAIL_COOLDOWN
		end
		autoHandleInProgress = false
	end)

	return true
end

local function tryAutoCollectGunDrop(map)
	if not autoCollectGunDropEnabled then
		return
	end
	if mm2WeaponClient:HasGun() then
		return
	end
	if not map then
		return
	end

	local gunDrop = map:FindFirstChild("GunDrop")
	if not gunDrop then
		return
	end

	local gunPart = gunDrop:IsA("BasePart") and gunDrop or gunDrop:FindFirstChildWhichIsA("BasePart")
	local myRoot = getRoot(LocalPlayer)
	if not gunPart or not myRoot then
		return
	end

	gunPart.CFrame = myRoot.CFrame

	if firetouchinterest then
		pcall(firetouchinterest, myRoot, gunPart, 0)
		pcall(firetouchinterest, myRoot, gunPart, 1)
	end
end

-- Coin bag tracker from provided coinBagClient pattern.
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
	if not remotes then
		return
	end

	local gameplay = remotes:WaitForChild("Gameplay", 30)
	if not gameplay then
		return
	end

	local coinCollected = gameplay:WaitForChild("CoinCollected", 30)
	local coinsStarted = gameplay:WaitForChild("CoinsStarted", 30)

	if coinCollected and coinCollected:IsA("RemoteEvent") then
		coinCollected.OnClientEvent:Connect(function(_, current, max)
			if type(current) == "number" then
				bagCurrent = current
			end
			if type(max) == "number" then
				bagMax = max
			end
		end)
	end

	if coinsStarted and coinsStarted:IsA("RemoteEvent") then
		coinsStarted.OnClientEvent:Connect(function()
			bagCurrent = 0
		end)
	end
end)

local CombatTab = UI:CreatePage("Combat")
local CombatSection = CombatTab:CreateSection("MM2 Controls")

CombatSection:CreateParagraph(
	"MM2 Panel",
	"Shoot keybind targets murderer. Knife All keybind hits all alive players if murderer. Auto Handle Murder runs after bag is full.",
	5
)

CombatSection:CreateToggle("Gun Prediction", {
	Description = "When enabled, UseGun uses prediction.",
	Toggled = false,
}, function(state)
	gunPredictionEnabled = state
	mm2WeaponClient:TogglePrediction(state)
end)

CombatSection:CreateKeybind("Shoot", Enum.KeyCode.F, function()
	shootMurderer()
end)

CombatSection:CreateKeybind("Knife All", Enum.KeyCode.G, function()
	if not isLocalMurderer() then
		UI:AddNoti("Knife All", "Only works when you are murderer.", 2)
		return
	end
	mm2WeaponClient:UseKnifeAll()
end)

CombatSection:CreateToggle("Auto Knife All", {
	Description = "When collection is ON and bag full, auto uses Knife All.",
	Toggled = false,
}, function(state)
	autoKnifeAllEnabled = state
end)

CombatSection:CreateToggle("Auto Handle Murder", {
	Description = "After bag full: teleport behind murderer, shoot, return to platform; repeat until dead.",
	Toggled = false,
}, function(state)
	autoHandleMurderEnabled = state
end)

CombatSection:CreateToggle("Nearby Knife Enabled", {
	Description = "Auto knife nearby alive round players.",
	Toggled = false,
}, function(state)
	nearbyKnifeEnabled = state
end)

CombatSection:CreateSlider("Nearby Knife", {
	Min = 0,
	Max = 50,
	DefaultValue = 0,
}, function(value)
	nearbyKnifeRange = value
end)

local CoinTab = UI:CreatePage("CoinCollection")
local CoinSection = CoinTab:CreateSection("Collection")

CoinSection:CreateToggle("OptimizedCoinCollection", {
	Description = "Collect nearest valid coins with center-touch enforcement.",
	Toggled = false,
}, function(state)
	optimizedCoinCollectionEnabled = state
	if state then
		ensureSafePlatform()
	else
		stopCoinMovement(true)
	end
end)

CoinSection:CreateToggle("Auto Collect GunDrop", {
	Description = "When GunDrop appears, move it to your rootpart and touch it.",
	Toggled = false,
}, function(state)
	autoCollectGunDropEnabled = state
end)

CoinSection:CreateToggle("Fling Sheriff + End Round", {
	Description = "When bag is full and no gun, fling sheriff. If you are dead/out-of-round while round is active, fling murderer.",
	Toggled = false,
}, function(state)
	flingSheriffEndRoundEnabled = state
end)

CoinSection:CreateParagraph(
	"Notes",
	"Speed is dynamic 17.5 to 25 while far, never below 17.5. Platform teleports are throttled and only used when needed.",
	4
)

local knifeAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	knifeAccumulator = knifeAccumulator + dt
	if knifeAccumulator < 0.12 then
		return
	end
	knifeAccumulator = 0

	if not nearbyKnifeEnabled or nearbyKnifeRange <= 0 then
		return
	end
	if not isLocalMurderer() then
		return
	end

	local myRoot = getRoot(LocalPlayer)
	if not myRoot then
		return
	end

	for _, p in ipairs(getRoundAlivePlayers()) do
		local targetRoot = getRoot(p)
		if targetRoot then
			local dist = (myRoot.Position - targetRoot.Position).Magnitude
			if dist <= nearbyKnifeRange then
				local now = os.clock()
				if not lastKnifeAt[p] or (now - lastKnifeAt[p]) >= nearbyKnifeCooldown then
					mm2WeaponClient:UseKnife(p)
					lastKnifeAt[p] = now
				end
			end
		end
	end
end)

task.spawn(function()
	while task.wait(0.03) do
		local roundActive = mm2RoundClient:IsRoundActive()
		local localInRound = roundActive and mm2RoundClient:IsPlayerInRound(LocalPlayer) and isAlive(LocalPlayer)

		if prevRoundActive and not roundActive and optimizedCoinCollectionEnabled then
			stopCoinMovement(true)
			teleportToPlatform(true)
			bagCurrent = 0
		end
		prevRoundActive = roundActive

		if not optimizedCoinCollectionEnabled then
			stopCoinMovement(true)
			continue
		end

			if roundActive and not localInRound then
				stopCoinMovement(true)
				teleportToPlatform(false)
			if flingSheriffEndRoundEnabled then
				local roles = getRoundRolesSafe()
				local murderer = roles and roles.Murderer
				local now = os.clock()
				if canFlingTarget(murderer) and (now - lastFlingMurderAt) >= FLING_COOLDOWN then
					lastFlingMurderAt = now
					startFlingTarget(murderer, "murder")
				end
			end
			continue
		end

		if not roundActive then
			stopCoinMovement(true)
			continue
		end

		local map = mm2RoundClient:GetMap()
		if not map then
			stopCoinMovement(true)
			continue
		end

		tryAutoCollectGunDrop(map)

			local coinContainer = map:FindFirstChild("CoinContainer")
			if not coinContainer then
				stopCoinMovement(true)
				continue
			end

			if bagMax > 0 and bagCurrent >= bagMax then
				stopCoinMovement(true)

				local now = os.clock()
				local hasGun = mm2WeaponClient:HasGun()
				local shouldAutoHandle = autoHandleMurderEnabled and hasGun

				if flingSheriffEndRoundEnabled and (not hasGun) then
					local roles = getRoundRolesSafe()
					local sheriff = roles and roles.Sheriff
					if canFlingTarget(sheriff) and (now - lastFlingSheriffAt) >= FLING_COOLDOWN then
						lastFlingSheriffAt = now
						startFlingTarget(sheriff, "sheriff")
					end
				end

				if autoKnifeAllEnabled and (now - lastAutoKnifeAllAt) >= 0.5 and isLocalMurderer() then
					lastAutoKnifeAllAt = now
					mm2WeaponClient:UseKnifeAll()
				end

				if shouldAutoHandle then
					tryAutoHandleMurder()
				else
					teleportToPlatform(false)
				end

				continue
			end

			if not ensureCoinMovementEnabled() then
				continue
			end

			purgeSkippedCoins(coinContainer)
			local bestCoin, bestPos, bestDist = getBestSelectableCoin(coinContainer)

				if activeTargetCoin then
					local now = os.clock()
					local myRoot = getRoot(LocalPlayer)
					local elapsed = now - activeTargetAssignedAt
					local targetPos = activeTargetPos or getCoinTargetPosition(activeTargetCoin)
					local coinAlive = activeTargetCoin.Parent and activeTargetCoin:IsDescendantOf(coinContainer) and coinHasTouchInterest(activeTargetCoin)
					local touchedByOther = coinTouchedByOtherRecently(activeTargetCoin, now)

					if (not myRoot) or (not targetPos) then
						mv:StopGoto()
						activeTargetCoin = nil
						activeTargetPos = nil
					else
						activeTargetPos = targetPos
						local dist = (myRoot.Position - targetPos).Magnitude
						setMoveSpeedForDistance(dist)
						if dist <= FORCED_TOUCH_DISTANCE then
							tryForceTouchCoin(activeTargetCoin, myRoot)
						end
						local touchedByLocal = coinTouchedByLocalRecently(activeTargetCoin, now)

						if touchedByOther then
							skippedCoins[activeTargetCoin] = now + COIN_TOUCHED_IGNORE_TIME
							mv:StopGoto()
							activeTargetCoin = nil
							activeTargetPos = nil
						elseif touchedByLocal then
							-- Immediate retarget after local touch; no idle wait at coin.
							skippedCoins[activeTargetCoin] = now + LOCAL_TOUCH_RETARGET_DELAY
							mv:StopGoto()
							activeTargetCoin = nil
							activeTargetPos = nil
							activeTargetBagAtStart = bagCurrent
						else
							local bagIncreased = bagCurrent > activeTargetBagAtStart
							if not coinAlive then
								skippedCoins[activeTargetCoin] = now + 0.8
								mv:StopGoto()
								activeTargetCoin = nil
								activeTargetPos = nil
							elseif bagIncreased then
								if dist <= TARGET_COMMIT_DISTANCE then
									skippedCoins[activeTargetCoin] = now + 0.12
									mv:StopGoto()
									activeTargetCoin = nil
									activeTargetPos = nil
								else
									-- Another coin may have been collected at the same time; keep target unless close/touched.
									activeTargetBagAtStart = bagCurrent
								end
							elseif elapsed >= MAX_STUCK_NEAR_TARGET_TIME and dist <= TARGET_COMMIT_DISTANCE then
								skippedCoins[activeTargetCoin] = now + 0.45
								mv:StopGoto()
								activeTargetCoin = nil
								activeTargetPos = nil
						elseif bestCoin and bestCoin ~= activeTargetCoin and elapsed >= TARGET_MIN_HOLD_TIME then
							local shouldSwitch = false
							if dist > TARGET_FOCUS_RANGE and bestDist <= TARGET_FOCUS_RANGE then
								shouldSwitch = true
							elseif dist <= TARGET_FOCUS_RANGE and bestDist <= TARGET_FOCUS_RANGE then
								shouldSwitch = dist > TARGET_COMMIT_DISTANCE and ((bestDist + RETARGET_MARGIN_NEAR) < dist)
							else
								shouldSwitch = dist > TARGET_COMMIT_DISTANCE and ((bestDist + RETARGET_MARGIN_FAR) < dist)
							end

							if shouldSwitch then
								skippedCoins[activeTargetCoin] = now + 0.12
								mv:StopGoto()
								activeTargetCoin = nil
								activeTargetPos = nil
							end
						end
					end
				end
			end

			if not activeTargetCoin then
				if bestCoin and bestPos then
					local myRoot = getRoot(LocalPlayer)
					if myRoot then
						setMoveSpeedForDistance((myRoot.Position - bestPos).Magnitude)
					end

					activeTargetCoin = bestCoin
					activeTargetPos = bestPos
					activeTargetAssignedAt = os.clock()
					activeTargetBagAtStart = bagCurrent
					mv:StopGoto()
					task.spawn(function()
						mv:Goto(bestPos)
					end)
				else
					stopCoinMovement(true)
				end
			end
	end
end)

-- Keep module toggle state in sync on startup.
mm2WeaponClient:TogglePrediction(gunPredictionEnabled)
