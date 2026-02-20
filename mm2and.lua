local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local ZexonUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/zexonUI.lua"))()

-- Requested module names.
local mm2RoundClient = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/MM2-RoundModule.lua"))()
local mm2WeaponClient = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/mm2WeaponModule.lua"))()
local mv = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/moveVelocityModule.lua"))()

mv:SetConfig({
	minSpeed = 17.5,
	maxSpeed = 17.5,
	brakeStart = 10,
	arrivalDist = 0.25,
	smoothRate = 16,
	snapDist = 0.6,
	snapEpsilon = 0.03,
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

local coinMoveEnabled = false
local activeTargetCoin = nil
local activeTargetAssignedAt = 0
local activeTargetBagAtStart = 0
local skippedCoins = {}

local bagCurrent = 0
local bagMax = 0

local lastAutoKnifeAllAt = 0
local lastAutoHandleAt = 0

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

local function isLocalMurderer()
	local roles = mm2RoundClient:GetRoundRoles()
	return roles and roles.Murderer == LocalPlayer
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

local function stopCoinMovement(disableAll)
	mv:StopGoto()
	activeTargetCoin = nil
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
	local minSpeed = 17.5
	local maxSpeed = 17.5

	if distance > 10 then
		maxSpeed = math.clamp(17.5 + ((distance - 10) * 0.5), 17.5, 25)
	end

	mv:SetConfig({
		minSpeed = minSpeed,
		maxSpeed = maxSpeed,
		brakeStart = math.max(distance * 0.6, 10),
		arrivalDist = 0.25,
		smoothRate = 16,
		snapDist = 0.6,
		snapEpsilon = 0.03,
	})
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
	if coinContainer and (not coin:IsDescendantOf(coinContainer)) then
		return false
	end
	if skippedCoins[coin] and skippedCoins[coin] > os.clock() then
		return false
	end
	return getCoinTargetPosition(coin) ~= nil
end

local function getNextCoin(coinContainer)
	local myRoot = getRoot(LocalPlayer)
	if not myRoot or not coinContainer then
		return nil
	end

	local others = {}
	for _, p in ipairs(getRoundAlivePlayers()) do
		local r = getRoot(p)
		if r then
			others[#others + 1] = r
		end
	end

	local bestCoin = nil
	local bestScore = math.huge

	for _, coin in ipairs(coinContainer:GetChildren()) do
		if isCoinSelectable(coin, coinContainer) then
			local coinPos = getCoinTargetPosition(coin)
			if coinPos then
				local myDist = (coinPos - myRoot.Position).Magnitude
				local nearestOther = math.huge
				for _, otherRoot in ipairs(others) do
					local d = (coinPos - otherRoot.Position).Magnitude
					if d < nearestOther then
						nearestOther = d
					end
				end

				local contestedPenalty = 0
				if nearestOther <= myDist + 2 then
					contestedPenalty = 400
				end

				local score = myDist + contestedPenalty
				if score < bestScore then
					bestScore = score
					bestCoin = coin
				end
			end
		end
	end

	return bestCoin
end

local function shootMurderer()
	local roles = mm2RoundClient:GetRoundRoles()
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

local function tryAutoHandleMurder()
	if not autoHandleMurderEnabled then
		return
	end
	if not mm2WeaponClient:HasGun() then
		return
	end

	local roles = mm2RoundClient:GetRoundRoles()
	local murderer = roles and roles.Murderer
	if not murderer or murderer == LocalPlayer or not isAlive(murderer) then
		return
	end

	local myRoot = getRoot(LocalPlayer)
	local targetRoot = getRoot(murderer)
	if not myRoot or not targetRoot then
		return
	end

	local offset = math.random(3, 5)
	local behind = targetRoot.CFrame * CFrame.new(0, 0, offset)
	myRoot.CFrame = CFrame.new(behind.Position, targetRoot.Position)
	mm2WeaponClient:UseGun(murderer)
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

	gunPart.CFrame = myRoot.CFrame * CFrame.new(0, 0, -1.5)

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
	"Shoot keybind targets murderer. Knife All keybind hits all alive players if you are murderer. Nearby Knife can auto-hit nearby round players.",
	5
)

CombatSection:CreateToggle("Gun Prediction", {
	Description = "When enabled, UseGun uses prediction.",
	Toggled = false,
}, function(state)
	gunPredictionEnabled = state
	mm2WeaponClient:TogglePrediction(state)
	UI:AddNoti("Gun Prediction", state and "Enabled" or "Disabled", 2)
end)

CombatSection:CreateKeybind("Shoot", Enum.KeyCode.F, function()
	shootMurderer()
end)

CombatSection:CreateKeybind("Knife All", Enum.KeyCode.G, function()
	if not isLocalMurderer() then
		UI:AddNoti("Knife All", "Only works when you are murderer.", 2)
		return
	end
	local ok, result = mm2WeaponClient:UseKnifeAll()
	if not ok then
		UI:AddNoti("Knife All Failed", tostring(result), 2)
	else
		UI:AddNoti("Knife All", "Hit players: " .. tostring(result), 2)
	end
end)

CombatSection:CreateToggle("Auto Knife All", {
	Description = "When coin collection is ON and bag is full, auto uses Knife All.",
	Toggled = false,
}, function(state)
	autoKnifeAllEnabled = state
end)

CombatSection:CreateToggle("Auto Handle Murder", {
	Description = "When coin collection is ON and bag is full, teleports behind murderer and shoots.",
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
	Description = "Collects nearest safe coins, retargets fast, and stops on round end/full bag.",
	Toggled = false,
}, function(state)
	optimizedCoinCollectionEnabled = state
	if not state then
		stopCoinMovement(true)
	end
end)

CoinSection:CreateToggle("Auto Collect GunDrop", {
	Description = "When GunDrop appears in map, pulls it to you and triggers touch.",
	Toggled = false,
}, function(state)
	autoCollectGunDropEnabled = state
end)

CoinSection:CreateParagraph(
	"Notes",
	"Coin speed is dynamic: 17.5 minimum, up to 25 when far. At 10 studs and below it stays at 17.5 for safer coin touches.",
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

		if not optimizedCoinCollectionEnabled then
			stopCoinMovement(true)
			if not roundActive then
				bagCurrent = 0
			end
			continue
		end

		if not roundActive then
			stopCoinMovement(true)
			bagCurrent = 0
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
			if autoKnifeAllEnabled and (now - lastAutoKnifeAllAt) >= 0.5 then
				lastAutoKnifeAllAt = now
				if isLocalMurderer() then
					mm2WeaponClient:UseKnifeAll()
				end
			end

			if autoHandleMurderEnabled and (now - lastAutoHandleAt) >= 0.65 then
				lastAutoHandleAt = now
				tryAutoHandleMurder()
			end

			continue
		end

		if not ensureCoinMovementEnabled() then
			continue
		end

		purgeSkippedCoins()

		if activeTargetCoin and (not activeTargetCoin.Parent or not activeTargetCoin:IsDescendantOf(coinContainer)) then
			mv:StopGoto()
			activeTargetCoin = nil
		end

		if activeTargetCoin then
			if bagCurrent > activeTargetBagAtStart then
				skippedCoins[activeTargetCoin] = os.clock() + 0.2
				mv:StopGoto()
				activeTargetCoin = nil
			else
				local myRoot = getRoot(LocalPlayer)
				local targetPos = getCoinTargetPosition(activeTargetCoin)
				local elapsed = os.clock() - activeTargetAssignedAt

				if (not myRoot) or (not targetPos) then
					mv:StopGoto()
					activeTargetCoin = nil
				else
					local dist = (myRoot.Position - targetPos).Magnitude
					setMoveSpeedForDistance(dist)

					if elapsed >= 0.6 and dist <= 0.9 then
						-- If we reached center-ish but no bag update, skip this coin shortly.
						skippedCoins[activeTargetCoin] = os.clock() + 0.9
						mv:StopGoto()
						activeTargetCoin = nil
					elseif elapsed >= 1.3 and dist <= 1.8 then
						skippedCoins[activeTargetCoin] = os.clock() + 0.9
						mv:StopGoto()
						activeTargetCoin = nil
					end
				end
			end
		end

		if not activeTargetCoin then
			local nextCoin = getNextCoin(coinContainer)
			if nextCoin then
				local nextPos = getCoinTargetPosition(nextCoin)
				if nextPos then
					local myRoot = getRoot(LocalPlayer)
					if myRoot then
						setMoveSpeedForDistance((myRoot.Position - nextPos).Magnitude)
					end

					activeTargetCoin = nextCoin
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
