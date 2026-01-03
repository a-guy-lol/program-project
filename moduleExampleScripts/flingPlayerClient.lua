local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local FlingLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/flingPlayerModule.lua"))()

local TargetUsername = "TargetUser"

local TargetPlayer
for _, Player in ipairs(Players:GetPlayers()) do
	if Player ~= LocalPlayer and (Player.Name == TargetUsername or Player.DisplayName == TargetUsername) then
		TargetPlayer = Player
		break
	end
end

if TargetPlayer then
	FlingLib:Fling(TargetPlayer, 5, true)
end
