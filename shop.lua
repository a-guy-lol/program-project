-- Teleport Check Script
-- This script ensures that upon teleporting, a specific script is reloaded

-- Variables
local TeleportCheck = false
local Players = game:GetService("Players")
local KeepInfYield = true -- Ensure this variable is properly set as per your use case
local queueteleport = syn and syn.queue_on_teleport or queue_on_teleport -- Adjust for your executor compatibility
local timerDuration = 300 -- Timer duration in seconds

print("[DEBUG] Script initialized. TeleportCheck: false, KeepInfYield: " .. tostring(KeepInfYield))

-- Create a screen GUI to display the timer
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TimerDisplayGui"
ScreenGui.Parent = game.CoreGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0.3, 0, 0.1, 0) -- Size of the frame
Frame.Position = UDim2.new(0.35, 0, 0.45, 0) -- Center of the screen
Frame.BackgroundColor3 = Color3.new(0, 0, 0)
Frame.BackgroundTransparency = 0.5
Frame.ZIndex = 10 -- Ensure it's on top of all elements
Frame.Parent = ScreenGui

local TimerLabel = Instance.new("TextLabel")
TimerLabel.Size = UDim2.new(1, 0, 1, 0)
TimerLabel.BackgroundTransparency = 1
TimerLabel.TextColor3 = Color3.new(1, 1, 1)
TimerLabel.TextScaled = true
TimerLabel.Font = Enum.Font.SourceSansBold
TimerLabel.Text = "Starting..."
TimerLabel.ZIndex = 11
TimerLabel.Parent = Frame

-- Function to update the timer label
local function updateTimerDisplay(remainingTime)
    TimerLabel.Text = string.format("Time until next event: %d seconds", remainingTime)
end

spawn(function()
    while true do
        for remainingTime = timerDuration, 0, -1 do
            updateTimerDisplay(remainingTime)
            wait(1)
        end
        print("[DEBUG] Timer reached zero. Restarting countdown.")
    end
end)
Players.LocalPlayer.OnTeleport:Connect(function(State)
    print("[DEBUG] OnTeleport triggered with State: " .. tostring(State))
    if KeepInfYield and (not TeleportCheck) and queueteleport then
        print("[DEBUG] Conditions met. Setting TeleportCheck to true and queuing teleport.")
        TeleportCheck = true
        queueteleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/shop.lua'))()")
        script_key="VNpKkDavpOSXEntdFsXYRnMTaUQFEoaX";
        loadstring(game:HttpGet('http://scripts.projectauto.xyz/AutoRobV4'))()
    else
        print("[DEBUG] Conditions not met. TeleportCheck: " .. tostring(TeleportCheck))
    end
end)
