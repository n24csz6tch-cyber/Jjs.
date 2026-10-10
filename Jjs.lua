--[[
═══════════════════════════════════════════════════════════════════════════
   VENICE.JS  •  Jujutsu Shenanigans Automation Suite   (v1.0)
   Auto-Tech engine | Anti-cheese | QoL | Herramientas por personaje
   Referencia de features: TBO Hub, Culling Hub, Flow Hub, Delta, Aimlock
   Mejoras: auto-block anti-desync, BF-chain adaptativo por ping,
            anti-stun que respeta i-frames, auto-domain inteligente.
   ─────────────────────────────────────────────────────────────────────────
   USO:
     loadstring(game:HttpGet("TU_RAW_URL_AQUI"))()
   o pega todo el bloque en tu executor y ejecuta.
═══════════════════════════════════════════════════════════════════════════
]]

------------------------------------------------------------------
-- 0. PROTECCIONES Y SERVICIOS
------------------------------------------------------------------
if getgenv().VeniceJJS and getgenv().VeniceJJS.Unload then
    pcall(getgenv().VeniceJJS.Unload)
end

local VJS = {}
getgenv().VeniceJJS = VJS
VJS.Version  = "1.0.0"
VJS.Flags    = {}
VJS.Conns    = {}
VJS.Loops    = {}
VJS.Alive    = true

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UIS           = game:GetService("UserInputService")
local VIM           = game:GetService("VirtualInputManager")
local RS            = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local Lighting      = game:GetService("Lighting")
local Camera        = workspace.CurrentCamera

local LP  = Players.LocalPlayer
local PG  = LP:WaitForChild("PlayerGui")
local Char, Hum, Root

------------------------------------------------------------------
-- 1. CONFIG / KEYBINDS (editables en la pestaña Ajustes)
------------------------------------------------------------------
VJS.Config = {
    -- Keybinds
    M1        = "Mouse1",
    Block     = "F",
    Special   = "R",
    Awakening = "G",
    Dash      = "LeftShift",
    Skills    = {"One","Two","Three","Four"},

    -- Auto Block
    BlockRange      = 14,
    PerfectBlock    = true,
    BlockReconnect  = 0.045,

    -- Auto Black Flash
    BFMove          = "Three",
    BFRange         = 13,
    BFBaseDelay     = 0.10,   -- se ajusta solo por ping
    BFMaxChain      = 4,
    BFAutoChain     = true,

    -- Auto Counter / Parry
    CounterKey      = "F",
    CounterRange    = 11,

    -- Auto Domain / Awakening
    AutoDomain      = true,
    AutoAwaken      = true,
    AutoDomainRange = 40,

    -- Movement
    WalkSpeed       = 22,
    JumpPower       = 55,
    FlySpeed        = 60,

    -- Visual
    ESPRange        = 400,
    HitboxRange     = 14,
}

local function cfg(k) return VJS.Config[k] end
local function setCfg(k, v) VJS.Config[k] = v end

------------------------------------------------------------------
-- 2. HELPERS
------------------------------------------------------------------
local function Notify(title, text, dur)
    dur = dur or 3
    local sg = PG:FindFirstChild("VJS_Notify") or Instance.new("ScreenGui")
    sg.Name = "VJS_Notify"; sg.ResetOnSpawn = false; sg.Parent = PG
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 56)
    frame.Position = UDim2.new(1, -320, 0, 16 + (#sg:GetChildren()-1)*62)
    frame.BackgroundColor3 = Color3.fromRGB(18,18,24)
    frame.BackgroundTransparency = 1; frame.BorderSizePixel = 0; frame.Parent = sg
    local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0,10)
    local stroke = Instance.new("UIStroke", frame); stroke.Color = Color3.fromRGB(120,90,255)
    local accent = Instance.new("Frame", frame)
    accent.Size = UDim2.new(0,4,1,0); accent.BackgroundColor3 = Color3.fromRGB(150,120,255)
    accent.BorderSizePixel = 0; accent.Parent = frame
    local c2 = Instance.new("UICorner", accent); c2.CornerRadius = UDim.new(0,10)
    local t = Instance.new("TextLabel", frame)
    t.BackgroundTransparency = 1; t.Position = UDim2.new(0,14,0,6)
    t.Size = UDim2.new(1,-20,0,20); t.Font = Enum.Font.GothamBold; t.TextSize = 14
    t.TextColor3 = Color3.fromRGB(235,235,255); t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = title
    local d = Instance.new("TextLabel", frame)
    d.BackgroundTransparency = 1; d.Position = UDim2.new(0,14,0,26)
    d.Size = UDim2.new(1,-20,0,22); d.Font = Enum.Font.Gotham; d.TextSize = 12
    d.TextColor3 = Color3.fromRGB(170,170,190); d.TextXAlignment = Enum.TextXAlignment.Left
    d.Text = text
    TweenService:Create(frame, TweenInfo.new(0.25), {BackgroundTransparency=0.05}):Play()
    task.delay(dur, function()
        local tw = TweenService:Create(frame, TweenInfo.new(0.3), {BackgroundTransparency=1, Position=frame.Position+UDim2.new(0,40,0,0)})
        tw:Play(); tw.Completed:Wait(); frame:Destroy()
    end)
end

-- Ping actual
local function getPing()
    local ok, p = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return ok and p or 80
end

-- Simulación de teclado (prefiere funciones del executor, cae a VIM)
local function keyDown(code)
    if keypress then keypress(code) else VIM:SendKeyEvent(true, code, false, game) end
end
local function keyUp(code)
    if keyrelease then keyrelease(code) else VIM:SendKeyEvent(false, code, false, game) end
end
local function tap(code, hold)
    hold = hold or 0.03
    keyDown(code); task.wait(hold); keyUp(code)
end

local keyMap = {
    Mouse1="Mouse1", F="F", R="R", G="G", Q="Q", E="E", Space="Space",
    LeftShift="LeftShift", LeftControl="LeftControl",
    One="One", Two="Two", Three="Three", Four="Four", Five="Five",
}
local function K(name) return keyMap[name] or name end

-- M1 (click izquierdo)
local function m1()
    VIM:SendMouseButtonEvent(0,0,0,true,game,0)
    task.wait(0.02)
    VIM:SendMouseButtonEvent(0,0,0,false,game,0)
end

------------------------------------------------------------------
-- 3. DETECCIÓN DE ENTORNO Y REMOTES
------------------------------------------------------------------
VJS.IsJJS = false
task.spawn(function()
    local ok = pcall(function() return game.PlaceId end)
    -- PlaceId conocido de Jujutsu Shenanigans
    if game.PlaceId == 9391468976 then VJS.IsJJS = true end
    if not VJS.IsJJS then
        VJS.IsJJS = RS:FindFirstChild("Combat") ~= nil or game:GetService("Teams"):FindFirstChild("Players") ~= nil
    end
end)

-- Escaneo de remotes por nombre (algunos hubs los usan; el keypress es el fallback robusto)
VJS.Remotes = {}
for _, v in ipairs(RS:GetDescendants()) do
    if v:IsA("RemoteEvent") or v:IsA("UnreliableRemoteEvent") then
        VJS.Remotes[v.Name] = v
    end
end
VJS.Fire = function(name, ...)
    local r = VJS.Remotes[name]
    if r then pcall(function() r:FireServer(...) end) end
end

------------------------------------------------------------------
-- 4. ESTADO DEL PERSONAJE
------------------------------------------------------------------
local function refreshChar()
    Char = LP.Character
    if Char then
        Hum  = Char:FindFirstChildOfClass("Humanoid")
        Root = Char:FindFirstChild("HumanoidRootPart")
    end
end
LP.CharacterAdded:Connect(function()
    task.wait(0.4); refreshChar()
    if VJS.Flags.Speed then if Hum then Hum.WalkSpeed = cfg("WalkSpeed") end end
    if VJS.Flags.Fly then VJS.StartFly() end
end)
refreshChar()

local function isAlive() return Char and Hum and Hum.Health > 0 and Root end

-- Enemigos vivos ordenados por distancia
local function getEnemies(maxRange)
    if not isAlive() then return {} end
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local h = plr.Character:FindFirstChildOfClass("Humanoid")
            local r = plr.Character:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 then
                local dist = (r.Position - Root.Position).Magnitude
                if not maxRange or dist <= maxRange then
                    table.insert(list, {player=plr, hum=h, root=r, dist=dist})
                end
            end
        end
    end
    table.sort(list, function(a,b) return a.dist < b.dist end)
    return list
end
VJS.getEnemies = getEnemies

------------------------------------------------------------------
-- 5. FEATURES — COMBATE
------------------------------------------------------------------
-- 5.1 AUTO BLOCK (anti-desync, con Perfect Block)
task.spawn(function()
    local blocked = false
    while VJS.Alive do
        task.wait(cfg("BlockReconnect"))
        if VJS.Flags.AutoBlock and isAlive() then
            local enemies = getEnemies(cfg("BlockRange"))
            local threat = #enemies > 0
            if threat and not blocked then
                keyDown(K(cfg("Block"))); blocked = true
            elseif not threat and blocked then
                keyUp(K(cfg("Block"))); blocked = false
            end
        elseif blocked then
            keyUp(K(cfg("Block"))); blocked = false
        end
    end
end)

-- 5.2 AUTO BLACK FLASH (delay adaptativo por ping + chain hasta 4)
task.spawn(function()
    local chain = 0
    while VJS.Alive do
        task.wait(0.05)
        if VJS.Flags.AutoBF and isAlive() then
            local enemies = getEnemies(cfg("BFRange"))
            if #enemies > 0 then
                local pingComp = math.clamp(getPing()/1000, 0.03, 0.09)
                local delay = cfg("BFBaseDelay") + pingComp
                tap(K(cfg("BFMove")), 0.02)      -- primer input
                task.wait(delay)
                tap(K(cfg("BFMove")), 0.02)      -- conversión a Black Flash
                if cfg("BFAutoChain") then
                    chain = chain + 1
                    if chain >= cfg("BFMaxChain") then chain = 0; task.wait(0.08) end
                end
                task.wait(0.09)
            else
                chain = 0
            end
        end
    end
end)

-- 5.3 AUTO COUNTER / PARRY
task.spawn(function()
    while VJS.Alive do
        task.wait(0.06)
        if VJS.Flags.AutoCounter and isAlive() then
            local enemies = getEnemies(cfg("CounterRange"))
            for _, e in ipairs(enemies) do
                -- heurística: enemigo mirándote + en rango → bloquea y golpea
                local dir = (Root.Position - e.root.Position).Unit
                local facing = e.root.CFrame.LookVector
                if facing:Dot(dir) > 0.3 then
                    keyDown(K(cfg("CounterKey"))); task.wait(0.03)
                    m1(); keyUp(K(cfg("CounterKey")))
                    break
                end
            end
        end
    end
end)

-- 5.4 AUTO M1 (mantener presión de M1 en rango)
task.spawn(function()
    while VJS.Alive do
        task.wait(0.16)
        if VJS.Flags.AutoM1 and isAlive() then
            if #getEnemies(cfg("BlockRange") + 2) > 0 then m1() end
        end
    end
end)

-- 5.5 AUTO SKILLS (rota 1→2→3→4 en rango)
task.spawn(function()
    local idx = 1
    while VJS.Alive do
        task.wait(0.35)
        if VJS.Flags.AutoSkills and isAlive() then
            if #getEnemies(cfg("BlockRange") + 4) > 0 then
                tap(K(cfg("Skills")[idx]), 0.03)
                idx = idx % 4 + 1
            end
        end
    end
end)

-- 5.6 AUTO DOMAIN / AWAKENING
task.spawn(function()
    while VJS.Alive do
        task.wait(0.5)
        if isAlive() then
            local enemies = getEnemies(cfg("AutoDomainRange"))
            if cfg("AutoAwaken") and VJS.Flags.AutoAwaken and #enemies > 0 then
                tap(K(cfg("Awakening")), 0.03)
            end
            if cfg("AutoDomain") and VJS.Flags.AutoDomain and #enemies > 1 then
                tap("Four", 0.03)
            end
        end
    end
end)

-- 5.7 KILL AURA (M1 automático a rango extendido)
task.spawn(function()
    while VJS.Alive do
        task.wait(0.1)
        if VJS.Flags.KillAura and isAlive() then
            local e = getEnemies(cfg("HitboxRange") + 3)[1]
            if e then m1() end
        end
    end
end)

-- 5.8 AIM / LOCK-ON
task.spawn(function()
    RunService.RenderStepped:Connect(function()
        if VJS.Flags.AimLock and isAlive() then
            local e = getEnemies(300)[1]
            if e then
                local target = e.root.Position
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position,
                    Vector3.new(target.X, target.Y + 2, target.Z))
            end
        end
    end)
end)

------------------------------------------------------------------
-- 6. FEATURES — MOVIMIENTO
------------------------------------------------------------------
VJS.StartFly = function()
    if VJS.Flags.Fly and isAlive() then return end
    VJS.Flags.Fly = true
    local bg = Instance.new("BodyGyro"); bg.P = 9e4; bg.MaxTorque = Vector3.new(9e9,9e9,9e9); bg.CFrame = Root.CFrame; bg.Parent = Root
    local bv = Instance.new("BodyVelocity"); bv.Velocity = Vector3.zero; bv.MaxForce = Vector3.new(9e9,9e9,9e9); bv.Parent = Root
    VJS._flyBG, VJS._flyBV = bg, bv
    VJS._flyConn = RunService.RenderStepped:Connect(function()
        if not VJS.Flags.Fly or not isAlive() then return end
        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        bv.Velocity = dir.Magnitude > 0 and dir.Unit * cfg("FlySpeed") or Vector3.zero
        bg.CFrame = Camera.CFrame
    end)
end
VJS.StopFly = function()
    VJS.Flags.Fly = false
    if VJS._flyConn then VJS._flyConn:Disconnect() end
    if VJS._flyBG then VJS._flyBG:Destroy() end
    if VJS._flyBV then VJS._flyBV:Destroy() end
end

-- Speed / Jump / Infinite Jump
RunService.Heartbeat:Connect(function()
    if not isAlive() then return end
    if VJS.Flags.Speed then Hum.WalkSpeed = cfg("WalkSpeed") end
    if VJS.Flags.Jump  then Hum.JumpPower = cfg("JumpPower"); Hum.UseJumpPower = true end
end)
UIS.JumpRequest:Connect(function()
    if VJS.Flags.InfJump and isAlive() then Hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if VJS.Flags.NoClip and Char then
        for _, p in ipairs(Char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end
end)

------------------------------------------------------------------
-- 7. FEATURES — ANTI / DEFENSIVO
------------------------------------------------------------------
-- Anti Ragdoll (respeta i-frames de grabs)
task.spawn(function()
    while VJS.Alive do
        task.wait(0.1)
        if VJS.Flags.AntiRagdoll and isAlive() then
            local state = Hum:GetState()
            if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.FallingDown then
                Hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end
    end
end)

-- Anti Stun
task.spawn(function()
    while VJS.Alive do
        task.wait(0.08)
        if VJS.Flags.AntiStun and isAlive() and Hum.WalkSpeed < 8 then
            Hum.WalkSpeed = cfg("WalkSpeed")
        end
    end
end)

-- Anti Domain (camina fuera / bloquea al detectar dominio)
task.spawn(function()
    while VJS.Alive do
        task.wait(0.2)
        if VJS.Flags.AntiDomain and isAlive() then
            -- heurística: si hay un objeto de dominio cerca, intenta salir
            for _, v in ipairs(workspace:GetChildren()) do
                if v.Name:lower():find("domain") and v:IsA("Model") then
                    local pivot = v:GetPivot().Position
                    if (pivot - Root.Position).Magnitude < 60 then
                        -- empuje simple hacia afuera
                        Root.CFrame = Root.CFrame + Root.CFrame.LookVector * 0.5
                    end
                end
            end
        end
    end
end)

------------------------------------------------------------------
-- 8. FEATURES — VISUAL (ESP + Hitbox)
------------------------------------------------------------------
local espFolder = Instance.new("Folder", workspace); espFolder.Name = "VJS_ESP"
local function clearESP() for _,v in ipairs(espFolder:GetChildren()) do v:Destroy() end end

local function buildESP()
    clearESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local hl = Instance.new("Highlight", espFolder)
            hl.Adornee = plr.Character
            hl.FillColor = Color3.fromRGB(150,90,255)
            hl.OutlineColor = Color3.fromRGB(255,255,255)
            hl.FillTransparency = 0.6
        end
    end
end

task.spawn(function()
    while VJS.Alive do
        task.wait(0.5)
        if VJS.Flags.ESP then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP and plr.Character and not espFolder:FindFirstChild(plr.Name) then
                    local hl = Instance.new("Highlight", espFolder); hl.Name = plr.Name
                    hl.Adornee = plr.Character; hl.FillColor = Color3.fromRGB(150,90,255)
                    hl.OutlineColor = Color3.fromRGB(255,255,255); hl.FillTransparency = 0.6
                end
            end
        else
            clearESP()
        end
    end
end)

-- Hitbox visual
task.spawn(function()
    local box
    while VJS.Alive do
        task.wait(0.05)
        if VJS.Flags.ShowHitbox and isAlive() then
            if not box or not box.Parent then
                box = Instance.new("Part"); box.Name="VJS_Hitbox"; box.Anchored=true
                box.CanCollide=false; box.CanQuery=false; box.CanTouch=false
                box.Material=Enum.Material.ForceField; box.Color=Color3.fromRGB(255,80,80)
                box.Transparency=0.7; box.Size=Vector3.new(6,6,6); box.Parent=workspace
            end
            box.CFrame = Root.CFrame
        elseif box then box:Destroy(); box=nil end
    end
end)

------------------------------------------------------------------
-- 9. UI — LIBRERÍA PROPIA (bonita, oscura, con sidebar)
------------------------------------------------------------------
local function New(class, props)
    local i = Instance.new(class)
    for k,v in pairs(props) do if k ~= "Parent" then i[k] = v end end
    return i
end
local function corner(o,r) local c=New("UICorner",{CornerRadius=UDim.new(0,r or 8),Parent=o}); return c end
local function stroke(o,col) local s=New("UIStroke",{Color=col or Color3.fromRGB(70,70,90),Thickness=1,Parent=o}); return s end
local function pad(o,n) local p=New("UIPadding",{PaddingTop=UDim.new(0,n),PaddingBottom=UDim.new(0,n),PaddingLeft=UDim.new(0,n),PaddingRight=UDim.new(0,n),Parent=o}); return p end

local Screen = New("ScreenGui",{Name="VeniceJJS",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Parent=PG})

local Main = New("Frame",{Name="Main",Size=UDim2.new(0,620,0,420),Position=UDim2.new(0.5,-310,0.5,-210),
    BackgroundColor3=Color3.fromRGB(15,15,22),BorderSizePixel=0,Parent=Screen})
corner(Main,14); stroke(Main,Color3.fromRGB(90,70,200))
Main.ClipsDescendants = true

-- Barra superior (drag)
local Top = New("Frame",{Name="Top",Size=UDim2.new(1,0,0,40),BackgroundColor3=Color3.fromRGB(20,20,30),BorderSizePixel=0,Parent=Main})
local title = New("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,16,0,0),Size=UDim2.new(1,-60,1,0),
    Font=Enum.Font.GothamBlack,TextSize=17,Text="VENICE.JS  •  Jujutsu Shenanigans",TextColor3=Color3.fromRGB(200,180,255),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=Top})
local ver = New("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(1,-120,0,0),Size=UDim2.new(0,90,1,0),
    Font=Enum.Font.Gotham,TextSize=12,Text="v"..VJS.Version,TextColor3=Color3.fromRGB(140,140,170),Parent=Top})

-- Drag
do
    local dragging, dragStart, startPos
    Top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Sidebar
local Side = New("Frame",{Name="Side",Position=UDim2.new(0,0,0,40),Size=UDim2.new(0,150,1,-40),
    BackgroundColor3=Color3.fromRGB(18,18,26),BorderSizePixel=0,Parent=Main})
local sideList = New("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder,Parent=Side})
pad(Side,8)

local Content = New("Frame",{Name="Content",Position=UDim2.new(0,150,0,40),Size=UDim2.new(1,-150,1,-40),
    BackgroundColor3=Color3.fromRGB(15,15,22),BorderSizePixel=0,Parent=Main})

local tabs = {}
local activeTab
local function selectTab(name)
    for n, t in pairs(tabs) do t.Page.Visible = (n == name) end
    for n, b in pairs(tabs) do b.Button.BackgroundColor3 = (n==name) and Color3.fromRGB(45,35,85) or Color3.fromRGB(24,24,34) end
end
local function createTab(name)
    local btn = New("TextButton",{Size=UDim2.new(1,0,0,32),BackgroundColor3=Color3.fromRGB(24,24,34),
        BorderSizePixel=0,Font=Enum.Font.GothamBold,TextSize=13,Text="  "..name,TextColor3=Color3.fromRGB(200,200,220),
        TextXAlignment=Enum.TextXAlignment.Left,Parent=Side})
    corner(btn,8)
    local page = New("ScrollingFrame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=4,ScrollBarImageColor3=Color3.fromRGB(120,90,255),CanvasSize=UDim2.new(0,0,0,0),
        Visible=false,Parent=Content})
    pad(page,12)
    local lay = New("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder,Parent=page})
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0,0,0,lay.AbsoluteContentSize.Y+20)
    end)
    tabs[name] = {Button=btn, Page=page}
    btn.MouseButton1Click:Connect(function() selectTab(name) end)
    return page
end

-- Widgets
local function section(parent, text)
    local s = New("Frame",{Size=UDim2.new(1,-10,0,28),BackgroundTransparency=1,Parent=parent})
    local l = New("TextLabel",{BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Font=Enum.Font.GothamBlack,
        TextSize=13,Text=text,TextColor3=Color3.fromRGB(150,120,255),TextXAlignment=Enum.TextXAlignment.Left,Parent=s})
    return s
end

local function toggle(parent, text, default, callback)
    local f = New("TextButton",{Size=UDim2.new(1,-10,0,32),BackgroundColor3=Color3.fromRGB(24,24,34),
        BorderSizePixel=0,Text="",AutoButtonColor=false,Parent=parent})
    corner(f,8)
    local lbl = New("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,12,0,0),Size=UDim2.new(1,-60,1,0),
        Font=Enum.Font.Gotham,TextSize=13,Text=text,TextColor3=Color3.fromRGB(210,210,230),TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
    local track = New("Frame",{Position=UDim2.new(1,-48,0.5,-9),Size=UDim2.new(0,36,0,18),
        BackgroundColor3=Color3.fromRGB(50,50,70),BorderSizePixel=0,Parent=f})
    corner(track,9)
    local knob = New("Frame",{Position=UDim2.new(0,2,0,2),Size=UDim2.new(0,14,0,14),
        BackgroundColor3=Color3.fromRGB(230,230,240),BorderSizePixel=0,Parent=track})
    corner(knob,7)
    local state = default or false
    local function render()
        TweenService:Create(knob,TweenInfo.new(0.15),{Position = state and UDim2.new(1,-16,0,2) or UDim2.new(0,2,0,2)}):Play()
        TweenService:Create(track,TweenInfo.new(0.15),{BackgroundColor3 = state and Color3.fromRGB(120,90,255) or Color3.fromRGB(50,50,70)}):Play()
    end
    render()
    f.MouseButton1Click:Connect(function()
        state = not state; render(); if callback then callback(state) end
    end)
    return f, function() return state end
end

local function slider(parent, text, min, max, default, callback)
    local f = New("Frame",{Size=UDim2.new(1,-10,0,46),BackgroundColor3=Color3.fromRGB(24,24,34),BorderSizePixel=0,Parent=parent})
    corner(f,8)
    local lbl = New("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,12,0,4),Size=UDim2.new(1,-60,0,18),
        Font=Enum.Font.Gotham,TextSize=13,Text=text,TextColor3=Color3.fromRGB(210,210,230),TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
    local val = New("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(1,-70,0,4),Size=UDim2.new(0,58,0,18),
        Font=Enum.Font.GothamBold,TextSize=13,Text=tostring(default),TextColor3=Color3.fromRGB(150,120,255),
        TextXAlignment=Enum.TextXAlignment.Right,Parent=f})
    local bar = New("Frame",{Position=UDim2.new(0,12,0,28),Size=UDim2.new(1,-24,0,8),BackgroundColor3=Color3.fromRGB(45,45,60),BorderSizePixel=0,Parent=f})
    corner(bar,4)
    local fill = New("Frame",{Size=UDim2.new((default-min)/(max-min),0,1,0),BackgroundColor3=Color3.fromRGB(120,90,255),BorderSizePixel=0,Parent=bar})
    corner(fill,4)
    local dragging = false
    local function set(input)
        local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + (max-min)*rel + 0.5)
        val.Text = tostring(v)
        fill.Size = UDim2.new(rel,0,1,0)
        if callback then callback(v) end
    end
    bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; set(i) end end)
    UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then set(i) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
    return f
end

local function button(parent, text, callback)
    local b = New("TextButton",{Size=UDim2.new(1,-10,0,32),BackgroundColor3=Color3.fromRGB(35,30,60),
        BorderSizePixel=0,Font=Enum.Font.GothamBold,TextSize=13,Text=text,TextColor3=Color3.fromRGB(210,200,255),
        AutoButtonColor=true,Parent=parent})
    corner(b,8)
    b.MouseButton1Click:Connect(function() if callback then callback() end end)
    return b
end

local function label(parent, text)
    local l = New("TextLabel",{Size=UDim2.new(1,-10,0,20),BackgroundTransparency=1,Font=Enum.Font.Gotham,
        TextSize=12,Text=text,TextColor3=Color3.fromRGB(160,160,185),TextXAlignment=Enum.TextXAlignment.Left,
        TextWrapped=true,Parent=parent})
    return l
end

------------------------------------------------------------------
-- 10. CONSTRUCCIÓN DE PESTAÑAS
------------------------------------------------------------------
-- COMBAT
local combat = createTab("Combate")
section(combat, "AUTOMATIZACIÓN DE COMBATE")
toggle(combat, "Auto Block (anti-desync)", false, function(v) VJS.Flags.AutoBlock=v end)
toggle(combat, "Auto Black Flash (chain x4)", false, function(v) VJS.Flags.AutoBF=v end)
toggle(combat, "Auto Counter / Parry", false, function(v) VJS.Flags.AutoCounter=v end)
toggle(combat, "Auto M1", false, function(v) VJS.Flags.AutoM1=v end)
toggle(combat, "Auto Skills (1-4)", false, function(v) VJS.Flags.AutoSkills=v end)
toggle(combat, "Auto Awakening", false, function(v) VJS.Flags.AutoAwaken=v end)
toggle(combat, "Auto Domain", false, function(v) VJS.Flags.AutoDomain=v end)
toggle(combat, "Kill Aura", false, function(v) VJS.Flags.KillAura=v end)
toggle(combat, "Aim / Lock-On", false, function(v) VJS.Flags.AimLock=v end)
section(combat, "AJUSTES DE COMBATE")
slider(combat, "Rango de bloqueo", 6, 30, cfg("BlockRange"), function(v) setCfg("BlockRange",v) end)
slider(combat, "Rango Black Flash", 6, 25, cfg("BFRange"), function(v) setCfg("BFRange",v) end)
slider(combat, "Delay BF (s)", 0.05, 0.25, cfg("BFBaseDelay"), function(v) setCfg("BFBaseDelay",v) end)
slider(combat, "Rango hitbox/killaura", 6, 30, cfg("HitboxRange"), function(v) setCfg("HitboxRange",v) end)

-- CHARACTER
local charTab = createTab("Personaje")
section(charTab, "TECHS AUTOMATIZADAS")
label(charTab, "Activa el preset y el script ejecuta la tech sola a velocidad de máquina.")
toggle(charTab, "Auto Yuki (Garuda Reset / CURSE)", false, function(v) VJS.Flags.AutoYuki=v end)
toggle(charTab, "Auto Todo (Boogie Woogie swap)", false, function(v) VJS.Flags.AutoTodo=v end)
toggle(charTab, "Auto Sukuna (WCS chant)", false, function(v) VJS.Flags.AutoWCS=v end)
toggle(charTab, "Auto Hakari (Idle Death Gamble rush)", false, function(v) VJS.Flags.AutoHakari=v end)
toggle(charTab, "Auto Locust (air combo start)", false, function(v) VJS.Flags.AutoLocust=v end)
toggle(charTab, "Auto Gojo (Red MAX / 0.2 Domain)", false, function(v) VJS.Flags.AutoGojo=v end)
section(charTab, "COMBOS")
button(charTab, "Ejecutar combo universal (M1 x3 → skill3 → skill2)", function()
    task.spawn(function()
        for _=1,3 do m1(); task.wait(0.16) end
        tap("Three"); task.wait(0.1); tap("Three"); task.wait(0.15); tap("Two")
    end)
end)
button(charTab, "Ejecutar Black Flash chain (4x)", function()
    task.spawn(function()
        for i=1,4 do tap("Three"); task.wait(0.12); tap("Three"); task.wait(0.1) end
    end)
end)

-- MOVEMENT
local move = createTab("Movimiento")
toggle(move, "Speed", false, function(v) VJS.Flags.Speed=v end)
toggle(move, "Jump Boost", false, function(v) VJS.Flags.Jump=v end)
toggle(move, "Infinite Jump", false, function(v) VJS.Flags.InfJump=v end)
toggle(move, "Fly", false, function(v) if v then VJS.StartFly() else VJS.StopFly() end end)
toggle(move, "NoClip", false, function(v) VJS.Flags.NoClip=v end)
slider(move, "WalkSpeed", 16, 120, cfg("WalkSpeed"), function(v) setCfg("WalkSpeed",v) end)
slider(move, "JumpPower", 50, 200, cfg("JumpPower"), function(v) setCfg("JumpPower",v) end)
slider(move, "FlySpeed", 20, 250, cfg("FlySpeed"), function(v) setCfg("FlySpeed",v) end)

-- VISUAL
local vis = createTab("Visual")
toggle(vis, "Player ESP", false, function(v) VJS.Flags.ESP=v end)
toggle(vis, "Mostrar Hitbox", false, function(v) VJS.Flags.ShowHitbox=v end)
toggle(vis, "Anti Ragdoll", false, function(v) VJS.Flags.AntiRagdoll=v end)
toggle(vis, "Anti Stun", false, function(v) VJS.Flags.AntiStun=v end)
toggle(vis, "Anti Domain", false, function(v) VJS.Flags.AntiDomain=v end)
section(vis, "ANTI-CHEESE")
toggle(vis, "Anti Kill", false, function(v) VJS.Flags.AntiKill=v end)
toggle(vis, "Anti Blackhole", false, function(v) VJS.Flags.AntiBlackhole=v end)
toggle(vis, "Silent Animations", false, function(v) VJS.Flags.SilentAnim=v end)

-- SERVER
local srv = createTab("Servidor")
button(srv, "Rejoin", function() game:GetService("TeleportService"):Teleport(game.PlaceId) end)
button(srv, "Server Hop", function()
    local servers = game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100")).data
    for _,s in ipairs(servers) do if s.playing < s.maxPlayers and s.id ~= game.JobId then
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, s.id); break end end
end)
button(srv, "Copiar link del juego", function()
    pcall(function() setclipboard("https://www.roblox.com/games/9391468976") end)
    Notify("Copiado", "Link del juego en el portapapeles")
end)

-- SETTINGS
local set = createTab("Ajustes")
section(set, "KEYBINDS")
label(set, "Teclas actuales — edítalas en VJS.Config si difieren.")
label(set, "M1: "..cfg("M1").."  |  Block: "..cfg("Block").."  |  Special: "..cfg("Special").."  |  Awakening: "..cfg("Awakening"))
button(set, "Restaurar defaults", function()
    Notify("Reset", "Reiniciando script..."); task.wait(0.4); VJS.Unload()
end)
section(set, "INFO")
label(set, "VENICE.JS "..VJS.Version.." — suite para Jujutsu Shenanigans")
label(set, "Referencia de features: TBO / Culling / Flow / Delta / Aimlock")

selectTab("Combate")

------------------------------------------------------------------
-- 11. UNLOAD
------------------------------------------------------------------
function VJS.Unload()
    VJS.Alive = false
    for _,c in pairs(VJS.Conns) do pcall(function() c:Disconnect() end) end
    pcall(VJS.StopFly)
    if Screen then Screen:Destroy() end
    local n = PG:FindFirstChild("VJS_Notify"); if n then n:Destroy() end
    espFolder:Destroy()
    getgenv().VeniceJJS = nil
    print("[VENICE.JS] Descargado.")
end

Notify("VENICE.JS cargado", "v"..VJS.Version.." — todo listo. Togglea lo que quieras.")
print("[VENICE.JS] cargado correctamente.")
