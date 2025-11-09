-- ShardManager: Handles shard spawning, collection, and state management
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Config = require(ReplicatedStorage.Shared.Config)

local ShardManager = {}
ShardManager.__index = ShardManager

-- Track collected shards per player
local player_shard_counts = {}
local shard_states = {} -- Track which shards are collected (by index)
local shards = {} -- Store shard instances
local shard_base_positions = {} -- Store base positions (before bobbing) for accurate distance checking

function ShardManager.new()
	local self = setmetatable({}, ShardManager)

	-- Initialize shard states (all uncollected)
	for i = 1, Config.SHARD_COUNT do
		shard_states[i] = false
	end
	
	-- Initialize player counts
	for _, player in ipairs(game.Players:GetPlayers()) do
		player_shard_counts[player] = 0
	end
	
	-- Listen for new players
	game.Players.PlayerAdded:Connect(function(player)
		player_shard_counts[player] = 0
		-- Send current shard states to new player
		task.wait(0.5) -- Wait for client to load
		RemoteEvents.ShardStateUpdate:FireClient(player, shard_states, player_shard_counts[player])
	end)
	
	game.Players.PlayerRemoving:Connect(function(player)
		player_shard_counts[player] = nil
	end)
	
	return self
end

function ShardManager:spawn_shards()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if not baseplate then
		warn("[ShardManager] Baseplate not found!")
		return
	end
	
	
	local shards_folder = Instance.new("Folder")
	shards_folder.Name = "Shards"
	shards_folder.Parent = Workspace
	
    -- Spawn shards
	for i = 1, Config.SHARD_COUNT do
		local shard = Instance.new("Part")
		shard.Name = "Shard" .. i
		shard.Size = Config.SHARD_SIZE
		shard.Material = Config.SHARD_MATERIAL
		shard.Color = Config.SHARD_COLOR
		shard.Shape = Enum.PartType.Block
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanTouch = true -- Enable touch detection
		local base_position = Config.BASEPLATE_POSITION + Config.SHARD_SPAWN_POSITIONS[i]
		shard.Position = base_position
		
		-- Add ShardIndex BEFORE parenting to folder (ensures it replicates together)
		local string_value = Instance.new("StringValue")
		string_value.Name = "ShardIndex"
		string_value.Value = tostring(i)
		string_value.Parent = shard
		
		-- Now parent to folder (ShardIndex will replicate with shard)
		shard.Parent = shards_folder
		
		-- Store base position for accurate distance checking (ignoring bobbing effects)
		shard_base_positions[i] = base_position
		
		shards[i] = shard
	end
end

function ShardManager:collect_shard(player, shard_index)
	-- Validate shard index
	if not shard_index then
		warn(string.format("[ShardManager] Shard index is nil!"))
		return false
	end
	
	if type(shard_index) == "string" then
		shard_index = tonumber(shard_index)
	end
	
	if not shard_index or shard_index < 1 or shard_index > Config.SHARD_COUNT then
		warn(string.format("[ShardManager] Invalid shard index: %s (range: 1-%d)", tostring(shard_index), Config.SHARD_COUNT))
		return false
	end
	
	-- Check if already collected
	if shard_states[shard_index] then
		return false
	end
	
	-- Validate player has touched the shard (basic anti-cheat)
	local shard = shards[shard_index]
	if not shard then
		warn(string.format("[ShardManager] Shard %d not found in shards table!", shard_index))
		return false
	end
	
	if not shard.Parent then
		warn(string.format("[ShardManager] Shard %d has no parent (already destroyed?)", shard_index))
		return false
	end
	
	-- Check distance (anti-cheat: player must be near shard)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	
	local player_position = character.HumanoidRootPart.Position
	-- Use base position instead of current position to account for bobbing effects
	local shard_base_position = shard_base_positions[shard_index]
	local shard_current_position = shard.Position
	
	-- Check distance to both base and current position (whichever is closer)
	local distance_to_base = (player_position - shard_base_position).Magnitude
	local distance_to_current = (player_position - shard_current_position).Magnitude
	local distance = math.min(distance_to_base, distance_to_current)
	
	-- Increased max collection distance to account for bobbing effects, client-side proximity detection, and network latency
	-- Client uses collection_radius ~9 units, but network latency and position sync can cause larger distances
	-- Using 50 units to be safe while still preventing obvious cheating
	local max_collection_distance = 50
	
	if distance > max_collection_distance then
		warn(string.format("[ShardManager] Player %s tried to collect shard %d from too far away (distance to base: %.2f, to current: %.2f, min: %.2f, max: %.2f)", 
			player.Name, shard_index, distance_to_base, distance_to_current, distance, max_collection_distance))
		return false
	end
	
	-- Mark as collected
	shard_states[shard_index] = true
	
	-- Update player count
	if not player_shard_counts[player] then
		player_shard_counts[player] = 0
	end
	player_shard_counts[player] = player_shard_counts[player] + 1
	
	-- Remove shard from workspace
	shard:Destroy()
	
	-- Notify all clients with individual player counts
	for target_player, count in pairs(player_shard_counts) do
		if target_player and target_player.Parent then
			RemoteEvents.ShardStateUpdate:FireClient(target_player, shard_states, count)
		end
	end
	
	return true
end

function ShardManager:get_player_count(player)
	return player_shard_counts[player] or 0
end

function ShardManager:get_all_collected()
	local all_collected = true
	for i = 1, Config.SHARD_COUNT do
		if not shard_states[i] then
			all_collected = false
			break
		end
	end
	return all_collected
end

function ShardManager:reset()
	-- Reset all shard states
	for i = 1, Config.SHARD_COUNT do
		shard_states[i] = false
	end
	
	-- Reset player counts
	for player, _ in pairs(player_shard_counts) do
		player_shard_counts[player] = 0
	end
	
	-- Remove old shards
	local shards_folder = Workspace:FindFirstChild("Shards")
	if shards_folder then
		shards_folder:Destroy()
	end
	
	-- Clear shards table and base positions
	shards = {}
	shard_base_positions = {}
	
	-- Respawn shards
	self:spawn_shards()
	
	-- Notify all clients with individual player counts
	for target_player, count in pairs(player_shard_counts) do
		if target_player and target_player.Parent then
			RemoteEvents.ShardStateUpdate:FireClient(target_player, shard_states, count or 0)
		end
	end
end

return ShardManager