  -- === PEŁNY KOD: ESP + AIMBOT + SMOOTH SLIDER + DISTANCE DISPLAY + LOOPFB + NOFOG ===

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local npcEspColor = BrickColor.new("Lime green")
local FOV_ANGLE = 35
local aimbotSmoothing = 0

local previousTextLabel
local brightLoop = nil
local fullBrightEnabled = false
local noFogEnabled = false
local originalFogEnd = Lighting.FogEnd
local originalAtmospheres = {}

local allowedWeapons = {
    ["AI_AK"] = true, ["igla"] = true, ["AI_RPD"] = true, ["AI_PKM"] = true,
    ["AI_SVD"] = true, ["rpg7v2"] = true, ["AI_PP19"] = true, ["AI_RPK"] = true,
    ["AI_SAIGA"] = true, ["AI_MAKAROV"] = true, ["AI_PPSH"] = true, ["AI_DB"] = true,
    ["AI_MOSIN"] = true, ["AI_VZ"] = true, ["AI_6B47_Rifleman"] = true,
    ["AI_6B45_Commander"] = true, ["AI_6B47_Commander"] = true, ["AI_6B45_Rifleman"] = true,
    ["AI_KSVK"] = true, ["AI_Chicom"] = true
}

local function saveOriginalLighting() originalAtmospheres = {} end

local function LoopFullBright()
    if brightLoop then brightLoop:Disconnect() end
    brightLoop = RunService.RenderStepped:Connect(function()
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
    end)
end

local function StopFullBright()
    if brightLoop then brightLoop:Disconnect() brightLoop = nil end
    Lighting.Brightness = 1
    Lighting.GlobalShadows = true
end

local function applyNoFog()
    Lighting.FogEnd = 100000
    for _, v in pairs(Lighting:GetDescendants()) do
        if v:IsA("Atmosphere") then
            table.insert(originalAtmospheres, v:Clone())
            v:Destroy()
        end
    end
end

local function disableNoFog()
    Lighting.FogEnd = originalFogEnd
    for _, v in pairs(originalAtmospheres) do v.Parent = Lighting end
    originalAtmospheres = {}
end

local function getDistanceToHead(head)
    return (head.Position - Camera.CFrame.Position).Magnitude
end

local function isInFOV(head)
    local dir = (head.Position - Camera.CFrame.Position).Unit
    local dot = Camera.CFrame.LookVector:Dot(dir)
    local angle = math.acos(dot) * (180 / math.pi)
    return angle <= FOV_ANGLE
end

local function displayDistance(distance)
    if previousTextLabel then
        previousTextLabel.Text = "Distance: " .. math.floor(distance) .. " Feet"
    else
        previousTextLabel = Instance.new("TextLabel")
        previousTextLabel.Parent = LocalPlayer.PlayerGui:WaitForChild("ScreenGui")
        previousTextLabel.Text = "Distance: " .. math.floor(distance) .. " Feet"
        previousTextLabel.Size = UDim2.new(0, 200, 0, 50)
        previousTextLabel.Position = UDim2.new(0.5, -100, 0.9, 0)
        previousTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        previousTextLabel.BackgroundTransparency = 1
        previousTextLabel.Font = Enum.Font.SourceSans
        previousTextLabel.TextSize = 16
    end
end

local function hasAllowedWeapon(npc)
    for weapon, _ in pairs(allowedWeapons) do
        if npc:FindFirstChild(weapon) then return true end
    end
    return false
end

local function isAlive(npc)
    for _, d in ipairs(npc:GetDescendants()) do
        if d:IsA("BallSocketConstraint") then return false end
    end
    return true
end

local function createNpcHeadESP(npc)
    local head = npc:FindFirstChild("Head")
    if head and not head:FindFirstChild("HeadESP") then
        local esp = Instance.new("BoxHandleAdornment")
        esp.Name = "HeadESP"
        esp.Adornee = head
        esp.AlwaysOnTop = true
        esp.ZIndex = 5
        esp.Size = head.Size
        esp.Transparency = 0.5
        esp.Color = npcEspColor
        esp.Parent = head
        task.spawn(function()
            while isAlive(npc) do task.wait(0.2) end
            if esp and esp.Parent then esp:Destroy() end
        end)
    end
end

for _, npc in ipairs(workspace:GetChildren()) do
    if npc:IsA("Model") and npc.Name == "Male" and hasAllowedWeapon(npc) then
        createNpcHeadESP(npc)
    end
end

workspace.ChildAdded:Connect(function(npc)
    if npc:IsA("Model") and npc.Name == "Male" then
        task.defer(function()
            if npc:FindFirstChild("Head") and hasAllowedWeapon(npc) then
                createNpcHeadESP(npc)
            end
        end)
    end
end)

local screenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
screenGui.Name = "AimbotGUI"

local label = Instance.new("TextLabel", screenGui)
label.Size = UDim2.new(0, 200, 0, 20)
label.Position = UDim2.new(0, 10, 0, 10)
label.Text = "Smoothing: 0"
label.TextColor3 = Color3.new(1,1,1)
label.BackgroundTransparency = 1
label.Font = Enum.Font.SourceSans
label.TextSize = 16

local slider = Instance.new("TextButton", screenGui)
slider.Size = UDim2.new(0, 180, 0, 20)
slider.Position = UDim2.new(0, 10, 0, 35)
slider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
slider.Text = ""
slider.AutoButtonColor = false

local fill = Instance.new("Frame", slider)
fill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
fill.Size = UDim2.new(0, 0, 1, 0)
fill.BorderSizePixel = 0

local dragging = false

local function updateSlider(x)
    local relative = math.clamp((x - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
    fill.Size = UDim2.new(relative, 0, 1, 0)
    aimbotSmoothing = math.floor(relative * 100)
    label.Text = "Smoothing: " .. aimbotSmoothing
end

slider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        updateSlider(input.Position.X)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        updateSlider(input.Position.X)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        RunService:BindToRenderStep("Aimbot", Enum.RenderPriority.Input.Value, function()
            local closestDist = math.huge
            local closestHead = nil
            for _, npc in ipairs(workspace:GetChildren()) do
                if npc:IsA("Model") and npc.Name == "Male" and hasAllowedWeapon(npc) and isAlive(npc) then
                    local head = npc:FindFirstChild("Head")
                    if head and isInFOV(head) then
                        local dist = getDistanceToHead(head)
                        if dist < closestDist then
                            closestDist = dist
                            closestHead = head
                        end
                    end
                end
            end
            if closestHead then
                displayDistance(closestDist)
                local screenPos = Camera:WorldToViewportPoint(closestHead.Position)
                local mousePos = UserInputService:GetMouseLocation()
                local dx = screenPos.X - mousePos.X
                local dy = screenPos.Y - mousePos.Y
                local smoothing = math.clamp(aimbotSmoothing, 0, 100) / 100
                local moveX = dx * (1 - smoothing)
                local moveY = dy * (1 - smoothing)
                if mousemoverel and (math.abs(moveX) > 1 or math.abs(moveY) > 1) then
    mousemoverel(moveX, moveY)
end
            end
        end)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        RunService:UnbindFromRenderStep("Aimbot")
    end
end)

local function CreateToggleButton()
    local gui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
    gui.Name = "LightingControls"

    local container = Instance.new("Frame", gui)
    container.Size = UDim2.new(0, 200, 0, 100)
    container.Position = UDim2.new(0, 10, 0.5, -50)
    container.BackgroundTransparency = 0.7
    container.BackgroundColor3 = Color3.new(0, 0, 0)

    local loopFBButton = Instance.new("TextButton", container)
    loopFBButton.Size = UDim2.new(0.9, 0, 0.4, 0)
    loopFBButton.Position = UDim2.new(0.05, 0, 0.05, 0)
    loopFBButton.Text = "LoopFullBright: OFF"
    loopFBButton.TextColor3 = Color3.new(1, 1, 1)
    loopFBButton.BackgroundColor3 = Color3.new(0.3, 0, 0)

    local noFogButton = Instance.new("TextButton", container)
    noFogButton.Size = UDim2.new(0.9, 0, 0.4, 0)
    noFogButton.Position = UDim2.new(0.05, 0, 0.55, 0)
    noFogButton.Text = "NoFog: OFF"
    noFogButton.TextColor3 = Color3.new(1, 1, 1)
    noFogButton.BackgroundColor3 = Color3.new(0.3, 0, 0)

    loopFBButton.MouseButton1Click:Connect(function()
        fullBrightEnabled = not fullBrightEnabled
        if fullBrightEnabled then
            LoopFullBright()
            loopFBButton.Text = "LoopFullBright: ON"
            loopFBButton.BackgroundColor3 = Color3.new(0, 0.5, 0)
        else
            StopFullBright()
            loopFBButton.Text = "LoopFullBright: OFF"
            loopFBButton.BackgroundColor3 = Color3.new(0.3, 0, 0)
        end
    end)

    noFogButton.MouseButton1Click:Connect(function()
        noFogEnabled = not noFogEnabled
        if noFogEnabled then
            applyNoFog()
            noFogButton.Text = "NoFog: ON"
            noFogButton.BackgroundColor3 = Color3.new(0, 0.5, 0)
        else
            disableNoFog()
            noFogButton.Text = "NoFog: OFF"
            noFogButton.BackgroundColor3 = Color3.new(0.3, 0, 0)
        end
    end)
end

saveOriginalLighting()
CreateToggleButton()
