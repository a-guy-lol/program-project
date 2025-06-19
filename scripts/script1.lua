-- This single LocalScript creates the entire "Work in Progress" UI programmatically.
-- Place this script in StarterPlayer > StarterPlayerScripts.

-- Get the LocalPlayer and their PlayerGui, which is where all UI for that player is stored.
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- A function to create and manage the UI to keep the code organized.
local function createWipUI()
	
	-- Create the main ScreenGui container. This is the top-level object for 2D UI.
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WIP_UI"
	screenGui.ResetOnSpawn = false -- Prevents the UI from being destroyed and recreated when the player respawns.

	-- Create the main background frame for the pop-up.
	local backgroundFrame = Instance.new("Frame")
	backgroundFrame.Name = "BackgroundFrame"
	backgroundFrame.AnchorPoint = Vector2.new(0.5, 0.5) -- Center the frame's origin.
	backgroundFrame.Position = UDim2.fromScale(0.5, 0.5) -- Position it in the center of the screen.
	backgroundFrame.Size = UDim2.fromOffset(450, 220) -- Set a fixed size in pixels.
	backgroundFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 8) -- A very dark gray, almost black.
	backgroundFrame.Parent = screenGui

	-- Add UICorner for modern, rounded edges.
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = backgroundFrame

	-- Add UIStroke to create a border.
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255) -- White border.
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = backgroundFrame
	
	-- Create the main title label.
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 40)
	titleLabel.Position = UDim2.fromScale(0.5, 0.25)
	titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamSemibold
	titleLabel.Text = "Work in Progress"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 24
	titleLabel.Parent = backgroundFrame

	-- Create the description label.
	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Name = "DescriptionLabel"
	descriptionLabel.Size = UDim2.new(0.9, 0, 0.4, 0)
	descriptionLabel.Position = UDim2.fromScale(0.5, 0.55)
	descriptionLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Font = Enum.Font.Gotham
	descriptionLabel.Text = "This feature is currently under development. Please check back later!"
	descriptionLabel.TextColor3 = Color3.fromRGB(180, 180, 180) -- Light gray for contrast.
	descriptionLabel.TextSize = 16
	descriptionLabel.TextWrapped = true -- Ensure the text wraps if it's too long.
	descriptionLabel.Parent = backgroundFrame
	
	-- Create the close button.
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.fromOffset(35, 35)
	closeButton.Position = UDim2.new(1, -5, 0, 5) -- Position at top right with a small margin.
	closeButton.AnchorPoint = Vector2.new(1, 0) -- Anchor to the top right.
	closeButton.BackgroundTransparency = 1
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(200, 200, 200)
	closeButton.TextSize = 22
	closeButton.Parent = backgroundFrame

	-- --- Functionality ---
	
	-- Function to handle the close button click.
	local function onClose()
		-- Smoothly fade out the UI before destroying it.
		game:GetService("TweenService"):Create(backgroundFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		game:GetService("TweenService"):Create(titleLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		game:GetService("TweenService"):Create(descriptionLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		game:GetService("TweenService"):Create(closeButton, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		game:GetService("TweenService"):Create(stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
		
		-- Wait for the fade-out to complete, then destroy the entire UI.
		task.wait(0.3)
		screenGui:Destroy()
	end
	
	-- Connect the function to the button's click event.
	closeButton.MouseButton1Click:Connect(onClose)
	
	-- Parent the completed ScreenGui to the PlayerGui to make it visible.
	screenGui.Parent = playerGui
	
	print("WIP UI created successfully.")
end

-- Run the function to create the UI.
createWipUI()
