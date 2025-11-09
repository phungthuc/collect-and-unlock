-- GameManager: Main game logic coordinator
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for Shared folder and modules
local shared_folder = ReplicatedStorage:WaitForChild("Shared", 10)
if not shared_folder then
	error("Shared folder not found in ReplicatedStorage!")
end

local remote_events_module = shared_folder:WaitForChild("RemoteEvents", 10)
local config_module = shared_folder:WaitForChild("Config", 10)

if not remote_events_module or not config_module then
	error("Required modules not found in Shared folder!")
end

local RemoteEvents = require(remote_events_module)
local Config = require(config_module)
local ShardManager = require(script.Parent.ShardManager)
local PuzzleManager = require(script.Parent.PuzzleManager)
local GateManager = require(script.Parent.GateManager)

-- GameManager class implementation
local GameManager = {}
GameManager.__index = GameManager

local shard_manager = nil
local puzzle_manager = nil
local gate_manager = nil
local game_started = false
local timer_started = false
local start_time = 0
local game_completed = false -- Track if game has been completed
local game_reset_in_progress = false -- Track if reset is in progress

function GameManager.new()
	local self = setmetatable({}, GameManager)
	
	shard_manager = ShardManager.new()
	puzzle_manager = PuzzleManager.new()
	gate_manager = GateManager.new()
	
	-- Initialize game
	self:initialize_game()
	
	-- Setup RemoteEvent handlers
	self:setup_handlers()
	
	return self
end

function GameManager:initialize_game()
	
	-- -- Create gate
	gate_manager:create_gate()
	
	-- -- Create puzzle
	puzzle_manager:create_puzzle()
	
	-- Spawn shards
	shard_manager:spawn_shards()
	
	game_started = true
end

function GameManager:setup_handlers()
	-- Handle shard collection
	RemoteEvents.CollectShard.OnServerEvent:Connect(function(player, shard_index)
		if not game_started then
			return
		end
		
		local success = shard_manager:collect_shard(player, shard_index)
		
		if success then
			local count = shard_manager:get_player_count(player)
			
			-- Start timer on first shard collection
			if not timer_started then
				timer_started = true
				start_time = tick()
				RemoteEvents.TimerStart:FireAllClients(start_time)
			end
			
			-- Check if all shards collected
			if shard_manager:get_all_collected() then
				RemoteEvents.AllShardsCollected:FireAllClients()
				-- Show start button when all shards are collected
				puzzle_manager:show_start_button()
			end
		end
	end)
	
	-- Handle puzzle start
	RemoteEvents.PuzzleInteract.OnServerEvent:Connect(function(player, interaction_type, ring_index)
		
		if not game_started then
			warn("[GameManager] Game not started yet!")
			return
		end
		
		if interaction_type == "start" then
			puzzle_manager:start_puzzle()
		elseif interaction_type == "rotate" then
			puzzle_manager:rotate_ring(ring_index)
		else
			warn(string.format("[GameManager] Unknown interaction type: %s", tostring(interaction_type)))
		end
	end)
	
	-- Handle gate opening when puzzle is solved
	RemoteEvents.GateOpen.OnServerEvent:Connect(function()
		-- This shouldn't be called from client, but handle it anyway
	end)
	
	-- Listen for puzzle completion
	spawn(function()
		while true do
			task.wait(0.5)
			if puzzle_manager:is_solved() and not gate_manager:is_open() and not game_completed then
				game_completed = true
				local completion_time = timer_started and (tick() - start_time) or 0
				-- Fire PuzzleSolved event to trigger countdown on client
				RemoteEvents.PuzzleSolved:FireAllClients(completion_time)
			end
		end
	end)
	
	-- Handle gate opening request from client (after countdown)
	RemoteEvents.OpenGateNow.OnServerEvent:Connect(function(player)
		if puzzle_manager:is_solved() and not gate_manager:is_open() then
			gate_manager:open_gate()
			local completion_time = timer_started and (tick() - start_time) or 0
			-- Fire GameComplete after gate opens
			task.wait(0.5) -- Small delay to let gate animation start
			RemoteEvents.GameComplete:FireAllClients(completion_time)
		end
	end)
	
	-- Handle game reset
	RemoteEvents.ResetGame.OnServerEvent:Connect(function(player)
		if not game_started then
			return
		end
		
		-- Only reset if game was completed and not already resetting
		if game_completed and not game_reset_in_progress then
			game_reset_in_progress = true
			self:reset_game()
			-- Notify all clients that game was reset
			RemoteEvents.GameReset:FireAllClients()
			game_reset_in_progress = false
		else
			-- Game already reset or not completed, just acknowledge to this player
			-- They should just close their UI
		end
	end)
end

function GameManager:reset_game()
	-- Reset completion flag
	game_completed = false
	
	-- Reset all managers
	shard_manager:reset()
	puzzle_manager:reset()
	gate_manager:reset()
	
	-- Reset timer
	timer_started = false
	start_time = 0
	
	-- Notify clients to reset timer
	RemoteEvents.TimerStart:FireAllClients(0)
end

return GameManager
