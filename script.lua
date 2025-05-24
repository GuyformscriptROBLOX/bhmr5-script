-- Aimbot + ESP for Roblox NPCs closest to crosshair
-- Includes smoothing and distance display

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local npcEspColor = BrickColor.new("Lime green")
local aimbotSmoothing = 0
local aimbotFOV = 200 -- max screen distance from crosshair to lock target

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

local function saveOriginalLighting()
    originalAtmospheres = {}
end

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

local function hasAllowedWeapon(npc)
    for weapon in pairs(allowedWeapons) do
        if npc:FindFirstChild(weapon) then
            return true
        end
    end
    return false
end

local function isAlive(npc)
    for _, d in ipairs(npc:GetDescendants()) do
        if d:IsA("BallSocketConstraint") then
            return false
        end
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

-- === AIMBOT ===
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
    end
end)

RunService.RenderStepped:Connect(function()
    if not aiming then return end

    local closestHead = nil
    local closestDist = aimbotFOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, npc in ipairs(workspace:GetChildren()) do
        if npc:IsA("Model") and npc.Name == "Male" and hasAllowedWeapon(npc) and isAlive(npc) then
            local head = npc:FindFirstChild("Head")
            if head then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestHead = head
                    end
                end
            end
        end
    end

    if closestHead then
        local screenPos = Camera:WorldToViewportPoint(closestHead.Position)
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

-- === GUI ===
local gui = Instance.new("ScreenGui")
gui.Name = "AimbotESPGui"
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- === Slider Function ===
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

createSlider("Smoothing", 100, aimbotSmoothing, 100, function(val)
    aimbotSmoothing = val
end)

createSlider("FOV", 60, aimbotFOV, 200, function(val)
    aimbotFOV = val
end)

-- === No Fog & FullBright Buttons ===
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
