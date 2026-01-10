-- Moon Hub UI (Merged with Instant Steal Logic)
-- Theme: Dark/Snow with Smooth Bypass
-- Features: Instant Steal (Notify -> Kick), Waypoint, Noclip

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- SMOOTH BYPASS (User Provided)
-- ==========================================
local lastCF, stopBypass = nil, false
local heartbeatConnection, cframeConnection
local bypassRunning = false

local function StopBypass()
    if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
    if cframeConnection then cframeConnection:Disconnect(); cframeConnection = nil end
    bypassRunning = false; lastCF = nil
end

local function StartBypass()
    if bypassRunning then return end
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass('Humanoid'); if not hum then return end
    local hrp = hum.RootPart or char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end
    
    lastCF = hrp.CFrame; bypassRunning = true
    heartbeatConnection = RunService.Heartbeat:Connect(function() 
        if not stopBypass and hrp and hrp.Parent then lastCF = hrp.CFrame end 
    end)
    cframeConnection = hrp:GetPropertyChangedSignal('CFrame'):Connect(function()
        if not stopBypass and lastCF then
            local dist = (hrp.Position - lastCF.Position).Magnitude
            if dist > 5 then
                stopBypass = true; hrp.CFrame = lastCF; RunService.Heartbeat:Wait(); stopBypass = false
            end
        end
    end)
    hum.Died:Connect(function() StopBypass() end)
end

-- Desync Logic
local DesyncVisuals = {Clone = nil, Line = nil, Label = nil}
local function handleDesync(v)
    -- CLEANUP FIRST (Always clean up to prevent duplicates)
    if DesyncVisuals.Clone then DesyncVisuals.Clone:Destroy(); DesyncVisuals.Clone = nil end
    if DesyncVisuals.Line then DesyncVisuals.Line:Destroy(); DesyncVisuals.Line = nil end
    for _, obj in pairs(workspace:GetChildren()) do
        if obj.Name == "FakeDesyncClone" then obj:Destroy() end
    end

    if v then
        local char = LocalPlayer.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        StartBypass()
        local originalCF = hrp.CFrame
        stopBypass = true
        
        -- Desync TP (Random far away)
        hrp.CFrame = originalCF * CFrame.new(math.random(-500, 500), math.random(500, 1000), math.random(-500, 500)) 
        task.wait(0.15)
        hrp.CFrame = originalCF
        stopBypass = false
        
        -- Create Visual Clone
        char.Archivable = true
        local clone = char:Clone()
        clone.Parent = workspace
        clone.Name = "FakeDesyncClone"
        
        for _, part in pairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = true
                part.CanCollide = false
                part.Transparency = 0.5
                part.Color = Color3.new(1, 1, 1)
                if part:FindFirstChildOfClass("SpecialMesh") then part:FindFirstChildOfClass("SpecialMesh").TextureId = "" end
            elseif part:IsA("Decal") or part:IsA("Texture") or part:IsA("Script") or part:IsA("LocalScript") then
                part:Destroy()
            end
        end
        clone:SetPrimaryPartCFrame(originalCF * CFrame.new(6, 0, 6)) -- Offset visualization slightly
        
        local h = Instance.new("Highlight", clone); h.FillColor = Color3.new(1, 1, 1); h.OutlineColor = Color3.new(1, 1, 1); h.FillTransparency = 0.5; h.OutlineTransparency = 0
        local bgui = Instance.new("BillboardGui", clone:FindFirstChild("Head") or clone.PrimaryPart)
        bgui.Size = UDim2.new(0, 200, 0, 50); bgui.AlwaysOnTop = true; bgui.ExtentsOffset = Vector3.new(0, 4, 0)
        local label = Instance.new("TextLabel", bgui); label.Size = UDim2.new(1, 0, 1, 0); label.BackgroundTransparency = 1; label.Text = "Desync Position"; label.TextColor3 = Color3.new(1, 1, 1); label.Font = Enum.Font.GothamBold; label.TextSize = 20
        
        local att0 = Instance.new("Attachment", hrp); att0.Position = Vector3.new(0, -3, 0) 
        local att1 = Instance.new("Attachment", clone.PrimaryPart or clone:FindFirstChild("HumanoidRootPart"))
        local beam = Instance.new("Beam", hrp); beam.Attachment0 = att0; beam.Attachment1 = att1; beam.Width0 = 0.2; beam.Width1 = 0.2; beam.Color = ColorSequence.new(Color3.new(1, 1, 1)); beam.FaceCamera = true
        
        DesyncVisuals.Clone = clone
        DesyncVisuals.Line = beam
        DesyncVisuals.Label = bgui
    else
        StopBypass()
    end
end

-- State Tracking
local stealEnabled = false
-- noclipEnabled is defined below

-- Dynamic Bypass Management
local function UpdateBypassState()
    if noclipEnabled or stealEnabled then
         StartBypass()
    else
         StopBypass()
    end
end

-- ==========================================
-- STEAL LOGIC (Preserved)
-- ==========================================

local noclipEnabled = false
local noclipConnection = nil
local stealConnection = nil

local function setNoclip(state)
    noclipEnabled = state
    
    if state then
        StartBypass() -- User Request: Active CE bypass AVANT
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                if LocalPlayer.Character then
                    for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
                        if v:IsA("BasePart") and v.CanCollide then
                            v.CanCollide = false
                        end
                    end
                end
            end)
        end
    else
        if not stealEnabled then -- Only stop if not used by Instant Steal
            StopBypass() 
        end
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end

-- Helper: Find My Plot
local function FindMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in pairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign then
            local yb = sign:FindFirstChild("YourBase")
            if yb then
                -- Safe Visibility Check
                if yb:IsA("LayerCollector") then -- BillboardGui, SurfaceGui, ScreenGui
                    if yb.Enabled then return plot end
                elseif yb:IsA("GuiObject") then -- TextLabel, Frame, etc.
                    if yb.Visible then return plot end
                elseif yb:IsA("BasePart") then
                    if yb.Transparency < 1 then return plot end
                end
            end
        end
    end
    return nil
end

-- Default Drop Position (Fallback if no base found)
local DefaultDropPos = Vector3.new(-331.489, -4.593, 94.692)

local function teleportToWaypoint(itemName)
    -- Determine Target Position (Auto Base Detection)
    local destCFrame = nil
    local myPlot = FindMyPlot()
    
    if myPlot then
        local cashFolder = myPlot:FindFirstChild("CashPad") -- User requested: .CashPad instead of .Cash
        if cashFolder then
            local children = cashFolder:GetChildren()
            if #children >= 2 then
                -- User requested: .Cash:GetChildren()[2]
                local targetPart = children[2]
                if targetPart and targetPart:IsA("BasePart") then
                    -- "sane tp plus a la parts masi dazn sl base a linbterueur" -> Height/Offset issue.
                    -- 1. Using 180 degrees (Behind).
                    -- 2. Increasing Height (Y+6) to avoid clipping inside.
                    destCFrame = targetPart.CFrame * CFrame.Angles(0, math.pi, 0) + Vector3.new(0, 6, 0)
                end
            end
        end
    end
    
    if not destCFrame then
        -- Fallback to default if detection fails
        destCFrame = CFrame.new(DefaultDropPos) + Vector3.new(0, 2, 0)
    end
    
    -- Notification & Kick (INVERTED: Notify -> Kick -> Cleanup)
    if itemName then
        -- Notification (Instant with TP)
        task.delay(0, function()
            local success, event = pcall(function() return ReplicatedStorage.Packages.Net["RE/NotificationService/Notify"] end)
            if success and event and firesignal then
                firesignal(event.OnClientEvent, "You stole <zebra>" .. itemName .. "</zebra>", 5, "Sounds.Sfx.Success", nil, nil, nil, nil)
            end
        end)
        
        -- KICK FIRST (At T+0.25s)
        task.delay(0.25, function() 
             LocalPlayer:Kick("You stole " .. itemName .. " ggs")
        end)
    end
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = LocalPlayer.Character.HumanoidRootPart
    
    -- Temp Noclip
    local wasNoclip = noclipEnabled
    if not noclipEnabled then setNoclip(true) end
    
    -- NUCLEAR CLEANUP LOOP (Delayed to T+0.81s - 0.56s After Kick)
    task.delay(0.81, function()
        task.spawn(function()
            local startTime = tick()
            local connection
            connection = RunService.RenderStepped:Connect(function()
                if tick() - startTime > 2 then
                    if connection then connection:Disconnect() end
                    return
                end

                -- Destroy Workspace Models (except Player/Baseplate/etc)
                for _, v in pairs(workspace:GetChildren()) do
                    if v:IsA("Model") and v ~= LocalPlayer.Character then 
                        if v.Name ~= "Workspace" and v.Name ~= "Camera" then
                            pcall(function() v:Destroy() end)
                        end
                    end
                    if v:IsA("Tool") or v:IsA("Accessory") then
                        pcall(function() v:Destroy() end)
                    end
                end
                
                -- Destroy Character Items
                if LocalPlayer.Character then
                    for _, child in pairs(LocalPlayer.Character:GetChildren()) do
                        if child:IsA("Tool") or (child:IsA("Model") and child.Name ~= "HumanoidRootPart" and child.Name ~= "Head") then
                             pcall(function() child:Destroy() end)
                        end
                    end
                    
                    -- Stop Animations (Remove Hand Up Pose)
                    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
                    if hum then
                        for _, track in pairs(hum:GetPlayingAnimationTracks()) do
                            track:Stop()
                        end
                    end
                end
            end)
        end)
    end)
    
    -- Force TP with Bypass Pause & Anti-Ragdoll
    stopBypass = true
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    for i = 1, 5 do
        hrp.CFrame = destCFrame
        hrp.Velocity = Vector3.new(0,0,0)
        if hum then
             hum.PlatformStand = false
             hum.Sit = false
        end
        RunService.Heartbeat:Wait()
    end
    if hum then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
    stopBypass = false
    
    -- Visuals Removed (No Fake Model)
    
    -- Drop/Unequip Logic (After TP) -> (This block was partially redundant or needed)
    if hum then -- Reuse hum
        hum:UnequipTools()
    end
    
    -- Smart Detach Loop (Persistent for 1s)
    task.spawn(function()
        local function GetConnectedModels(char)
            local models = {}
            -- 1. Scan for specific itemName (Primary Target)
            if itemName then
                -- Try Recursive match for itemName
                local namedCallback = char:FindFirstChild(itemName, true) 
                if namedCallback then
                     if namedCallback:IsA("Model") then
                         models[namedCallback] = "NamedMatch"
                     elseif namedCallback.Parent:IsA("Model") and namedCallback.Parent ~= char then
                         models[namedCallback.Parent] = "NamedMatch"
                     end
                end
            end

            -- 2. General Scan (Fallback)
            for _, desc in pairs(char:GetDescendants()) do
                if desc:IsA("Weld") or desc:IsA("WeldConstraint") or desc:IsA("Motor6D") or desc:IsA("ManualWeld") or desc:IsA("Snap") then
                    local p0, p1 = desc.Part0, desc.Part1
                    if p0 and p1 then
                        local model = nil
                        if p0:IsDescendantOf(char) and not p1:IsDescendantOf(char) then
                            model = p1:FindFirstAncestorOfClass("Model")
                        elseif p1:IsDescendantOf(char) and not p0:IsDescendantOf(char) then
                            model = p0:FindFirstAncestorOfClass("Model")
                        end
                        
                        if model and model ~= char and not models[model] and model.Name ~= "Workspace" then
                            models[model] = desc 
                        end
                    end
                end
            end
            return models
        end

        for i = 1, 60 do -- Run for ~1 second
            if not LocalPlayer.Character then break end
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum then hum:UnequipTools() end

            local attached = GetConnectedModels(LocalPlayer.Character)
            for model, joint in pairs(attached) do
                -- 1. Break ALL connections to Character
                if typeof(joint) == "Instance" then joint:Destroy() end
                
                for _, desc in pairs(LocalPlayer.Character:GetDescendants()) do
                     if (desc:IsA("JointInstance") or desc:IsA("WeldConstraint")) then
                         local p0, p1 = desc.Part0, desc.Part1
                         if (p0 and p0:IsDescendantOf(model)) or (p1 and p1:IsDescendantOf(model)) then
                             desc:Destroy()
                         end
                     end
                end
                
                -- 2. HIDE REAL MODEL (Send to Sky + Transparency)
                model.Parent = workspace
                
                local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
                if primary then
                    -- Send high up so user doesn't see it stuck to hand
                    primary.CFrame = CFrame.new(0, 100000, 0)
                    primary.Velocity = Vector3.new(0, 100, 0)
                    primary.RotVelocity = Vector3.new(0,0,0)
                end
                
                for _, p in pairs(model:GetDescendants()) do
                     if p:IsA("BasePart") then
                         p.Anchored = false
                         p.CanCollide = false
                         p.Massless = true
                         p.Transparency = 1 -- Hide visual
                         if not primary then p.CFrame = CFrame.new(0, 100000, 0) end
                     elseif p:IsA("Decal") or p:IsA("Texture") then
                         p.Transparency = 1
                     elseif p:IsA("BillboardGui") or p:IsA("SurfaceGui") then
                         p.Enabled = false
                     end
                end
            end
            
            RunService.Heartbeat:Wait()
        end
    end)
    
    -- Notification & Kick (Moved Up)
    
    if not wasNoclip then
        task.delay(0.5, function() setNoclip(false) end)
    end
end

-- ==========================================
-- MODERN UI IMPLEMENTATION (Undetectable + Dark Theme)
-- ==========================================

local HttpService = game:GetService("HttpService")

-- 1. Stealth / Security
local function randomString()
    return HttpService:GenerateGUID(false)
end

local function getParent()
    local success, parent = pcall(function() return gethui() end)
    if not success or not parent then
        parent = CoreGui
    end
    return parent
end

local function protect(instance)
    if syn and syn.protect_gui then
        pcall(function() syn.protect_gui(instance) end)
    end
end

-- 2. Theme Configuration
local Theme = {
    MainBg = Color3.fromRGB(15, 15, 20),       -- Very Dark Blue/Black
    SidebarBg = Color3.fromRGB(20, 20, 25),    -- Slightly Lighter Sidebar
    CardBg = Color3.fromRGB(25, 25, 30),       -- Card Background
    TextPrimary = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(150, 150, 160),
    Accent = Color3.fromRGB(100, 255, 100),    -- Green Accent (like image)
    ToggleOff = Color3.fromRGB(60, 60, 70),
    Divider = Color3.fromRGB(40, 40, 50)
}

-- 3. UI Helper Library
local Library = {}

function Library:CreateWindow(titleText)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = randomString()
    ScreenGui.Parent = getParent()
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protect(ScreenGui)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = randomString()
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Theme.MainBg
    MainFrame.Position = UDim2.new(0.5, -225, 0.5, -150)
    MainFrame.Size = UDim2.new(0, 500, 0, 320) -- Wider for Dashboard feel
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame
    
    -- SNOW EFFECT
    task.spawn(function()
        local SnowContainer = Instance.new("Frame", MainFrame)
        SnowContainer.Size = UDim2.new(1, 0, 1, 0)
        SnowContainer.BackgroundTransparency = 1
        SnowContainer.ZIndex = 0 -- Very back
        SnowContainer.Name = "SnowFX"
        
        while MainFrame.Parent do
            local flake = Instance.new("Frame", SnowContainer)
            flake.BackgroundColor3 = Color3.fromRGB(200, 200, 255)
            flake.BackgroundTransparency = math.random(50, 90) / 100
            flake.BorderSizePixel = 0
            local size = math.random(2, 4)
            flake.Size = UDim2.new(0, size, 0, size)
            
            local startX = math.random(0, 500)
            flake.Position = UDim2.new(0, startX, 0, -10)
            Instance.new("UICorner", flake).CornerRadius = UDim.new(1, 0)
            
            local duration = math.random(20, 50) / 10
            local endX = startX + math.random(-30, 30)
            
            local tw = TweenService:Create(flake, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Position = UDim2.new(0, endX, 1, 10), BackgroundTransparency = 1})
            tw:Play()
            tw.Completed:Connect(function() flake:Destroy() end)
            
            task.wait(math.random(1, 3) / 10)
        end
    end)
    
    -- Dragging
    local dragging, dragStart, startPos
    local dragInput
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- Sidebar
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = randomString()
    Sidebar.Parent = MainFrame
    Sidebar.BackgroundColor3 = Theme.SidebarBg
    Sidebar.Size = UDim2.new(0, 140, 1, 0)
    Sidebar.BorderSizePixel = 0
    
    local Title = Instance.new("TextLabel")
    Title.Parent = Sidebar
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 15, 0, 15)
    Title.Size = UDim2.new(1, -30, 0, 25)
    Title.Font = Enum.Font.GothamBold
    Title.Text = titleText
    Title.TextColor3 = Theme.TextPrimary
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local DiscordLink = Instance.new("TextLabel")
    DiscordLink.Parent = Sidebar
    DiscordLink.BackgroundTransparency = 1
    DiscordLink.Position = UDim2.new(0, 15, 0, 35)
    DiscordLink.Size = UDim2.new(1, -30, 0, 15)
    DiscordLink.Font = Enum.Font.Gotham
    DiscordLink.Text = "discord.gg/CPRcAfDfMZ"
    DiscordLink.TextColor3 = Color3.fromRGB(88, 101, 242) -- Discord Blue
    DiscordLink.TextSize = 10
    DiscordLink.TextXAlignment = Enum.TextXAlignment.Left
    

    
    -- Profile Section (Bottom Left)
    local ProfileFrame = Instance.new("Frame")
    ProfileFrame.Parent = Sidebar
    ProfileFrame.BackgroundTransparency = 1
    ProfileFrame.Position = UDim2.new(0, 0, 1, -50)
    ProfileFrame.Size = UDim2.new(1, 0, 0, 50)
    
    local Avatar = Instance.new("ImageLabel")
    Avatar.Parent = ProfileFrame
    Avatar.BackgroundColor3 = Color3.fromRGB(40,40,40)
    Avatar.Position = UDim2.new(0, 15, 0, 8)
    Avatar.Size = UDim2.new(0, 32, 0, 32)
    Instance.new("UICorner", Avatar).CornerRadius = UDim.new(1, 0) -- Circle
    pcall(function()
        Avatar.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)
    
    local NameLabel = Instance.new("TextLabel")
    NameLabel.Parent = ProfileFrame
    NameLabel.BackgroundTransparency = 1
    NameLabel.Position = UDim2.new(0, 55, 0, 8)
    NameLabel.Size = UDim2.new(1, -60, 0, 16)
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.Text = LocalPlayer.Name
    NameLabel.TextColor3 = Theme.TextPrimary
    NameLabel.TextSize = 12
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- RankLabel Removed as requested
    
    -- Content Area
    local Content = Instance.new("ScrollingFrame")
    Content.Name = randomString()
    Content.Parent = MainFrame
    Content.BackgroundColor3 = Theme.MainBg
    Content.BackgroundTransparency = 1
    Content.Position = UDim2.new(0, 150, 0, 15)
    Content.Size = UDim2.new(1, -160, 1, -30)
    Content.ScrollBarThickness = 2
    Content.ScrollBarImageColor3 = Theme.Accent
    Content.BorderSizePixel = 0
    Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Content.CanvasSize = UDim2.new(0,0,0,0)
    
    local UIList = Instance.new("UIListLayout")
    UIList.Parent = Content
    UIList.Padding = UDim.new(0, 10)
    UIList.SortOrder = Enum.SortOrder.LayoutOrder
    

    
    -- Fake Tab Button
    local TabBtn = Instance.new("TextButton")
    TabBtn.Parent = Sidebar
    TabBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    TabBtn.Position = UDim2.new(0, 10, 0, 80) -- Manual pos roughly
    TabBtn.Size = UDim2.new(0, 120, 0, 30)
    TabBtn.Font = Enum.Font.GothamBold
    TabBtn.Text = "Main"
    TabBtn.TextColor3 = Theme.TextPrimary
    TabBtn.TextSize = 12
    Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)
    
    return {
        Content = Content,
        ScreenGui = ScreenGui
    }
end

function Library:CreateCard(parent, title)
    local Card = Instance.new("Frame")
    Card.Name = randomString()
    Card.Parent = parent
    Card.BackgroundColor3 = Theme.CardBg
    Card.Size = UDim2.new(1, 0, 0, 0) -- Auto height
    Card.AutomaticSize = Enum.AutomaticSize.Y
    Card.BorderSizePixel = 0
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Card
    
    local Label = Instance.new("TextLabel")
    Label.Parent = Card
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 12, 0, 8)
    Label.Size = UDim2.new(1, -24, 0, 20)
    Label.Font = Enum.Font.GothamBold
    Label.Text = title
    Label.TextColor3 = Theme.TextSecondary
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local Container = Instance.new("Frame")
    Container.Parent = Card
    Container.BackgroundTransparency = 1
    Container.Position = UDim2.new(0, 0, 0, 30)
    Container.Size = UDim2.new(1, 0, 0, 0)
    Container.AutomaticSize = Enum.AutomaticSize.Y
    
    local Grid = Instance.new("UIListLayout")
    Grid.Parent = Container
    Grid.Padding = UDim.new(0, 0) -- No padding between items
    Grid.SortOrder = Enum.SortOrder.LayoutOrder
    
    local Pad = Instance.new("UIPadding")
    Pad.Parent = Container
    Pad.PaddingBottom = UDim.new(0, 10)
    
    return Container
end

function Library:CreateToggle(parent, text, default, callback)
    local Item = Instance.new("Frame")
    Item.Name = randomString()
    Item.Parent = parent
    Item.BackgroundTransparency = 1
    Item.Size = UDim2.new(1, 0, 0, 32)
    
    local Label = Instance.new("TextLabel")
    Label.Parent = Item
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 15, 0, 0)
    Label.Size = UDim2.new(0.6, 0, 1, 0)
    Label.Font = Enum.Font.Gotham
    Label.Text = text
    Label.TextColor3 = Theme.TextPrimary
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local SwitchBg = Instance.new("Frame")
    SwitchBg.Parent = Item
    SwitchBg.BackgroundColor3 = default and Theme.Accent or Theme.ToggleOff
    SwitchBg.Position = UDim2.new(1, -45, 0.5, -9)
    SwitchBg.Size = UDim2.new(0, 34, 0, 18)
    SwitchBg.BorderSizePixel = 0
    
    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(1, 0)
    SwitchCorner.Parent = SwitchBg
    
    local Dot = Instance.new("Frame")
    Dot.Parent = SwitchBg
    Dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Dot.Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    Dot.Size = UDim2.new(0, 14, 0, 14)
    Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)
    
    local Button = Instance.new("TextButton")
    Button.Parent = Item
    Button.BackgroundTransparency = 1
    Button.Size = UDim2.new(1, 0, 1, 0)
    Button.Text = ""
    
    local toggled = default
    Button.MouseButton1Click:Connect(function()
        toggled = not toggled
        
        -- Animation
        local goalColor = toggled and Theme.Accent or Theme.ToggleOff
        local goalPos = toggled and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        
        TweenService:Create(SwitchBg, TweenInfo.new(0.2), {BackgroundColor3 = goalColor}):Play()
        TweenService:Create(Dot, TweenInfo.new(0.2), {Position = goalPos}):Play()
        
        callback(toggled)
    end)
    
    return Item
end

-- ==========================================
-- BUILD UI
-- ==========================================

local Window = Library:CreateWindow("Moon Hub")

-- Card 1: Exploits
local ExploitsCard = Library:CreateCard(Window.Content, "Exploits")

Library:CreateToggle(ExploitsCard, "Noclip Bypass", false, function(v)
    setNoclip(v)
end)

Library:CreateToggle(ExploitsCard, "No Tool Desync", false, handleDesync)

Library:CreateToggle(ExploitsCard, "Instant Steal", false, function(v)
    stealEnabled = v
    UpdateBypassState()
    
    if v then
        local success, event = pcall(function() return ReplicatedStorage.Packages.Net["RE/NotificationService/Notify"] end)
        if success and event then
            stealConnection = event.OnClientEvent:Connect(function(...)
                local args = {...}
                local detectedName = nil
                for _, val in pairs(args) do
                    if typeof(val) == "string" and string.find(val, "Sounds.Animals") then
                        local parts = string.split(val, ".")
                        detectedName = (parts and #parts >= 3) and parts[3] or "Unknown"
                        break
                    end
                end
                
                if detectedName then
                   teleportToWaypoint(detectedName)
                end
            end)
        end
    else
        if stealConnection then stealConnection:Disconnect() stealConnection = nil end
    end
end)

-- Card 2: Visuals
local VisualsCard = Library:CreateCard(Window.Content, "Base Visuals")

local plotHighlight = nil
Library:CreateToggle(VisualsCard, "Base Red", false, function(v)
    if v then
        local plot = FindMyPlot()
        if plot then
            -- Create Highlight
            if plotHighlight then plotHighlight:Destroy() end
            plotHighlight = Instance.new("Highlight")
            plotHighlight.Name = randomString()
            plotHighlight.Adornee = plot
            plotHighlight.FillColor = Color3.fromRGB(255, 0, 0)
            plotHighlight.OutlineColor = Color3.fromRGB(255, 100, 100)
            plotHighlight.FillTransparency = 0.5
            plotHighlight.OutlineTransparency = 0
            
            -- Parent safely
            plotHighlight.Parent = getParent() 
        end
    else
        if plotHighlight then
            plotHighlight:Destroy()
            plotHighlight = nil
        end
    end
end)

print("Moon Hub UI Loaded (Modern)")
