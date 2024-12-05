local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")


local uilibrary = loadstring(game:HttpGet("https://pastebin.com/raw/1Qg7Lmad"))()
local windowz = uilibrary:CreateWindow("                                                              Zexon", "Script Menu", true)

local mainPage = windowz:CreatePage("Main - FE")
local mainSection = mainPage:CreateSection("Main")


mainSection:CreateButton("   Execute | Inf Yield", function ()
   loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
end)

mainSection:CreateSlider("   Change WalkSpeed", {Min = 16, Max = 150, DefaultValue = 16}, function(Value)
        local speaker = game.Players.LocalPlayer
        local Char = speaker.Character or workspace:FindFirstChild(speaker.Name)
        local Human = Char and Char:FindFirstChildWhichIsA("Humanoid")

        if Char and Human then
            Human.WalkSpeed = Value
        end

        HumanModCons = HumanModCons or {}
        HumanModCons.wsLoop = (HumanModCons.wsLoop and HumanModCons.wsLoop:Disconnect() and false) or Human:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if Human then
                Human.WalkSpeed = Value
            end
        end)

        HumanModCons.wsCA = (HumanModCons.wsCA and HumanModCons.wsCA:Disconnect() and false) or speaker.CharacterAdded:Connect(function(nChar)
            Char, Human = nChar, nChar:WaitForChild("Humanoid")
            Human.WalkSpeed = Value
            HumanModCons.wsLoop = (HumanModCons.wsLoop and HumanModCons.wsLoop:Disconnect() and false) or Human:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if Human then
                    Human.WalkSpeed = Value
                end
            end)
        end)
end)



local CyclonePage = windowz:CreatePage("Cyclone - FE")
local CycloneSection = CyclonePage:CreateSection("Cyclone - Load")

CycloneSection:CreateButton("   Execute | Cyclone", function ()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/main-tabs/cyclone-source.lua'))()
 end)

uilibrary:AddNoti("UI loaded.", "Zexon has successfully loaded.", 5, true)

