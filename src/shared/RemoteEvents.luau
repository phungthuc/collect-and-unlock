-- RemoteEvents module for client-server communication
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

-- Get or create RemoteEvents folder
local remote_events_folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remote_events_folder then
	remote_events_folder = Instance.new("Folder")
	remote_events_folder.Name = "RemoteEvents"
	remote_events_folder.Parent = ReplicatedStorage
end

-- Helper function to get or create RemoteEvent
local function get_or_create_event(name)
	local event = remote_events_folder:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = remote_events_folder
	end
	return event
end

-- Shard collection event
local collect_shard_event = get_or_create_event("CollectShard")

-- Shard state update event (server -> client)
local shard_state_event = get_or_create_event("ShardStateUpdate")

-- Puzzle interaction event
local puzzle_interact_event = get_or_create_event("PuzzleInteract")

-- Puzzle state update event (server -> client)
local puzzle_state_event = get_or_create_event("PuzzleStateUpdate")

-- Gate open event (server -> client)
local gate_open_event = get_or_create_event("GateOpen")

-- Timer start event (server -> client)
local timer_start_event = get_or_create_event("TimerStart")

-- Game completion event (server -> client)
local game_complete_event = get_or_create_event("GameComplete")

-- Reset game event (client -> server)
local reset_game_event = get_or_create_event("ResetGame")

-- All shards collected event (server -> client)
local all_shards_collected_event = get_or_create_event("AllShardsCollected")

-- Game reset event (server -> client) - notifies all clients when game is reset
local game_reset_event = get_or_create_event("GameReset")

-- Puzzle solved event (server -> client) - notifies when puzzle is solved (before gate opens)
local puzzle_solved_event = get_or_create_event("PuzzleSolved")

-- Open gate now event (client -> server) - client requests gate to open after countdown
local open_gate_now_event = get_or_create_event("OpenGateNow")

-- Export events
RemoteEvents.CollectShard = collect_shard_event
RemoteEvents.ShardStateUpdate = shard_state_event
RemoteEvents.PuzzleInteract = puzzle_interact_event
RemoteEvents.PuzzleStateUpdate = puzzle_state_event
RemoteEvents.GateOpen = gate_open_event
RemoteEvents.TimerStart = timer_start_event
RemoteEvents.GameComplete = game_complete_event
RemoteEvents.ResetGame = reset_game_event
RemoteEvents.AllShardsCollected = all_shards_collected_event
RemoteEvents.GameReset = game_reset_event
RemoteEvents.PuzzleSolved = puzzle_solved_event
RemoteEvents.OpenGateNow = open_gate_now_event

return RemoteEvents