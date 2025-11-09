-- CompletionModal: Shows completion screen with time and reset option
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local SoundManager = require(script.Parent.SoundManager)

local CompletionModal = {}
CompletionModal.__index = CompletionModal

local player = Players.LocalPlayer
local player_gui = nil
local modal_gui = nil
local is_visible = false
local sound_manager = nil -- SoundManager instance

function CompletionModal.new()
	local self = setmetatable({}, CompletionModal)
	return self
end

function CompletionModal:create()
	-- Get SoundManager instance
	sound_manager = _G.SoundManager or SoundManager.new()
	
	player_gui = player:WaitForChild("PlayerGui")
	
	-- Create ScreenGui for modal
	modal_gui = Instance.new("ScreenGui")
	modal_gui.Name = "CompletionModal"
	modal_gui.ResetOnSpawn = false
	modal_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	modal_gui.DisplayOrder = 10
	modal_gui.Parent = player_gui
	
	-- Create background overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Parent = modal_gui
	
	-- Create modal frame
	local modal_frame = Instance.new("Frame")
	modal_frame.Name = "ModalFrame"
	modal_frame.Size = UDim2.new(0.9, 0, 0.9, 0) -- 90% height of screen
	modal_frame.Position = UDim2.new(0.5, 0, 0.5, 0) -- center of screen
	modal_frame.AnchorPoint = Vector2.new(0.5, 0.5) -- center of screen
	modal_frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	modal_frame.BorderSizePixel = 0
	modal_frame.Parent = modal_gui

	local size_constraint = Instance.new("UISizeConstraint")
	size_constraint.MaxSize = Vector2.new(600, 400)  -- Maximum: 600x400 pixels
	size_constraint.Parent = modal_frame
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = modal_frame
	
	-- Add title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 0, 60)
	title.Position = UDim2.new(0.5, 0, 0.15, 0)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.BackgroundTransparency = 1
	title.Text = "Gate Opened!"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 36
	title.Font = Enum.Font.GothamBold
	title.Parent = modal_frame
	
	-- Add completion time label
	local time_label = Instance.new("TextLabel")
	time_label.Name = "TimeLabel"
	time_label.Size = UDim2.new(1, -40, 0, 50)
	time_label.Position = UDim2.new(0, 20, 0.25, 0)
	time_label.BackgroundTransparency = 1
	time_label.Text = "Completion Time: 00:00"
	time_label.TextColor3 = Color3.fromRGB(200, 200, 200)
	time_label.TextSize = 24
	time_label.Font = Enum.Font.Gotham
	time_label.Parent = modal_frame
	
	-- Create button container
	local button_container = Instance.new("Frame")
	button_container.Name = "ButtonContainer"
	local horizontalPadding = 20  
	local bottomPadding = 20
	button_container.AnchorPoint = Vector2.new(0.5, 1)
	button_container.Position = UDim2.new(0.5, 0, 1, -bottomPadding)
	button_container.Size = UDim2.new(1, -2 * horizontalPadding, 0.25, 0)
	button_container.BackgroundTransparency = 1
	button_container.Parent = modal_frame
	
	-- Create Reset button
	local reset_button = Instance.new("TextButton")
	reset_button.Name = "ResetButton"
	reset_button.Size = UDim2.new(0.45, 0, 1, 0)
	reset_button.Position = UDim2.new(0, 0, 0, 0)
	reset_button.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
	reset_button.Text = "Reset Run"
	reset_button.TextColor3 = Color3.fromRGB(255, 255, 255)
	reset_button.TextSize = 20
	reset_button.Font = Enum.Font.GothamBold
	reset_button.Parent = button_container
	
	local reset_corner = Instance.new("UICorner")
	reset_corner.CornerRadius = UDim.new(0, 8)
	reset_corner.Parent = reset_button
	
	-- Create Close button
	local close_button = Instance.new("TextButton")
	close_button.Name = "CloseButton"
	close_button.Size = UDim2.new(0.45, 0, 1, 0)
	close_button.Position = UDim2.new(0.55, 0, 0, 0)
	close_button.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	close_button.Text = "Close"
	close_button.TextColor3 = Color3.fromRGB(255, 255, 255)
	close_button.TextSize = 20
	close_button.Font = Enum.Font.GothamBold
	close_button.Parent = button_container
	
	local close_corner = Instance.new("UICorner")
	close_corner.CornerRadius = UDim.new(0, 8)
	close_corner.Parent = close_button
	
	-- Button events
	reset_button.MouseButton1Click:Connect(function()
		-- Play button sound
		if sound_manager then
			sound_manager:play_sound_2d(123872698765939, {Volume = 0.5})
		end
		RemoteEvents.ResetGame:FireServer()
		self:hide()
	end)
	
	close_button.MouseButton1Click:Connect(function()
		-- Play button sound
		if sound_manager then
			sound_manager:play_sound_2d(123872698765939, {Volume = 0.5})
		end
		self:hide()
	end)
	
	-- Make responsive
	local ui_scale = Instance.new("UIScale")
	ui_scale.Parent = modal_gui
	
	-- Initially hidden
	modal_gui.Enabled = false
	
	-- Listen for completion event (after gate opens)
	RemoteEvents.GameComplete.OnClientEvent:Connect(function(completion_time)
		task.wait(2)
		self:show(completion_time)
	end)
	
	-- Listen for game reset event (when another player resets the game)
	RemoteEvents.GameReset.OnClientEvent:Connect(function()
		-- If modal is visible, just hide it (game was already reset by another player)
		if is_visible then
			self:hide()
		end
	end)
end

function CompletionModal:show(completion_time)
	if not modal_gui then
		return
	end
	
	is_visible = true
	modal_gui.Enabled = true
	
	-- Play completion sound
	if sound_manager then
		sound_manager:play_sound_2d(122635127122416, {Volume = 0.7})
	end
	
	-- Update time label
	local time_label = modal_gui.ModalFrame:FindFirstChild("TimeLabel")
	if time_label then
		local minutes = math.floor(completion_time / 60)
		local seconds = math.floor(completion_time % 60)
		time_label.Text = string.format("Completion Time: %02d:%02d", minutes, seconds)
	end
end

function CompletionModal:hide()
	if not modal_gui then
		return
	end
	
	is_visible = false
	modal_gui.Enabled = false
end

return CompletionModal

