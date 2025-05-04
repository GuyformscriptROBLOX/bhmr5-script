    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local Lighting = game:GetService("Lighting")
    local camera = game.Workspace.CurrentCamera

    local npcEspColor = BrickColor.new("Lime green") 
    local FOV_ANGLE = 0.01
    local previousTextLabel
    local brightLoop = nil
    local fullBrightEnabled = false
    local noFogEnabled = false
    local originalFogEnd = Lighting.FogEnd
    local originalAtmospheres = {}


    local originalLighting = {}


    local function saveOriginalLighting()
        originalLighting = {
            Ambient = Lighting.Ambient,
            Brightness = Lighting.Brightness,
            GlobalShadows = Lighting.GlobalShadows,
            Outlines = Lighting.Outlines,
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart,
            FogColor = Lighting.FogColor
        }
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
        if brightLoop then
            brightLoop:Disconnect()
            brightLoop = nil
        end
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
        for _, atmosphere in pairs(originalAtmospheres) do
            atmosphere.Parent = Lighting
        end
        originalAtmospheres = {}
    end

    local function getDistanceToHead(head)
        return (head.Position - camera.CFrame.Position).Magnitude
    end

    local function isInFOV(head)
        local rayOrigin = camera.CFrame.Position
        local directionToHead = (head.Position - rayOrigin).unit
        local dotProduct = camera.CFrame.LookVector:Dot(directionToHead)
        local angle = math.acos(dotProduct) * (180 / math.pi)
        return angle <= FOV_ANGLE
    end

    local function displayDistance(distance)
        if previousTextLabel then
            previousTextLabel.Text = "Distance: " .. math.floor(distance) .. " Feet"
        else
            previousTextLabel = Instance.new("TextLabel")
            previousTextLabel.Parent = game.Players.LocalPlayer.PlayerGui:WaitForChild("ScreenGui")
            previousTextLabel.Text = "Distance: " .. math.floor(distance) .. " Feet"
            previousTextLabel.Size = UDim2.new(0, 200, 0, 50)
            previousTextLabel.Position = UDim2.new(0.5, -100, 0.9, 0)
            previousTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            previousTextLabel.BackgroundTransparency = 1
        end
    end

    local function createNpcHeadESP(npc)
        if npc and npc:FindFirstChild("Head") and npc.Name:lower():match("male") then
            local head = npc:FindFirstChild("Head")
            if head then
                if not npc:FindFirstChild("HeadESP") then
                    local adornment = Instance.new("BoxHandleAdornment")
                    adornment.Name = "HeadESP"
                    adornment.Parent = head
                    adornment.Adornee = head
                    adornment.AlwaysOnTop = true
                    adornment.ZIndex = 5
                    adornment.Size = head.Size
                    adornment.Transparency = 0.5
                    adornment.Color = npcEspColor
                    adornment.Parent = npc
                end
            end
        end
    end

    local function removeNpcHeadESP(npc)
        local adornment = npc:FindFirstChild("HeadESP")
        if adornment then
            adornment:Destroy()
        end
    end

    workspace.DescendantAdded:Connect(function(part)
        if part:IsA("Model") and part:FindFirstChild("Head") and part.Name:lower():match("male") then
            createNpcHeadESP(part)
        end
    end)

    workspace.DescendantRemoving:Connect(function(part)
        if part:IsA("Model") and part:FindFirstChild("Head") and part.Name:lower():match("male") then
            removeNpcHeadESP(part)
        end
    end)

    local function highlightMaleHeads()
        local closestDistance = math.huge
        local closestHead = nil
        for _, object in pairs(workspace:GetChildren()) do
            if object:IsA("Model") and object.Name == "Male" then
                local head = object:FindFirstChild("Head")
                if head then
                    createNpcHeadESP(object)
                    if isInFOV(head) then
                        local distance = getDistanceToHead(head)
                        if distance < closestDistance then
                            closestDistance = distance
                            closestHead = head
                        end
                    end
                end
            end
        end
        if closestHead then
            displayDistance(closestDistance)
        end
    end

    game:GetService("RunService").Heartbeat:Connect(function()
        highlightMaleHeads()
    end)

    local function CreateToggleButton()
        local player = Players.LocalPlayer
        local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
        gui.Name = "LightingControls"

        local container = Instance.new("Frame")
        container.Size = UDim2.new(0, 200, 0, 100)
        container.Position = UDim2.new(0, 10, 0.5, -50)
        container.BackgroundTransparency = 0.7
        container.BackgroundColor3 = Color3.new(0, 0, 0)
        container.Parent = gui

        local loopFBButton = Instance.new("TextButton")
        loopFBButton.Size = UDim2.new(0.9, 0, 0.4, 0)
        loopFBButton.Position = UDim2.new(0.05, 0, 0.05, 0)
        loopFBButton.Text = "LoopFullBright: OFF"
        loopFBButton.TextColor3 = Color3.new(1, 1, 1)
        loopFBButton.BackgroundColor3 = Color3.new(0.3, 0, 0)
        loopFBButton.Parent = container

        local noFogButton = Instance.new("TextButton")
        noFogButton.Size = UDim2.new(0.9, 0, 0.4, 0)
        noFogButton.Position = UDim2.new(0.05, 0, 0.55, 0)
        noFogButton.Text = "NoFog: OFF"
        noFogButton.TextColor3 = Color3.new(1, 1, 1)
        noFogButton.BackgroundColor3 = Color3.new(0.3, 0, 0)
        noFogButton.Parent = container

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
