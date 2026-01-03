local GameLogic = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/MM2-RoundModule.lua"))()

print("--- MM2 Logic Loaded ---")

-- 2. Loop to monitor the round
while task.wait(1) do
    local isActive = GameLogic:IsRoundActive()
    
    if isActive then
        local roles = GameLogic:GetRoundRoles()
        local amIPlaying = GameLogic:IsPlayerInRound(game.Players.LocalPlayer)
        
        -- Print Logic
        print("-----------------------------")
        print("Round Active: YES")
        print("Am I Playing: " .. tostring(amIPlaying))
        
        if roles.Murderer then
            print("Murderer detected: " .. roles.Murderer.Name)
        else
            print("Murderer: Unknown/Hidden")
        end
        
        if roles.Sheriff then
            print("Sheriff detected: " .. roles.Sheriff.Name)
        else
            print("Sheriff: Unknown/Dead")
        end
        
    else
        print("Round Status: Waiting in Lobby...")
    end
end
