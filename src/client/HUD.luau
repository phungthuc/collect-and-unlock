-- HUD: Manages game HUD (shard counter and timer)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Config = require(ReplicatedStorage.Shared.Config)

local HUD = {}
HUD.__index = HUD

local player = Players.LocalPlayer
local player_gui = nil
local screen_gui = nil
local shard_label = nil
local timer_label = nil
local timer_start_time = 0
local timer_running = false

function HUD.new()
	local self = setmetatable({}, HUD)
	return self
end

function HUD:create()
	-- Create ScreenGui
	player_gui = player:WaitForChild("PlayerGui")
	
	screen_gui = Instance.new("ScreenGui")
	screen_gui.Name = "GameHUD"
	screen_gui.ResetOnSpawn = false
	screen_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen_gui.Parent = player_gui
	
	-- Create main frame (top right + responsive)
	local main_frame = Instance.new("Frame")
	main_frame.Name = "MainFrame"
	main_frame.Size = UDim2.new(0.15, 0, 0.1, 0)      -- 15% width, 10% height: auto resize
	main_frame.AnchorPoint = Vector2.new(0, 0)         -- Anchor at left top
	main_frame.Position = UDim2.new(0, 10, 0, 10)     -- X=10px, Y=10px
	main_frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	main_frame.BackgroundTransparency = 0.3
	main_frame.BorderSizePixel = 0

	local size_constraint = Instance.new("UISizeConstraint")
	size_constraint.MinSize = Vector2.new(75, 25)
	size_constraint.Parent = main_frame

	-- Add UICorner to main frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = main_frame

	-- Add UIPadding to main frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.1, 0)      -- 10% padding top
	padding.PaddingBottom = UDim.new(0.1, 0)   -- 10% padding bottom
	padding.PaddingLeft = UDim.new(0.05, 0)    -- 5% padding left
	padding.PaddingRight = UDim.new(0.05, 0)   -- 5% padding right
	padding.Parent = main_frame

	-- Add main frame to screen gui
	main_frame.Parent = screen_gui

	-- Create shard counter label
	shard_label = Instance.new("TextLabel")
	shard_label.Name = "ShardLabel"
	shard_label.Size = UDim2.new(1, 0, 0.45, 0)        -- 100% width, 45% height (Scale only)
	shard_label.Position = UDim2.new(0, 0, 0, 0)       -- Top position (Scale only)
	shard_label.BackgroundTransparency = 1
	shard_label.Text = "Shards: 0/" .. Config.SHARD_COUNT
	shard_label.TextColor3 = Color3.fromRGB(255, 255, 255)
	shard_label.TextScaled = true                      -- Auto scale text
	shard_label.TextXAlignment = Enum.TextXAlignment.Left
	shard_label.Font = Enum.Font.GothamBold
	shard_label.Parent = main_frame
	
	-- Add UITextSizeConstraint to shard label
	local shardTextConstraint = Instance.new("UITextSizeConstraint")
	shardTextConstraint.MinTextSize = 10              -- Minimum 10px
	shardTextConstraint.MaxTextSize = 28              -- Maximum 28px
	shardTextConstraint.Parent = shard_label

	-- Create timer label
	timer_label = Instance.new("TextLabel")
	timer_label.Name = "TimerLabel"
	timer_label.Size = UDim2.new(1, 0, 0.45, 0)       -- 100% width, 45% height (Scale only)
	timer_label.Position = UDim2.new(0, 0, 0.55, 0)   -- Start at 55% from top (Scale only)
	timer_label.BackgroundTransparency = 1
	timer_label.Text = "Time: 00:00"
	timer_label.TextColor3 = Color3.fromRGB(255, 255, 255)
	timer_label.TextScaled = true                     -- Auto scale text
	timer_label.TextXAlignment = Enum.TextXAlignment.Left
	timer_label.Font = Enum.Font.GothamBold
	timer_label.Parent = main_frame

	local timerTextConstraint = Instance.new("UITextSizeConstraint")
	timerTextConstraint.MinTextSize = 10
	timerTextConstraint.MaxTextSize = 28
	timerTextConstraint.Parent = timer_label
	
	-- Make responsive
	local ui_scale = Instance.new("UIScale")
	ui_scale.Parent = screen_gui
	
	-- Listen for updates
	self:setup_listeners()
end

function HUD:setup_listeners()
	-- Listen for shard state updates
	RemoteEvents.ShardStateUpdate.OnClientEvent:Connect(function(shard_states, player_count)
		self:update_shard_count(player_count)
	end)
	
	-- Listen for timer start
	RemoteEvents.TimerStart.OnClientEvent:Connect(function(start_time_value)
		if start_time_value > 0 then
			timer_start_time = start_time_value
			timer_running = true
			self:start_timer()
		else
			-- Reset timer
			timer_running = false
			timer_start_time = 0
			if timer_label then
				timer_label.Text = "Time: 00:00"
			end
		end
	end)
	
	-- Listen for all shards collected
	RemoteEvents.AllShardsCollected.OnClientEvent:Connect(function()
		self:show_all_shards_collected_message()
	end)
end

function HUD:show_all_shards_collected_message()
	-- Create notification message
	if not screen_gui then
		return
	end
	
	-- Remove existing notification if any
	local existing_notification = screen_gui:FindFirstChild("AllShardsNotification")
	if existing_notification then
		existing_notification:Destroy()
	end
	
	local notification = Instance.new("Frame")
	notification.Name = "AllShardsNotification"
	notification.Size = UDim2.new(0.9, 0, 0.1, 0)
	notification.Position = UDim2.new(0.5, 0, 0.5, 0)
	notification.AnchorPoint = Vector2.new(0.5, 0.5)
	notification.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
	notification.BackgroundTransparency = 0.2
	notification.BorderSizePixel = 0
	notification.Parent = screen_gui
	
	local size_constraint = Instance.new("UISizeConstraint")
	size_constraint.MaxSize = Vector2.new(600, 100)  -- Maximum: 600x100 pixels
	size_constraint.Parent = notification
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = notification
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, -20)
	label.Position = UDim2.new(0, 10, 0, 10)
	label.BackgroundTransparency = 1
	label.Text = "All Shards Collected!\nGo to the puzzle at z=60 to continue!"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 20
	label.Font = Enum.Font.GothamBold
	label.TextWrapped = true
	label.Parent = notification
	
	-- Animate in
	notification.Size = UDim2.new(0, 0, 0, 0)
	local tween_service = game:GetService("TweenService")
	local tween_info = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local goal = {Size = UDim2.new(0, 400, 0, 100)}
	local tween = tween_service:Create(notification, tween_info, goal)
	tween:Play()
	
	-- Auto-hide after 5 seconds (use spawn to avoid blocking)
	spawn(function()
		task.wait(5)
		
		-- Animate out
		local tween_out = tween_service:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
		tween_out:Play()
		tween_out.Completed:Connect(function()
			notification:Destroy()
		end)
	end)
end

function HUD:update_shard_count(count)
	if shard_label then
		shard_label.Text = "Shards: " .. (count or 0) .. "/" .. Config.SHARD_COUNT
	end
end

function HUD:start_timer()
	if not timer_running then
		return
	end
	
	-- Update timer every frame
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		if not timer_running then
			connection:Disconnect()
			return
		end
		
		local elapsed = tick() - timer_start_time
		local minutes = math.floor(elapsed / 60)
		local seconds = math.floor(elapsed % 60)
		
		if timer_label then
			timer_label.Text = string.format("Time: %02d:%02d", minutes, seconds)
		end
	end)
end

function HUD:stop_timer()
	timer_running = false
end

function HUD:get_elapsed_time()
	if timer_running and timer_start_time > 0 then
		return tick() - timer_start_time
	end
	return 0
end

return HUD

