local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local MM2Weapons = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/mm2WeaponModule.lua"))()

local TargetUsername = "TargetUser"

local TargetPlayer
for _, p in ipairs(Players:GetPlayers()) do
	if p ~= LocalPlayer and (p.Name == TargetUsername or p.DisplayName == TargetUsername) then
		TargetPlayer = p
		break
	end
end

if not TargetPlayer then
	warn("Target player not found")
	return
end

print("HasGun:", MM2Weapons:HasGun())
print("HasKnife:", MM2Weapons:HasKnife())

if MM2Weapons:HasGun() then
	MM2Weapons:TogglePrediction(true)
	local ok, reason = MM2Weapons:UseGun(TargetPlayer)
	print("UseGun:", ok, reason)
elseif MM2Weapons:HasKnife() then
	local okOne, reasonOne = MM2Weapons:UseKnife(TargetPlayer)
	print("UseKnife:", okOne, reasonOne)

	local okAll, resultAll = MM2Weapons:UseKnifeAll()
	print("UseKnifeAll:", okAll, resultAll)
else
	warn("No usable MM2 weapon found")
end
