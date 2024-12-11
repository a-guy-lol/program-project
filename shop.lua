-- Teleport Check and Server Hop Script
-- This script ensures teleport functionality with server hopping capability

-- Variables
local TeleportCheck = false
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local KeepInfYield = true -- Ensure this variable is properly set as per your use case
local queueteleport = syn and syn.queue_on_teleport or queue_on_teleport -- Adjust for your executor compatibility
local timerDuration = math.random(100, 160) -- Timer duration in seconds
local PlaceId = game.PlaceId
local JobId = game.JobId
local httprequest = syn and syn.request or http_request or request -- Adjust for your exploit compatibility

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

-- Combined Server Hop and Teleport Logic
local function serverHopAndTeleport()
    if httprequest then
        local servers = {}
        local req = httprequest({Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", PlaceId)})
        local body = HttpService:JSONDecode(req.Body)

        if body and body.data then
            for i, v in next, body.data do
                if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= JobId then
                    table.insert(servers, 1, v.id)
                end
            end
        end

        if #servers > 0 then
            TeleportService:TeleportToPlaceInstance(PlaceId, servers[math.random(1, #servers)], Players.LocalPlayer)
        else
            print("[DEBUG] Serverhop: Couldn't find a server.")
        end
    else
        print("[DEBUG] Incompatible Exploit: Your exploit does not support this command (missing request)")
    end

    if KeepInfYield and (not TeleportCheck) and queueteleport then
        print("[DEBUG] Conditions met. Setting TeleportCheck to true and queuing teleport.")
        TeleportCheck = true
        queueteleport("loadstring(game:HttpGet('https://pastebin.com/raw/HYuVwnZK'))()")
    else
        print("[DEBUG] Conditions not met. TeleportCheck: " .. tostring(TeleportCheck))
    end
end

-- Timer Logic
spawn(function()
    while true do
        for remainingTime = timerDuration, 0, -1 do
            updateTimerDisplay(remainingTime)
            wait(1)
        end
        print("[DEBUG] Timer reached zero. Attempting server hop and teleport.")
        serverHopAndTeleport()
    end
end)

-- Teleport Trigger Logic
Players.LocalPlayer.OnTeleport:Connect(function(State)
    print("[DEBUG] OnTeleport triggered with State: " .. tostring(State))
    serverHopAndTeleport()
end)
