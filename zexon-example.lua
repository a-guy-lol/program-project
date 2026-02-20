local ZexonUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/zexonUI.lua"))()

local UI = ZexonUI:CreateWindow("<font color=\"#1CB2F5\">Zexon UI Example</font>", "Element Showcase", false)
UI:SetTheme("SchemaColor", Color3.fromRGB(28, 178, 245))

UI:AddNoti("Zexon Example", "UI loaded. This script showcases all major elements.", 4)

local MainTab = UI:CreatePage("Main")
local MainSection = MainTab:CreateSection("Examples")

MainSection:CreateButton("Notify", function()
	UI:AddNoti("Button", "You clicked the button.", 3)
end)

MainSection:CreateParagraph(
	"Paragraph",
	"This is a paragraph element. Use this to show longer descriptive text in your UI.",
	4
)

MainSection:CreateToggle("Feature Toggle", {
	Description = "Example toggle with description text.",
	Toggled = false,
}, function(state)
	print("[Example] Toggle state:", state)
end)

MainSection:CreateDropdown("Mode", {
	List = { "Normal", "Aggressive", "Stealth" },
	Search = false,
	Default = "Normal",
}, function(mode)
	print("[Example] Dropdown selected:", mode)
end)

MainSection:CreateSlider("Power", {
	Min = 0,
	Max = 100,
	DefaultValue = 35,
}, function(value)
	print("[Example] Slider value:", value)
end)

MainSection:CreateTextbox("Message", "Type text and press Enter", function(text)
	print("[Example] Textbox:", text)
	UI:AddNoti("Textbox", "You entered: " .. tostring(text), 3)
end, "Hello")

MainSection:CreateKeybind("Ping Key", Enum.KeyCode.RightBracket, function()
	UI:AddNoti("Keybind", "Ping key pressed.", 2)
end)

MainSection:CreateColorPicker("Accent", Color3.fromRGB(28, 178, 245), function(color)
	UI:SetTheme("SchemaColor", color)
end)

local ExtraTab = UI:CreatePage("Extra")
local ExtraSection = ExtraTab:CreateSection("Tips")

ExtraSection:CreateParagraph(
	"How To Use",
	"Press the tab buttons to switch pages. Press Z to move the whole UI off-screen and bring it back.",
	5
)

ExtraSection:CreateButton("Toggle UI Visibility", function()
	UI:ToggleUI()
end)
