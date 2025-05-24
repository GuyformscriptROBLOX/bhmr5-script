-- ✅ Load Roblox services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ✅ Configuration settings
local npcEspColor = BrickColor.new("Lime green") -- Color for ESP boxes
local aimbotSmoothing = 0 -- How smoothly aim moves to target (unused in "mocarny" mode)
local aimbotFOV = 60 -- Field of view for aimbot lock-on (in screen pixels)

-- ✅ Lighting and fog management variables
local previousTextLabel
local brightLoop = nil
local fullBrightEnabled = false
local noFogEnabled = false
local originalFogEnd = Lighting.FogEnd
local originalAtmospheres = {}

-- ✅ Distance label setup
local distanceLabel = Instance.new("TextLabel")
distanceLabel.Size = UDim2.new(0, 200, 0, 30)
distanceLabel.Position = UDim2.new(0.5, -100, 0.8, 0)
distanceLabel.BackgroundColor3 = Color3.new(0, 0, 0)
distanceLabel.TextColor3 = Color3.new(1, 1, 1)
distanceLabel.TextScaled = true
distanceLabel.Visible = false
distanceLabel.Text = ""
distanceLabel.BackgroundTransparency = 0.4
distanceLabel.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- ✅ Define NPCs (enemies) that can be targeted
local allowedWeapons = {
    ["AI_AK"] = true, ["igla"] = true, ["AI_RPD"] = true, ["AI_PKM"] = true,
    ["AI_SVD"] = true, ["rpg7v2"] = true, ["AI_PP19"] = true, ["AI_RPK"] = true,
    ["AI_SAIGA"] = true, ["AI_MAKAROV"] = true, ["AI_PPSH"] = true, ["AI_DB"] = true,
    ["AI_MOSIN"] = true, ["AI_VZ"] = true, ["AI_6B47_Rifleman"] = true,
    ["AI_6B45_Commander"] = true, ["AI_6B47_Commander"] = true, ["AI_6B45_Rifleman"] = true,
    ["AI_KSVK"] = true, ["AI_Chicom"] = true
}

-- ✅ Helper to check if NPC has allowed weapon
local function hasAllowedWeapon(npc)
    for weapon in pairs(allowedWeapons) do
        if npc:FindFirstChild(weapon) then
            return true
        end
    end
    return false
end

-- ✅ Check if NPC is alive
local function isAlive(npc)
    for _, d in ipairs(npc:GetDescendants()) do
        if d:IsA("BallSocketConstraint") then
            return false
        end
    end
    return true
end

-- ✅ Check if NPC is visible (not behind a wall)
local function isVisible(npc, head)
    local origin = Camera.CFrame.Position
    local direction = head.Position - origin
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local ray = workspace:Raycast(origin, direction, rayParams)
    return ray and ray.Instance and ray.Instance:IsDescendantOf(npc)
end

-- ✅ Add ESP (visual box) to NPC's head
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

-- ✅ Add ESP to existing NPCs
for _, npc in ipairs(workspace:GetChildren()) do
    if npc:IsA("Model") and npc.Name == "Male" and hasAllowedWeapon(npc) then
        createNpcHeadESP(npc)
    end
end

-- ✅ Monitor new NPCs added to workspace
workspace.ChildAdded:Connect(function(npc)
    if npc:IsA("Model") and npc.Name == "Male" then
        task.defer(function()
            if npc:FindFirstChild("Head") and hasAllowedWeapon(npc) then
                createNpcHeadESP(npc)
            end
        end)
    end
end)

-- ✅ FullBright functions
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
    Lighting.FogEnd = originalFogEnd
end

-- ✅ No Fog functions
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
    for _, v in pairs(originalAtmospheres) do
        v.Parent = Lighting
    end
    originalAtmospheres = {}
end

-- ✅ Aimbot control toggle
local aiming = false
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aiming = true
    end
end)
UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aiming = false
        distanceLabel.Visible = false
    end
end)

-- ✅ MOCARNY Aimbot (zero smoothing, instant aim to head)
RunService.RenderStepped:Connect(function()
    if not aiming then return end

    local closestHead = nil
    local closestDist = math.huge
    local mousePos = UserInputService:GetMouseLocation()

    for _, npc in ipairs(workspace:GetChildren()) do
        if npc:IsA("Model") and npc.Name == "Male" and hasAllowedWeapon(npc) and isAlive(npc) then
            local head = npc:FindFirstChild("Head")
            if head and isVisible(npc, head) then
                local screen3D, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local screenPos = Vector2.new(screen3D.X, screen3D.Y)
                    local dist = (screenPos - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestHead = head
                    end
                end
            end
        end
    end

    if closestHead then
        local screen3D = Camera:WorldToViewportPoint(closestHead.Position)
        local screenPos = Vector2.new(screen3D.X, screen3D.Y)
        local dx = screenPos.X - mousePos.X
        local dy = screenPos.Y - mousePos.Y
        if mousemoverel then
            mousemoverel(dx, dy)
        end
    end
end)

-- ✅ GUI setup for controls
local gui = Instance.new("ScreenGui")
gui.Name = "AimbotESPGui"
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local function createSlider(text, posY, initialValue, maxValue, callback)
    local slider = Instance.new("TextButton")
    slider.Size = UDim2.new(0, 200, 0, 30)
    slider.Position = UDim2.new(0, 20, 0, posY)
    slider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    slider.TextColor3 = Color3.new(1, 1, 1)
    slider.Text = text .. ": " .. initialValue
    slider.Parent = gui

    slider.MouseButton1Down:Connect(function()
        local conn
        conn = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                local mouseX = input.Position.X
                local newValue = math.clamp((mouseX - slider.AbsolutePosition.X) / slider.AbsoluteSize.X * maxValue, 0, maxValue)
                newValue = math.floor(newValue)
                callback(newValue)
                slider.Text = text .. ": " .. newValue
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and conn then
                conn:Disconnect()
            end
        end)
    end)
end

-- ✅ Sliders for tuning FOV and smoothing
createSlider("Smoothing", 100, aimbotSmoothing, 100, function(val)
    aimbotSmoothing = val
end)

createSlider("FOV", 60, aimbotFOV, 200, function(val)
    aimbotFOV = val
end)

-- ✅ No Fog toggle button
local noFogButton = Instance.new("TextButton")
noFogButton.Size = UDim2.new(0, 100, 0, 30)
noFogButton.Position = UDim2.new(0, 20, 0, 180)
noFogButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
noFogButton.TextColor3 = Color3.new(1, 1, 1)
noFogButton.Text = "No Fog: OFF"
noFogButton.Parent = gui

noFogButton.MouseButton1Click:Connect(function()
    noFogEnabled = not noFogEnabled
    if noFogEnabled then
        applyNoFog()
        noFogButton.Text = "No Fog: ON"
    else
        disableNoFog()
        noFogButton.Text = "No Fog: OFF"
    end
end)

-- ✅ FullBright toggle button
local fullBrightButton = Instance.new("TextButton")
fullBrightButton.Size = UDim2.new(0, 100, 0, 30)
fullBrightButton.Position = UDim2.new(0, 130, 0, 180)
fullBrightButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
fullBrightButton.TextColor3 = Color3.new(1, 1, 1)
fullBrightButton.Text = "FullBright: OFF"
fullBrightButton.Parent = gui

fullBrightButton.MouseButton1Click:Connect(function()
    fullBrightEnabled = not fullBrightEnabled
    if fullBrightEnabled then
        LoopFullBright()
        fullBrightButton.Text = "FullBright: ON"
    else
        StopFullBright()
        fullBrightButton.Text = "FullBright: OFF"
    end
end)
