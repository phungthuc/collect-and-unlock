-- CountdownPopup: Shows countdown popup before gate opens
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local CountdownPopup = {}
CountdownPopup.__index = CountdownPopup

local player = Players.LocalPlayer
local player_gui = nil
local popup_gui = nil
local is_visible = false
local countdown_connection = nil

function CountdownPopup.new()
	local self = setmetatable({}, CountdownPopup)
	return self
end

function CountdownPopup:create()
	player_gui = player:WaitForChild("PlayerGui")
	
	-- Create ScreenGui for popup
	popup_gui = Instance.new("ScreenGui")
	popup_gui.Name = "CountdownPopup"
	popup_gui.ResetOnSpawn = false
	popup_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	popup_gui.DisplayOrder = 8
	popup_gui.Parent = player_gui
	
	-- Create popup frame
	local popup_frame = Instance.new("Frame")
	popup_frame.Name = "PopupFrame"
	popup_frame.Size = UDim2.new(0, 300, 0, 120)
	popup_frame.Position = UDim2.new(0.5, 0, 0.3, 0)
	popup_frame.AnchorPoint = Vector2.new(0.5, 0.5)
	popup_frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	popup_frame.BackgroundTransparency = 0.1
	popup_frame.BorderSizePixel = 0
	popup_frame.Parent = popup_gui
	
	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = popup_frame
	
	-- Add stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 0)
	stroke.Thickness = 3
	stroke.Parent = popup_frame
	
	-- Create text label
	local text_label = Instance.new("TextLabel")
	text_label.Name = "TextLabel"
	text_label.Size = UDim2.new(1, -40, 1, -40)
	text_label.Position = UDim2.new(0, 20, 0, 20)
	text_label.BackgroundTransparency = 1
	text_label.Text = "Gate opened in 3 seconds."
	text_label.TextColor3 = Color3.fromRGB(255, 255, 255)
	text_label.TextSize = 24
	text_label.Font = Enum.Font.GothamBold
	text_label.TextWrapped = true
	text_label.Parent = popup_frame
	
	-- Add text size constraint
	local text_constraint = Instance.new("UITextSizeConstraint")
	text_constraint.MaxTextSize = 28
	text_constraint.MinTextSize = 18
	text_constraint.Parent = text_label
	
	-- Make responsive
	local ui_scale = Instance.new("UIScale")
	ui_scale.Parent = popup_gui
	
	-- Initially hidden
	popup_gui.Enabled = false
end

function CountdownPopup:show(callback)
	if not popup_gui then
		return
	end
	
	if is_visible then
		return
	end
	
	is_visible = true
	popup_gui.Enabled = true
	
	local text_label = popup_gui.PopupFrame:FindFirstChild("TextLabel")
	if not text_label then
		return
	end
	
	-- Animate in
	local popup_frame = popup_gui.PopupFrame
	popup_frame.Size = UDim2.new(0, 0, 0, 0)
	local tween_in = TweenService:Create(
		popup_frame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = UDim2.new(0, 300, 0, 120)}
	)
	tween_in:Play()
	
	-- Start countdown from 3 to 0
	local count = 3
	text_label.Text = string.format("Gate opened in %d seconds.", count)
	
	-- Countdown loop
	countdown_connection = game:GetService("RunService").Heartbeat:Connect(function()
		-- This will be replaced by a proper countdown timer
	end)
	
	-- Use spawn for countdown
	spawn(function()
		for i = 3, 0, -1 do
			if not is_visible then
				break
			end
			
			text_label.Text = string.format("Gate opened in %d seconds.", i)
			
			-- Pulse animation
			local pulse_tween = TweenService:Create(
				text_label,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{TextSize = 28}
			)
			pulse_tween:Play()
			pulse_tween.Completed:Connect(function()
				local reset_tween = TweenService:Create(
					text_label,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{TextSize = 24}
				)
				reset_tween:Play()
			end)
			
			if i > 0 then
				task.wait(1)
			end
		end
		
		-- Countdown finished
		if is_visible then
			text_label.Text = "Gate opened!"
			
			-- Animate out
			local tween_out = TweenService:Create(
				popup_frame,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Size = UDim2.new(0, 0, 0, 0)}
			)
			tween_out:Play()
			tween_out.Completed:Connect(function()
				self:hide()
				if callback then
					callback()
				end
			end)
		end
	end)
end

function CountdownPopup:hide()
	if not popup_gui then
		return
	end
	
	is_visible = false
	popup_gui.Enabled = false
	
	if countdown_connection then
		countdown_connection:Disconnect()
		countdown_connection = nil
	end
end

return CountdownPopup

