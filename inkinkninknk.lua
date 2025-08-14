local Config = getgenv().Config
assert(Config)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserInput = game:GetService("UserInputService")

local ESPObjects = {}
local DrawObjects = {}
local toggledSpeed = false
local savedSpeed = 16

local function PrintLoading()
    local barLength = 20
    for i = 0, barLength do
        local fill = string.rep("=", i)
        local empty = string.rep(" ", barLength - i)
        print(string.format("[%-20s] %d%%", fill..empty, math.floor((i/barLength)*100)))
        task.wait(0.25)
    end
    print("[ESP] Loaded successfully!")
end
spawn(PrintLoading)

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
        highlight.Parent = game.CoreGui
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

RunService.RenderStepped:Connect(function()
    for player, highlight in pairs(ESPObjects) do
        local char = player.Character
        if char then
            highlight.Adornee = char
            highlight.Enabled = Config.HighlightEnabled
            highlight.FillColor = Config.HighlightFillColor
            highlight.OutlineColor = Config.HighlightOutlineColor
        end
    end
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
            else objs.Dead.Visible = false end
        else
            objs.Box.Visible = false
            objs.Tracer.Visible = false
            objs.Name.Visible = false
            objs.Dead.Visible = false
        end
    end
end)

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
