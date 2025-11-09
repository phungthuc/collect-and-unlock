-- ShardEffects: Handles visual effects for shards (bobbing and rotation)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local ShardEffects = {}
ShardEffects.__index = ShardEffects

local shard_connections = {}

function ShardEffects.new()
	local self = setmetatable({}, ShardEffects)
	return self
end

function ShardEffects:start_effects()
	-- Wait for shards folder to be created
	local shards_folder = Workspace:WaitForChild("Shards", 10)
	if shards_folder then
		self:connect_to_shards_folder(shards_folder)
	end
	
	-- Always listen for shards folder creation (handles game reset)
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Shards" then
			self:connect_to_shards_folder(child)
		end
	end)
	
	-- Listen for game reset to restart effects
	RemoteEvents.GameReset.OnClientEvent:Connect(function()
		-- Stop all current effects
		self:stop_effects()
		
		-- Wait a bit for new shards to be created, then restart
		spawn(function()
			task.wait(0.5)
			local shards_folder = Workspace:FindFirstChild("Shards")
			if shards_folder then
				self:connect_to_shards_folder(shards_folder)
			end
		end)
	end)
end

function ShardEffects:connect_to_shards_folder(shards_folder)
	-- Connect to all existing shards
	for _, shard in ipairs(shards_folder:GetChildren()) do
		if shard:IsA("Part") then
			self:add_shard_effect(shard)
		end
	end
	
	-- Listen for new shards
	shards_folder.ChildAdded:Connect(function(shard)
		if shard:IsA("Part") then
			self:add_shard_effect(shard)
		end
	end)
end

function ShardEffects:add_shard_effect(shard)
	-- Skip if already has effect
	if shard_connections[shard] then
		return
	end
	
	-- Store base CFrame (position + rotation)
	local base_cframe = shard.CFrame
	local base_position = base_cframe.Position
	local start_time = tick()
	local rotation_angle = 0  -- Track total rotation
	
	-- Create connection for bobbing and rotation
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not shard.Parent then
			connection:Disconnect()
			shard_connections[shard] = nil
			return
		end
		
		local current_time = tick()
		local elapsed = current_time - start_time
		
		local bob_offset = math.sin(elapsed * Config.SHARD_BOBBING_SPEED) * Config.SHARD_BOBBING_AMPLITUDE
		local new_position = base_position + Vector3.new(0, bob_offset, 0)
		
		rotation_angle = rotation_angle + Config.SHARD_ROTATION_SPEED * (1/60) -- Assume 60 FPS
		
		shard.CFrame = CFrame.new(new_position) * CFrame.Angles(0, math.rad(rotation_angle), 0)
	end)
	
	shard_connections[shard] = connection
end

function ShardEffects:stop_effects()
	for shard, connection in pairs(shard_connections) do
		if connection then
			connection:Disconnect()
		end
	end
	shard_connections = {}
end

return ShardEffects

