-- Configuration constants for the game
local Config = {}

-- Shard configuration
Config.SHARD_COUNT = 20
Config.SHARD_SIZE = Vector3.new(3, 3, 3) -- Increased size for better visibility
Config.SHARD_COLOR = Color3.fromRGB(100, 200, 255)
Config.SHARD_MATERIAL = Enum.Material.Neon
Config.SHARD_BOBBING_SPEED = 2 -- units per second
Config.SHARD_BOBBING_AMPLITUDE = 0.5 -- units
Config.SHARD_ROTATION_SPEED = 90 -- degrees per second

-- Baseplate configuration
Config.BASEPLATE_SIZE = Vector3.new(512, 20, 512)
Config.BASEPLATE_POSITION = Vector3.new(50, -10, 0)

-- Shard spawn positions (20 positions distributed on baseplate)
-- Positions are relative to baseplate center
-- Y = 15 means shards will be 15 units above baseplate center (at y = -10), so at y = 5 (5 units above baseplate top)
-- TEST MODE: Shards spawn in a smaller area near spawn point for quick testing
Config.SHARD_SPAWN_POSITIONS = {
	Vector3.new(-30, 15, -30),
	Vector3.new(-20, 15, -20),
	Vector3.new(-30, 15, 0),
	Vector3.new(-20, 15, 20),
	Vector3.new(-30, 15, 30),
	Vector3.new(-10, 15, -30),
	Vector3.new(-5, 15, -20),
	Vector3.new(-10, 15, 0),
	Vector3.new(-5, 15, 20),
	Vector3.new(-10, 15, 30),
	Vector3.new(0, 15, -30),
	Vector3.new(5, 15, -20),
	Vector3.new(0, 15, 0),
	Vector3.new(5, 15, 20),
	Vector3.new(0, 15, 30),
	Vector3.new(10, 15, -30),
	Vector3.new(20, 15, -20),
	Vector3.new(10, 15, 0),
	Vector3.new(20, 15, 20),
	Vector3.new(30, 15, 30),
}

-- Puzzle configuration
Config.PUZZLE_RING_COUNT = 3
Config.PUZZLE_CENTER_POSITION = Vector3.new(0, 10, 55) -- Center position of puzzle (in front of gate)
Config.PUZZLE_RING_DEPTH_OFFSET = -1 -- Distance between rings along Z axis (depth)
Config.PUZZLE_RING_THICKNESS = 0.5 -- Thickness of each ring
Config.PUZZLE_RING_RADII = {4, 6, 8} -- Radii for outer, middle, inner rings
Config.PUZZLE_RING_1_COLOR = Color3.fromRGB(255, 150, 0) -- Brighter orange
Config.PUZZLE_RING_2_COLOR = Color3.fromRGB(0, 255, 0) -- Green
Config.PUZZLE_RING_3_COLOR = Color3.fromRGB(0, 0, 255) -- Blue
Config.PUZZLE_ROTATION_STEP = 15 -- degrees per interaction
Config.PUZZLE_TARGET_ANGLE = 0 -- Target angle for alignment (0° = upward/forward)
Config.PUZZLE_TOLERANCE = 10 -- degrees tolerance for alignment check
Config.PUZZLE_MARKER_LENGTH = -1 -- Length of marker line on each ring
Config.PUZZLE_MARKER_WIDTH = 0.5 -- Width of marker line
Config.PUZZLE_MARKER_COLOR = Color3.fromRGB(255, 0, 0) -- Yellow marker

-- Gate configuration
-- Gate position: far enough to not overlap with shards (shards are at -30 to +30, gate at +60)
Config.GATE_POSITION = Vector3.new(0, 0, 60)
Config.GATE_SIZE = Vector3.new(30, 40, 5) -- Larger gate for better visibility
Config.GATE_COLOR = Color3.fromRGB(100, 100, 100) -- Darker gray for better contrast

return Config

