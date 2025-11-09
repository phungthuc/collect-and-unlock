-- PuzzleManager: Handles 3-ring puzzle logic
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Config = require(ReplicatedStorage.Shared.Config)

local PuzzleManager = {}
PuzzleManager.__index = PuzzleManager

local puzzle_rings = {}
local ring_markers = {} -- Store marker parts for each ring
local ring_angles = {0, 0, 0} -- Current angles of each ring
local puzzle_active = false
local puzzle_solved = false
local start_button = nil
local puzzle_folder = nil
local puzzle_created = false
-- ClickDetector removed - rings can only be rotated via UI buttons or keyboard

function PuzzleManager.new()
    local self = setmetatable({}, PuzzleManager)
    return self
end

function PuzzleManager:create_puzzle()
    -- Only create puzzle folder, puzzle elements will be created when all shards are collected
    puzzle_folder = Instance.new("Folder")
    puzzle_folder.Name = "Puzzle"
    puzzle_folder.Parent = Workspace

    puzzle_created = false
end

function PuzzleManager:create_puzzle_elements()
    -- Only create once
    if puzzle_created then
        return
    end

    if not puzzle_folder or not puzzle_folder.Parent then
        warn("[PuzzleManager] Puzzle folder not found! Creating new one...")
        self:create_puzzle()
    end

    -- Create 3 concentric rings stacked along depth axis
    -- Ring 1 = lớn nhất, xa người chơi nhất
    -- Ring 3 = nhỏ nhất, gần người chơi nhất
    for i = 1, Config.PUZZLE_RING_COUNT do
        local radius = Config.PUZZLE_RING_RADII[i]

        -- CHANGED: đảm bảo ring 1 xa nhất, ring 3 gần nhất (0, offset, 2*offset, ...)
        local depth_offset = (Config.PUZZLE_RING_COUNT - i) * Config.PUZZLE_RING_DEPTH_OFFSET

        local ring_position = Config.PUZZLE_CENTER_POSITION + Vector3.new(0, 0, depth_offset)

        -- Create ring as a torus-like structure using a cylinder
        local ring = Instance.new("Part")
        ring.Name = "Ring" .. i
        ring.Size = Vector3.new(Config.PUZZLE_RING_THICKNESS,  radius * 2, radius * 2)
        ring.Material = Enum.Material.DiamondPlate
        ring.Shape = Enum.PartType.Cylinder
        ring.Anchored = true
        ring.CanCollide = false
        ring.Position = ring_position
        ring.Parent = puzzle_folder


        if i == 1 then
            ring.Color = Config.PUZZLE_RING_1_COLOR
        elseif i == 2 then
            ring.Color = Config.PUZZLE_RING_2_COLOR
        elseif i == 3 then
            ring.Color = Config.PUZZLE_RING_3_COLOR
        end

        -- Create marker line on the ring (visible line/notch)
        local marker = Instance.new("Part")
        marker.Name = "Marker"
        marker.Size = Vector3.new(
            Config.PUZZLE_MARKER_WIDTH,
            Config.PUZZLE_MARKER_WIDTH,
            Config.PUZZLE_MARKER_WIDTH
        )
        marker.Material = Enum.Material.Neon
        marker.Color = Config.PUZZLE_MARKER_COLOR
        marker.Anchored = true
        marker.CanCollide = false
        marker.Parent = ring

        -- Position marker at the top of the ring (angle 0 = upward)
        local marker_offset = radius + (Config.PUZZLE_MARKER_LENGTH / 2)
        marker.Position = ring_position + Vector3.new(0, marker_offset, 0)
        marker.Rotation = Vector3.new(0, 0, 90)

        -- Store marker reference
        ring_markers[i] = marker

        -- Add number label on ring
        local billboard_gui = Instance.new("BillboardGui")
        billboard_gui.Size = UDim2.new(0, 80, 0, 80)
        billboard_gui.StudsOffset = Vector3.new(0, radius + 2, 0)
        billboard_gui.AlwaysOnTop = true
        billboard_gui.Parent = ring

        -- local number_label = Instance.new("TextLabel")
        -- number_label.Size = UDim2.new(1, 0, 1, 0)
        -- number_label.BackgroundTransparency = 0.5
        -- number_label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        -- number_label.Text = "Ring " .. i
        -- number_label.TextColor3 = Color3.fromRGB(255, 255, 255)
        -- number_label.TextScaled = true
        -- number_label.Font = Enum.Font.GothamBold
        -- number_label.Parent = billboard_gui

        -- Add interaction part (invisible button covering the ring area)
        local interaction = Instance.new("Part")
        interaction.Name = "Interaction"
        interaction.Size = Vector3.new(
            radius * 2 + 2,
            radius * 2 + 2,
            Config.PUZZLE_RING_THICKNESS + 1
        )
        interaction.Transparency = 1
        interaction.CanCollide = false
        interaction.CanTouch = false
        interaction.Anchored = true
        interaction.Position = ring_position
        interaction.Parent = ring

        -- ClickDetector removed - rings can only be rotated via UI buttons or keyboard

        -- Add StringValue to identify ring index
        local string_value = Instance.new("StringValue")
        string_value.Name = "RingIndex"
        string_value.Value = tostring(i)
        string_value.Parent = interaction

        puzzle_rings[i] = ring
        ring_angles[i] = math.random(0, 359) -- Random initial angle for each ring
    end

    -- Update initial visual rotation
    self:update_ring_rotations()

    -- Create start button - larger and more visible
    start_button = Instance.new("Part")
    start_button.Name = "StartButton"
    start_button.Size = Vector3.new(10, 4, 10)
    start_button.Rotation = Vector3.new(0, 90, 0)
    start_button.Material = Enum.Material.Neon
    start_button.Color = Color3.fromRGB(0, 255, 0)
    start_button.Anchored = true
    start_button.CanCollide = false
    start_button.CanTouch = true
    start_button.Transparency = 0
    start_button.Position = Config.GATE_POSITION + Vector3.new(0, 2, -15) -- In front of gate, at eye level
    start_button.Parent = puzzle_folder

    local point_light = Instance.new("PointLight")
    point_light.Color = Color3.fromRGB(0, 255, 0)
    point_light.Brightness = 2
    point_light.Range = 20
    point_light.Parent = start_button

    local surface_gui = Instance.new("SurfaceGui")
    surface_gui.Face = Enum.NormalId.Top
    surface_gui.Parent = start_button

    local text_label = Instance.new("TextLabel")
    text_label.Size = UDim2.new(1, 0, 1, 0)
    text_label.BackgroundTransparency = 0.3
    text_label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    text_label.Text = "START PUZZLE"
    text_label.TextColor3 = Color3.fromRGB(255, 255, 255)
    text_label.TextScaled = true
    text_label.Font = Enum.Font.GothamBold
    text_label.Parent = surface_gui

    -- OPTIONAL: start button tự bật puzzle trên server khi chạm
    start_button.Touched:Connect(function(hit)
        local character = hit.Parent
        local player = game.Players:GetPlayerFromCharacter(character)
        if player then
            self:start_puzzle() -- This will hide the button automatically
        end
    end)

    -- Pulsing animation
    spawn(function()
        local button_ref = start_button -- Store reference
        while button_ref and button_ref.Parent do
            -- Check again before creating tween
            if not button_ref or not button_ref.Parent then
                break
            end
            
            local success1, tween1 = pcall(function()
                return TweenService:Create(
                    button_ref,
                    TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    { Transparency = 0.3 }
                )
            end)
            
            if success1 and tween1 then
                tween1:Play()
                tween1.Completed:Wait()
            else
                break -- Button was destroyed
            end

            -- Check again before second tween
            if not button_ref or not button_ref.Parent then
                break
            end

            local success2, tween2 = pcall(function()
                return TweenService:Create(
                    button_ref,
                    TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    { Transparency = 0 }
                )
            end)
            
            if success2 and tween2 then
                tween2:Play()
                tween2.Completed:Wait()
            else
                break -- Button was destroyed
            end
        end
    end)

    -- Animate appearance of puzzle elements
    start_button.Size = Vector3.new(5, 2, 5)
    local button_tween = TweenService:Create(
        start_button,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = Vector3.new(10, 4, 10) }
    )
    button_tween:Play()

    for i = 1, Config.PUZZLE_RING_COUNT do
        if puzzle_rings[i] then
            local original_size = puzzle_rings[i].Size
            puzzle_rings[i].Size = original_size * 0.5
            local ring_tween = TweenService:Create(
                puzzle_rings[i],
                TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { Size = original_size }
            )
            ring_tween:Play()
        end
    end

    puzzle_created = true
end

function PuzzleManager:start_puzzle()
    if not puzzle_created then
        warn("[PuzzleManager] Puzzle elements not created yet!")
        return false
    end

    if puzzle_active or puzzle_solved then
        return false
    end

    puzzle_active = true
    -- Keep random initial angles

    self:update_ring_rotations()
    
    -- Hide start button when puzzle starts
    self:hide_start_button()
    
    -- Enable ring interactions
    for i = 1, Config.PUZZLE_RING_COUNT do
        if puzzle_rings[i] then
            local interaction = puzzle_rings[i]:FindFirstChild("Interaction")
            if interaction then
                interaction.CanTouch = true
            end
            -- ClickDetector removed - rings can only be rotated via UI buttons or keyboard
        end
    end
    
    RemoteEvents.PuzzleStateUpdate:FireAllClients(true, ring_angles)
    return true
end

function PuzzleManager:update_ring_rotations()
    -- Update visual rotation of rings and markers
    for i = 1, Config.PUZZLE_RING_COUNT do
        if puzzle_rings[i] then
            local angle = ring_angles[i]
            puzzle_rings[i].Rotation = Vector3.new(90, angle, 90)

            if ring_markers[i] then
                local radius = Config.PUZZLE_RING_RADII[i]
                local depth_offset = (Config.PUZZLE_RING_COUNT - i) * Config.PUZZLE_RING_DEPTH_OFFSET
                local ring_position = Config.PUZZLE_CENTER_POSITION + Vector3.new(0, 0, depth_offset)

                local rad = math.rad(angle)
                local marker_offset = radius + (Config.PUZZLE_MARKER_LENGTH / 2)
                local marker_x = math.sin(rad) * marker_offset
                local marker_y = math.cos(rad) * marker_offset

                ring_markers[i].Position = ring_position + Vector3.new(marker_x, marker_y, -0.25)
                ring_markers[i].Rotation = Vector3.new(0, -angle, 0)
            end
        end
    end
end

function PuzzleManager:rotate_ring(ring_index)
    if not puzzle_created then
        warn("[PuzzleManager] Puzzle elements not created yet!")
        return false
    end

    if puzzle_solved then
        -- Puzzle already solved, silently ignore (no need to warn)
        return false
    end

    if not puzzle_active then
        -- Puzzle not active yet or already solved, silently ignore
        return false
    end

    if ring_index < 1 or ring_index > Config.PUZZLE_RING_COUNT then
        warn(string.format("[PuzzleManager] Invalid ring index: %d", ring_index))
        return false
    end

    -- Rotate ring by fixed step
    ring_angles[ring_index] =
        (ring_angles[ring_index] + Config.PUZZLE_ROTATION_STEP) % 360

    self:update_ring_rotations()

    local solved = self:check_solution()

    RemoteEvents.PuzzleStateUpdate:FireAllClients(puzzle_active, ring_angles)

    if solved then
        self:solve_puzzle()
    end

    return true
end

function PuzzleManager:check_solution()
    -- CHANGED: check alignment tương đối giữa các ring
    -- Lấy ring 1 làm chuẩn, các ring còn lại chỉ cần lệch trong tolerance
    local reference_angle = ring_angles[1]

    for i = 2, Config.PUZZLE_RING_COUNT do
        local current_angle = ring_angles[i]

        local diff = (current_angle - reference_angle + 180) % 360 - 180
        local abs_diff = math.abs(diff)

        if abs_diff > Config.PUZZLE_TOLERANCE then
            return false
        end
    end

    -- Tất cả marker trùng nhau (hoặc gần trùng nhau)
    return true
end

function PuzzleManager:solve_puzzle()
    if puzzle_solved then
        return
    end

    puzzle_solved = true
    puzzle_active = false


    -- Notify that puzzle is solved (GameManager will handle gate opening)
    RemoteEvents.GateOpen:FireAllClients()
end

function PuzzleManager:is_solved()
    return puzzle_solved
end

function PuzzleManager:show_start_button()
    self:create_puzzle_elements()
end

function PuzzleManager:hide_start_button()
    if start_button and start_button.Parent then
        -- Hide button with animation
        local tween_service = game:GetService("TweenService")
        local hide_tween = tween_service:Create(
            start_button,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Transparency = 1, Size = Vector3.new(0, 0, 0) }
        )
        hide_tween:Play()
        hide_tween.Completed:Connect(function()
            -- Disable interaction after animation
            start_button.CanTouch = false
        end)
    end
end

function PuzzleManager:destroy_puzzle_elements()
    for i = 1, Config.PUZZLE_RING_COUNT do
        if puzzle_rings[i] and puzzle_rings[i].Parent then
            puzzle_rings[i]:Destroy()
        end
        puzzle_rings[i] = nil
        ring_markers[i] = nil
-- ClickDetector references removed
    end

    if start_button and start_button.Parent then
        start_button:Destroy()
    end
    start_button = nil

    puzzle_created = false
    ring_angles = {0, 0, 0}
end

function PuzzleManager:reset()
    puzzle_active = false
    puzzle_solved = false
    ring_angles = {0, 0, 0}

    -- Disable ring interactions before destroying
    for i = 1, Config.PUZZLE_RING_COUNT do
        if puzzle_rings[i] then
            local interaction = puzzle_rings[i]:FindFirstChild("Interaction")
            if interaction then
                interaction.CanTouch = false
            end
            -- ClickDetector removed - rings can only be rotated via UI buttons or keyboard
        end
    end

    self:destroy_puzzle_elements()
    RemoteEvents.PuzzleStateUpdate:FireAllClients(false, ring_angles)
end

return PuzzleManager
