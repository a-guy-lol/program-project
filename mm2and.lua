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
	brakeStart = 9999,
	arrivalDist = 1.0,
	smoothRate = 16,
	snapDist = 1.25,
	snapEpsilon = 0.05,
})

local UI = ZexonUI:CreateWindow("<font color=\"#1CB2F5\">MM2 And</font>", "Round + Weapons", false)

local gunPredictionEnabled = false
local nearbyKnifeEnabled = false
local nearbyKnifeRange = 0
local nearbyKnifeCooldown = 0.2
local lastKnifeAt = {}

local optimizedCoinCollectionEnabled = false
local coinMoveEnabled = false
local activeTargetCoin = nil
local activeTargetAssignedAt = 0
local activeTargetBagAtStart = 0
local skippedCoins = {}

local bagCurrent = 0
local bagMax = 0

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
	return getCoinPart(coin) ~= nil
end

local function getNextCoin(coinContainer)
	-- First preference: use round module API.
	local nearestCoin = mm2RoundClient:GetNearestCoin(LocalPlayer)
	if isCoinSelectable(nearestCoin, coinContainer) then
		return nearestCoin
	end

	-- Fallback: local scan to avoid selecting a temporarily skipped/stale coin.
	local myRoot = getRoot(LocalPlayer)
	if not myRoot or not coinContainer then
		return nil
	end

	local bestCoin = nil
	local bestDist = math.huge
	for _, coin in ipairs(coinContainer:GetChildren()) do
		if isCoinSelectable(coin, coinContainer) then
			local part = getCoinPart(coin)
			local dist = (part.Position - myRoot.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestCoin = coin
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

-- Coin bag tracker from the provided coinBagClient pattern.
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

local MainTab = UI:CreatePage("Combat")
local MainSection = MainTab:CreateSection("MM2 Controls")

MainSection:CreateParagraph(
	"MM2 Panel",
	"Shoot keybind targets murderer. Knife All keybind hits all alive players if you are murderer. Nearby Knife can auto-hit nearby round players.",
	5
)

MainSection:CreateToggle("Gun Prediction", {
	Description = "When enabled, UseGun uses prediction.",
	Toggled = false,
}, function(state)
	gunPredictionEnabled = state
	mm2WeaponClient:TogglePrediction(state)
	UI:AddNoti("Gun Prediction", state and "Enabled" or "Disabled", 2)
end)

MainSection:CreateKeybind("Shoot", Enum.KeyCode.F, function()
	shootMurderer()
end)

MainSection:CreateKeybind("Knife All", Enum.KeyCode.G, function()
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

MainSection:CreateToggle("Nearby Knife Enabled", {
	Description = "Auto knife nearby alive round players.",
	Toggled = false,
}, function(state)
	nearbyKnifeEnabled = state
end)

MainSection:CreateSlider("Nearby Knife", {
	Min = 0,
	Max = 50,
	DefaultValue = 0,
}, function(value)
	nearbyKnifeRange = value
end)

MainSection:CreateToggle("OptimizedCoinCollection", {
	Description = "Auto collect nearest coins at 17.5 speed while in active round.",
	Toggled = false,
}, function(state)
	optimizedCoinCollectionEnabled = state
	if not state then
		stopCoinMovement(true)
	end
end)

MainSection:CreateParagraph(
	"Notes",
	"Nearby Knife is disabled if toggle is off OR slider is 0. OptimizedCoinCollection waits for round + map + CoinContainer, retargets if coin disappears, and pauses when bag is full.",
	5
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
		local coinContainer = map and map:FindFirstChild("CoinContainer")
		if not coinContainer then
			stopCoinMovement(true)
			continue
		end

		if bagMax > 0 and bagCurrent >= bagMax then
			stopCoinMovement(true)
			continue
		end

		if not ensureCoinMovementEnabled() then
			continue
		end

		purgeSkippedCoins()

		if activeTargetCoin and (not activeTargetCoin.Parent or not activeTargetCoin:IsDescendantOf(coinContainer)) then
			-- Coin was taken/removed, pick a new one.
			mv:StopGoto()
			activeTargetCoin = nil
		end

		if activeTargetCoin then
			-- Fast retarget once we know bag increased (coin collected).
			if bagCurrent > activeTargetBagAtStart then
				mv:StopGoto()
				activeTargetCoin = nil
			else
				local myRoot = getRoot(LocalPlayer)
				local targetPart = getCoinPart(activeTargetCoin)
				local elapsed = os.clock() - activeTargetAssignedAt
				if (not targetPart) or (not myRoot) then
					mv:StopGoto()
					activeTargetCoin = nil
				elseif elapsed >= 0.25 and (myRoot.Position - targetPart.Position).Magnitude <= 2.2 then
					-- Prevent 1-3s stalls near stale/contested coins.
					skippedCoins[activeTargetCoin] = os.clock() + 0.9
					mv:StopGoto()
					activeTargetCoin = nil
				end
			end
		end

		if not activeTargetCoin then
			local nearestCoin = getNextCoin(coinContainer)
			if nearestCoin then
				local targetPart = getCoinPart(nearestCoin)
				if targetPart then
					activeTargetCoin = nearestCoin
					activeTargetAssignedAt = os.clock()
					activeTargetBagAtStart = bagCurrent
					mv:StopGoto()
					task.spawn(function()
						mv:Goto(targetPart.Position)
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
