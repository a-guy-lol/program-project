local TeleportCheck = false
local Players = game:GetService("Players")
local KeepInfYield = true
local queueteleport = syn and syn.queue_on_teleport or queue_on_teleport

while true do
    wait(300)
Players.LocalPlayer.OnTeleport:Connect(function(State)
    if KeepInfYield and (not TeleportCheck) and queueteleport then
        TeleportCheck = true
        queueteleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/shop.lua'))()")
    end
end)
end
