local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local FlingLib = loadstring(game:HttpGet("YOUR_RAW_MODULE_URL_HERE"))()

local TargetUsername = "TargetUser"
local MaxTime = 5
local DetectIfFlung = true

local TargetPlayer
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer and (player.Name == TargetUsername or player.DisplayName == TargetUsername) then
		TargetPlayer = player
		break
	end
end

if TargetPlayer then
	FlingLib:Fling(TargetPlayer, MaxTime, DetectIfFlung)
end
