-- SoundManager: Handles sound effect playback with ID
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundManager = {}
SoundManager.__index = SoundManager

local player = Players.LocalPlayer
local player_gui = player:WaitForChild("PlayerGui")

-- Sound pool for reusing Sound objects (performance optimization)
local sound_pool = {}
local active_sounds = {} -- Track active sounds for cleanup

-- Default sound properties
local DEFAULT_VOLUME = 0.5
local DEFAULT_PITCH = 1.0
local MAX_POOL_SIZE = 10 -- Maximum number of sounds in pool

function SoundManager.new()
	local self = setmetatable({}, SoundManager)
	return self
end

-- Get a Sound object from pool or create new one
local function get_sound_object()
	local sound = table.remove(sound_pool)
	if not sound then
		sound = Instance.new("Sound")
		sound.Volume = DEFAULT_VOLUME
		sound.Pitch = DEFAULT_PITCH
	end
	return sound
end

-- Return Sound object to pool for reuse
local function return_sound_to_pool(sound)
	if #sound_pool < MAX_POOL_SIZE then
		-- Clean up sound
		sound:Stop()
		sound.SoundId = ""
		sound.Volume = DEFAULT_VOLUME
		sound.Pitch = DEFAULT_PITCH
		sound.Looped = false
		sound.TimePosition = 0
		
		-- Remove from active sounds
		active_sounds[sound] = nil
		
		-- Note: Connections will be automatically cleaned up when sound is reused
		-- No need to manually disconnect them
		
		table.insert(sound_pool, sound)
	else
		-- Pool is full, destroy the sound
		sound:Destroy()
	end
end

-- Play a 2D sound (UI sound, plays from ScreenGui)
function SoundManager:play_sound_2d(sound_id, options)
	options = options or {}
	
	local sound = get_sound_object()
	sound.SoundId = "rbxassetid://" .. tostring(sound_id)
	sound.Volume = options.Volume or DEFAULT_VOLUME
	sound.Pitch = options.Pitch or DEFAULT_PITCH
	sound.Looped = options.Looped or false
	
	-- Parent to a ScreenGui for 2D sound
	local screen_gui = player_gui:FindFirstChild("SoundManagerGui")
	if not screen_gui then
		screen_gui = Instance.new("ScreenGui")
		screen_gui.Name = "SoundManagerGui"
		screen_gui.ResetOnSpawn = false
		screen_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screen_gui.Parent = player_gui
	end
	
	sound.Parent = screen_gui
	active_sounds[sound] = true
	
	-- Play sound
	sound:Play()
	
	-- Cleanup when sound ends (if not looped)
	if not options.Looped then
		local ended_connection
		ended_connection = sound.Ended:Connect(function()
			ended_connection:Disconnect()
			return_sound_to_pool(sound)
		end)
		
		-- Also handle if sound is stopped manually
		local stopped_connection
		stopped_connection = sound.Stopped:Connect(function()
			stopped_connection:Disconnect()
			if active_sounds[sound] then
				return_sound_to_pool(sound)
			end
		end)
	end
	
	return sound
end

-- Play a 3D sound at a specific position in the world
function SoundManager:play_sound_3d(sound_id, position, options)
	options = options or {}
	
	local sound = get_sound_object()
	sound.SoundId = "rbxassetid://" .. tostring(sound_id)
	sound.Volume = options.Volume or DEFAULT_VOLUME
	sound.Pitch = options.Pitch or DEFAULT_PITCH
	sound.Looped = options.Looped or false
	sound.RollOffMode = options.RollOffMode or Enum.RollOffMode.Inverse
	sound.MaxDistance = options.MaxDistance or 100
	sound.MinDistance = options.MinDistance or 10
	
	-- Create a part to hold the sound at the position
	local sound_part = Instance.new("Part")
	sound_part.Name = "SoundPart"
	sound_part.Size = Vector3.new(1, 1, 1)
	sound_part.Position = position
	sound_part.Anchored = true
	sound_part.CanCollide = false
	sound_part.Transparency = 1
	sound_part.Parent = workspace
	
	sound.Parent = sound_part
	active_sounds[sound] = true
	
	-- Play sound
	sound:Play()
	
	-- Cleanup when sound ends (if not looped)
	if not options.Looped then
		local ended_connection
		ended_connection = sound.Ended:Connect(function()
			ended_connection:Disconnect()
			sound_part:Destroy()
			return_sound_to_pool(sound)
		end)
		
		-- Also handle if sound is stopped manually
		local stopped_connection
		stopped_connection = sound.Stopped:Connect(function()
			stopped_connection:Disconnect()
			if active_sounds[sound] then
				sound_part:Destroy()
				return_sound_to_pool(sound)
			end
		end)
	else
		-- For looped sounds, store the part reference for manual cleanup
		sound:SetAttribute("SoundPart", sound_part)
	end
	
	return sound, sound_part
end

-- Play a sound attached to a specific instance (e.g., a part)
function SoundManager:play_sound_attached(sound_id, parent_instance, options)
	options = options or {}
	
	local sound = get_sound_object()
	sound.SoundId = "rbxassetid://" .. tostring(sound_id)
	sound.Volume = options.Volume or DEFAULT_VOLUME
	sound.Pitch = options.Pitch or DEFAULT_PITCH
	sound.Looped = options.Looped or false
	
	if options.RollOffMode then
		sound.RollOffMode = options.RollOffMode
	end
	if options.MaxDistance then
		sound.MaxDistance = options.MaxDistance
	end
	if options.MinDistance then
		sound.MinDistance = options.MinDistance
	end
	
	sound.Parent = parent_instance
	active_sounds[sound] = true
	
	-- Play sound
	sound:Play()
	
	-- Cleanup when sound ends (if not looped)
	if not options.Looped then
		local ended_connection
		ended_connection = sound.Ended:Connect(function()
			ended_connection:Disconnect()
			return_sound_to_pool(sound)
		end)
		
		-- Also handle if sound is stopped manually
		local stopped_connection
		stopped_connection = sound.Stopped:Connect(function()
			stopped_connection:Disconnect()
			if active_sounds[sound] then
				return_sound_to_pool(sound)
			end
		end)
	end
	
	return sound
end

-- Stop a specific sound
function SoundManager:stop_sound(sound)
	if sound and active_sounds[sound] then
		sound:Stop()
		active_sounds[sound] = nil
		
		-- Cleanup 3D sound part if exists
		local sound_part = sound:GetAttribute("SoundPart")
		if sound_part then
			sound_part:Destroy()
		end
		
		return_sound_to_pool(sound)
	end
end

-- Stop all active sounds
function SoundManager:stop_all_sounds()
	for sound, _ in pairs(active_sounds) do
		sound:Stop()
		active_sounds[sound] = nil
		
		-- Cleanup 3D sound part if exists
		local sound_part = sound:GetAttribute("SoundPart")
		if sound_part then
			sound_part:Destroy()
		end
		
		return_sound_to_pool(sound)
	end
end

-- Set master volume (affects all new sounds)
function SoundManager:set_master_volume(volume)
	DEFAULT_VOLUME = math.clamp(volume, 0, 1)
end

-- Get master volume
function SoundManager:get_master_volume()
	return DEFAULT_VOLUME
end

-- Cleanup all sounds and pool
function SoundManager:cleanup()
	self:stop_all_sounds()
	
	-- Destroy all pooled sounds
	for _, sound in ipairs(sound_pool) do
		sound:Destroy()
	end
	sound_pool = {}
	
	-- Destroy SoundManagerGui if exists
	local screen_gui = player_gui:FindFirstChild("SoundManagerGui")
	if screen_gui then
		screen_gui:Destroy()
	end
end

return SoundManager

