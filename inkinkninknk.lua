assert(Config, "[ESP] Config table is missing!")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ESPObjects = {}
local DrawObjects = {}

local function AddHighlight(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    if not ESPObjects[player] then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = char
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.FillColor = Config.HighlightFillColor
        highlight.OutlineColor = Config.HighlightOutlineColor
        highlight.Parent = game.CoreGui
        ESPObjects[player] = highlight
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

    DrawObjects[player] = {Box = box, Tracer = tracer, Name = nameTag}
end

RunService.RenderStepped:Connect(function()
    for player, highlight in pairs(ESPObjects) do
        if highlight and highlight.Adornee and highlight.Adornee.Parent then
            highlight.Enabled = Config.HighlightEnabled
            highlight.FillColor = Config.HighlightFillColor
            highlight.OutlineColor = Config.HighlightOutlineColor
        end
    end

    for player, objs in pairs(DrawObjects) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        if hrp and head then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            if Config.BoxEnabled and onScreen then
                objs.Box.Visible = true
                objs.Box.Size = Vector2.new(50, 100)
                objs.Box.Position = Vector2.new(pos.X - 25, pos.Y - 50)
            else
                objs.Box.Visible = false
            end
            if Config.TracerEnabled and onScreen then
                objs.Tracer.Visible = true
                objs.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                objs.Tracer.To = Vector2.new(pos.X, pos.Y)
            else
                objs.Tracer.Visible = false
            end
            if Config.NameEnabled and onScreen then
                objs.Name.Visible = true
                objs.Name.Text = player.Name
                objs.Name.Position = Vector2.new(headPos.X, headPos.Y - 20)
            else
                objs.Name.Visible = false
            end
        else
            objs.Box.Visible = false
            objs.Tracer.Visible = false
            objs.Name.Visible = false
        end
    end
end)


Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        AddHighlight(player)
        AddDrawESP(player)
    end)
end)

Players.PlayerRemoving:Connect(RemoveESP)

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        AddHighlight(player)
        AddDrawESP(player)
    end
end


if LocalPlayer.Character then
    for _, part in ipairs(LocalPlayer.Character:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.BrickColor = Config.SkinTone
        end
    end
end


local function WalkBurst()
    if not Config.BurstEnabled then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = Config.WalkBurstSpeed
        task.delay(0.5, function()
            hum.WalkSpeed = 16
        end)
    end
end


game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.V then
        WalkBurst()
    end
end)
