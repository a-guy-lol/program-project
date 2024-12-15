local customGame = windowz:CreatePage("Game")
local customGameSection = customGame:CreateSection("Natural Disaster Survival")

customGameSection:CreateButton("   Teleport | Lobby", function ()
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
if humanoidRootPart then
    humanoidRootPart.CFrame = CFrame.new(-280, 179, 341)
end
end)
customGameSection:CreateButton("   Teleport | Map", function ()
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
if humanoidRootPart then
    humanoidRootPart.CFrame = CFrame.new(-117, 48, 7)
end
end)