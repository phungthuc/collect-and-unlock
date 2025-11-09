-- GateManager: Handles gate creation and opening animation
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local GateManager = {}
GateManager.__index = GateManager

local gate_model = nil
local gate_open = false

function GateManager.new()
	local self = setmetatable({}, GateManager)
	return self
end

function GateManager:create_gate()
	local gate_folder = Instance.new("Folder")
	gate_folder.Name = "Gate"
	gate_folder.Parent = Workspace
	
	-- Create gate frame (left side) - larger and more visible
	local left_frame = Instance.new("Part")
	left_frame.Name = "LeftFrame"
	left_frame.Size = Vector3.new(6, 40, 6)
	left_frame.Material = Enum.Material.Metal
	left_frame.Color = Config.GATE_COLOR
	left_frame.Anchored = true
	left_frame.Position = Config.GATE_POSITION + Vector3.new(-18, 0, 0)
	left_frame.Parent = gate_folder
	
	-- Create gate frame (right side)
	local right_frame = Instance.new("Part")
	right_frame.Name = "RightFrame"
	right_frame.Size = Vector3.new(6, 40, 6)
	right_frame.Material = Enum.Material.Metal
	right_frame.Color = Config.GATE_COLOR
	right_frame.Anchored = true
	right_frame.Position = Config.GATE_POSITION + Vector3.new(18, 0, 0)
	right_frame.Parent = gate_folder
	
	-- Create gate door (will move when opened) - larger
	local gate_door = Instance.new("Part")
	gate_door.Name = "GateDoor"
	gate_door.Size = Config.GATE_SIZE
	gate_door.Material = Enum.Material.Metal
	gate_door.Color = Color3.fromRGB(80, 80, 80) -- Slightly darker for contrast
	gate_door.Anchored = true
	gate_door.Position = Config.GATE_POSITION
	gate_door.Parent = gate_folder
	
	-- Add top frame for better visibility
	local top_frame = Instance.new("Part")
	top_frame.Name = "TopFrame"
	top_frame.Size = Vector3.new(36, 3, 6)
	top_frame.Material = Enum.Material.Metal
	top_frame.Color = Config.GATE_COLOR
	top_frame.Anchored = true
	top_frame.Position = Config.GATE_POSITION + Vector3.new(0, 21.5, 0)
	top_frame.Parent = gate_folder
	
	gate_model = gate_folder
	gate_open = false
end

function GateManager:open_gate()
	if gate_open then
		return
	end
	
	gate_open = true
	
	if gate_model then
		local gate_door = gate_model:FindFirstChild("GateDoor")
		if gate_door then
			-- Animate gate opening (move up)
			local tween_service = game:GetService("TweenService")
			local tween_info = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local goal = {Position = gate_door.Position + Vector3.new(0, 35, 0)}
			local tween = tween_service:Create(gate_door, tween_info, goal)
			tween:Play()
		end
	end
end

function GateManager:is_open()
	return gate_open
end

function GateManager:reset()
	gate_open = false
	
	if gate_model then
		local gate_door = gate_model:FindFirstChild("GateDoor")
		if gate_door then
			gate_door.Position = Config.GATE_POSITION
		end
	end
end

return GateManager

