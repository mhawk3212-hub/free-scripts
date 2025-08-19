local Config = getgenv().Config
assert(Config)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserInput = game:GetService("UserInputService")
local Mouse = LocalPlayer:GetMouse()

local ESPObjects = {}
local DrawObjects = {}
local WallHighlight
local WallTarget
local positionHistory = {}
local maxHistory = 60
local toggledSpeed = false
local originalSpeed = nil

-- Dynamic highlight creation
local function ApplyHighlight(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    if not ESPObjects[player] then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = char
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.FillColor = Config.HighlightFillColor
        highlight.OutlineColor = Config.HighlightOutlineColor
        highlight.Parent = char
        ESPObjects[player] = highlight
    else
        local h = ESPObjects[player]
        h.Adornee = char
        h.Enabled = Config.HighlightEnabled
        h.FillColor = Config.HighlightFillColor
        h.OutlineColor = Config.HighlightOutlineColor
    end
end

local function RemoveESP(player)
    if ESPObjects[player] then
        ESPObjects[player]:Destroy()
        ESPObjects[player] = nil
    end
    if DrawObjects[player] then
        for _, obj in pairs(DrawObjects[player]) do
            obj:Remove()
        end
        DrawObjects[player] = nil
    end
end

local function AddDrawESP(player)
    if player == LocalPlayer then return end
    if DrawObjects[player] then return end

    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Color = Color3.fromRGB(255, 255, 255)
    box.Filled = false

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Color = Color3.fromRGB(255, 255, 255)

    local nameTag = Drawing.new("Text")
    nameTag.Size = 14
    nameTag.Color = Color3.fromRGB(255, 255, 255)
    nameTag.Center = true
    nameTag.Outline = true

    local deadTag = Drawing.new("Text")
    deadTag.Size = 14
    deadTag.Color = Color3.fromRGB(255, 0, 0)
    deadTag.Center = true
    deadTag.Outline = true
    deadTag.Text = "DEAD"
    deadTag.Visible = false

    DrawObjects[player] = {Box = box, Tracer = tracer, Name = nameTag, Dead = deadTag}
end

local function SetupPlayer(player)
    player.CharacterAdded:Connect(function(char)
        repeat task.wait() until char:FindFirstChild("HumanoidRootPart")
        ApplyHighlight(player)
        AddDrawESP(player)
        if DrawObjects[player] and DrawObjects[player].Dead then
            DrawObjects[player].Dead.Visible = false
        end
    end)
    if player.Character then
        ApplyHighlight(player)
        AddDrawESP(player)
    end
end

Players.PlayerAdded:Connect(SetupPlayer)
Players.PlayerRemoving:Connect(RemoveESP)
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then SetupPlayer(player) end
end

-- Apply skin tone dynamically
RunService.RenderStepped:Connect(function()
    if LocalPlayer.Character and Config.SkinTone then
        for _, part in ipairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.BrickColor = Config.SkinTone
            end
        end
    end
end)

-- WalkSpeed toggle
UserInput.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Config.WalkKey then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                if not originalSpeed then
                    originalSpeed = hum.WalkSpeed
                end
                toggledSpeed = not toggledSpeed
                hum.WalkSpeed = toggledSpeed and Config.WalkSpeed or originalSpeed
            end
        end
    end
end)

-- Wall highlight
local function HighlightWall(part)
    if not WallHighlight then
        WallHighlight = Instance.new("Highlight")
        WallHighlight.FillColor = Color3.fromRGB(0, 255, 0)
        WallHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        WallHighlight.FillTransparency = 0.6
        WallHighlight.OutlineTransparency = 0
        WallHighlight.Parent = workspace
    end
    WallHighlight.Adornee = part
    WallTarget = part
end

local function ClearWallHighlight()
    if WallHighlight then
        WallHighlight.Adornee = nil
    end
    WallTarget = nil
end

-- Wall teleport
UserInput.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and UserInput:IsKeyDown(Config.WallKey) and WallTarget then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local topY = WallTarget.Position.Y + (WallTarget.Size.Y / 2) + 5
            hrp.CFrame = CFrame.new(WallTarget.Position.X, topY, WallTarget.Position.Z)
        end
    end
end)

-- Anti-fall (G key)
UserInput.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.G then
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp and #positionHistory > 0 then
                hrp.CFrame = CFrame.new(positionHistory[1])
            end
        end
    end
end)

-- Main loop
RunService.RenderStepped:Connect(function()
    local target = Mouse.Target
    if UserInput:IsKeyDown(Config.WallKey) and target and target:IsA("BasePart") and not target:IsDescendantOf(LocalPlayer.Character) then
        HighlightWall(target)
    else
        ClearWallHighlight()
    end

    -- Position history for anti-fall
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            table.insert(positionHistory, hrp.Position)
            if #positionHistory > maxHistory then
                table.remove(positionHistory, 1)
            end
        end
    end

    -- Update other players' ESP dynamically
    for player, objs in pairs(DrawObjects) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and head and hum then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
            local distance = (Camera.CFrame.Position - hrp.Position).Magnitude
            local size = math.clamp(50 / distance, 5, 15)

            -- Box
            objs.Box.Visible = Config.BoxEnabled and onScreen
            if objs.Box.Visible then
                objs.Box.Size = Vector2.new(size, size)
                objs.Box.Position = Vector2.new(pos.X - size/2, pos.Y - size/2)
                objs.Box.Color = Config.HighlightOutlineColor
            end

            -- Tracer
            objs.Tracer.Visible = Config.TracerEnabled and onScreen
            if objs.Tracer.Visible then
                objs.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                objs.Tracer.To = Vector2.new(pos.X, pos.Y)
                objs.Tracer.Color = Config.HighlightOutlineColor
            end

            -- Name
            objs.Name.Visible = Config.NameEnabled and onScreen
            if objs.Name.Visible then
                objs.Name.Text = player.Name
                objs.Name.Position = Vector2.new(headPos.X, headPos.Y - size)
                objs.Name.Color = Config.HighlightOutlineColor
            end

            -- Dead
            objs.Dead.Visible = hum.Health <= 0 and onScreen
            if objs.Dead.Visible then
                objs.Dead.Position = Vector2.new(headPos.X, headPos.Y - size*2)
            end

            -- Highlight player
            if ESPObjects[player] then
                ESPObjects[player].Enabled = Config.HighlightEnabled
                ESPObjects[player].FillColor = Config.HighlightFillColor
                ESPObjects[player].OutlineColor = Config.HighlightOutlineColor
            end
        else
            objs.Box.Visible = false
            objs.Tracer.Visible = false
            objs.Name.Visible = false
            objs.Dead.Visible = false
        end
    end
end)
