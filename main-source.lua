local placeId = game.PlaceId
local repoBranch = "https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/"

-- Construct the link for the specific game ID
local specificGameLink = repoBranch .. "games/" .. placeId .. ".lua"
-- The default link
local defaultLink = repoBranch .. "zexon-cyclone-main.lua"

-- Attempt to fetch the specific game script safely
local success, scriptSource = pcall(function()
    return game:HttpGet(specificGameLink)
end)

if success then
    -- If the file exists for this PlaceId, run it
    loadstring(scriptSource)()
else
    -- If the file does not exist (404), run the default script
    loadstring(game:HttpGet(defaultLink))()
end
