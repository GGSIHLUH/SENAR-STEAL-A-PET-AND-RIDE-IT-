-- ====== SENAR HUB | STEAL SYSTEM + TAB SCANNER ======
-- Tempel di PALING BAWAH Senar.Lua (di bawah baris "TARUH KODE PROJECT KAMU DI BAWAH SINI").
-- Kalau kamu juga pakai Senar_Features.lua, tempel file ini SETELAHNYA (toggle lama tetap jalan).
--
-- Perubahan UI:
--   * Tab baru "Scanner" (pengaturan: metode, kecepatan, filter)
--   * Live Feed: tombol JOIN jadi STEAL + ikon per kelangkaan
--   * Tombol "Cancel Steal" di tab Logs
--   * Auto-Join diganti nama jadi "Auto-Steal"
--   * 2 metode gerak: TP (step teleport) dan Gerak Paksa (default 100 speed, bisa diubah)

do
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
		{ id = "cosmic",    en = "cosmic",    label = "Cosmic",    color = Color3.fromRGB(110, 100, 255), img = nil },
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
		local card = origAddLog((e.spooky and "Spooky " or "") .. e.name, income, info)
		if not card then return end

		for _, c in ipairs(card:GetChildren()) do
			if c:IsA("Frame") and c.Size == UDim2.fromOffset(30, 30) then
				if r then c.BackgroundColor3 = r.color end
				if r and r.img then
					local im = make("ImageLabel", {
						Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
						Image = r.img, ScaleType = Enum.ScaleType.Fit,
					}, c)
					corner(im, 15)
				end
			elseif c:IsA("TextButton") and c.Text == "JOIN" then
				c.Text = "STEAL"
				c.Activated:Connect(function()
					if S.busy then setStatus("masih sibuk") return end
					task.spawn(stealEntry, e, true)
				end)
			end
		end
	end

	local function pushList(shown)
		UI.clearLogs()
		for i = #shown, 1, -1 do addEntry(shown[i]) end
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

	-- ================= UI: LOGS (rename + Cancel Steal) =================
	for _, d in ipairs(pages.Logs:GetDescendants()) do
		if d:IsA("TextLabel") and d.Text == "Auto-Join" then d.Text = "Auto-Steal" end
	end

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
		pages.Scanner = make("Frame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
		}, content)

		local b = make("TextButton", {
			Size = UDim2.fromOffset(108, 27), BackgroundColor3 = C.HOVER, BackgroundTransparency = 1,
			BorderSizePixel = 0, Text = "Scanner", TextColor3 = C.GRAY,
			Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
		}, side)
		corner(b, 8)
		local st = glowStroke(b, 1)
		st.Enabled = false
		tabBtns.Scanner = { btn = b, stroke = st }
		b.Activated:Connect(function() selectTab("Scanner") end)

		-- susun ulang tab (muat 5 tombol di atas Hide)
		for i, n in ipairs({ "Logs", "Scanner", "History", "Settings", "System Key" }) do
			local t = tabBtns[n]
			if t then
				t.btn.Position = UDim2.fromOffset(8, 58 + (i - 1) * 31)
				t.btn.Size = UDim2.fromOffset(108, 27)
			end
		end

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
		if name == "Auto-Join" then -- sekarang berfungsi sebagai Auto-Steal
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
end
