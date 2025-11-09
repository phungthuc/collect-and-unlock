-- Main client initialization
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShardEffects = require(script.ShardEffects)
local ShardCollector = require(script.ShardCollector)
local PuzzleController = require(script.PuzzleController)
local HUD = require(script.HUD)
local CompletionModal = require(script.CompletionModal)
local CountdownPopup = require(script.CountdownPopup)
local SoundManager = require(script.SoundManager)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Initialize modules
local shard_effects = ShardEffects.new()
local shard_collector = ShardCollector.new()
local puzzle_controller = PuzzleController.new()
local hud = HUD.new()
local completion_modal = CompletionModal.new()
local countdown_popup = CountdownPopup.new()
local sound_manager = SoundManager.new()

-- Export sound_manager globally for easy access (optional)
_G.SoundManager = sound_manager

-- Wait for player and services to fully load
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Wait for PlayerGui to be ready (helps avoid CoreGui errors)
if player then
	player:WaitForChild("PlayerGui", 10)
	-- Additional wait to ensure all core scripts are loaded
	task.wait(0.5)
end

-- Start shard effects
shard_effects:start_effects()

-- Initialize shard collector
shard_collector:initialize()

-- Initialize puzzle controller
puzzle_controller:initialize()

-- Create HUD (with error handling)
local success, err = pcall(function()
	hud:create()
end)
if not success then
	warn("[init.client] Error creating HUD:", err)
end

-- Create completion modal (with error handling)
success, err = pcall(function()
	completion_modal:create()
end)
if not success then
	warn("[init.client] Error creating completion modal:", err)
end

-- Create countdown popup (with error handling)
success, err = pcall(function()
	countdown_popup:create()
end)
if not success then
	warn("[init.client] Error creating countdown popup:", err)
end

-- Listen for puzzle solved to show countdown
RemoteEvents.PuzzleSolved.OnClientEvent:Connect(function(completion_time)
	-- Show countdown popup
	countdown_popup:show(function()
		-- After countdown, request gate to open
		RemoteEvents.OpenGateNow:FireServer()
		-- Play gate opening sound
		if sound_manager then
			sound_manager:play_sound_2d(74860753060159, {Volume = 0.7})
		end
	end)
end)

-- Listen for game reset to hide countdown
RemoteEvents.GameReset.OnClientEvent:Connect(function()
	countdown_popup:hide()
end)

print("Client initialized!")
