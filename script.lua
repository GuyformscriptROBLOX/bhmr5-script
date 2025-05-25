-- 🔧 SERVICES
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ⚙️ SETTINGS
local aimbotSmoothing = 0
local aimbotFOV = 60
local scanCooldown = 0.15
local aimbotEnabled = true

-- 🔁 VARIABLES
local aiming = false
local currentTarget = nil
local lastScan = 0
local cachedNPCs = {}
local fullBrightEnabled = false
local noFogEnabled = false
local originalFogEnd = Lighting.FogEnd
local originalAtmospheres = {}
local createdESP = {}

-- 🎯 ALLOWED NPC WEAPONS
local allowedWeapons = {
    ["AI_AK"] = true, ["igla"] = true, ["AI_RPD"] = true, ["AI_PKM"] = true,
    ["AI_SVD"] = true, ["rpg7v2"] = true, ["AI_PP19"] = true, ["AI_RPK"] = true,
    ["AI_SAIGA"] = true, ["AI_MAKAROV"] = true, ["AI_PPSH"] = true, ["AI_DB"] = true,
    ["AI_MOSIN"] = true, ["AI_VZ"] = true, ["AI_6B47_Rifleman"] = true,
    ["AI_6B45_Commander"] = true, ["AI_6B47_Commander"] = true, ["AI_6B45_Rifleman"] = true,
    ["AI_KSVK"] = true, ["AI_Chicom"] = true, ["AI_6B26"] = true, ["AI_6B3M"] = true
}

-- 🛠️ HELPER FUNCTIONS
local function hasAllowedWeapon(npc)
    for weapon in pairs(allowedWeapons) do
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

-- 🔲 ESP
local function createNpcHeadESP(npc)
    if createdESP[npc] then return end
    local head = npc:FindFirstChild("Head")
    if head and not head:FindFirstChild("HeadESP") then
        local esp = Instance.new("BoxHandleAdornment")
        esp.Name = "HeadESP"
        esp.Adornee = head
        esp.AlwaysOnTop = true
        esp.ZIndex = 5
        esp.Size = head.Size
        esp.Transparency = 0.5
        esp.Color3 = Color3.new(0, 1, 0)
        esp.Parent = head
        createdESP[npc] = true

        task.spawn(function()
            while isAlive(npc) do task.wait(0.5) end
            if esp and esp.Parent then esp:Destroy() end
            createdESP[npc] = nil
        end)
    end
end

-- ♻️ CACHING NPCS
task.spawn(function()
    while true do
        cachedNPCs = {}
        for _, npc in ipairs(workspace:GetChildren()) do
            if npc:IsA("Model") and npc.Name == "Male" and hasAllowedWeapon(npc) and isAlive(npc) then
                local head = npc:FindFirstChild("Head")
                if head then
                    table.insert(cachedNPCs, {npc = npc, head = head})
                    createNpcHeadESP(npc)
                end
            end
        end
        task.wait(1)
    end
end)

-- ☀️ FULLBRIGHT & NOFOG
local brightLoop = nil
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

-- 👆 MOUSE
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
        currentTarget = nil
    end
end)

-- 🎯 AIMBOT
RunService.RenderStepped:Connect(function()
    if not aiming or not aimbotEnabled then
        currentTarget = nil
        return
    end

    local mousePos = UserInputService:GetMouseLocation()
    
    if tick() - lastScan > scanCooldown or not currentTarget or not currentTarget:IsDescendantOf(workspace) or not isAlive(currentTarget.Parent) then
        lastScan = tick()
        local closestDist = math.huge
        local newTarget = nil

        for _, data in ipairs(cachedNPCs) do
            local npc = data.npc
            local head = data.head

            -- Sprawdzenie poprawności head
            if head and head:IsA("BasePart") then
                local screen3D, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local screenPos = Vector2.new(screen3D.X, screen3D.Y)
                    local dist = (screenPos - Vector2.new(mousePos.X, mousePos.Y)).Magnitude

                    if dist < aimbotFOV and dist < closestDist then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                        rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}

                        local direction = (head.Position - Camera.CFrame.Position).Unit * 1000
                        local result = workspace:Raycast(Camera.CFrame.Position, direction, rayParams)

                        if result and result.Instance and result.Instance:IsDescendantOf(npc) then
                            closestDist = dist
                            newTarget = head
                        end
                    end
                end
            end
        end

        currentTarget = newTarget
    end

    -- Przesuwanie myszki do celu
    if currentTarget then
        local head = currentTarget
        if head and head:IsA("BasePart") then
            local screen3D, onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local screenPos = Vector2.new(screen3D.X, screen3D.Y)
                local dx = (screenPos.X - mousePos.X) / math.clamp(aimbotSmoothing, 0.6, 100)
                local dy = (screenPos.Y - mousePos.Y) / math.clamp(aimbotSmoothing, 0.6, 100)

                -- Upewnij się, że mousemoverel istnieje
                if typeof(mousemoverel) == "function" then
                    mousemoverel(dx, dy)
                end
            end
        end
    end
end)

-- GUI 🧃
local gui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
gui.Name = "AimbotMenu"

local function createButton(text, pos, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 120, 0, 30)
    button.Position = pos
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = text
    button.Parent = gui
    button.MouseButton1Click:Connect(function()
        callback(button)
    end)
    return button
end

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

createSlider("FOV", 60, aimbotFOV, 200, function(val) aimbotFOV = val end)

createButton("No Fog: OFF", UDim2.new(0, 20, 0, 100), function(btn)
    noFogEnabled = not noFogEnabled
    if noFogEnabled then applyNoFog() btn.Text = "No Fog: ON"
    else disableNoFog() btn.Text = "No Fog: OFF" end
end)

createButton("FullBright: OFF", UDim2.new(0, 150, 0, 100), function(btn)
    fullBrightEnabled = not fullBrightEnabled
    if fullBrightEnabled then LoopFullBright() btn.Text = "FullBright: ON"
    else StopFullBright() btn.Text = "FullBright: OFF" end
end)

createButton("Aimbot: ON", UDim2.new(0, 20, 0, 180), function(btn)
    aimbotEnabled = not aimbotEnabled
    btn.Text = aimbotEnabled and "Aimbot: ON" or "Aimbot: OFF"
end)
