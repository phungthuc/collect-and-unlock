-- PuzzleController: Handles puzzle interaction on client
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
-- GuiService removed as it's not used

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local SoundManager = require(script.Parent.SoundManager)

local PuzzleController = {}
PuzzleController.__index = PuzzleController

local puzzle_active = false
local puzzle_solved = false -- Track if puzzle is solved on client
local puzzle_gui = nil
local player = Players.LocalPlayer
local keyboard_connection = nil
local start_button_connection = nil
local proximity_connection = nil
local ring_buttons = {} -- Store ring buttons to enable/disable them
local sound_manager = nil -- SoundManager instance

function PuzzleController.new()
	local self = setmetatable({}, PuzzleController)
	return self
end

function PuzzleController:connect_start_button()
	-- Get puzzle folder
	local puzzle_folder = Workspace:FindFirstChild("Puzzle")
	if not puzzle_folder then
		return
	end
	
	-- Function to connect to start button when it's created
	local function connect_start_button_internal()
		local start_button = puzzle_folder:FindFirstChild("StartButton")
		if start_button and not start_button_connection then
			start_button.CanTouch = true

			-- Use proximity detection as backup for start button
			local RunService = game:GetService("RunService")
			
			-- Store reference to start_button for closure
			local button_ref = start_button
			
			local start_button_touched = false
			start_button_connection = start_button.Touched:Connect(function(hit)
				if start_button_touched or puzzle_active then
					return
				end
				
				local character = hit.Parent
				
				-- Check if hit part belongs to player's character
				if character == player.Character or (player.Character and hit:IsDescendantOf(player.Character)) then
					start_button_touched = true
					-- Play button sound
					if sound_manager then
						sound_manager:play_sound_2d(123872698765939, {Volume = 0.5})
					end
					RemoteEvents.PuzzleInteract:FireServer("start", 0)
				end
			end)
			
			-- Proximity detection for start button (runs continuously)
			local start_button_activated = false
			local last_log_time = 0
			proximity_connection = RunService.Heartbeat:Connect(function()
				if puzzle_active or start_button_activated or not button_ref.Parent then
					if proximity_connection then
						proximity_connection:Disconnect()
						proximity_connection = nil
					end
					return
				end
				
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					local distance = (button_ref.Position - player.Character.HumanoidRootPart.Position).Magnitude
					local current_time = tick()
					
					-- Log distance every 2 seconds
					if current_time - last_log_time > 2 then
						last_log_time = current_time
					end
					
					if distance <= 10 then -- Increased threshold to 10 units
						start_button_activated = true
						if proximity_connection then
							proximity_connection:Disconnect()
							proximity_connection = nil
						end
						-- Play button sound
						if sound_manager then
							sound_manager:play_sound_2d(123872698765939, {Volume = 0.5})
						end
						RemoteEvents.PuzzleInteract:FireServer("start", 0)
					end
				end
			end)
		end
	end
	
	-- Try to connect immediately (in case button already exists)
	connect_start_button_internal()
	
	-- Listen for start button being added to puzzle folder (only if not already listening)
	-- Note: This connection persists, so we don't need to recreate it
	if not puzzle_folder:GetAttribute("StartButtonListenerAdded") then
		puzzle_folder:SetAttribute("StartButtonListenerAdded", true)
		puzzle_folder.ChildAdded:Connect(function(child)
			if child.Name == "StartButton" then
				connect_start_button_internal()
			end
		end)
	end
end

function PuzzleController:initialize()
	-- Get SoundManager instance
	sound_manager = _G.SoundManager or SoundManager.new()
	
	-- Wait for puzzle to be created
	local puzzle_folder = Workspace:WaitForChild("Puzzle", 10)
	if not puzzle_folder then
		warn("[PuzzleController] Puzzle folder not found after 10 seconds!")
		-- Try to find it again
		puzzle_folder = Workspace:FindFirstChild("Puzzle")
		if not puzzle_folder then
			warn("[PuzzleController] Puzzle folder still not found!")
			return
		end
	end
	
	-- Connect to start button
	self:connect_start_button()
	
	-- Touched event removed - rings can only be rotated via UI buttons or keyboard
	-- No need to connect Touched event or ClickDetector
	
	-- Listen for puzzle state updates
	RemoteEvents.PuzzleStateUpdate.OnClientEvent:Connect(function(active, angles)
		local old_active = puzzle_active
		puzzle_active = active
		
		-- Check if puzzle was solved (active becomes false after solving)
		if old_active and not active then
			puzzle_solved = true
		end
		
		if active and not old_active then
			-- Reset solved flag when puzzle becomes active again
			puzzle_solved = false
			-- Create puzzle control GUI
			self:create_puzzle_gui()
			-- Setup keyboard controls
			self:setup_keyboard_controls()
			-- Enable buttons
			self:enable_ring_buttons()
		elseif not active and old_active then
			-- Disable buttons when puzzle is not active or solved
			self:disable_ring_buttons()
			-- Hide puzzle GUI when puzzle is not active
			if puzzle_gui then
				puzzle_gui.Enabled = false
			end
			-- Disconnect keyboard controls
			if keyboard_connection then
				keyboard_connection:Disconnect()
				keyboard_connection = nil
			end
		end
	end)
	
	-- Periodic check to remind player
	spawn(function()
		task.wait(5)
		if not puzzle_active then
		end
	end)
	
	-- Listen for game reset event
	RemoteEvents.GameReset.OnClientEvent:Connect(function()
		-- Reset puzzle state when game is reset
		puzzle_active = false
		puzzle_solved = false
		
		-- Disable buttons
		self:disable_ring_buttons()
		
		-- Hide puzzle GUI
		if puzzle_gui then
			puzzle_gui.Enabled = false
		end
		
		-- Disconnect keyboard controls
		if keyboard_connection then
			keyboard_connection:Disconnect()
			keyboard_connection = nil
		end
		
		-- Reset start button connection to allow reconnection
		if start_button_connection then
			start_button_connection:Disconnect()
			start_button_connection = nil
		end
		if proximity_connection then
			proximity_connection:Disconnect()
			proximity_connection = nil
		end
		
		-- Reconnect to start button after a delay (when puzzle elements are recreated)
		spawn(function()
			task.wait(0.5)
			-- Reconnect using the same logic
			self:connect_start_button()
		end)
	end)
end

function PuzzleController:create_puzzle_gui()
	-- Remove existing GUI if any
	if puzzle_gui then
		puzzle_gui:Destroy()
	end
	
	local player_gui = player:WaitForChild("PlayerGui")
	
	puzzle_gui = Instance.new("ScreenGui")
	puzzle_gui.Name = "PuzzleControls"
	puzzle_gui.ResetOnSpawn = false
	puzzle_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	puzzle_gui.DisplayOrder = 5
	puzzle_gui.Parent = player_gui
	
	-- Main frame
	local main_frame = Instance.new("Frame")
	main_frame.Name = "MainFrame"
	main_frame.Size = UDim2.new(0, 275, 0, 200)
	main_frame.Position = UDim2.new(1, -295, 0.5, -100)
	main_frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	main_frame.BackgroundTransparency = 0.2
	main_frame.BorderSizePixel = 0
	main_frame.Parent = puzzle_gui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = main_frame
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "Puzzle Controls"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Parent = main_frame
	
	-- Instructions
	local instructions = Instance.new("TextLabel")
	instructions.Name = "Instructions"
	instructions.Size = UDim2.new(1, -20, 0, 40)
	instructions.Position = UDim2.new(0, 10, 0, 40)
	instructions.BackgroundTransparency = 1
	instructions.Text = "Press 1/2/3 or click buttons to rotate rings"
	instructions.TextColor3 = Color3.fromRGB(200, 200, 200)
	instructions.TextSize = 14
	instructions.TextWrapped = true
	instructions.Font = Enum.Font.Gotham
	instructions.Parent = main_frame
	
	-- Button container
	local button_container = Instance.new("Frame")
	button_container.Name = "ButtonContainer"
	button_container.Size = UDim2.new(1, -20, 0, 100)
	button_container.Position = UDim2.new(0, 10, 0, 90)
	button_container.BackgroundTransparency = 1
	button_container.Parent = main_frame
	
	-- Create buttons for each ring
	for i = 1, 3 do
		local button = Instance.new("TextButton")
		button.Name = "Ring" .. i .. "Button"
		button.Size = UDim2.new(0.3, -5, 1, 0)
		button.Position = UDim2.new((i - 1) * 0.33, 0, 0, 0)
		button.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
		button.Text = "Ring " .. i .. "\n(Key " .. i .. ")"
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextSize = 16
		button.Font = Enum.Font.GothamBold
		button.Parent = button_container
		
		local button_corner = Instance.new("UICorner")
		button_corner.CornerRadius = UDim.new(0, 8)
		button_corner.Parent = button
		
		-- Store button reference
		ring_buttons[i] = button
		
		-- Button click event
		button.MouseButton1Click:Connect(function()
			if puzzle_active and not puzzle_solved then
				-- Play button sound
				if sound_manager then
					sound_manager:play_sound_2d(123872698765939, {Volume = 0.5})
				end
				RemoteEvents.PuzzleInteract:FireServer("rotate", i)
			end
		end)
		
		-- Button hover effect
		button.MouseEnter:Connect(function()
			button.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
		end)
	end
	
	-- Make responsive
	local ui_scale = Instance.new("UIScale")
	ui_scale.Parent = puzzle_gui
end

function PuzzleController:setup_keyboard_controls()
	-- Disconnect existing connection if any
	if keyboard_connection then
		keyboard_connection:Disconnect()
		keyboard_connection = nil
	end
	
	-- Keyboard input for rotating rings
	keyboard_connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		
		if not puzzle_active or puzzle_solved then
			return
		end
		
		-- Check for number keys 1, 2, 3
		if input.KeyCode == Enum.KeyCode.One then
			-- Play button sound
			if sound_manager then
				sound_manager:play_sound_2d(123872698765939, {Volume = 0.5})
			end
			RemoteEvents.PuzzleInteract:FireServer("rotate", 1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			-- Play button sound
			if sound_manager then
				sound_manager:play_sound_2d(123872698765939, {Volume = 0.5})
			end
			RemoteEvents.PuzzleInteract:FireServer("rotate", 2)
		elseif input.KeyCode == Enum.KeyCode.Three then
			-- Play button sound
			if sound_manager then
				sound_manager:play_sound_2d(123872698765939, {Volume = 0.5})
			end
			RemoteEvents.PuzzleInteract:FireServer("rotate", 3)
		end
	end)
end

function PuzzleController:disable_ring_buttons()
	-- Disable all ring buttons
	for i = 1, 3 do
		if ring_buttons[i] then
			ring_buttons[i].Active = false
			ring_buttons[i].BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- Gray out
		end
	end
end

function PuzzleController:enable_ring_buttons()
	-- Enable all ring buttons
	for i = 1, 3 do
		if ring_buttons[i] then
			ring_buttons[i].Active = true
			ring_buttons[i].BackgroundColor3 = Color3.fromRGB(255, 150, 0) -- Original color
		end
	end
end

return PuzzleController

