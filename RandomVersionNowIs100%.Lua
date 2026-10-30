-- Codium X3 | Steal a Pet and Ride It  -  FINDER & CLONE SYSTEM (KEYLESS)
-- By: GGSIHLUH  |  YOUTUBE: CDM_TEAM
-- Update: Walkto + TP infrequent (1.5s delay), Clone at home with camera lock, Secret/Eternal/Divine/Halloween

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

-- ================= CONFIG (EDIT DI SINI) =================
local TITLE = "Senar Hub v1.9 [NOW IS NOT SAFE]"
local SIDE  = "right"          -- sisi tombol tab: "left" atau "right"

local HOME = Vector3.new(-1.52, 5.48, -48.56)
local SAFE_ZONE = Vector3.new(-1.52, 5.48, -48.56)

local ZONES = {
    { name = "Zona 1", pos = Vector3.new(40.2, 4.0, -114.9)   },
    { name = "Zona 2", pos = Vector3.new(-35.5, 6.5, -224.2)  },
    { name = "Zona 3", pos = Vector3.new(34.7, 6.5, -356.8)   },
    { name = "Zona 4", pos = Vector3.new(-34.2, 6.5, -524.4)  },
    { name = "Zona 5", pos = Vector3.new(36.9, 6.5, -730.2)   },
    { name = "Zona 6", pos = Vector3.new(-35.6, 6.5, -975.1)  },
    { name = "Zona 7", pos = Vector3.new(36.9, 6.5, -1244.4)  },
    { name = "Zona 8", pos = Vector3.new(-37.1, 6.5, -1545.4) },
}

local TP_BOOST     = 25     
local GLIDE_STEP   = 16     
local GLIDE_DELAY  = 0.05   
local LIFT         = 50
local WALK_TIMEOUT = 120
local AFTER_DELAY  = 0.1

local STEAL_WORDS = { "curi", "steal", "mencuri", "colong" }
local TAKE_WORDS  = { "curi", "steal", "ambil", "take", "grab", "pick", "collect", "angkat", "mencuri" }
local PLACE_WORDS = { "taruh", "taro", "place", "letak", "put", "pasang", "tempatkan", "drop" }
local CARRY_WORDS = { "egg", "telur", "pet", "kandang" }
local NOT_CARRY_TOOL = { "bat", "tongkat", "trap", "perangkap", "jebakan", "net", "jaring" }

local RARITIES = {
    { id = "Common",       en = "common",    label = "Umum",       color = Color3.fromRGB(170, 170, 176) },
    { id = "Rare",     en = "rare",      label = "Langka",     color = Color3.fromRGB(60, 150, 255)  },
    { id = "Epic",       en = "epic",      label = "Epik",       color = Color3.fromRGB(176, 90, 255)  },
    { id = "Legendary", en = "legendary", label = "Legendaris", color = Color3.fromRGB(255, 170, 40)  },
    { id = "mythical",      en = "mythic",    label = "Mitos",      color = Color3.fromRGB(255, 80, 80)   },
    { id = "Cosmic",     en = "cosmic",    label = "Kosmik",     color = Color3.fromRGB(110, 100, 255) },
    { id = "secret",     en = "secret",    label = "Secret",     color = Color3.fromRGB(255, 50, 150)  },
    { id = "eternal",    en = "eternal",   label = "Eternal",    color = Color3.fromRGB(0, 229, 255)   },
    { id = "divine",     en = "divine",    label = "Divine",     color = Color3.fromRGB(255, 215, 0)   },
    { id = "spooky",  en = "spooky", label = "Halloween",  color = Color3.fromRGB(255, 100, 0)   },
}

-- ================= UTIL =================
local function randName(n)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local t = table.create(n)
    for i = 1, n do
        local k = math.random(1, #chars)
        t[i] = chars:sub(k, k)
    end
    return table.concat(t)
end

local env = (getgenv and getgenv()) or _G
if env.__CodiumX3Cleanup then pcall(env.__CodiumX3Cleanup) end

local UI = {}
env.CodiumX3UI = UI
local uiConns = {}

local C = {
    PURPLE  = Color3.fromRGB(150, 55, 225),
    PURPLE2 = Color3.fromRGB(100, 35, 190),
    PANEL   = Color3.fromRGB(60, 62, 72),
    LISTBG  = Color3.fromRGB(46, 48, 56),
    ROW     = Color3.fromRGB(78, 78, 84),
    DARK    = Color3.fromRGB(28, 28, 34),
    GREEN   = Color3.fromRGB(64, 200, 64),
    BLUE    = Color3.fromRGB(52, 140, 232),
    ORANGE  = Color3.fromRGB(255, 158, 28),
    GOLD    = Color3.fromRGB(255, 204, 40),
    WHITE   = Color3.fromRGB(255, 255, 255),
    SUB     = Color3.fromRGB(196, 196, 204),
    GRAY    = Color3.fromRGB(110, 110, 118),
}

local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function corner(o, r) return make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function stroke(o, col, th)
    return make("UIStroke", { Color = col or C.DARK, Thickness = th or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function tw(o, t, p, style)
    local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), p)
    x:Play()
    return x
end

local function coreGuiOk()
    local okc, core = pcall(function() return game:GetService("CoreGui") end)
    if not okc or not core then return nil end
    local test = pcall(function()
        local f = Instance.new("Folder")
        f.Parent = core
        f:Destroy()
    end)
    return test and core or nil
end

local function mountGui(g)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(g)
        elseif protectgui then protectgui(g)
        elseif protect_gui then protect_gui(g) end
    end)
    local target = coreGuiOk()
    if not target then
        local okh, ui = pcall(function() return gethui and gethui() end)
        if okh and ui then target = ui end
    end
    if not target then target = LocalPlayer:WaitForChild("PlayerGui") end
    local okp = pcall(function() g.Parent = target end)
    if not okp or not g.Parent then g.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end

local gui = make("ScreenGui", { Name = randName(14), ResetOnSpawn = false, DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
mountGui(gui)

local function myCleanup()
    if gui and gui.Parent then gui:Destroy() end
end
env.__CodiumX3Cleanup = myCleanup

local MULT = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18 }
local function parseNum(s)
    s = tostring(s or ""):lower():gsub(",", "")
    local num, suf = s:match("([%d%.]+)%s*([a-z]*)")
    num = tonumber(num)
    if not num then return nil end
    local m = MULT[suf:sub(1, 2)] or MULT[suf:sub(1, 1)] or 1
    return num * m
end
local function fmtNum(n)
    local units = { { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
    for _, u in ipairs(units) do
        if n >= u[1] then return string.format("%.2f%s", n / u[1], u[2]) end
    end
    return string.format("%.0f", n)
end
local function clean(s) return (tostring(s):gsub("<[^>]+>", "")) end

local alive = true
local running = false          
local busy = false
local autoSafe = true
local instantSteal = true
local antiRagdoll = true
local scanTour = true
local minValue = 0
local filterIdx = 0            
local stolen, failed = 0, 0
local floatOn, floatPart = false, nil
local phase = "idle"
local entries = {}
local blacklist = {}
local sessionStart = os.clock()
local tourI = 0

-- ==========================================================================
-- ================================ UI ======================================
-- ==========================================================================
local function buildUI()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(800, 400)
    local W, H, TAB_W = 316, 336, 26
    local S = math.clamp((vp.Y - 24) / H, 0.55, 1)
    local RIGHT = (SIDE == "right")

    local dock = make("Frame", { Name = "Dock", Size = UDim2.fromOffset(W + TAB_W, H), BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(RIGHT and 1 or 0, 0.5) }, gui)
    make("UIScale", { Scale = S }, dock)

    local dockOff, isOpen = 0, false
    local function dockPos(open)
        local xo = 0
        if not open then xo = RIGHT and (W * S) or -(W * S) end
        return UDim2.new(RIGHT and 1 or 0, xo, 0.5, dockOff)
    end
    dock.Position = dockPos(false)

    local panel = make("Frame", { Name = "Panel", Size = UDim2.fromOffset(W, H),
        Position = UDim2.fromOffset(RIGHT and TAB_W or 0, 0), BackgroundColor3 = C.PANEL,
        BorderSizePixel = 0, ClipsDescendants = true }, dock)
    corner(panel, 12)
    stroke(panel, C.DARK, 3)

    local header = make("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.PURPLE, BorderSizePixel = 0 }, panel)
    make("UIGradient", { Color = ColorSequence.new(C.PURPLE, C.PURPLE2), Rotation = 90 }, header)
    make("TextLabel", { Size = UDim2.new(0, 160, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
        Text = TITLE, TextColor3 = C.WHITE, Font = Enum.Font.GothamBlack, TextSize = 21,
        TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0, TextStrokeColor3 = C.DARK }, header)

    local gear = make("TextButton", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(W - 140, 8),
        BackgroundColor3 = C.BLUE, Text = "⚙", TextColor3 = C.WHITE, Font = Enum.Font.GothamBold, TextSize = 20,
        AutoButtonColor = false }, header)
    corner(gear, 8)
    stroke(gear, Color3.fromRGB(30, 80, 160), 2)

    local autoBtn = make("TextButton", { Size = UDim2.fromOffset(92, 34), Position = UDim2.fromOffset(W - 100, 8),
        BackgroundColor3 = C.GRAY, Text = "AUTO OFF", TextColor3 = C.WHITE, Font = Enum.Font.GothamBlack, TextSize = 14,
        AutoButtonColor = false }, header)
    corner(autoBtn, 8)
    stroke(autoBtn, C.DARK, 2)

    local tileW = math.floor((W - 20 - 18) / 4)
    local function tile(i, color, label)
        local f = make("Frame", { Size = UDim2.fromOffset(tileW, 46), Position = UDim2.fromOffset(10 + (i - 1) * (tileW + 6), 58),
            BackgroundColor3 = color, BorderSizePixel = 0 }, panel)
        corner(f, 8)
        stroke(f, C.DARK, 2)
        make("TextLabel", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 3), BackgroundTransparency = 1,
            Text = label, TextColor3 = C.WHITE, Font = Enum.Font.GothamBold, TextSize = 9 }, f)
        return f
    end
    local t1 = tile(1, C.GREEN, "TP SPEED /s")
    local tpBox = make("TextBox", { Size = UDim2.new(1, -6, 0, 24), Position = UDim2.fromOffset(3, 18), BackgroundTransparency = 1,
        Text = tostring(TP_BOOST), TextColor3 = C.WHITE, Font = Enum.Font.GothamBlack, TextSize = 17, ClearTextOnFocus = false }, t1)
    local t2 = tile(2, C.BLUE, "MIN VALUE /s")
    local minBox = make("TextBox", { Size = UDim2.new(1, -6, 0, 24), Position = UDim2.fromOffset(3, 18), BackgroundTransparency = 1,
        Text = "0", TextColor3 = C.WHITE, Font = Enum.Font.GothamBlack, TextSize = 16, ClearTextOnFocus = false }, t2)
    local t3 = tile(3, C.BLUE, "RARITY")
    local rarBtn = make("TextButton", { Size = UDim2.new(1, -6, 0, 24), Position = UDim2.fromOffset(3, 18), BackgroundTransparency = 1,
        Text = "Any", TextColor3 = C.WHITE, Font = Enum.Font.GothamBlack, TextSize = 14, AutoButtonColor = false }, t3)
    local t4 = tile(4, C.ORANGE, "SESI")
    local timerLbl = make("TextLabel", { Size = UDim2.new(1, -6, 0, 24), Position = UDim2.fromOffset(3, 18), BackgroundTransparency = 1,
        Text = "0m", TextColor3 = C.WHITE, Font = Enum.Font.GothamBlack, TextSize = 16 }, t4)

    local statusLbl = make("TextLabel", { Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 108), BackgroundTransparency = 1,
        Text = "Live | 0 kandang | Tap Steal", TextColor3 = C.WHITE, Font = Enum.Font.GothamBlack, TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd }, panel)

    local LIST_Y = 132
    local list = make("ScrollingFrame", { Size = UDim2.new(1, -16, 1, -(LIST_Y + 8)), Position = UDim2.fromOffset(8, LIST_Y),
        BackgroundColor3 = C.LISTBG, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.SUB,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, panel)
    corner(list, 8)
    stroke(list, C.DARK, 2)
    make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, list)
    make("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 5) }, list)

    local settings = make("ScrollingFrame", { Size = list.Size, Position = list.Position, BackgroundColor3 = C.LISTBG,
        BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.SUB, Visible = false,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, panel)
    corner(settings, 8)
    stroke(settings, C.DARK, 2)
    make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, settings)
    make("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 5) }, settings)

    local sOrder = 0
    local function sRow(title)
        sOrder += 1
        local r = make("Frame", { Size = UDim2.new(1, -6, 0, 38), BackgroundColor3 = C.ROW, BorderSizePixel = 0,
            LayoutOrder = sOrder }, settings)
        corner(r, 8)
        stroke(r, C.DARK, 2)
        make("TextLabel", { Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1,
            Text = title, TextColor3 = C.WHITE, Font = Enum.Font.GothamBold, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, r)
        return r
    end
    local function sSwitch(title, default, cb)
        local r = sRow(title)
        local b = make("TextButton", { Size = UDim2.fromOffset(60, 26), AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0), Text = default and "ON" or "OFF", TextColor3 = C.WHITE,
            BackgroundColor3 = default and C.GREEN or C.GRAY, Font = Enum.Font.GothamBlack, TextSize = 12,
            AutoButtonColor = false }, r)
        corner(b, 6)
        stroke(b, C.DARK, 2)
        local state = default
        b.MouseButton1Click:Connect(function()
            state = not state
            b.Text = state and "ON" or "OFF"
            b.BackgroundColor3 = state and C.GREEN or C.GRAY
            pcall(cb, state)
        end)
    end
    local function sInput(title, default, cb)
        local r = sRow(title)
        local box = make("TextBox", { Size = UDim2.fromOffset(60, 26), AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0), BackgroundColor3 = C.DARK, Text = tostring(default), TextColor3 = C.WHITE,
            Font = Enum.Font.GothamBold, TextSize = 12, ClearTextOnFocus = false }, r)
        corner(box, 6)
        box.FocusLost:Connect(function()
            local n = tonumber(box.Text)
            if n then pcall(cb, n) end
        end)
    end
    local function sButton(title, btnText, cb)
        local r = sRow(title)
        local b = make("TextButton", { Size = UDim2.fromOffset(84, 26), AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0), Text = btnText, TextColor3 = C.WHITE, BackgroundColor3 = C.BLUE,
            Font = Enum.Font.GothamBlack, TextSize = 11, AutoButtonColor = false }, r)
        corner(b, 6)
        stroke(b, C.DARK, 2)
        b.MouseButton1Click:Connect(function() pcall(cb) end)
    end

    sSwitch("Instant Steal (auto ambil)", true, function(s) instantSteal = s end)
    sSwitch("Auto ke Safe Zone", true, function(s) autoSafe = s end)
    sSwitch("Anti Ragdoll", true, function(s) antiRagdoll = s end)
    sSwitch("Auto Scan Zona (AUTO)", true, function(s) scanTour = s end)
    sInput("Walk Timeout (detik)", WALK_TIMEOUT, function(n) WALK_TIMEOUT = math.clamp(n, 5, 600) end)
    sInput("Glide Step (stud)", GLIDE_STEP, function(n) GLIDE_STEP = math.clamp(n, 1, 100) end)
    sInput("Glide Delay (detik)", GLIDE_DELAY, function(n) GLIDE_DELAY = math.clamp(n, 0.01, 1) end)
    sButton("Safe Zone = posisiku", "Set Safe", function() UI.onSetSafe() end)
    sButton("Home = posisiku", "Set Home", function() UI.onSetHome() end)
    sButton("Salin teks kandang (debug)", "Dump", function() UI.onDump() end)
    sButton("Hapus UI & hentikan", "Tutup", function() myCleanup() end)
    do
        sOrder += 1
        make("TextLabel", { Size = UDim2.new(1, -6, 0, 34), BackgroundTransparency = 1, LayoutOrder = sOrder,
            Text = "By: GGSIHLUH\nYOUTUBE: SENAR_TEAM", TextColor3 = C.SUB, Font = Enum.Font.GothamBold, TextSize = 11 }, settings)
    end

    local function rarityOf(e)
        return RARITIES[e.rarityIdx or 0]
    end
    local function addRow(i, e)
        local r = rarityOf(e)
        local row = make("Frame", { Size = UDim2.new(1, -6, 0, 56), BackgroundColor3 = C.ROW, BorderSizePixel = 0,
            LayoutOrder = i }, list)
        corner(row, 8)
        stroke(row, C.DARK, 2)

        local icon = make("Frame", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(6, 6),
            BackgroundColor3 = r and r.color or C.GRAY, BorderSizePixel = 0 }, row)
        corner(icon, 8)
        stroke(icon, C.DARK, 2)
        make("TextLabel", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = r and r.label:sub(1, 1) or "?",
            TextColor3 = C.WHITE, Font = Enum.Font.GothamBlack, TextSize = 22, TextStrokeTransparency = 0.3 }, icon)
        make("TextLabel", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 29), BackgroundTransparency = 1,
            Text = r and r.label or "?", TextColor3 = C.WHITE, Font = Enum.Font.GothamBold, TextSize = 8,
            TextStrokeTransparency = 0 }, icon)

        make("TextLabel", { Size = UDim2.new(1, -140, 0, 20), Position = UDim2.fromOffset(56, 6), BackgroundTransparency = 1,
            Text = (e.spooky and "SPOOKY " or "") .. e.name, TextColor3 = C.GOLD, Font = Enum.Font.GothamBlack, TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            TextStrokeTransparency = 0.5 }, row)
        local info = string.format(
            '<font color="#58e058">%s</font>  <font color="#ffa01c">%s</font>  <font color="#c4c4cc">%d stud</font>',
            e.income and (fmtNum(e.income) .. "/s") or "?/s",
            e.weight and (string.format("%.2fkg", e.weight)) or "-kg",
            math.floor(e.dist or 0))
        make("TextLabel", { Size = UDim2.new(1, -140, 0, 18), Position = UDim2.fromOffset(56, 29), BackgroundTransparency = 1,
            RichText = true, Text = info, TextColor3 = C.WHITE, Font = Enum.Font.GothamBold, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, row)

        local btn = make("TextButton", { Size = UDim2.fromOffset(68, 40), AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0), BackgroundColor3 = C.GREEN, Text = "Steal", TextColor3 = C.WHITE,
            Font = Enum.Font.GothamBlack, TextSize = 16, AutoButtonColor = false, TextStrokeTransparency = 0.4 }, row)
        corner(btn, 8)
        stroke(btn, C.DARK, 2)
        btn.MouseButton1Click:Connect(function() UI.onSteal(e) end)
    end

    UI.setList = function(shown)
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
        end
        if #shown == 0 then
            make("TextLabel", { Size = UDim2.new(1, -6, 0, 60), BackgroundTransparency = 1, LayoutOrder = 1,
                Text = "Belum ada kandang terdeteksi.\nDekati zona atau nyalakan AUTO.", TextColor3 = C.SUB,
                Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true }, list)
            return
        end
        for i, e in ipairs(shown) do addRow(i, e) end
    end

    UI.setStatus = function(t)
        if statusLbl and statusLbl.Parent then statusLbl.Text = tostring(t) end
    end

    local function renderAuto()
        autoBtn.Text = running and "AUTO ON" or "AUTO OFF"
        autoBtn.BackgroundColor3 = running and C.GREEN or C.GRAY
    end
    autoBtn.MouseButton1Click:Connect(function()
        UI.onToggle(not running)
        renderAuto()
    end)
    UI.renderAuto = renderAuto

    local showSettings = false
    gear.MouseButton1Click:Connect(function()
        showSettings = not showSettings
        settings.Visible = showSettings
        list.Visible = not showSettings
    end)

    tpBox.FocusLost:Connect(function()
        local n = tonumber(tpBox.Text)
        if n then TP_BOOST = math.clamp(n, 0, 200) end
        tpBox.Text = tostring(TP_BOOST)
    end)
    minBox.FocusLost:Connect(function()
        minValue = parseNum(minBox.Text) or 0
        UI.refreshNow()
    end)
    rarBtn.MouseButton1Click:Connect(function()
        filterIdx = (filterIdx + 1) % (#RARITIES + 1)
        rarBtn.Text = filterIdx == 0 and "Any" or RARITIES[filterIdx].label
        rarBtn.TextSize = filterIdx == 0 and 14 or 11
        UI.refreshNow()
    end)

    table.insert(uiConns, RunService.Heartbeat:Connect((function()
        local last = 0
        return function()
            local now = os.clock()
            if now - last < 1 then return end
            last = now
            local s = math.floor(now - sessionStart)
            timerLbl.Text = s >= 3600 and string.format("%dh%02dm", s // 3600, (s % 3600) // 60)
                or string.format("%dm%02ds", s // 60, s % 60)
        end
    end)()))

    local tab = make("TextButton", { Size = UDim2.fromOffset(TAB_W, 76), Position = UDim2.fromOffset(RIGHT and 0 or W, H / 2 - 38),
        BackgroundColor3 = C.PURPLE, Text = "", AutoButtonColor = false, ZIndex = 5 }, dock)
    corner(tab, 10)
    stroke(tab, C.DARK, 2)
    local arrow = make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
        TextColor3 = C.WHITE, Font = Enum.Font.GothamBlack, TextSize = 18, ZIndex = 6 }, tab)
    local function renderArrow()
        local pointsRight = (not RIGHT and not isOpen) or (RIGHT and isOpen)
        arrow.Text = pointsRight and "▶" or "◀"
    end
    local function setOpen(open)
        isOpen = open
        renderArrow()
        tw(dock, 0.32, { Position = dockPos(open) }, Enum.EasingStyle.Quart)
    end

    do
        local dragging, moved, dragStart, startOff = false, false, nil, 0
        tab.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging, moved, dragStart, startOff = true, false, input.Position, dockOff
            end
        end)
        table.insert(uiConns, UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local dy = input.Position.Y - dragStart.Y
                if math.abs(dy) > 8 then moved = true end
                if moved then
                    dockOff = math.clamp(startOff + dy, -(vp.Y / 2 - 50), vp.Y / 2 - 50)
                    dock.Position = dockPos(isOpen)
                end
            end
        end))
        table.insert(uiConns, UserInputService.InputEnded:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                if not moved then setOpen(not isOpen) end
            end
        end))
    end

    renderArrow()
    task.delay(0.3, function() if alive then setOpen(true) end end)
    UI.renderAuto()
    UI.setList({})
end

-- ==========================================================================
-- ============================== FITUR ====================================
-- ==========================================================================
gui.Destroying:Connect(function()
    alive = false
    running = false
    if env.__CodiumX3Cleanup == myCleanup then env.__CodiumX3Cleanup = nil end
    if env.CodiumX3UI == UI then env.CodiumX3UI = nil end
    if floatPart then pcall(function() floatPart:Destroy() end) end
    for _, c in ipairs(uiConns) do c:Disconnect() end
end)

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
local function setPos(h, pos)
    if not h then return end
    h.CFrame = CFrame.new(pos) * (h.CFrame - h.CFrame.Position)
    h.AssemblyLinearVelocity = Vector3.zero
end
local function jitter(t) return t * (0.9 + math.random() * 0.2) end
local function act(force) return alive and (running or force) end

local function stopAnimations()
    local h = hum()
    if h then
        local animator = h:FindFirstChildOfClass("Animator")
        if animator then
            for _, t in ipairs(animator:GetPlayingAnimationTracks()) do t:Stop() end
        end
    end
end

table.insert(uiConns, RunService.Heartbeat:Connect(function()
    local h = hrp()
    if floatOn and h then
        if not floatPart or not floatPart.Parent then
            floatPart = make("Part", { Name = randName(8), Size = Vector3.new(14, 1, 14), Anchored = true, CanCollide = true,
                Transparency = 1, CanQuery = false, CanTouch = false }, workspace)
        end
        floatPart.CFrame = CFrame.new(h.Position - Vector3.new(0, 3.5, 0))
    elseif floatPart then
        floatPart:Destroy()
        floatPart = nil
    end
end))

task.spawn(function()
    local tick = 0
    while alive do
        if antiRagdoll then
            local c = LocalPlayer.Character
            local hm = hum()
            if hm then
                for _, s in ipairs({ Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown }) do
                    pcall(function() hm:SetStateEnabled(s, false) end)
                end
                local st = hm:GetState()
                if st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown
                    or st == Enum.HumanoidStateType.Physics then
                    pcall(function() hm:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                end
                if hm.PlatformStand then hm.PlatformStand = false end
            end
            tick += 1
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

local prompts = {}
local function reg(d) if d:IsA("ProximityPrompt") then prompts[d] = true end end
table.insert(uiConns, workspace.DescendantAdded:Connect(reg))
table.insert(uiConns, workspace.DescendantRemoving:Connect(function(d) prompts[d] = nil end))
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
    return any(t, TAKE_WORDS) and not any(t, PLACE_WORDS)
end
local function isPlace(p) return any(ptext(p), PLACE_WORDS) end
local function isSteal(p)
    local t = (p.ActionText .. " " .. p.ObjectText .. " " .. p.Name):lower()
    return any(t, STEAL_WORDS)
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
    until os.clock() - t0 >= timeout or not alive
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

local function carryScore()
    local n = 0
    local c = LocalPlayer.Character
    if c then
        for _, d in ipairs(c:GetChildren()) do
            if d:IsA("Tool") or any(d.Name:lower(), CARRY_WORDS) then n += 1 end
        end
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, d in ipairs(bp:GetChildren()) do
            if d:IsA("Tool") or any(d.Name:lower(), CARRY_WORDS) then n += 1 end
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
                if any(n, CARRY_WORDS) then return t end
                if not any(n, NOT_CARRY_TOOL) then fallback = fallback or t end
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

-- Fungsi Membuat Klon Karakter di Posisi Awal (Home)
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

-- GLIDE LANGSUNG KE HOME
local function glideDirect(target, force)
    local h = hrp()
    if not h then return false end
    floatOn = true
    stopAnimations()

    while act(force) do
        h = hrp()
        if not h then floatOn = false return false end
        local diff = target - h.Position
        local d = diff.Magnitude
        if d < 1 then break end
        setPos(h, h.Position + diff.Unit * math.min(GLIDE_STEP * 1.5, d))
        task.wait(jitter(GLIDE_DELAY))
    end

    h = hrp()
    if h and act(force) then setPos(h, target) end
    task.wait(0.05)
    floatOn = false
    return hrp() ~= nil
end

-- Walkto + TP dengan jeda 1.5 detik (tidak sering-sering agar tidak ke-kick)
local function walkBoost(target, timeout, stopDist, force)
    floatOn = false
    local t0 = os.clock()
    local last = os.clock()
    local lastTp = os.clock()
    local lastPos, lastCheck = nil, os.clock()
    while act(force) and os.clock() - t0 < timeout do
        local h, hm = hrp(), hum()
        if not h or not hm then return false end
        local d = target - h.Position
        local flatV = Vector3.new(d.X, 0, d.Z)
        local flat = flatV.Magnitude
        if flat <= stopDist then return true end
        hm:MoveTo(target)

        local now = os.clock()
        local dt = math.min(now - last, 0.5)
        last = now

        -- TP Boost hanya aktif setiap 1.5 detik sekali agar aman dari kick
        if TP_BOOST > 0 and flat > 4 and (now - lastTp >= 1.5) then
            lastTp = now
            local step = math.min(TP_BOOST * dt * 2, flat - 1)
            h.CFrame = h.CFrame + flatV.Unit * step
        end

        if now - lastCheck > 1.5 then
            if lastPos and (h.Position - lastPos).Magnitude < 1 then hm.Jump = true end
            lastPos, lastCheck = h.Position, now
        end
        task.wait(0.1)
    end
    return false
end

local function goSafe(force)
    if not SAFE_ZONE then return end
    UI.setStatus("jalan ke safe zone")
    walkBoost(SAFE_ZONE, 40, 5, force)
end

local function placeEgg()
    local tool = equipCarryTool()
    local pp = waitPrompt(HOME, 40, isPlace, 2)
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
    local texts = {}
    local n = 0
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

    local e = { prompt = p, model = model, pos = pos, name = nil, rarityIdx = nil, income = nil, weight = nil,
        spooky = false, texts = texts }

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
    if filterIdx ~= 0 and e.rarityIdx ~= filterIdx then return false end
    if minValue > 0 and (e.income or 0) < minValue then return false end
    return true
end

local lastSig = ""
local function scanNow()
    local h = hrp()
    local mypos = h and h.Position or HOME
    local seen, list = {}, {}
    for p in pairs(prompts) do
        if p.Parent and p.Enabled and isSteal(p) then
            local pos = promptPos(p)
            if pos and (pos - HOME).Magnitude > 45 then
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

    local shown = {}
    for _, e in ipairs(list) do
        if passes(e) then
            shown[#shown + 1] = e
            if #shown >= 40 then break end
        end
    end
    local parts = {}
    for _, e in ipairs(shown) do
        parts[#parts + 1] = string.format("%s|%s|%s|%d", e.name, tostring(e.rarityIdx), tostring(e.income),
            math.floor(e.dist / 25))
    end
    local sig = table.concat(parts, ";")
    if sig ~= lastSig then
        lastSig = sig
        UI.setList(shown)
    end
    if not busy then
        UI.setStatus(string.format("Live | %d kandang | Tap Steal", #shown))
    end
    return shown
end
UI.refreshNow = function() lastSig = "" ; scanNow() end

task.spawn(function()
    while alive do
        pcall(scanNow)
        task.wait(1)
    end
end)

local function stealEntry(e, force)
    if busy then return end
    busy = true
    phase = "travel"
    local ok, err = pcall(function()
        local p = e.prompt
        if not isLive(p) then UI.setStatus("kandang sudah hilang") return end

        local hrpPart = hrp()
        local hm = hum()
        local camera = workspace.CurrentCamera
        local originalSubject = camera and camera.CameraSubject

        -- 1. Buat Klon di Home dan Kunci Kamera di Klon saat mulai proses ambil
        local clone, chum = nil, nil
        if hrpPart and hm and camera then
            clone, chum = createClone(hrpPart.CFrame)
            if chum then
                camera.CameraSubject = chum
            end
        end

        UI.setStatus("jalan ke " .. e.name)
        local arrived = walkBoost(promptPos(p) or e.pos, WALK_TIMEOUT, 10, force)
        if not arrived then
            if clone then clone:Destroy() end
            if camera and hm then camera.CameraSubject = hm end
            if act(force) then UI.setStatus("gagal sampai ke kandang") end
            return
        end

        phase = "take"
        UI.setStatus("instant steal " .. e.name)
        local before = carryScore()
        local got = false
        for _ = 1, 6 do
            if not isLive(p) then break end
            fire(p)
            task.wait(0.05)
            if carryScore() > before then got = true break end
        end
        task.wait(AFTER_DELAY)
        if not got then got = carryScore() > before or not isLive(p) end
        if not got then
            if clone then clone:Destroy() end
            if camera and hm then camera.CameraSubject = hm end
            failed += 1
            blacklist[p] = os.clock() + 60
            UI.setStatus("gagal steal " .. e.name)
            return
        end
        stolen += 1

        phase = "safe"
        goSafe(force)
        if not act(force) then 
            if clone then clone:Destroy() end
            if camera and hm then camera.CameraSubject = hm end
            return 
        end

        phase = "travel"
        UI.setStatus("langsung ke home")
        glideDirect(HOME, force) 
        if not act(force) then 
            if clone then clone:Destroy() end
            if camera and hm then camera.CameraSubject = hm end
            return 
        end

        phase = "place"
        UI.setStatus("menaruh di home")
        placeEgg()
        task.wait(0.3)

        -- 2. Kembalikan Kamera ke Karakter Asli dan Hapus Klon setelah sampai di Home
        if camera and hm then
            camera.CameraSubject = hm
        end
        if clone then
            clone:Destroy()
        end

        UI.setStatus(string.format("selesai | steal %d | gagal %d", stolen, failed))
    end)
    if not ok then warn("[Codium X3] " .. tostring(err)) end
    phase = "idle"
    floatOn = false
    busy = false
end

local function pickBest()
    for _, e in ipairs(entries) do
        if passes(e) and isLive(e.prompt) then return e end
    end
    return nil
end

local function autoLoop()
    while running and alive do
        if not hrp() then
            UI.setStatus("menunggu karakter...")
            repeat task.wait(0.5) until hrp() or not running or not alive
            floatOn = false
            task.wait(1)
        end
        if not running then break end
        if busy then
            task.wait(0.3)
        else
            local e = pickBest()
            if e then
                stealEntry(e, false)
                task.wait(jitter(0.2))
            elseif scanTour and #ZONES > 0 then
                tourI = tourI % #ZONES + 1
                UI.setStatus("scan " .. ZONES[tourI].name)
                busy = true
                glideDirect(ZONES[tourI].pos, false)
                busy = false
                local t0 = os.clock()
                while running and alive and os.clock() - t0 < 2 and not pickBest() do task.wait(0.2) end
            else
                UI.setStatus("menunggu kandang yang cocok...")
                task.wait(1)
            end
        end
    end
    floatOn = false
    phase = "idle"
    UI.setStatus("AUTO OFF")
end

task.spawn(function()
    local cooldown = {}
    while alive do
        local h = hrp()
        if instantSteal and h and phase == "idle" and not busy then
            local p = nearestPrompt(h.Position, 14, isTake)
            if p and (cooldown[p] or 0) < os.clock() then
                cooldown[p] = os.clock() + 1
                fire(p)
            end
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    local prev = carryScore()
    while alive do
        local cur = carryScore()
        if autoSafe and not running and not busy and phase == "idle" and cur > prev then
            busy = true
            phase = "safe"
            task.spawn(function()
                goSafe(true)
                phase = "idle"
                busy = false
            end)
        end
        prev = cur
        task.wait(0.2)
    end
end)

pcall(function()
    if hookmetamethod and getnamecallmethod and newcclosure then
        local old
        old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            if self == LocalPlayer and getnamecallmethod():lower() == "kick" then return nil end
            return old(self, ...)
        end))
    end
end)
pcall(function()
    local vu = game:GetService("VirtualUser")
    table.insert(uiConns, LocalPlayer.Idled:Connect(function()
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end))
end)

local loopRunning = false
UI.onToggle = function(state)
    running = state
    if state then
        UI.setStatus("AUTO ON")
        if not loopRunning then
            loopRunning = true
            task.spawn(function()
                autoLoop()
                loopRunning = false
            end)
        end
    else
        floatOn = false
    end
    if UI.renderAuto then UI.renderAuto() end
end

UI.onSteal = function(e)
    if busy then UI.setStatus("masih sibuk, tunggu selesai") return end
    task.spawn(stealEntry, e, true)
end

local function fmtV(v) return string.format("Vector3.new(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) end
UI.onSetSafe = function()
    local h = hrp()
    if h then
        SAFE_ZONE = h.Position
        UI.setStatus("safe zone: " .. fmtV(SAFE_ZONE))
    end
end
UI.onSetHome = function()
    local h = hrp()
    if h then
        HOME = h.Position
        UI.setStatus("home: " .. fmtV(HOME))
    end
end
UI.onDump = function()
    local lines = {}
    for i = 1, math.min(8, #entries) do
        local e = entries[i]
        lines[#lines + 1] = string.format("#%d %s | rarity=%s | income=%s | weight=%s | %d stud\n   texts: %s",
            i, e.name, tostring(e.rarityIdx and RARITIES[e.rarityIdx].label), tostring(e.income), tostring(e.weight),
            math.floor(e.dist or 0), table.concat(e.texts, " / "))
    end
    local s = #lines > 0 and table.concat(lines, "\n") or "(tidak ada kandang terdeteksi)"
    if setclipboard then pcall(setclipboard, s) end
    print(s)
    UI.setStatus("dump disalin ke clipboard & console")
end

buildUI()
