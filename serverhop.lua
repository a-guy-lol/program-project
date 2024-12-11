local TeleportCheck = false
local Players = game:GetService("Players")
local KeepInfYield = true
local queueteleport = syn and syn.queue_on_teleport or queue_on_teleport

Players.LocalPlayer.OnTeleport:Connect(function(State)
    if KeepInfYield and (not TeleportCheck) and queueteleport then
        TeleportCheck = true
        queueteleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()")
    end
end)
