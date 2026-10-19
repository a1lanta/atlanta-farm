local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local VirtualUser        = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local cfg = {
	autoFarm   = false,
	antiAFK    = true,
	antiFling  = true,
	avoidMurderer = true,
	autoReset  = true,
	autoEndGame = false, -- experimental physics attempt after an automatic reset
	farmSpeed  = 30,
	loopDelay  = 0.18,
}

local stats = {
	coins   = 0,
	started = os.clock(),
}

local C = {
	bgTop    = Color3.fromRGB(58, 28, 86),
	bgBot    = Color3.fromRGB(14, 8, 22),
	card     = Color3.fromRGB(28, 18, 40),
	glass    = Color3.fromRGB(46, 30, 66),
	glassTop = Color3.fromRGB(68, 46, 94),
	accent   = Color3.fromRGB(255, 118, 20),
	accent2  = Color3.fromRGB(255, 176, 64),
	trackOff = Color3.fromRGB(72, 54, 96),
	ink      = Color3.fromRGB(255, 240, 222),
	inkSoft  = Color3.fromRGB(178, 152, 204),
}

local function corner(inst, r)
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(0, r or 8)
	u.Parent = inst
	return u
end

local function pad(inst, p)
	local u = Instance.new("UIPadding")
	u.PaddingLeft   = UDim.new(0, p)
	u.PaddingRight  = UDim.new(0, p)
	u.PaddingTop    = UDim.new(0, p)
	u.PaddingBottom = UDim.new(0, p)
	u.Parent = inst
	return u
end

local function gradient(inst, c1, c2, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rot or 90
	g.Parent = inst
	return g
end

local function stroke(inst, col, thick, trans)
	local s = Instance.new("UIStroke")
	s.Color = col
	s.Thickness = thick or 1
	s.Transparency = trans or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local function addPop(btn, down)
	local sc = Instance.new("UIScale")
	sc.Parent = btn
	local target = down or 0.9
	local function to(v)
		TweenService:Create(sc, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Scale = v }):Play()
	end
	btn.MouseButton1Down:Connect(function() to(target) end)
	btn.MouseButton1Up:Connect(function() to(1) end)
	btn.MouseLeave:Connect(function() to(1) end)
end

local guiParent = PlayerGui
do
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and hui then
		guiParent = hui
	else
		local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
		if ok2 and cg then guiParent = cg end
	end
end

for _, where in ipairs({ guiParent, PlayerGui, game:GetService("CoreGui") }) do
	pcall(function()
		for _, name in ipairs({ "HalloweenAutofarm", "SummerAutofarm", "Heatwave", "XHub" }) do
			local old = where:FindFirstChild(name)
			if old then old:Destroy() end
		end
	end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "HalloweenAutofarm"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
if not pcall(function() gui.Parent = guiParent end) then
	gui.Parent = PlayerGui
end

local WIN_W, WIN_H = 292, 340

local win = Instance.new("Frame")
win.Name = "Window"
win.AnchorPoint = Vector2.new(0, 0)
win.Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2)
win.Size = UDim2.new(0, WIN_W, 0, WIN_H)
win.BackgroundColor3 = C.card
win.BorderSizePixel = 0
win.ZIndex = 2
win.Active = true
win.ClipsDescendants = true
