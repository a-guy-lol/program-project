local FlingLib = {}

-- [[ CONFIGURATION ]] --
local Config = {
    Velocity = Vector3.new(9e8, 9e8, 9e8), -- Do not touch (Original script value)
    RotVelocity = Vector3.new(9e8, 9e8, 9e8), -- Do not touch
    FlungThreshold = 200 -- Studs per second to consider "Flung" (for the 'dif' parameter)
}

-- [[ STATE TRACKING ]] --
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CurrentFlingId = 0 -- Used to cancel previous flings

function FlingLib:Fling(TargetPlayer, Time, Dif)
    -- Increment ID to invalidate any previous running flings
    CurrentFlingId = CurrentFlingId + 1
    local MyFlingId = CurrentFlingId
    
    local StartTime = tick()
    
    -- Basic checks
    if not TargetPlayer or not TargetPlayer.Character or not LocalPlayer.Character then return end
    
    local Character = LocalPlayer.Character
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart
    
    local TCharacter = TargetPlayer.Character
    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    
    -- Determine target part (Logic from original script)
    local TargetPart = TRootPart or THead or TCharacter:FindFirstChildWhichIsA("BasePart")
    
    if not Character or not Humanoid or not RootPart or not TargetPart then return end
    
    -- Setup Old Position for return
    local OldPos = RootPart.CFrame
    local OriginalFPDH = workspace.FallenPartsDestroyHeight
    
    -- [[ FLING MECHANIC SETUP ]] --
    workspace.FallenPartsDestroyHeight = 0/0
    
    local BV = Instance.new("BodyVelocity")
    BV.Name = "EpixVel"
    BV.Parent = RootPart
    BV.Velocity = Config.Velocity
    BV.MaxForce = Vector3.new(1/0, 1/0, 1/0)
    
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    
    -- Camera Lock
    if THumanoid then
        workspace.CurrentCamera.CameraSubject = THumanoid
    elseif TargetPart then
         workspace.CurrentCamera.CameraSubject = TargetPart
    end

    -- [[ FPOS FUNCTION (UNALTERED MATH) ]] --
    local function FPos(BasePart, Pos, Ang)
        RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
        Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
        RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
        RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    -- [[ MAIN LOOP ]] --
    local Angle = 0
    
    repeat
        -- 1. Check Cancellation (New Fling Started)
        if CurrentFlingId ~= MyFlingId then break end
        
        -- 2. Check Time
        if (tick() - StartTime) > Time then break end
        
        -- 3. Check Death/Existence
        if not TargetPlayer.Parent or not TCharacter.Parent or (THumanoid and THumanoid.Health <= 0) then break end
        if not Character.Parent or (Humanoid and Humanoid.Health <= 0) then break end

        -- 4. Check "Dif" (Detect if Flung)
        if Dif and TargetPart.Velocity.Magnitude > Config.FlungThreshold then break end

        -- [[ FLING SEQUENCE (Original Logic) ]] --
        if RootPart and THumanoid then
             if TargetPart.Velocity.Magnitude < 50 then
                Angle = Angle + 100
                
                -- Sequence of teleports from original script
                FPos(TargetPart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * TargetPart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * TargetPart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(2.25, 1.5, -2.25) + THumanoid.MoveDirection * TargetPart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(-2.25, -1.5, 2.25) + THumanoid.MoveDirection * TargetPart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection,CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection,CFrame.Angles(math.rad(Angle), 0, 0))
                task.wait()
            else
                -- High velocity chase sequence
                FPos(TargetPart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(0, 1.5, TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(0, -1.5, -TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(0, 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(0, 1.5, TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(0, -1.5 ,0), CFrame.Angles(math.rad(-90), 0, 0))
                task.wait()
                
                FPos(TargetPart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                task.wait()
            end
        else
            break
        end
    until false -- Breaks are handled at the start of loop

    -- [[ CLEANUP ]] --
    if BV then BV:Destroy() end
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    workspace.CurrentCamera.CameraSubject = Humanoid
    workspace.FallenPartsDestroyHeight = OriginalFPDH
    
    -- Reset Character
    RootPart.CFrame = OldPos * CFrame.new(0, .5, 0)
    Character:SetPrimaryPartCFrame(OldPos * CFrame.new(0, .5, 0))
    Humanoid:ChangeState("GettingUp")
    
    -- Stop velocity on self
    for _, x in ipairs(Character:GetChildren()) do
        if x:IsA("BasePart") then
            x.Velocity, x.RotVelocity = Vector3.new(), Vector3.new()
        end
    end
end

return FlingLib
