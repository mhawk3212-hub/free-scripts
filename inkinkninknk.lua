--[[ 
    Loader config (example):
    getgenv().Config = {
        HighlightEnabled = true,
        BoxEnabled = true,
        TracerEnabled = true,
        NameEnabled = true,
        HighlightFillColor = Color3.fromRGB(255, 0, 0),
        HighlightOutlineColor = Color3.fromRGB(255, 255, 255),
        SkinTone = BrickColor.new("Pastel brown"),
        WalkSpeed = 100,          
        WalkKey = Enum.KeyCode.K,
        WallKey = Enum.KeyCode.B -- hold to highlight walls
    }
]]

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

-- wall highlight state
local WallHighlight
local WallTarget

-----------------------------------------------------
-- Loading bar
-----------------------------------------------------
local function PrintLoading()
    local barLength = 20
    for i = 0, barLength do
        local fill = string.rep("=", i)
        local empty = string.rep(" ", barLength - i)
        print(string.format("[%-20s] %d%%", fill..empty, math.floor((i/barLength)*100)))
        task.wait(0.1)
    end
    print("[ESP] Loaded successfully!")
end
task.spawn(PrintLoading)

-----------------------------------------------------
-- Highlight Player Characters
-----------------------------------------------------
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
        highlight.Parent = char -- ✅ parent to character
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

-----------------------------------------------------
-- Drawing ESP (box, tracer, name, dead-tag)
-----------------------------------------------------
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

-----------------------------------------------------
-- Player setup
-----------------------------------------------------
local function SetupPlayer(player)
    player.CharacterAdded:Connect(function(char)
        repeat task.wait() until char:FindFirstChild("HumanoidRootPart")
        ApplyHighlight(player)
        AddDrawESP(player)

        -- reset dead tag when new char spawns
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

-----------------------------------------------------
-- Main ESP updater
-----------------------------------------------------
RunService.RenderStepped:Connect(function()
    -- update highlights
    for player, highlight in pairs(ESPObjects) do
        local char = player.Character
        if char then
            highlight.Adornee = char
            highlight.Enabled = Config.HighlightEnabled
            highlight.FillColor = Config.HighlightFillColor
            highlight.OutlineColor = Config.HighlightOutlineColor
        end
    end

    -- update drawing objects
    for player, objs in pairs(DrawObjects) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and head and hum then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
            if Config.BoxEnabled and onScreen then
                objs.Box.Visible = true
                objs.Box.Size = Vector2.new(10,10)
                objs.Box.Position = Vector2.new(pos.X-5,pos.Y-5)
            else objs.Box.Visible = false end

            if Config.TracerEnabled and onScreen then
                objs.Tracer.Visible = true
                objs.Tracer.From = Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y)
                objs.Tracer.To = Vector2.new(pos.X,pos.Y)
            else objs.Tracer.Visible = false end

            if Config.NameEnabled and onScreen then
                objs.Name.Visible = true
                objs.Name.Text = player.Name
                objs.Name.Position = Vector2.new(headPos.X,headPos.Y-20)
            else objs.Name.Visible = false end

            if hum.Health <= 0 and onScreen then
                objs.Dead.Visible = true
                objs.Dead.Position = Vector2.new(headPos.X,headPos.Y-40)
            else
                objs.Dead.Visible = false
            end
        else
            objs.Box.Visible = false
            objs.Tracer.Visible = false
            objs.Name.Visible = false
            objs.Dead.Visible = false
        end
    end
end)

-----------------------------------------------------
-- Change local player skin tone
-----------------------------------------------------
if LocalPlayer.Character then
    for _, part in ipairs(LocalPlayer.Character:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.BrickColor = Config.SkinTone
        end
    end
end

-----------------------------------------------------
-- Walkspeed toggle
-----------------------------------------------------
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

-----------------------------------------------------
-- Wall Highlight + Teleport System
-----------------------------------------------------
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

-- teleport when clicked (top-of-wall)
UserInput.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and WallTarget then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local topY = WallTarget.Position.Y + (WallTarget.Size.Y / 2) + 5
            hrp.CFrame = CFrame.new(WallTarget.Position.X, topY, WallTarget.Position.Z)
        end
    end
end)

-- teleport on B + Click (top of wall)
UserInput.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and UserInput:IsKeyDown(Config.WallKey) then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and WallTarget then
            local hrp = char.HumanoidRootPart
            local topY = WallTarget.Position.Y + (WallTarget.Size.Y / 2) + 5
            hrp.CFrame = CFrame.new(WallTarget.Position.X, topY, WallTarget.Position.Z)
        end
    end
end)

-- teleport on CTRL + Click (directly to mouse target)
UserInput.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and UserInput:IsKeyDown(Enum.KeyCode.Q) then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and Mouse.Target then
            local hrp = char.HumanoidRootPart
            hrp.CFrame = CFrame.new(Mouse.Target.Position)
        end
    end
end)


-- update highlight while holding wall key
RunService.RenderStepped:Connect(function()
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
end)
