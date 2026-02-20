local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local roundClient = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/MM2-RoundModule.lua"))()
local moveClient = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/moveVelocityModule.lua"))()
local autoFarm = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/mm2AutoFarmModule.lua"))()

autoFarm:Bind({
	RoundClient = roundClient,
	MoveClient = moveClient,
	LocalPlayer = LocalPlayer,
})

autoFarm:SetConfig({
	FocusRange = 50,
	MoveMinSpeed = 17.5,
	MoveMaxSpeed = 17.5,
	MoveArrivalDist = 0,
	MoveSnapDist = 0,
	MoveSnapEpsilon = 0,
})

local bagCurrent = 0
local bagMax = 0

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

autoFarm:Enable()

while task.wait(0.3) do
	autoFarm:SetBag(bagCurrent, bagMax)

	local status = autoFarm:GetStatus()
	print(
		"[AutoFarm]",
		"Enabled:", status.Enabled,
		"RoundActive:", status.RoundActive,
		"InRound:", status.LocalInRound,
		"Collecting:", status.Collecting,
		"Bag:", bagCurrent .. "/" .. bagMax,
		"Reason:", status.LastReason
	)
end
