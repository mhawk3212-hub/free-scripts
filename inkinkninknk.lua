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
local toggledSpeed = false
local savedSpeed = 16
local WallHighlight
local WallTarget
local lastUpdate = 0

local positionHistory = {}
local maxHistory = 60 -- last ~2 seconds
local movementDrawings = {}
local lastCircleTime = 0
local circleInterval = 2
local lastPosition = nil

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
        ESPObjects[player].Adornee = char
        ESPObjects[player].Enabled = Config.HighlightEnabled
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

if LocalPlayer.Character then
    for _, part in ipairs(LocalPlayer.Character:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.BrickColor = Config.SkinTone
        end
    end
end

UserInput.InputBegan:Connect(function(input,gp)
    if not gp and input.KeyCode == Config.WalkKey then
        toggledSpeed = not toggledSpeed
    end
end)

RunService.RenderStepped:Connect(function()
    if LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            if toggledSpeed then
                hum.WalkSpeed = Config.WalkSpeed
            else
                hum.WalkSpeed = hum.WalkSpeed ~= savedSpeed and savedSpeed or hum.WalkSpeed
            end
        end
    end
end)

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

-- Anti-fall using position history
RunService.RenderStepped:Connect(function()
    if not LocalPlayer.Character then return end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    table.insert(positionHistory, hrp.Position)
    if #positionHistory > maxHistory then
        table.remove(positionHistory, 1)
    end
end)

UserInput.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.G then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local lastSafe = positionHistory[1] or char.HumanoidRootPart.Position
            char.HumanoidRootPart.CFrame = CFrame.new(lastSafe)
        end
    end
end)

-- Main ESP + Wall Highlight + Movement Drawing
RunService.RenderStepped:Connect(function()
    local delta = tick() - lastUpdate
    if delta < 0.03 then return end
    lastUpdate = tick()

    -- Wall Highlight
    if UserInput:IsKeyDown(Config.WallKey) then
        local target = Mouse.Target
        if target and target:IsA("BasePart") and not target:IsDescendantOf(LocalPlayer.Character) then
            HighlightWall(target)
        else
            ClearWallHighlight()
        end
    else
        ClearWallHighlight()
    end

    -- Update ESP for other players
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

            objs.Box.Visible = Config.BoxEnabled and onScreen
            if objs.Box.Visible then
                objs.Box.Size = Vector2.new(size, size)
                objs.Box.Position = Vector2.new(pos.X - size/2, pos.Y - size/2)
            end

            objs.Tracer.Visible = Config.TracerEnabled and onScreen
            if objs.Tracer.Visible then
                objs.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                objs.Tracer.To = Vector2.new(pos.X, pos.Y)
            end

            objs.Name.Visible = Config.NameEnabled and onScreen
            if objs.Name.Visible then
                objs.Name.Text = player.Name
                objs.Name.Position = Vector2.new(headPos.X, headPos.Y - size)
            end

            objs.Dead.Visible = hum.Health <= 0 and onScreen
            if objs.Dead.Visible then
                objs.Dead.Position = Vector2.new(headPos.X, headPos.Y - size*2)
            end
        else
            objs.Box.Visible = false
            objs.Tracer.Visible = false
            objs.Name.Visible = false
            objs.Dead.Visible = false
        end
    end

    -- LocalPlayer Movement Drawing
    if LocalPlayer.Character then
        local char = LocalPlayer.Character
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hrp and hum then
            -- Draw line when jumping
            if hum:GetState() == Enum.HumanoidStateType.Jumping and lastPosition then
                local line = Drawing.new("Line")
                local startScreen, onScreen1 = Camera:WorldToViewportPoint(lastPosition)
                local endScreen, onScreen2 = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen1 and onScreen2 then
                    line.From = Vector2.new(startScreen.X, startScreen.Y)
                    line.To = Vector2.new(endScreen.X, endScreen.Y)
                    line.Color = Color3.fromRGB(255,0,0)
                    line.Thickness = 2
                    table.insert(movementDrawings, line)
                    task.delay(5, function() line:Remove() end)
                end
            end

            -- Draw circle every 2 seconds while walking
            if tick() - lastCircleTime >= circleInterval and hum:GetState() == Enum.HumanoidStateType.Running then
                lastCircleTime = tick()
                local posScreen, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local circle = Drawing.new("Circle")
                    circle.Position = Vector2.new(posScreen.X, posScreen.Y)
                    circle.Radius = 6
                    circle.Filled = false
                    circle.Color = Color3.fromRGB(0,255,0)
                    circle.Thickness = 2
                    table.insert(movementDrawings, circle)
                    task.delay(5, function() circle:Remove() end)
                end
            end

            lastPosition = hrp.Position
        end
    end
end)
