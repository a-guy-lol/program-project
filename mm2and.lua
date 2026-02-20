local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local ZexonUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/zexonUI.lua"))()
local mm2RoundClient = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/MM2-RoundModule.lua"))()
local mm2WeaponClient = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/mm2WeaponModule.lua"))()
local flingClient = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/flingPlayerModule.lua"))()
local mv = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/moveVelocityModule.lua"))()
local mm2AutoFarm = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/mm2AutoFarmModule.lua"))()

local PLATFORM_POS = Vector3.new(200, 500, 200)
local PLATFORM_NAME = "MM2And_SafePlatform"
local PLATFORM_TP_COOLDOWN = 1.25

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
	smoothRate = 18,
	snapDist = 0,
	snapEpsilon = 0,
})

mm2AutoFarm:Bind({
	RoundClient = mm2RoundClient,
	MoveClient = mv,
	LocalPlayer = LocalPlayer,
})

mm2AutoFarm:SetConfig({
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
local AUTO_HANDLE_REPOSITION_ATTEMPTS = 5
local AUTO_HANDLE_SHOT_RETRY_ATTEMPTS = 2
local AUTO_HANDLE_SHOT_RETRY_STEP = 0.14
local AUTO_HANDLE_SUCCESS_COOLDOWN = 0.95
local AUTO_HANDLE_FAIL_COOLDOWN = 1.5

local prevRoundActive = false

local function getRoundAlivePlayers()
	local list = {}
	local seen = {}

	local function addPlayer(player)
		if not player or player == LocalPlayer or seen[player] or not isAlive(player) then
			return
		end
		seen[player] = true
		list[#list + 1] = player
	end

	local roles = getRoundRolesSafe()
	if roles then
		addPlayer(roles.Murderer)
		addPlayer(roles.Sheriff)
		for _, player in ipairs(roles.Innocents or {}) do
			addPlayer(player)
		end
	end

	if #list == 0 then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and mm2RoundClient:IsPlayerInRound(player) then
				addPlayer(player)
			end
		end
	end

	return list
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
	if os.clock() < nextAutoHandleAt then
		return false
	end

	local roles = getRoundRolesSafe()
	local murderer = roles and roles.Murderer
	if not murderer or murderer == LocalPlayer or not isAlive(murderer) then
		return false
	end

	autoHandleInProgress = true
	task.spawn(function()
		local shotSucceeded = false
		local ok = pcall(function()
			for attempt = 1, AUTO_HANDLE_REPOSITION_ATTEMPTS do
				if not autoHandleMurderEnabled then
					break
				end
				if not mm2RoundClient:IsRoundActive() or not isAlive(murderer) then
					break
				end

				local myRoot = getRoot(LocalPlayer)
				local targetRoot = getRoot(murderer)
				if not myRoot or not targetRoot then
					break
				end

				local backDistance = 4.2 + ((attempt - 1) * 0.25)
				local sideSign = (attempt % 2 == 0) and 1 or -1
				local sideOffset = (attempt == 1) and 0 or (1.1 * sideSign)
				local behindPos = targetRoot.Position
					- (targetRoot.CFrame.LookVector * backDistance)
					+ (targetRoot.CFrame.RightVector * sideOffset)

				myRoot.CFrame = CFrame.new(behindPos, targetRoot.Position)
				task.wait(0.08)

				for _ = 1, AUTO_HANDLE_SHOT_RETRY_ATTEMPTS do
					local fireOk = select(1, mm2WeaponClient:UseGun(murderer))
					if fireOk then
						shotSucceeded = true
						break
					end
					task.wait(AUTO_HANDLE_SHOT_RETRY_STEP)
				end

				if shotSucceeded then
					break
				end
				task.wait(0.18)
			end
		end)

		task.wait(shotSucceeded and 0.35 or 0.2)
		teleportToPlatform(false)

		if ok and shotSucceeded then
			nextAutoHandleAt = os.clock() + AUTO_HANDLE_SUCCESS_COOLDOWN
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
			mm2AutoFarm:SetBag(bagCurrent, bagMax)
		end)
	end

	if coinsStarted and coinsStarted:IsA("RemoteEvent") then
		coinsStarted.OnClientEvent:Connect(function()
			bagCurrent = 0
			mm2AutoFarm:SetBag(bagCurrent, bagMax)
		end)
	end
end)

local CombatTab = UI:CreatePage("Combat")
local CombatSection = CombatTab:CreateSection("MM2 Controls")

CombatSection:CreateParagraph(
	"MM2 Panel",
	"Shoot keybind targets murderer. Knife All keybind hits all alive players if murderer. Auto Handle Murder retries with cooldown-safe timing.",
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
	Description = "After bag full: teleport behind murderer, attempt shoot(s), return to platform, retry with cooldown.",
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
	Description = "Uses MM2AutoFarmModule: 50-stud focus, touch tracking, nearest real-time retargeting.",
	Toggled = false,
}, function(state)
	optimizedCoinCollectionEnabled = state
	if state then
		ensureSafePlatform()
		mm2AutoFarm:SetBag(bagCurrent, bagMax)
		mm2AutoFarm:Enable()
	else
		mm2AutoFarm:Disable()
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
	"Coin routing now runs in modules/mm2AutoFarmModule.lua and moveVelocity now hard-centers on exact destination.",
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

	for _, player in ipairs(getRoundAlivePlayers()) do
		local targetRoot = getRoot(player)
		if targetRoot then
			local dist = (myRoot.Position - targetRoot.Position).Magnitude
			if dist <= nearbyKnifeRange then
				local now = os.clock()
				if not lastKnifeAt[player] or (now - lastKnifeAt[player]) >= nearbyKnifeCooldown then
					mm2WeaponClient:UseKnife(player)
					lastKnifeAt[player] = now
				end
			end
		end
	end
end)

task.spawn(function()
	while task.wait(0.05) do
		mm2AutoFarm:SetBag(bagCurrent, bagMax)

		if optimizedCoinCollectionEnabled then
			if not mm2AutoFarm:IsEnabled() then
				mm2AutoFarm:Enable()
			end
		else
			if mm2AutoFarm:IsEnabled() then
				mm2AutoFarm:Disable()
			end
			continue
		end

		local farmStatus = mm2AutoFarm:GetStatus()
		local roundActive = farmStatus.RoundActive
		local localInRound = farmStatus.LocalInRound
		local bagFull = farmStatus.BagFull
		local map = farmStatus.Map

		if prevRoundActive and not roundActive then
			teleportToPlatform(true)
			bagCurrent = 0
			mm2AutoFarm:SetBag(bagCurrent, bagMax)
		end
		prevRoundActive = roundActive

		if roundActive and localInRound and map then
			tryAutoCollectGunDrop(map)
		end

		if roundActive and not localInRound then
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
			continue
		end

		if bagFull then
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

			if autoKnifeAllEnabled and isLocalMurderer() and (now - lastAutoKnifeAllAt) >= 0.5 then
				lastAutoKnifeAllAt = now
				mm2WeaponClient:UseKnifeAll()
			end

			if autoHandleMurderEnabled and hasGun then
				tryAutoHandleMurder()
			end
		end
	end
end)

mm2WeaponClient:TogglePrediction(gunPredictionEnabled)
