-- ShardCollector: Handles shard collection detection and events
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local SoundManager = require(script.Parent.SoundManager)

local ShardCollector = {}
ShardCollector.__index = ShardCollector

local player = Players.LocalPlayer
local character = nil
local humanoid_root_part = nil
local touched_shards = {} -- Track which shards have been touched to prevent duplicate events
local sound_manager = nil -- SoundManager instance
local shard_connections = {} -- Track connections for cleanup: shard -> {touched_connection, proximity_connection}


function ShardCollector.new()
	local self = setmetatable({}, ShardCollector)
	return self
end

function ShardCollector:initialize()
	-- Get SoundManager instance
	sound_manager = _G.SoundManager or SoundManager.new()
	
	-- Wait for character
	if player.Character then
		self:setup_character(player.Character)
	end
	
	player.CharacterAdded:Connect(function(character)
		self:setup_character(character)
	end)
	
	-- Listen for shards
	self:setup_shard_detection()
	
	-- Listen for game reset event
	RemoteEvents.GameReset.OnClientEvent:Connect(function()
		-- Reset touched shards when game is reset
		touched_shards = {}
		
		-- Cleanup old connections
		for shard, connections in pairs(shard_connections) do
			if connections.touched_connection then
				connections.touched_connection:Disconnect()
			end
			if connections.proximity_connection then
				connections.proximity_connection:Disconnect()
			end
		end
		shard_connections = {}
		
		-- Note: setup_shard_detection already listens for Shards folder creation,
		-- so it will automatically reconnect when shards are respawned
	end)
end

function ShardCollector:setup_character(character_instance)
	character = character_instance
	humanoid_root_part = character:WaitForChild("HumanoidRootPart")
	touched_shards = {} -- Reset on respawn
end

function ShardCollector:setup_shard_detection()
	-- Wait for shards folder with retry logic
	local function try_connect_shards()
		local shards_folder = Workspace:FindFirstChild("Shards")
		if shards_folder then
			-- Ensure character is ready before connecting
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				self:connect_shards(shards_folder)
			else
				-- Retry after character loads
				spawn(function()
					if player.Character then
						player.Character:WaitForChild("HumanoidRootPart")
					end
					task.wait(0.5) -- Small delay to ensure everything is ready
					if shards_folder.Parent then -- Check if folder still exists
						self:connect_shards(shards_folder)
					end
				end)
			end
		end
	end
	
	-- Try immediately
	try_connect_shards()
	
	-- Also wait with timeout as fallback
	spawn(function()
		local shards_folder = Workspace:WaitForChild("Shards", 15)
		if shards_folder then
			-- Ensure character is ready
			if player.Character then
				player.Character:WaitForChild("HumanoidRootPart", 5)
			end
			task.wait(0.5) -- Small delay
			if shards_folder.Parent then
				self:connect_shards(shards_folder)
			end
		end
	end)
	
	-- Always listen for shards folder creation (handles game reset and late spawning)
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Shards" then
			-- Ensure character is ready before connecting
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				self:connect_shards(child)
			else
				-- Wait for character if not ready
				spawn(function()
					if player.Character then
						player.Character:WaitForChild("HumanoidRootPart", 5)
					end
					task.wait(0.5)
					if child.Parent then
						self:connect_shards(child)
					end
				end)
			end
		end
	end)
end

function ShardCollector:connect_shards(shards_folder)
	-- Reset touched shards when shards folder is recreated (game reset)
	touched_shards = {}
	
	-- Cleanup old connections for this folder's shards
	for shard, connections in pairs(shard_connections) do
		if not shard.Parent or shard.Parent ~= shards_folder then
			-- Shard no longer exists or belongs to different folder, cleanup
			if connections.touched_connection then
				connections.touched_connection:Disconnect()
			end
			if connections.proximity_connection then
				connections.proximity_connection:Disconnect()
			end
			shard_connections[shard] = nil
		end
	end
	
	-- Connect to existing shards
	for _, shard in ipairs(shards_folder:GetChildren()) do
		if shard:IsA("Part") then
			-- Only connect if not already connected
			if not shard_connections[shard] then
				self:connect_shard(shard)
			end
		else
			warn("[ShardCollector] Found non-Part child:", shard.Name, shard.ClassName)
		end
	end
	
	-- Connect to new shards
	shards_folder.ChildAdded:Connect(function(shard)
		if shard:IsA("Part") then
			-- Only connect if not already connected
			if not shard_connections[shard] then
				self:connect_shard(shard)
			end
		end
	end)
end

function ShardCollector:connect_shard(shard)
	-- Prevent duplicate connections
	if shard_connections[shard] then
		return
	end
	
	-- Ensure character is ready before connecting
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		-- Retry when character is ready
		spawn(function()
			if player.Character then
				player.Character:WaitForChild("HumanoidRootPart", 5)
			end
			task.wait(0.1)
			if shard.Parent and not shard_connections[shard] then
				self:connect_shard(shard)
			end
		end)
		return
	end
	
	-- Update humanoid_root_part reference
	if player.Character then
		humanoid_root_part = player.Character:FindFirstChild("HumanoidRootPart")
	end
	
	if not humanoid_root_part then
		return
	end
	
	-- Wait for ShardIndex to be created (handles replication delay after game reset)
	local shard_index_value = shard:WaitForChild("ShardIndex", 2)
	if not shard_index_value then
		warn("[ShardCollector] Shard missing ShardIndex after wait:", shard.Name)
		return
	end
	
	local shard_index = tonumber(shard_index_value.Value)
	if not shard_index then
		warn("[ShardCollector] Invalid shard index value:", shard_index_value.Value)
		return
	end
	
	-- Initialize connections table for this shard
	shard_connections[shard] = {}
	
	-- Use Touched event (primary method)
	local touched_connection = shard.Touched:Connect(function(hit)
		if not humanoid_root_part then
			return
		end
		
		-- Check if the hit part belongs to the player's character
		local hit_parent = hit.Parent
		if not hit_parent then
			return
		end
		
		-- Check if it's the player's character (more flexible check)
		local is_player_character = false
		if hit_parent == player.Character then
			is_player_character = true
		else
			-- Check if hit part is a descendant of player's character
			local player_character = player.Character
			if player_character and hit:IsDescendantOf(player_character) then
				is_player_character = true
			end
		end
		
		if not is_player_character then
			return
		end
		
		-- Prevent duplicate collection
		if touched_shards[shard_index] then
			return
		end
		
		touched_shards[shard_index] = true
		
		-- Play collection sound
		if sound_manager then
			sound_manager:play_sound_2d(136791667101651, {Volume = 0.6})
		end
		
		-- Send collection event to server
		RemoteEvents.CollectShard:FireServer(shard_index)
	end)
	
	-- Store touched connection
	shard_connections[shard].touched_connection = touched_connection
	
	-- Proximity detection as backup (check distance every frame)
	local proximity_connection
	proximity_connection = RunService.Heartbeat:Connect(function()
		-- Update humanoid_root_part reference in case character respawned
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			humanoid_root_part = player.Character:FindFirstChild("HumanoidRootPart")
		end
		
		if not shard.Parent or not humanoid_root_part then
			proximity_connection:Disconnect()
			-- Cleanup connections when shard is destroyed
			if shard_connections[shard] then
				if shard_connections[shard].touched_connection then
					shard_connections[shard].touched_connection:Disconnect()
				end
				shard_connections[shard] = nil
			end
			return
		end
		
		-- Check if already collected
		if touched_shards[shard_index] then
			proximity_connection:Disconnect()
			-- Cleanup connections when shard is collected
			if shard_connections[shard] then
				if shard_connections[shard].touched_connection then
					shard_connections[shard].touched_connection:Disconnect()
				end
				shard_connections[shard] = nil
			end
			return
		end
		
		-- Check distance to player
		local shard_position = shard.Position
		local player_position = humanoid_root_part.Position
		local distance = (shard_position - player_position).Magnitude
		
		local collection_radius = (shard.Size.Magnitude / 2) + 1.5
		
		if distance <= collection_radius then
			touched_shards[shard_index] = true
			proximity_connection:Disconnect()
			
			-- Play collection sound
			if sound_manager then
				sound_manager:play_sound_2d(136791667101651, {Volume = 0.6})
			end
			
			-- Send collection event to server
			RemoteEvents.CollectShard:FireServer(shard_index)
		end
	end)
	
	-- Store proximity connection
	shard_connections[shard].proximity_connection = proximity_connection
end

return ShardCollector