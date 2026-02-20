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
	snapDist = 0,
	snapEpsilon = 0,
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
local AUTO_HANDLE_SHOT_WAIT = 0.9
local AUTO_HANDLE_RETRY_COOLDOWN = 1.2
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
		snapDist = 0,
		snapEpsilon = 0,
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

	local roles = mm2RoundClient:GetRoundRoles()
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

local function getCoinPart(coin)
	if not coin then
		return nil
	end
	if coin:IsA("BasePart") then
		return coin
	end
	return coin:FindFirstChildWhichIsA("BasePart")
end

local function getCoinTargetPosition(coin)
	if not coin then
		return nil
	end

	if coin:IsA("Model") then
		local cf = coin:GetBoundingBox()
		return cf.Position
	end

	local part = getCoinPart(coin)
	return part and part.Position or nil
end

local function coinHasTouchInterest(coin)
	local part = getCoinPart(coin)
	if not part then
		return false
	end
	if part:FindFirstChild("TouchInterest") then
		return true
	end
	return part:FindFirstChildOfClass("TouchTransmitter") ~= nil
end

local function purgeSkippedCoins()
	local now = os.clock()
	for coin, untilAt in pairs(skippedCoins) do
		if (not coin) or (not coin.Parent) or untilAt <= now then
			skippedCoins[coin] = nil
		end
	end
end

local function isCoinSelectable(coin, coinContainer)
	if not coin or not coin.Parent then
		return false
	end
	if coinContainer and not coin:IsDescendantOf(coinContainer) then
		return false
	end
	if skippedCoins[coin] and skippedCoins[coin] > os.clock() then
		return false
	end
	if not coinHasTouchInterest(coin) then
		return false
	end
	return getCoinTargetPosition(coin) ~= nil
end

local function getNearestSelectableCoin(coinContainer)
	local myRoot = getRoot(LocalPlayer)
	if not myRoot or not coinContainer then
		return nil
	end

	local bestCoin = nil
	local bestDist = math.huge

	for _, coin in ipairs(coinContainer:GetChildren()) do
		if isCoinSelectable(coin, coinContainer) then
			local pos = getCoinTargetPosition(coin)
			if pos then
				local dist = (myRoot.Position - pos).Magnitude
				if dist < bestDist then
					bestDist = dist
					bestCoin = coin
				end
			end
		end
	end

	return bestCoin
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
		local ok = pcall(function()
			local currentMurderer = murderer
			local myRoot = getRoot(LocalPlayer)
			local targetRoot = getRoot(currentMurderer)
			if not myRoot or not targetRoot then
				return
			end

			local safeBehind = math.random(5, 6)
			local behind = targetRoot.CFrame * CFrame.new(0, 0, safeBehind)
			myRoot.CFrame = CFrame.new(behind.Position, targetRoot.Position)
			task.wait(0.06)

			mm2WeaponClient:UseGun(currentMurderer)

			-- Wait for likely gun cooldown/server acceptance window before retrying.
			task.wait(AUTO_HANDLE_SHOT_WAIT)
			teleportToPlatform(true)
		end)

		nextAutoHandleAt = os.clock() + AUTO_HANDLE_RETRY_COOLDOWN
		autoHandleInProgress = false
		if not ok then
			teleportToPlatform(false)
		end
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
			teleportToPlatform(false)

			local now = os.clock()
			local hasGun = mm2WeaponClient:HasGun()

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

			if autoHandleMurderEnabled then
				tryAutoHandleMurder()
			end

			continue
		end

		if not ensureCoinMovementEnabled() then
			continue
		end

		purgeSkippedCoins()

		if activeTargetCoin then
			local myRoot = getRoot(LocalPlayer)
			local elapsed = os.clock() - activeTargetAssignedAt
			local targetPos = activeTargetPos or getCoinTargetPosition(activeTargetCoin)
			local coinAlive = activeTargetCoin.Parent and activeTargetCoin:IsDescendantOf(coinContainer) and coinHasTouchInterest(activeTargetCoin)

			if (not myRoot) or (not targetPos) then
				mv:StopGoto()
				activeTargetCoin = nil
				activeTargetPos = nil
			else
				activeTargetPos = targetPos
				local dist = (myRoot.Position - targetPos).Magnitude
				setMoveSpeedForDistance(dist)

				local bagIncreased = bagCurrent > activeTargetBagAtStart
				if bagIncreased then
					if dist <= 0.03 or elapsed >= 0.35 then
						skippedCoins[activeTargetCoin] = os.clock() + 0.2
						mv:StopGoto()
						activeTargetCoin = nil
						activeTargetPos = nil
					end
				else
					if not coinAlive then
						skippedCoins[activeTargetCoin] = os.clock() + 0.9
						mv:StopGoto()
						activeTargetCoin = nil
						activeTargetPos = nil
					elseif elapsed >= 1.1 and dist <= 1.0 then
						skippedCoins[activeTargetCoin] = os.clock() + 0.9
						mv:StopGoto()
						activeTargetCoin = nil
						activeTargetPos = nil
					elseif elapsed >= 1.8 and dist <= 2.0 then
						skippedCoins[activeTargetCoin] = os.clock() + 0.9
						mv:StopGoto()
						activeTargetCoin = nil
						activeTargetPos = nil
					end
				end
			end
		end

		if not activeTargetCoin then
			local nextCoin = getNearestSelectableCoin(coinContainer)
			if nextCoin then
				local nextPos = getCoinTargetPosition(nextCoin)
				if nextPos then
					local myRoot = getRoot(LocalPlayer)
					if myRoot then
						setMoveSpeedForDistance((myRoot.Position - nextPos).Magnitude)
					end

					activeTargetCoin = nextCoin
					activeTargetPos = nextPos
					activeTargetAssignedAt = os.clock()
					activeTargetBagAtStart = bagCurrent
					mv:StopGoto()
					task.spawn(function()
						mv:Goto(nextPos)
					end)
				end
			else
				stopCoinMovement(true)
			end
		end
	end
end)

-- Keep module toggle state in sync on startup.
mm2WeaponClient:TogglePrediction(gunPredictionEnabled)
