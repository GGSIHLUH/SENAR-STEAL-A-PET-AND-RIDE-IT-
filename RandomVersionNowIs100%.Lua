-- SENAR HUB | Steal a Pet and Ride It (UI + Scanner + Steal System)
-- Tema: merah + balok atas/bawah + kilatan cahaya putih/hitam
-- Floating icon (Asset ID) untuk buka/tutup

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

-- ================= CONFIG =================
local ICON_ASSET_ID = 94315198453864

-- ================= CLEANUP =================
local env = (getgenv and getgenv()) or _G
if env.__SenarCleanup then pcall(env.__SenarCleanup) end

-- ================= API PUBLIK =================
local UI = {
	onToggle = function(name, state) end,
	onJoin = function(entry) end,
	onCopy = function(entry) end,
	onClear = function() end,
	onKeySubmit = function(text) end,
	addLog = function() end,
	clearLogs = function() end,
	setStatus = function() end,
	destroy = function() end,
}
env.SenarUI = UI

-- ================= WARNA =================
local C = {
	RED    = Color3.fromRGB(235, 35, 60),
	RED_DK = Color3.fromRGB(110, 12, 26),
	PINK   = Color3.fromRGB(255, 140, 190),
	BG     = Color3.fromRGB(13, 8, 10),
	SIDE   = Color3.fromRGB(8, 5, 6),
	PANEL  = Color3.fromRGB(26, 15, 18),
	HOVER  = Color3.fromRGB(44, 24, 29),
	STROKE = Color3.fromRGB(100, 52, 60),
	OFF    = Color3.fromRGB(55, 40, 44),
	GRAY   = Color3.fromRGB(150, 132, 137),
	WHITE  = Color3.fromRGB(255, 255, 255),
	BLACK  = Color3.fromRGB(0, 0, 0),
}

-- ================= HELPER =================
local function make(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props) do obj[k] = v end
	obj.Parent = parent
	return obj
end

local function corner(o, r)
	return make("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end

local function randName(n)
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local t = table.create(n)
	for i = 1, n do
		local k = math.random(1, #chars)
		t[i] = chars:sub(k, k)
	end
	return table.concat(t)
end

local tweens = {}
local sweepGradients = {}

local function sweepSeq(base, hi)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, base),
		ColorSequenceKeypoint.new(0.38, base),
		ColorSequenceKeypoint.new(0.50, hi),
		ColorSequenceKeypoint.new(0.62, base),
		ColorSequenceKeypoint.new(1, base),
	})
end

local function addSweep(inst, base, hi)
	local g = make("UIGradient", { Color = sweepSeq(base, hi), Offset = Vector2.new(-1, 0) }, inst)
	sweepGradients[g] = true
	return g
end

-- garis tepi dengan kilatan putih yang menyapu
local function glowStroke(obj, th, base)
	local s = make("UIStroke", {
		Color = C.WHITE, Thickness = th or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, obj)
	addSweep(s, base or C.STROKE, C.WHITE)
	return s
end

-- garis tepi berputar: hitam / putih / merah
local function spinStroke(parent, th)
	local st = make("UIStroke", {
		Color = C.WHITE, Thickness = th or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
	local g = make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.BLACK),
			ColorSequenceKeypoint.new(0.2, C.RED),
			ColorSequenceKeypoint.new(0.35, C.WHITE),
			ColorSequenceKeypoint.new(0.5, C.BLACK),
			ColorSequenceKeypoint.new(0.7, C.RED_DK),
			ColorSequenceKeypoint.new(0.85, C.WHITE),
			ColorSequenceKeypoint.new(1, C.BLACK),
		}),
	}, st)
	local tw = TweenService:Create(g,
		TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0),
		{ Rotation = 360 })
	tw:Play()
	table.insert(tweens, tw)
	return st
end

local function tween(obj, info, props)
	local tw = TweenService:Create(obj, info, props)
	tw:Play()
	return tw
end

-- ================= GUI =================
local gui = make("ScreenGui", {
	Name = randName(14), ResetOnSpawn = false, DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

do
	local ok = pcall(function()
		gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
	end)
	if not ok or not gui.Parent then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

local conns = {}
local myCleanup = function()
	if gui and gui.Parent then gui:Destroy() end
end
env.__SenarCleanup = myCleanup
UI.destroy = myCleanup

-- driver kilatan (satu tween untuk semua gradien)
local sweepVal = make("NumberValue", { Value = -1 }, gui)
table.insert(conns, sweepVal.Changed:Connect(function(v)
	local off = Vector2.new(v, 0)
	for g in pairs(sweepGradients) do
		if g.Parent then g.Offset = off else sweepGradients[g] = nil end
	end
end))
do
	local tw = TweenService:Create(sweepVal,
		TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0),
		{ Value = 1 })
	tw:Play()
	table.insert(tweens, tw)
end

local W, H = 470, 300

-- holder (untuk posisi, drag, dan skala layar)
local holder = make("Frame", {
	Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
	BackgroundTransparency = 1,
}, gui)
local fitScale = make("UIScale", { Scale = 1 }, holder)

local function updateFit()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	fitScale.Scale = math.clamp(math.min(vp.X / (W + 30), vp.Y / (H + 30)), 0.45, 1)
end
updateFit()
if workspace.CurrentCamera then
	table.insert(conns, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFit))
end

-- window utama
local main = make("Frame", {
	Name = "Main", Size = UDim2.fromScale(1, 1),
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = C.BG, BorderSizePixel = 0, ClipsDescendants = true,
}, holder)
corner(main, 12)
local popScale = make("UIScale", { Scale = 1 }, main)
spinStroke(main, 1.5)

-- ---------- Balok atas & bawah (background) ----------
local blocks = {}
do
	local BW, GAP = 16, 4
	local count = math.floor((W - 16) / (BW + GAP))
	local rng = Random.new(7)
	for i = 1, count do
		local x = 8 + (i - 1) * (BW + GAP)
		local col = C.RED_DK:Lerp(C.RED, rng:NextNumber())
		local hTop = rng:NextInteger(7, 18)
		local hBot = rng:NextInteger(7, 18)

		local top = make("Frame", {
			Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(BW, hTop),
			BackgroundColor3 = col, BackgroundTransparency = 0.35, BorderSizePixel = 0,
		}, main)
		local bot = make("Frame", {
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(x, H),
			Size = UDim2.fromOffset(BW, hBot),
			BackgroundColor3 = col, BackgroundTransparency = 0.35, BorderSizePixel = 0,
		}, main)
		table.insert(blocks, { frame = top, base = hTop, phase = rng:NextNumber() * 6.28 })
		table.insert(blocks, { frame = bot, base = hBot, phase = rng:NextNumber() * 6.28 })
	end
	blocks.width = BW
end

-- ---------- Sidebar ----------
local side = make("Frame", {
	Position = UDim2.fromOffset(8, 24), Size = UDim2.fromOffset(124, 252),
	BackgroundColor3 = C.SIDE, BackgroundTransparency = 0.12, BorderSizePixel = 0,
}, main)
corner(side, 10)
glowStroke(side, 1)

-- judul: Senar (Se merah, nar merah muda) + Hub (rainbow)
local titleRow = make("Frame", {
	Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(108, 24),
	BackgroundTransparency = 1,
}, side)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center,
}, titleRow)

local senar = make("TextLabel", {
	Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1, Text = "Senar", TextColor3 = C.WHITE,
	Font = Enum.Font.GothamBlack, TextSize = 18, LayoutOrder = 1,
}, titleRow)
make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.RED),
		ColorSequenceKeypoint.new(0.40, C.RED),
		ColorSequenceKeypoint.new(0.44, C.PINK),
		ColorSequenceKeypoint.new(1, C.PINK),
	}),
}, senar)

local hub = make("TextLabel", {
	Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1, Text = "Hub", TextColor3 = C.WHITE,
	Font = Enum.Font.GothamBlack, TextSize = 18, LayoutOrder = 2,
}, titleRow)
local hubGrad = make("UIGradient", {}, hub)

local function rainbowSeq(t)
	local kps = {}
	for i = 0, 6 do
		kps[#kps + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((t * 0.25 + i / 6) % 1, 0.85, 1))
	end
	return ColorSequence.new(kps)
end
hubGrad.Color = rainbowSeq(0)

-- status
local dot = make("Frame", {
	Position = UDim2.fromOffset(12, 40), Size = UDim2.fromOffset(6, 6),
	BackgroundColor3 = C.WHITE, BorderSizePixel = 0,
}, side)
corner(dot, 3)
local statusLbl = make("TextLabel", {
	Position = UDim2.fromOffset(24, 34), Size = UDim2.new(1, -30, 0, 18),
	BackgroundTransparency = 1, Text = "Connected", TextColor3 = C.GRAY,
	Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, side)
UI.setStatus = function(t)
	statusLbl.Text = tostring(t)
end

-- ---------- Area konten & halaman ----------
local content = make("Frame", {
	Position = UDim2.fromOffset(140, 24), Size = UDim2.fromOffset(322, 252),
	BackgroundTransparency = 1,
}, main)

local pages, tabBtns = {}, {}
local tabNames = { "Logs", "Scanner", "History", "Settings", "System Key" }

for _, name in ipairs(tabNames) do
	pages[name] = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
	}, content)
end

local function selectTab(name)
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, t in pairs(tabBtns) do
		local on = (n == name)
		t.btn.BackgroundTransparency = on and 0.15 or 1
		t.btn.TextColor3 = on and C.WHITE or C.GRAY
		t.stroke.Enabled = on
	end
end

for i, name in ipairs(tabNames) do
	local b = make("TextButton", {
		Position = UDim2.fromOffset(8, 58 + (i - 1) * 31), Size = UDim2.fromOffset(108, 27),
		BackgroundColor3 = C.HOVER, BackgroundTransparency = 1, BorderSizePixel = 0,
		Text = name, TextColor3 = C.GRAY, Font = Enum.Font.GothamBold, TextSize = 12,
		AutoButtonColor = false,
	}, side)
	corner(b, 8)
	local st = glowStroke(b, 1)
	st.Enabled = false
	tabBtns[name] = { btn = b, stroke = st }
	b.Activated:Connect(function() selectTab(name) end)
end

-- tombol Hide
local hideBtn = make("TextButton", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.fromOffset(108, 28),
	BackgroundColor3 = C.PANEL, BorderSizePixel = 0, Text = "Hide", TextColor3 = C.WHITE,
	Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
}, side)
corner(hideBtn, 8)
glowStroke(hideBtn, 1)

-- ---------- Komponen: switch card ----------
local function makeSwitchCard(parent, name, size, pos, order)
	local card = make("Frame", {
		Size = size, Position = pos or UDim2.new(), LayoutOrder = order or 0,
		BackgroundColor3 = C.PANEL, BorderSizePixel = 0,
	}, parent)
	corner(card, 8)
	glowStroke(card, 1)

	make("TextLabel", {
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -64, 1, 0),
		BackgroundTransparency = 1, Text = name, TextColor3 = C.WHITE,
		Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	local track = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(38, 20), BackgroundColor3 = C.OFF, BorderSizePixel = 0,
	}, card)
	corner(track, 10)
	local knob = make("Frame", {
		Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = C.WHITE, BorderSizePixel = 0,
	}, track)
	corner(knob, 7)

	local overlay = make("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5,
	}, card)

	local on = false
	overlay.Activated:Connect(function()
		on = not on
		local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad)
		tween(knob, info, { Position = on and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3) })
		tween(track, info, { BackgroundColor3 = on and C.RED or C.OFF })
		local okc, err = pcall(UI.onToggle, name, on)
		if not okc then warn("[Senar Hub] onToggle: " .. tostring(err)) end
	end)
	return card
end

-- ---------- Komponen: list ----------
local function makeList(parent, size, pos)
	local s = make("ScrollingFrame", {
		Size = size, Position = pos or UDim2.new(),
		BackgroundColor3 = C.SIDE, BackgroundTransparency = 0.25, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.RED,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	}, parent)
	corner(s, 8)
	glowStroke(s, 1)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8),
	}, s)
	return s
end

local function smallButton(parent, text, pos, dim)
	local b = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = pos, Size = UDim2.fromOffset(48, 24),
		BackgroundColor3 = dim and C.HOVER or C.PANEL, BorderSizePixel = 0,
		Text = text, TextColor3 = dim and C.GRAY or C.WHITE,
		Font = Enum.Font.GothamBold, TextSize = 10, AutoButtonColor = false,
	}, parent)
	corner(b, 6)
	glowStroke(b, 1)
	return b
end

---------------------------------------------------------------------
-- HALAMAN: LOGS (Live Feed)
---------------------------------------------------------------------
do
	local p = pages.Logs
	makeSwitchCard(p, "Auto-Steal", UDim2.new(1, 0, 0, 38), UDim2.new(0, 0, 0, 0))

	make("TextLabel", {
		Position = UDim2.fromOffset(2, 46), Size = UDim2.fromOffset(100, 14),
		BackgroundTransparency = 1, Text = "LIVE FEED", TextColor3 = C.GRAY,
		Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
	}, p)

	local clearBtn = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 44), Size = UDim2.fromOffset(44, 16),
		BackgroundTransparency = 1, Text = "Clear", TextColor3 = C.WHITE,
		Font = Enum.Font.GothamBold, TextSize = 10,
	}, p)

	local list = makeList(p, UDim2.new(1, 0, 1, -64), UDim2.fromOffset(0, 64))

	local counter = 0
	UI.addLog = function(name, income, info)
		counter += 1
		local entry = {
			name = tostring(name or "Item Name"),
			income = tostring(income or "$0.0B/s"),
			info = tostring(info or "0/5 · Rarity · 0:00"),
		}

		local card = make("Frame", {
			LayoutOrder = -counter, Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = C.PANEL, BorderSizePixel = 0,
		}, list)
		corner(card, 8)
		glowStroke(card, 1)

		make("Frame", {
			Position = UDim2.fromOffset(8, 9), Size = UDim2.fromOffset(3, 34),
			BackgroundColor3 = C.WHITE, BorderSizePixel = 0,
		}, card)

		local icon = make("Frame", {
			Name = "RarityIcon",
			Position = UDim2.fromOffset(18, 11), Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = C.OFF, BorderSizePixel = 0,
		}, card)
		corner(icon, 15)

		make("TextLabel", {
			Position = UDim2.fromOffset(56, 8), Size = UDim2.new(1, -172, 0, 18),
			BackgroundTransparency = 1, Text = string.format("%s [ %s ]", entry.name, entry.income),
			TextColor3 = C.WHITE, Font = Enum.Font.GothamBold, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		}, card)
		make("TextLabel", {
			Position = UDim2.fromOffset(56, 28), Size = UDim2.new(1, -172, 0, 14),
			BackgroundTransparency = 1, Text = entry.info, TextColor3 = C.GRAY,
			Font = Enum.Font.Gotham, TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		}, card)

		local joinBtn = smallButton(card, "STEAL", UDim2.new(1, -62, 0.5, 0), false)
		joinBtn.Name = "StealBtn"
		local copyBtn = smallButton(card, "COPY", UDim2.new(1, -8, 0.5, 0), true)
		joinBtn.Activated:Connect(function()
			local okc, err = pcall(UI.onJoin, entry)
			if not okc then warn("[Senar Hub] onJoin: " .. tostring(err)) end
		end)
		copyBtn.Activated:Connect(function()
			if setclipboard then pcall(setclipboard, entry.name .. " " .. entry.income) end
			local okc, err = pcall(UI.onCopy, entry)
			if not okc then warn("[Senar Hub] onCopy: " .. tostring(err)) end
		end)
		return card, joinBtn, icon
	end

	UI.clearLogs = function()
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
	end

	clearBtn.Activated:Connect(function()
		UI.clearLogs()
		local okc, err = pcall(UI.onClear)
		if not okc then warn("[Senar Hub] onClear: " .. tostring(err)) end
	end)

	local empty = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 999999,
		Text = "Scanning...", TextColor3 = C.GRAY, Font = Enum.Font.Gotham, TextSize = 11,
	}, list)
	UI.emptyLabel = empty
end

---------------------------------------------------------------------
-- HALAMAN: HISTORY
---------------------------------------------------------------------
do
	local p = pages.History
	make("TextLabel", {
		Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(100, 14),
		BackgroundTransparency = 1, Text = "HISTORY", TextColor3 = C.GRAY,
		Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
	}, p)
	local list = makeList(p, UDim2.new(1, 0, 1, -20), UDim2.fromOffset(0, 20))
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
		Text = "Belum ada riwayat", TextColor3 = C.GRAY,
		Font = Enum.Font.Gotham, TextSize = 12,
	}, list)
end

---------------------------------------------------------------------
-- HALAMAN: SETTINGS
---------------------------------------------------------------------
do
	local p = pages.Settings
	make("TextLabel", {
		Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(100, 14),
		BackgroundTransparency = 1, Text = "SETTINGS", TextColor3 = C.GRAY,
		Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
	}, p)
	local list = makeList(p, UDim2.new(1, 0, 1, -20), UDim2.fromOffset(0, 20))
	for i, name in ipairs({ "Notification", "Sound", "Auto Hide" }) do
		makeSwitchCard(list, name, UDim2.new(1, 0, 0, 38), nil, i)
	end
end

---------------------------------------------------------------------
-- HALAMAN: SYSTEM KEY
---------------------------------------------------------------------
do
	local p = pages["System Key"]
	make("TextLabel", {
		Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(100, 14),
		BackgroundTransparency = 1, Text = "SYSTEM KEY", TextColor3 = C.GRAY,
		Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
	}, p)

	local box = make("TextBox", {
		Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = C.PANEL, BorderSizePixel = 0, Text = "",
		PlaceholderText = "Masukkan key...", PlaceholderColor3 = C.GRAY,
		TextColor3 = C.WHITE, Font = Enum.Font.Gotham, TextSize = 12,
		ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	}, p)
	corner(box, 8)
	glowStroke(box, 1)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, box)

	local verify = make("TextButton", {
		Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = C.RED, BorderSizePixel = 0, Text = "VERIFY",
		TextColor3 = C.WHITE, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
	}, p)
	corner(verify, 8)
	glowStroke(verify, 1, C.RED_DK)

	local keyStatus = make("TextLabel", {
		Position = UDim2.fromOffset(2, 110), Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1, Text = "Belum diverifikasi", TextColor3 = C.GRAY,
		Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
	}, p)

	verify.Activated:Connect(function()
		keyStatus.Text = "Key dikirim"
		local okc, err = pcall(UI.onKeySubmit, box.Text)
		if not okc then warn("[Senar Hub] onKeySubmit: " .. tostring(err)) end
	end)
end

selectTab("Logs")

-- ---------- Kilatan cahaya (garis putih + hitam menyapu) ----------
do
	local streak = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(-60, H / 2),
		Size = UDim2.fromOffset(14, H + 120), Rotation = 18,
		BackgroundTransparency = 1, ZIndex = 50,
	}, main)
	make("Frame", {
		Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(3, H + 120),
		BackgroundColor3 = C.WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 50,
	}, streak)
	make("Frame", {
		Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(5, H + 120),
		BackgroundColor3 = C.BLACK, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 50,
	}, streak)

	local tw = TweenService:Create(streak,
		TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 2.5),
		{ Position = UDim2.fromOffset(W + 60, H / 2) })
	tw:Play()
	table.insert(tweens, tw)
end

-- ---------- Buka / tutup ----------
local opened = true
local function setOpen(state)
	opened = state
	if state then
		holder.Visible = true
		popScale.Scale = 0.85
		tween(popScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	else
		tween(popScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 })
		task.delay(0.18, function()
			if not opened and holder.Parent then holder.Visible = false end
		end)
	end
end
hideBtn.Activated:Connect(function() setOpen(false) end)

-- ---------- Drag window (strip atas + area judul) ----------
local function attachDrag(dragFrame)
	local dragging, startMouse, startPos
	table.insert(conns, dragFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging, startMouse, startPos = true, input.Position, holder.Position
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = (input.Position - startMouse) / fitScale.Scale
			holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
end

attachDrag(make("Frame", {
	Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Active = true, ZIndex = 40,
}, main))
attachDrag(make("Frame", {
	Position = UDim2.fromOffset(8, 24), Size = UDim2.fromOffset(124, 30),
	BackgroundTransparency = 1, Active = true, ZIndex = 40,
}, main))

-- ---------- Floating icon ----------
local iconBtn = make("TextButton", {
	Name = "FloatingIcon", Position = UDim2.new(0, 16, 0.5, -26), Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = C.BG, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 60,
}, gui)
corner(iconBtn, 26)
spinStroke(iconBtn, 2)

local iconFallback = make("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "S",
	TextColor3 = C.RED, Font = Enum.Font.GothamBlack, TextSize = 24, ZIndex = 61,
}, iconBtn)

do
	local img = make("ImageLabel", {
		Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10),
		BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
		Image = "rbxassetid://" .. tostring(ICON_ASSET_ID), Visible = false, ZIndex = 62,
	}, iconBtn)
	corner(img, 21)
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ img }, function(_, status)
				if status == Enum.AssetFetchStatus.Success and img.Parent then
					img.Visible = true
					iconFallback.Text = ""
				end
			end)
		end)
	end)
end

-- icon bisa digeser; tap (tanpa geser) = buka/tutup
do
	local dragging, moved, startMouse, startPos
	table.insert(conns, iconBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging, moved, startMouse, startPos = true, false, input.Position, iconBtn.Position
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startMouse
			if d.Magnitude > 6 then moved = true end
			if moved then
				iconBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
					startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if not moved then setOpen(not opened) end
		end
	end))
end

-- ---------- Animasi: balok bergerak + Hub rainbow ----------
do
	local t0 = os.clock()
	local acc = 0
	table.insert(conns, RunService.Heartbeat:Connect(function(dt)
		if not holder.Visible then return end
		local t = os.clock() - t0
		local bw = blocks.width
		for _, b in ipairs(blocks) do
			b.frame.Size = UDim2.fromOffset(bw, b.base + math.sin(t * 2 + b.phase) * 3)
		end
		acc += dt
		if acc >= 0.05 then
			acc = 0
			hubGrad.Color = rainbowSeq(t)
		end
	end))
end

-- ---------- Cleanup ----------
gui.Destroying:Connect(function()
	if env.__SenarCleanup == myCleanup then env.__SenarCleanup = nil end
	if env.SenarUI == UI then env.SenarUI = nil end
	table.clear(sweepGradients)
	for _, c in ipairs(conns) do c:Disconnect() end
	for _, t in ipairs(tweens) do pcall(function() t:Cancel() end) end
end)

-- ====== SISTEM STEAL + SCANNER (dibungkus pcall: error tampil di sidebar) ======
local okSteal, errSteal = pcall(function()

	local VirtualUser = game:GetService("VirtualUser")

	-- ================= CONFIG =================
	local CFG = {
		HOME = Vector3.new(-1.52, 5.48, -48.56),
		SAFE = Vector3.new(-1.52, 5.48, -48.56),
		ZONES = {
			{ name = "Zona 1", pos = Vector3.new(40.2, 4.0, -114.9) },
			{ name = "Zona 2", pos = Vector3.new(-35.5, 6.5, -224.2) },
			{ name = "Zona 3", pos = Vector3.new(34.7, 6.5, -356.8) },
			{ name = "Zona 4", pos = Vector3.new(-34.2, 6.5, -524.4) },
			{ name = "Zona 5", pos = Vector3.new(36.9, 6.5, -730.2) },
			{ name = "Zona 6", pos = Vector3.new(-35.6, 6.5, -975.1) },
			{ name = "Zona 7", pos = Vector3.new(36.9, 6.5, -1244.4) },
			{ name = "Zona 8", pos = Vector3.new(-37.1, 6.5, -1545.4) },
		},

		METHOD      = "FORCE",  -- "TP" atau "FORCE" (bisa diganti di tab Scanner)
		FORCE_SPEED = 100,      -- kecepatan gerak paksa (stud/detik)
		TP_STEP     = 16,       -- jarak per lompatan TP
		TP_DELAY    = 0.05,     -- jeda antar lompatan TP
		WALK_TIMEOUT = 120,
		AFTER_DELAY  = 0.1,

		STEAL_WORDS = { "curi", "steal", "mencuri", "colong" },
		TAKE_WORDS  = { "curi", "steal", "ambil", "take", "grab", "pick", "collect", "angkat", "mencuri" },
		PLACE_WORDS = { "taruh", "taro", "place", "letak", "put", "pasang", "tempatkan", "drop" },
		CARRY_WORDS = { "egg", "telur", "pet", "kandang" },
		NOT_CARRY   = { "bat", "tongkat", "trap", "perangkap", "jebakan", "net", "jaring" },
	}

	local function icon(id) return "rbxassetid://" .. tostring(id) end
	local RARITIES = {
		{ id = "common",    en = "common",    label = "Common",    color = Color3.fromRGB(170, 170, 176), img = icon(85126966041880) },
		{ id = "rare",      en = "rare",      label = "Rare",      color = Color3.fromRGB(60, 150, 255),  img = icon(134910775381447) },
		{ id = "epic",      en = "epic",      label = "Epic",      color = Color3.fromRGB(176, 90, 255),  img = icon(123367448940620) },
		{ id = "legendary", en = "legendary", label = "Legendary", color = Color3.fromRGB(255, 170, 40),  img = icon(78792108393649) },
		{ id = "mythical",  en = "mythic",    label = "Mythic",    color = Color3.fromRGB(255, 80, 80),   img = icon(90056520665549) },
		{ id = "cosmic",    en = "cosmic",    label = "Cosmic",    color = Color3.fromRGB(110, 100, 255), img = icon(5405285409) },
		{ id = "secret",    en = "secret",    label = "Secret",    color = Color3.fromRGB(255, 50, 150),  img = icon(121324558664992) },
		{ id = "eternal",   en = "eternal",   label = "Eternal",   color = Color3.fromRGB(0, 229, 255),   img = icon(133625388915961) },
		{ id = "divine",    en = "divine",    label = "Divine",    color = Color3.fromRGB(255, 215, 0),   img = icon(96042806356330) },
		{ id = "spooky",    en = "spooky",    label = "Spooky",    color = Color3.fromRGB(255, 100, 0),   img = icon(17852734604) },
	}

	-- ================= STATE =================
	local S = {
		alive = true, running = false, busy = false, cancel = false,
		autoSafe = true, instant = true, antiRagdoll = true, tour = true,
		minValue = 0, filterIdx = 0,
		stolen = 0, failed = 0,
		floatOn = false, noclip = false, phase = "idle",
	}
	local entries, blacklist = {}, {}
	local tourI, lastSig, floatPart = 0, "", nil
	local setStatus = function(t) UI.setStatus(t) end

	-- ================= UTIL =================
	local function hrp()
		local c = LocalPlayer.Character
		return c and c:FindFirstChild("HumanoidRootPart")
	end
	local function hum()
		local c = LocalPlayer.Character
		return c and c:FindFirstChildOfClass("Humanoid")
	end
	local function any(s, words)
		for _, w in ipairs(words) do
			if s:find(w, 1, true) then return true end
		end
		return false
	end
	local function jitter(t) return t * (0.9 + math.random() * 0.2) end
	local function act(force) return S.alive and not S.cancel and (S.running or force) end
	local function clean(s) return (tostring(s):gsub("<[^>]+>", "")) end

	local MULT = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18 }
	local function parseNum(s)
		s = tostring(s or ""):lower():gsub(",", "")
		local num, suf = s:match("([%d%.]+)%s*([a-z]*)")
		num = tonumber(num)
		if not num then return nil end
		return num * (MULT[suf:sub(1, 2)] or MULT[suf:sub(1, 1)] or 1)
	end
	local function fmtNum(n)
		for _, u in ipairs({ { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
			if n >= u[1] then return string.format("%.2f%s", n / u[1], u[2]) end
		end
		return string.format("%.0f", n)
	end

	local function setPos(h, pos)
		if not h then return end
		h.CFrame = CFrame.new(pos) * (h.CFrame - h.CFrame.Position)
		h.AssemblyLinearVelocity = Vector3.zero
	end

	local function stopAnimations()
		local h = hum()
		local animator = h and h:FindFirstChildOfClass("Animator")
		if animator then
			for _, t in ipairs(animator:GetPlayingAnimationTracks()) do t:Stop() end
		end
	end

	-- platform tak terlihat + noclip saat bergerak
	table.insert(conns, RunService.Heartbeat:Connect(function()
		local h = hrp()
		if S.floatOn and h then
			if not floatPart or not floatPart.Parent then
				floatPart = make("Part", {
					Name = randName(8), Size = Vector3.new(14, 1, 14), Anchored = true, CanCollide = true,
					Transparency = 1, CanQuery = false, CanTouch = false,
				}, workspace)
			end
			floatPart.CFrame = CFrame.new(h.Position - Vector3.new(0, 3.5, 0))
		elseif floatPart then
			floatPart:Destroy()
			floatPart = nil
		end
	end))
	table.insert(conns, RunService.Stepped:Connect(function()
		if not S.noclip then return end
		local c = LocalPlayer.Character
		if not c then return end
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end))

	-- anti ragdoll
	task.spawn(function()
		local tick = 0
		while S.alive do
			if S.antiRagdoll then
				local hm = hum()
				if hm then
					for _, st in ipairs({ Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown }) do
						pcall(function() hm:SetStateEnabled(st, false) end)
					end
					local cur = hm:GetState()
					if cur == Enum.HumanoidStateType.Ragdoll or cur == Enum.HumanoidStateType.FallingDown
						or cur == Enum.HumanoidStateType.Physics then
						pcall(function() hm:ChangeState(Enum.HumanoidStateType.GettingUp) end)
					end
					if hm.PlatformStand then hm.PlatformStand = false end
				end
				tick += 1
				local c = LocalPlayer.Character
				if c and tick % 3 == 0 then
					for _, d in ipairs(c:GetDescendants()) do
						if d:IsA("BallSocketConstraint") then
							d:Destroy()
						elseif d:IsA("Motor6D") and not d.Enabled then
							d.Enabled = true
						end
					end
				end
			end
			task.wait(0.1)
		end
	end)

	-- anti idle
	table.insert(conns, LocalPlayer.Idled:Connect(function()
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end))

	-- ================= PROXIMITY PROMPT =================
	local prompts = {}
	local function reg(d) if d:IsA("ProximityPrompt") then prompts[d] = true end end
	table.insert(conns, workspace.DescendantAdded:Connect(reg))
	table.insert(conns, workspace.DescendantRemoving:Connect(function(d) prompts[d] = nil end))
	task.spawn(function()
		local n = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			reg(d)
			n += 1
			if n % 3000 == 0 then task.wait() end
		end
	end)

	local function promptPos(p)
		local par = p.Parent
		if not par then return nil end
		if par:IsA("BasePart") then return par.Position end
		if par:IsA("Attachment") then return par.WorldPosition end
		if par:IsA("Model") then return par:GetPivot().Position end
		return nil
	end
	local function ptext(p)
		local par = p.Parent
		return (p.ActionText .. " " .. p.ObjectText .. " " .. p.Name .. " " .. (par and par.Name or "")):lower()
	end
	local function isTake(p)
		local t = ptext(p)
		return any(t, CFG.TAKE_WORDS) and not any(t, CFG.PLACE_WORDS)
	end
	local function isPlace(p) return any(ptext(p), CFG.PLACE_WORDS) end
	local function isSteal(p)
		return any((p.ActionText .. " " .. p.ObjectText .. " " .. p.Name):lower(), CFG.STEAL_WORDS)
	end
	local function isLive(p) return p and p.Parent and p.Enabled end

	local function nearestPrompt(center, radius, matcher)
		local best, bpos, bd = nil, nil, radius
		local mychar = LocalPlayer.Character
		for p in pairs(prompts) do
			if p.Parent and p.Enabled and not (mychar and p:IsDescendantOf(mychar)) and matcher(p) then
				local pos = promptPos(p)
				if pos then
					local d = (pos - center).Magnitude
					if d <= bd then best, bpos, bd = p, pos, d end
				end
			end
		end
		return best, bpos
	end

	local function waitPrompt(center, radius, matcher, timeout)
		local t0 = os.clock()
		repeat
			local p, pos = nearestPrompt(center, radius, matcher)
			if p then return p, pos end
			task.wait(0.2)
		until os.clock() - t0 >= timeout or not S.alive
		return nil, nil
	end

	local function fire(p)
		pcall(function()
			p.HoldDuration = 0
			p.RequiresLineOfSight = false
			if p.MaxActivationDistance < 40 then p.MaxActivationDistance = 40 end
		end)
		if fireproximityprompt then
			pcall(fireproximityprompt, p)
		else
			pcall(function() p:InputHoldBegin(); p:InputHoldEnd() end)
		end
	end

	-- ================= CARRY / TOOL =================
	local function carryScore()
		local n = 0
		local c = LocalPlayer.Character
		if c then
			for _, d in ipairs(c:GetChildren()) do
				if d:IsA("Tool") or any(d.Name:lower(), CFG.CARRY_WORDS) then n += 1 end
			end
		end
		local bp = LocalPlayer:FindFirstChild("Backpack")
		if bp then
			for _, d in ipairs(bp:GetChildren()) do
				if d:IsA("Tool") or any(d.Name:lower(), CFG.CARRY_WORDS) then n += 1 end
			end
		end
		return n
	end

	local function findCarryTool()
		local function pick(root)
			if not root then return nil end
			local fallback
			for _, t in ipairs(root:GetChildren()) do
				if t:IsA("Tool") then
					local n = t.Name:lower()
					if any(n, CFG.CARRY_WORDS) then return t end
					if not any(n, CFG.NOT_CARRY) then fallback = fallback or t end
				end
			end
			return fallback
		end
		return pick(LocalPlayer.Character) or pick(LocalPlayer:FindFirstChild("Backpack"))
	end

	local function equipCarryTool()
		local t = findCarryTool()
		if not t then return nil end
		local hm = hum()
		if hm and t.Parent ~= LocalPlayer.Character then
			pcall(function() hm:EquipTool(t) end)
			task.wait(0.15)
		end
		return t
	end

	-- ================= GERAK: 2 METODE =================
	-- Metode 1: TP (lompat bertahap)
	local function tpMove(target, stopDist, force)
		S.floatOn = true
		stopAnimations()
		local t0 = os.clock()
		while act(force) and os.clock() - t0 < CFG.WALK_TIMEOUT do
			local h = hrp()
			if not h then return false end
			local diff = target - h.Position
			local d = diff.Magnitude
			if d <= stopDist then return true end
			setPos(h, h.Position + diff.Unit * math.min(CFG.TP_STEP, d))
			task.wait(jitter(CFG.TP_DELAY))
		end
		return false
	end

	-- Metode 2: Gerak paksa (velocity, kecepatan bisa diatur)
	local function forceMove(target, stopDist, force)
		S.floatOn = true
		S.noclip = true
		stopAnimations()
		local t0 = os.clock()
		local reached = false
		while act(force) and os.clock() - t0 < CFG.WALK_TIMEOUT do
			local h = hrp()
			if not h then break end
			local d = target - h.Position
			if d.Magnitude <= stopDist then reached = true break end
			h.AssemblyLinearVelocity = d.Unit * CFG.FORCE_SPEED
			RunService.Heartbeat:Wait()
		end
		local h = hrp()
		if h then h.AssemblyLinearVelocity = Vector3.zero end
		S.noclip = false
		return reached
	end

	local function moveTo(target, stopDist, force)
		if CFG.METHOD == "TP" then
			return tpMove(target, stopDist, force)
		end
		return forceMove(target, stopDist, force)
	end

	local function goSafe(force)
		if not CFG.SAFE then return end
		setStatus("ke safe zone")
		moveTo(CFG.SAFE, 5, force)
	end

	local function placeEgg()
		local tool = equipCarryTool()
		local pp = waitPrompt(CFG.HOME, 40, isPlace, 2)
		if pp then
			local pos = promptPos(pp)
			local h = hrp()
			if h and pos and (pos - h.Position).Magnitude > 8 then
				setPos(h, pos + Vector3.new(0, 3, 0))
				task.wait(0.1)
			end
			fire(pp)
			return true
		end
		if tool then
			pcall(function() tool:Activate() end)
			return true
		end
		return false
	end

	-- klon karakter di home + kamera dikunci selama steal
	local function createClone(originCFrame)
		local c = LocalPlayer.Character
		if not c then return nil, nil end
		c.Archivable = true
		local clone = c:Clone()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
		end
		clone.Name = "StealHomeClone"
		local chrp = clone:FindFirstChild("HumanoidRootPart")
		local chum = clone:FindFirstChildOfClass("Humanoid")
		if chrp and chum then
			chum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			chrp.Anchored = true
			chrp.CFrame = originCFrame
			clone.Parent = workspace
		end
		return clone, chum
	end

	-- ================= SCANNER =================
	local function hasGui(m)
		return m:FindFirstChildWhichIsA("BillboardGui", true) or m:FindFirstChildWhichIsA("SurfaceGui", true)
	end
	local function ownerModel(p)
		local node, found = p.Parent, nil
		for _ = 1, 8 do
			if not node or node == workspace then break end
			if node:IsA("Model") then
				found = found or node
				if hasGui(node) then return node end
			end
			node = node.Parent
		end
		return found
	end
	local function collectTexts(root)
		local texts, n = {}, 0
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("TextLabel") and d.Text ~= "" then
				texts[#texts + 1] = clean(d.Text)
				n += 1
				if n >= 60 then break end
			end
		end
		for k, v in pairs(root:GetAttributes()) do
			texts[#texts + 1] = tostring(k) .. ": " .. tostring(v)
		end
		return texts
	end

	local function parseEntry(p)
		local model = ownerModel(p)
		local root = model or p.Parent
		if not root then return nil end
		local pos = promptPos(p)
		if not pos then return nil end
		local texts = collectTexts(root)
		texts[#texts + 1] = p.ObjectText
		if model then texts[#texts + 1] = model.Name end

		local e = { prompt = p, model = model, pos = pos, rarityIdx = nil, spooky = false, texts = texts }
		for _, t in ipairs(texts) do
			local low = t:lower()
			if low:find("spooky", 1, true) then e.spooky = true end
			if not e.name and (low:find("kandang", 1, true) or low:find("egg", 1, true)) then e.name = t end
			if not e.rarityIdx then
				for i = #RARITIES, 1, -1 do
					local r = RARITIES[i]
					if low:find(r.id, 1, true) or low:find(r.en, 1, true) then e.rarityIdx = i break end
				end
			end
			if t:find("%$") then
				local raw = t:match("%$%s*([%d%.,]+%s*%a*)")
				local v = raw and parseNum(raw)
				if v and (not e.income or t:find("/")) then e.income = v end
			end
			if not e.weight then
				local kg = low:match("([%d%.,]+)%s*kg")
				if kg then e.weight = tonumber((kg:gsub(",", ""))) end
			end
		end
		e.name = e.name or (model and model.Name) or "Kandang"
		e.name = e.name:gsub("^%s*[Ss][Pp][Oo][Oo][Kk][Yy]%s*", "")
		if e.rarityIdx == nil then
			local low = e.name:lower()
			for i = #RARITIES, 1, -1 do
				if low:find(RARITIES[i].id, 1, true) or low:find(RARITIES[i].en, 1, true) then e.rarityIdx = i break end
			end
		end
		return e
	end

	local function passes(e)
		if (blacklist[e.prompt] or 0) > os.clock() then return false end
		if S.filterIdx ~= 0 and e.rarityIdx ~= S.filterIdx then return false end
		if S.minValue > 0 and (e.income or 0) < S.minValue then return false end
		return true
	end

	-- ================= LIVE FEED (Logs) =================
	local origAddLog = UI.addLog
	local stealEntry -- forward

	local function addEntry(e)
		local r = e.rarityIdx and RARITIES[e.rarityIdx]
		local income = e.income and (fmtNum(e.income) .. "/s") or "?/s"
		local info = string.format("%s · %s · %d stud",
			r and r.label or "?", e.weight and string.format("%.2fkg", e.weight) or "-kg", math.floor(e.dist or 0))
		local card, stealBtn, iconFrame = origAddLog((e.spooky and "Spooky " or "") .. e.name, income, info)
		if not card then return end
		if iconFrame then
			if r then iconFrame.BackgroundColor3 = r.color end
			if r and r.img then
				local im = make("ImageLabel", {
					Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
					Image = r.img, ScaleType = Enum.ScaleType.Fit,
				}, iconFrame)
				corner(im, 15)
			end
		end
		if stealBtn then
			-- handler lama (UI.onJoin) tetap noop; pakai handler langsung
			stealBtn.Activated:Connect(function()
				if S.busy then setStatus("masih sibuk") return end
				task.spawn(stealEntry, e, true)
			end)
		end
	end

	local function pushList(shown)
		UI.clearLogs()
		for i = #shown, 1, -1 do addEntry(shown[i]) end
		if UI.emptyLabel then
			UI.emptyLabel.Visible = (#shown == 0)
			UI.emptyLabel.Text = "Belum ada kandang terdeteksi"
		end
	end

	local function scanNow()
		local h = hrp()
		local mypos = h and h.Position or CFG.HOME
		local seen, list = {}, {}
		for p in pairs(prompts) do
			if p.Parent and p.Enabled and isSteal(p) then
				local pos = promptPos(p)
				if pos and (pos - CFG.HOME).Magnitude > 45 then
					local e = parseEntry(p)
					if e then
						local key = e.model or p
						if not seen[key] then
							seen[key] = true
							e.dist = (pos - mypos).Magnitude
							list[#list + 1] = e
						end
					end
				end
			end
		end
		table.sort(list, function(a, b)
			local ai, bi = a.income or 0, b.income or 0
			if ai ~= bi then return ai > bi end
			return a.dist < b.dist
		end)
		entries = list

		local shown, parts = {}, {}
		for _, e in ipairs(list) do
			if passes(e) then
				shown[#shown + 1] = e
				parts[#parts + 1] = string.format("%s|%s|%s|%d", e.name, tostring(e.rarityIdx),
					tostring(e.income), math.floor(e.dist / 25))
				if #shown >= 30 then break end
			end
		end
		local sig = table.concat(parts, ";")
		if sig ~= lastSig then
			lastSig = sig
			pushList(shown)
		end
		if not S.busy then setStatus(string.format("Live | %d kandang", #shown)) end
	end
	local function refreshNow() lastSig = "" pcall(scanNow) end

	UI.clearLogs() -- hapus contoh isi template
	task.spawn(function()
		while S.alive do
			pcall(scanNow)
			task.wait(1)
		end
	end)

	-- ================= STEAL =================
	stealEntry = function(e, force)
		if S.busy then return end
		S.busy, S.cancel, S.phase = true, false, "travel"
		local camera = workspace.CurrentCamera
		local clone

		local function cleanup()
			S.floatOn, S.noclip = false, false
			local hm = hum()
			if camera and hm then camera.CameraSubject = hm end
			if clone then clone:Destroy() clone = nil end
		end

		local ok, err = pcall(function()
			local p = e.prompt
			if not isLive(p) then setStatus("kandang sudah hilang") return end

			local h, hm = hrp(), hum()
			if h and hm and camera then
				local ch
				clone, ch = createClone(h.CFrame)
				if ch then camera.CameraSubject = ch end
			end

			setStatus("menuju " .. e.name)
			local arrived = moveTo(promptPos(p) or e.pos, 10, force)
			if not arrived then
				if S.cancel then blacklist[p] = os.clock() + 60 end
				setStatus(S.cancel and "steal dibatalkan" or "gagal sampai")
				return
			end

			S.phase = "take"
			setStatus("steal " .. e.name)
			local before = carryScore()
			local got = false
			for _ = 1, 6 do
				if not isLive(p) or S.cancel then break end
				fire(p)
				task.wait(0.05)
				if carryScore() > before then got = true break end
			end
			task.wait(CFG.AFTER_DELAY)
			if not got then got = carryScore() > before or not isLive(p) end
			if S.cancel then setStatus("steal dibatalkan") return end
			if not got then
				S.failed += 1
				blacklist[p] = os.clock() + 60
				setStatus("gagal steal " .. e.name)
				return
			end
			S.stolen += 1

			S.phase = "safe"
			if CFG.SAFE then goSafe(force) end
			if not act(force) then setStatus("steal dibatalkan") return end

			S.phase = "travel"
			setStatus("pulang ke home")
			moveTo(CFG.HOME, 2, force)
			if not act(force) then setStatus("steal dibatalkan") return end

			S.phase = "place"
			setStatus("menaruh di home")
			placeEgg()
			task.wait(0.3)
			setStatus(string.format("selesai | steal %d | gagal %d", S.stolen, S.failed))
		end)
		if not ok then warn("[Senar Hub] steal: " .. tostring(err)) end
		cleanup()
		S.phase, S.busy = "idle", false
	end

	local function pickBest()
		for _, e in ipairs(entries) do
			if passes(e) and isLive(e.prompt) then return e end
		end
		return nil
	end

	local loopRunning = false
	local function autoLoop()
		while S.running and S.alive do
			if not hrp() then
				setStatus("menunggu karakter...")
				repeat task.wait(0.5) until hrp() or not S.running or not S.alive
				S.floatOn = false
				task.wait(1)
			end
			if not S.running then break end
			if S.busy then
				task.wait(0.3)
			else
				local e = pickBest()
				if e then
					stealEntry(e, false)
					if S.cancel then task.wait(5) end -- jeda setelah Cancel Steal
					task.wait(jitter(0.2))
				elseif S.tour and #CFG.ZONES > 0 then
					tourI = tourI % #CFG.ZONES + 1
					setStatus("scan " .. CFG.ZONES[tourI].name)
					S.busy, S.cancel = true, false
					moveTo(CFG.ZONES[tourI].pos, 3, false)
					S.floatOn, S.noclip, S.busy = false, false, false
					local t0 = os.clock()
					while S.running and S.alive and os.clock() - t0 < 2 and not pickBest() do task.wait(0.2) end
				else
					setStatus("menunggu kandang...")
					task.wait(1)
				end
			end
		end
		S.floatOn = false
		S.phase = "idle"
		setStatus("AUTO OFF")
	end

	-- instant steal: ambil otomatis kalau dekat prompt
	task.spawn(function()
		local cooldown = {}
		while S.alive do
			local h = hrp()
			if S.instant and h and S.phase == "idle" and not S.busy then
				local p = nearestPrompt(h.Position, 14, isTake)
				if p and (cooldown[p] or 0) < os.clock() then
					cooldown[p] = os.clock() + 1
					fire(p)
				end
			end
			task.wait(0.2)
		end
	end)

	-- auto ke safe zone setelah memegang kandang (saat AUTO mati)
	task.spawn(function()
		local prev = carryScore()
		while S.alive do
			local cur = carryScore()
			if S.autoSafe and not S.running and not S.busy and S.phase == "idle" and cur > prev then
				S.busy, S.cancel, S.phase = true, false, "safe"
				task.spawn(function()
					goSafe(true)
					S.floatOn, S.noclip = false, false
					S.phase, S.busy = "idle", false
				end)
			end
			prev = cur
			task.wait(0.2)
		end
	end)

	-- ================= UI: Cancel Steal =================
	do
		local cancelBtn = make("TextButton", {
			Position = UDim2.fromOffset(108, 43), Size = UDim2.fromOffset(100, 18),
			BackgroundColor3 = C.RED_DK, BorderSizePixel = 0, Text = "Cancel Steal",
			TextColor3 = C.WHITE, Font = Enum.Font.GothamBold, TextSize = 10, AutoButtonColor = false,
		}, pages.Logs)
		corner(cancelBtn, 6)
		glowStroke(cancelBtn, 1, C.RED)
		cancelBtn.Activated:Connect(function()
			if S.busy then
				S.cancel = true
				setStatus("membatalkan steal...")
			else
				setStatus("tidak ada steal berjalan")
			end
		end)
	end

	UI.onClear = function() lastSig = "" end

	-- ================= UI: TAB SCANNER =================
	do
		make("TextLabel", {
			Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(100, 14),
			BackgroundTransparency = 1, Text = "SCANNER", TextColor3 = C.GRAY,
			Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
		}, pages.Scanner)
		local list = makeList(pages.Scanner, UDim2.new(1, 0, 1, -20), UDim2.fromOffset(0, 20))

		local order = 0
		local function row(title)
			order += 1
			local r = make("Frame", {
				Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.PANEL, BorderSizePixel = 0, LayoutOrder = order,
			}, list)
			corner(r, 8)
			glowStroke(r, 1)
			make("TextLabel", {
				Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -96, 1, 0), BackgroundTransparency = 1,
				Text = title, TextColor3 = C.WHITE, Font = Enum.Font.GothamBold, TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			}, r)
			return r
		end
		local function sSwitch(title, default, cb)
			local r = row(title)
			local btn = make("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(58, 24),
				BackgroundColor3 = default and C.RED or C.OFF, Text = default and "ON" or "OFF",
				TextColor3 = C.WHITE, Font = Enum.Font.GothamBlack, TextSize = 11, AutoButtonColor = false,
			}, r)
			corner(btn, 6)
			local state = default
			btn.Activated:Connect(function()
				state = not state
				btn.Text = state and "ON" or "OFF"
				btn.BackgroundColor3 = state and C.RED or C.OFF
				pcall(cb, state)
			end)
		end
		local function sInput(title, default, cb)
			local r = row(title)
			local box = make("TextBox", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(70, 24),
				BackgroundColor3 = C.BG, Text = tostring(default), TextColor3 = C.WHITE,
				Font = Enum.Font.GothamBold, TextSize = 11, ClearTextOnFocus = false,
			}, r)
			corner(box, 6)
			glowStroke(box, 1)
			box.FocusLost:Connect(function() pcall(cb, box) end)
		end
		local function sButton(title, text, cb)
			local r = row(title)
			local btn = make("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(84, 24),
				BackgroundColor3 = C.RED_DK, Text = text, TextColor3 = C.WHITE,
				Font = Enum.Font.GothamBold, TextSize = 10, AutoButtonColor = false,
			}, r)
			corner(btn, 6)
			glowStroke(btn, 1, C.RED)
			btn.Activated:Connect(function() pcall(cb, btn) end)
			return btn
		end

		-- metode gerak
		local function methodText() return CFG.METHOD == "TP" and "1: TP" or "2: Gerak Paksa" end
		sButton("Metode Gerak", methodText(), function(btn)
			CFG.METHOD = (CFG.METHOD == "TP") and "FORCE" or "TP"
			btn.Text = methodText()
			setStatus("metode: " .. methodText())
		end)
		sInput("Speed Gerak Paksa", CFG.FORCE_SPEED, function(box)
			local n = tonumber(box.Text)
			if n then CFG.FORCE_SPEED = math.clamp(n, 10, 500) end
			box.Text = tostring(CFG.FORCE_SPEED)
		end)
		sInput("TP Step (stud)", CFG.TP_STEP, function(box)
			local n = tonumber(box.Text)
			if n then CFG.TP_STEP = math.clamp(n, 1, 100) end
			box.Text = tostring(CFG.TP_STEP)
		end)
		sInput("TP Delay (detik)", CFG.TP_DELAY, function(box)
			local n = tonumber(box.Text)
			if n then CFG.TP_DELAY = math.clamp(n, 0.01, 1) end
			box.Text = tostring(CFG.TP_DELAY)
		end)

		-- filter scanner
		sInput("Min Value /s", "0", function(box)
			S.minValue = parseNum(box.Text) or 0
			refreshNow()
		end)
		sButton("Filter Rarity", "Semua", function(btn)
			S.filterIdx = (S.filterIdx + 1) % (#RARITIES + 1)
			btn.Text = S.filterIdx == 0 and "Semua" or RARITIES[S.filterIdx].label
			refreshNow()
		end)
		sSwitch("Auto Scan Zona", true, function(s) S.tour = s end)
		sSwitch("Instant Steal", true, function(s) S.instant = s end)
		sSwitch("Auto Safe Zone", true, function(s) S.autoSafe = s end)
		sSwitch("Anti Ragdoll", true, function(s) S.antiRagdoll = s end)
		sInput("Walk Timeout (detik)", CFG.WALK_TIMEOUT, function(box)
			local n = tonumber(box.Text)
			if n then CFG.WALK_TIMEOUT = math.clamp(n, 5, 600) end
			box.Text = tostring(CFG.WALK_TIMEOUT)
		end)
		sButton("Safe Zone = posisiku", "Set Safe", function()
			local h = hrp()
			if h then CFG.SAFE = h.Position setStatus("safe zone disimpan") end
		end)
		sButton("Home = posisiku", "Set Home", function()
			local h = hrp()
			if h then CFG.HOME = h.Position setStatus("home disimpan") end
		end)
		sButton("Salin teks kandang", "Dump", function()
			local lines = {}
			for i = 1, math.min(8, #entries) do
				local e = entries[i]
				lines[#lines + 1] = string.format("#%d %s | %s | %s | %d stud\n   %s", i, e.name,
					tostring(e.rarityIdx and RARITIES[e.rarityIdx].label), tostring(e.income),
					math.floor(e.dist or 0), table.concat(e.texts, " / "))
			end
			local s = #lines > 0 and table.concat(lines, "\n") or "(tidak ada kandang)"
			if setclipboard then pcall(setclipboard, s) end
			print(s)
			setStatus("dump disalin")
		end)
	end

	-- ================= HOOK TOGGLE =================
	local prevToggle = UI.onToggle
	UI.onToggle = function(name, state)
		if name == "Auto-Steal" then
			S.running = state
			if state then
				S.cancel = false
				setStatus("AUTO ON")
				if not loopRunning then
					loopRunning = true
					task.spawn(function()
						autoLoop()
						loopRunning = false
					end)
				end
			else
				S.floatOn, S.noclip = false, false
			end
		elseif prevToggle then
			prevToggle(name, state)
		end
	end

	-- cleanup
	gui.Destroying:Connect(function()
		S.alive, S.running = false, false
		if floatPart then pcall(function() floatPart:Destroy() end) end
	end)

	statusLbl.TextTruncate = Enum.TextTruncate.AtEnd
	statusLbl.TextSize = 10
end)
if not okSteal then
	warn("[Senar Hub] ERROR: " .. tostring(errSteal))
	UI.setStatus("ERR: " .. tostring(errSteal):sub(1, 60))
end
