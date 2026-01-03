local FlingModule = {}

-- // CONFIGURATION //
FlingModule.Config = {
    FlingVelocity = Vector3.new(9e8, 9e8, 9e8), -- The physics force
    RotVelocity = Vector3.new(9e8, 9e8, 9e8),   -- The spin force
    Threshold = 200 -- Velocity (studs/sec) to consider the target "flung"
}

-- // VARIABLES //
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Defines the current active fling job. 
-- Changing this variable automatically stops any previous running loops.
local CurrentJobId = nil 

function FlingModule:Fling(targetPlayer, duration, detectFlung)
    -- 1. Generate a unique ID for this specific function call
    local thisJobId = game:GetService("HttpService"):GenerateGUID(false)
    CurrentJobId = thisJobId

    -- 2. Validation
    if not targetPlayer or not LocalPlayer.Character then return end
    
    local myChar = LocalPlayer.Character
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local myHumanoid = myChar:FindFirstChild("Humanoid")
    
    if not myRoot or not myHumanoid then return end

    -- 3. Save State & Setup Physics
    local originalPos = myRoot.CFrame
    local startTime = tick()
    
    -- Create Force
    local bv = Instance.new("BodyVelocity")
    bv.Name = "FlingVelocity"
    bv.Parent = myRoot
    bv.Velocity = Vector3.zero 
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)

    -- Bypass Fallen Parts
    local originalFallenHeight = workspace.FallenPartsDestroyHeight
    workspace.FallenPartsDestroyHeight = 0/0 -- NaN

    -- 4. The Loop
    local connection
    connection = RunService.RenderStepped:Connect(function()
        -- A. Stop if a new fling command was called (Override)
        if CurrentJobId ~= thisJobId then
            connection:Disconnect()
            -- We do NOT cleanup here, we assume the new job takes over control
            return 
        end

        -- B. Target Validation
        local tChar = targetPlayer.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        
        if not tChar or not tRoot or not targetPlayer.Parent then
            connection:Disconnect()
            FlingModule:_Cleanup(originalPos, originalFallenHeight, bv)
            return
        end

        -- C. Time Limit Check
        if tick() - startTime > duration then
            connection:Disconnect()
            FlingModule:_Cleanup(originalPos, originalFallenHeight, bv)
            return
        end

        -- D. Velocity Check (Did we fling them?)
        if detectFlung and tRoot.Velocity.Magnitude > FlingModule.Config.Threshold then
            connection:Disconnect()
            FlingModule:_Cleanup(originalPos, originalFallenHeight, bv)
            return
        end

        -- E. Physics Logic (The Fling)
        -- We sit inside the target and rotate violently
        if myRoot and tRoot then
            bv.Velocity = FlingModule.Config.FlingVelocity
            myRoot.RotVelocity = FlingModule.Config.RotVelocity
            
            -- Teleport inside them with rotation
            local angle = (tick() * 10) % 360
            myRoot.CFrame = tRoot.CFrame * CFrame.Angles(math.rad(angle), math.rad(angle), 0)
            
            -- Prevent Sitting
            myHumanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        end
    end)
end

-- // CLEANUP HELPER //
function FlingModule:_Cleanup(restorePos, restoreHeight, velocityObj)
    if velocityObj then velocityObj:Destroy() end
    workspace.FallenPartsDestroyHeight = restoreHeight
    
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChild("Humanoid")
    
    if myRoot and restorePos then
        myRoot.Velocity = Vector3.zero
        myRoot.RotVelocity = Vector3.zero
        myRoot.CFrame = restorePos
    end
    
    if myHum then
        myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    end
end

return FlingModule
