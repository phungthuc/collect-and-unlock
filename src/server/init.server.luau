-- Main server initialization
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for Shared folder to be created
local shared_folder = ReplicatedStorage:WaitForChild("Shared", 10)
if not shared_folder then
	warn("Shared folder not found! Make sure Rojo is syncing correctly.")
	return
end

-- Wait for required modules
local config_module = shared_folder:WaitForChild("Config", 10)
local remote_events_module = shared_folder:WaitForChild("RemoteEvents", 10)

if not config_module or not remote_events_module then
	warn("Required modules not found in Shared folder!")
	return
end

local GameManager = require(script.GameManager)

-- Initialize game
local game_manager = GameManager.new()

print("Server initialized successfully!")
