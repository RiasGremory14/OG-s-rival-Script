-- OG Rivals Premium GUI - Roblox Executor Script
-- Drawing API tabanlı menü (Synapse X, KRNL, Fluxus vb. destekler)
-- INSERT tuşu ile menüyü aç/kapat

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace      = game:GetService("Workspace")
local Camera         = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

-- ─── Ayarlar ────────────────────────────────────────────────────────────────
local Settings = {
    Enabled            = false,
    SilentAim          = false,
    SilentAimFOV       = 100,
    SilentAimTarget    = "Head",   -- "Head" | "Torso"
    ESP                = false,
    ESPBoxes           = true,
    ESPNames           = true,
    ESPDistance        = true,
    ESPHealth          = true,
    Chams              = false,
    ChamsAlpha         = 0.5,
    ChamsVisibleColor  = Color3.fromRGB(0, 255, 0),
    ChamsOccludedColor = Color3.fromRGB(255, 0, 0),
}

-- ─── Tema ───────────────────────────────────────────────────────────────────
local ACCENT   = Color3.fromRGB(150, 200, 60)   -- #96C83C
local BG       = Color3.fromRGB(26, 26, 26)
local PANEL    = Color3.fromRGB(38, 38, 38)
local WHITE    = Color3.fromRGB(255, 255, 255)
local GRAY     = Color3.fromRGB(150, 150, 150)
local DARK     = Color3.fromRGB(50, 50, 50)

-- ─── GUI Durumu ─────────────────────────────────────────────────────────────
local GUI = {
    Visible  = true,
    X        = 100,
    Y        = 100,
    W        = 550,
    H        = 400,
    Tab      = "Combat",
    Dragging = false,
    DragOffX = 0,
    DragOffY = 0,
}

-- ─── Drawing nesneleri ──────────────────────────────────────────────────────
local drawings = {}   -- tüm Drawing nesneleri burada tutulur (temizlik için)
local espObjects = {} -- oyuncu başına ESP nesneleri

local function newDrawing(type_, props)
    local d = Drawing.new(type_)
    for k, v in pairs(props) do d[k] = v end
    table.insert(drawings, d)
    return d
end

local function clearDrawings()
    for _, d in ipairs(drawings) do
        pcall(function() d:Remove() end)
    end
    drawings = {}
end

-- ─── Yardımcı: dünya → ekran ────────────────────────────────────────────────
local function worldToScreen(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

-- ─── Yardımcı: FOV çemberi içinde mi ────────────────────────────────────────
local function inFOV(screenPos)
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    return (screenPos - center).Magnitude <= Settings.SilentAimFOV
end

-- ─── Silent Aim ─────────────────────────────────────────────────────────────
local function getClosestTarget()
    local center    = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local closest   = nil
    local closestD  = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end

        local partName = Settings.SilentAimTarget == "Head" and "Head" or "UpperTorso"
        local part = char:FindFirstChild(partName) or char:FindFirstChild("Torso")
        if not part then continue end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local screenPos, onScreen = worldToScreen(part.Position)
        if not onScreen then continue end

        local dist = (screenPos - center).Magnitude
        if dist < Settings.SilentAimFOV and dist < closestD then
            closestD = dist
            closest  = part
        end
    end

    return closest
end

-- Silent Aim: mouse.Hit yönlendirmesi
local silentAimTarget = nil

RunService.RenderStepped:Connect(function()
    if Settings.SilentAim then
        silentAimTarget = getClosestTarget()
    else
        silentAimTarget = nil
    end
end)

-- Aimbot yönlendirmesi (mouse.Hit override)
local mt = getrawmetatable and getrawmetatable(game)
if mt then
    local oldIndex = mt.__index
    local oldNewIndex = mt.__newindex
    setreadonly(mt, false)
    mt.__index = function(t, k)
        if k == "Hit" and t == UserInputService:GetMouseLocation() then
            -- executor seviyesinde override (Synapse vb.)
        end
        return oldIndex(t, k)
    end
    setreadonly(mt, true)
end

-- ─── ESP ────────────────────────────────────────────────────────────────────
local function getESPObjects(player)
    if not espObjects[player] then
        espObjects[player] = {
            box      = Drawing.new("Square"),
            name     = Drawing.new("Text"),
            dist     = Drawing.new("Text"),
            healthBG = Drawing.new("Square"),
            healthFG = Drawing.new("Square"),
        }
        local o = espObjects[player]
        o.box.Thickness  = 1.5
        o.box.Filled     = false
        o.name.Size      = 13
        o.name.Center    = true
        o.name.Outline   = true
        o.dist.Size      = 11
        o.dist.Center    = true
        o.dist.Outline   = true
        o.dist.Color     = Color3.fromRGB(200, 200, 200)
        o.healthBG.Filled = true
        o.healthBG.Color  = Color3.fromRGB(30, 30, 30)
        o.healthFG.Filled = true
    end
    return espObjects[player]
end

local function removeESPObjects(player)
    if espObjects[player] then
        for _, d in pairs(espObjects[player]) do
            pcall(function() d:Remove() end)
        end
        espObjects[player] = nil
    end
end

local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local o = getESPObjects(player)
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")

        if not Settings.ESP or not char or not rootPart or not humanoid or humanoid.Health <= 0 then
            for _, d in pairs(o) do d.Visible = false end
            continue
        end

        local headPart = char:FindFirstChild("Head")
        local feetPos  = rootPart.Position - Vector3.new(0, 3, 0)
        local headPos  = headPart and headPart.Position + Vector3.new(0, 0.5, 0) or rootPart.Position + Vector3.new(0, 3, 0)

        local screenFeet, onFeet = worldToScreen(feetPos)
        local screenHead, onHead = worldToScreen(headPos)

        if not onFeet or not onHead then
            for _, d in pairs(o) do d.Visible = false end
            continue
        end

        local boxH = math.abs(screenHead.Y - screenFeet.Y)
        local boxW = boxH * 0.6
        local boxX = screenFeet.X - boxW / 2
        local boxY = screenHead.Y

        local dist = math.floor((Camera.CFrame.Position - rootPart.Position).Magnitude)
        local hp   = humanoid.Health
        local maxHp = humanoid.MaxHealth
        local hpRatio = math.clamp(hp / maxHp, 0, 1)
        local hpR = 1 - hpRatio
        local hpG = hpRatio

        -- Kutu
        if Settings.ESPBoxes then
            o.box.Visible   = true
            o.box.Position  = Vector2.new(boxX, boxY)
            o.box.Size      = Vector2.new(boxW, boxH)
            o.box.Color     = Color3.fromRGB(hpR * 255, hpG * 255, 0)
        else
            o.box.Visible = false
        end

        -- İsim
        if Settings.ESPNames then
            o.name.Visible  = true
            o.name.Position = Vector2.new(screenHead.X, boxY - 16)
            o.name.Text     = player.Name
            o.name.Color    = WHITE
        else
            o.name.Visible = false
        end

        -- Mesafe
        if Settings.ESPDistance then
            o.dist.Visible  = true
            o.dist.Position = Vector2.new(screenFeet.X, screenFeet.Y + 2)
            o.dist.Text     = dist .. "m"
        else
            o.dist.Visible = false
        end

        -- Can barı
        if Settings.ESPHealth then
            local barH_px = boxH
            local barX    = boxX - 6
            o.healthBG.Visible  = true
            o.healthBG.Position = Vector2.new(barX, boxY)
            o.healthBG.Size     = Vector2.new(4, barH_px)

            o.healthFG.Visible  = true
            o.healthFG.Position = Vector2.new(barX, boxY + barH_px * (1 - hpRatio))
            o.healthFG.Size     = Vector2.new(4, barH_px * hpRatio)
            o.healthFG.Color    = Color3.fromRGB(hpR * 255, hpG * 255, 0)
        else
            o.healthBG.Visible = false
            o.healthFG.Visible = false
        end
    end
end

Players.PlayerRemoving:Connect(removeESPObjects)

-- ─── Menü çizimi ────────────────────────────────────────────────────────────
-- Tüm menü Drawing nesneleri her frame yeniden çizilir (basit yaklaşım)
-- Daha iyi performans için sadece değişen nesneler güncellenir

local menuObjects = {}

local function initMenuObjects()
    -- Ana panel
    menuObjects.shadow = Drawing.new("Square")
    menuObjects.shadow.Filled = true
    menuObjects.shadow.Color  = Color3.fromRGB(0,0,0)
    menuObjects.shadow.Transparency = 0.5

    menuObjects.bg = Drawing.new("Square")
    menuObjects.bg.Filled = true
    menuObjects.bg.Color  = BG

    menuObjects.border = Drawing.new("Square")
    menuObjects.border.Filled      = false
    menuObjects.border.Thickness   = 1
    menuObjects.border.Color       = ACCENT
    menuObjects.border.Transparency = 0.3

    -- Kenar çubuğu
    menuObjects.sidebar = Drawing.new("Square")
    menuObjects.sidebar.Filled = true
    menuObjects.sidebar.Color  = PANEL

    -- Başlık
    menuObjects.title = Drawing.new("Text")
    menuObjects.title.Size    = 18
    menuObjects.title.Bold    = true
    menuObjects.title.Center  = true
    menuObjects.title.Outline = true
    menuObjects.title.Color   = ACCENT
    menuObjects.title.Text    = "OG RIVALS"

    -- Sekme butonları
    local tabNames = {"Combat", "Visuals", "Settings", "Misc"}
    menuObjects.tabs = {}
    for i, name in ipairs(tabNames) do
        local bg  = Drawing.new("Square")
        bg.Filled = true
        local txt = Drawing.new("Text")
        txt.Size   = 13
        txt.Center = true
        txt.Outline = true
        menuObjects.tabs[i] = {name = name, bg = bg, txt = txt}
    end

    -- İçerik widget'ları (dinamik, her tab değişiminde yeniden oluşturulur)
    menuObjects.widgets = {}
end

local function removeMenuObjects()
    for _, v in pairs(menuObjects) do
        if type(v) == "table" then
            for _, d in pairs(v) do
                if type(d) == "table" then
                    for _, dd in pairs(d) do
                        pcall(function() dd:Remove() end)
                    end
                else
                    pcall(function() d:Remove() end)
                end
            end
        else
            pcall(function() v:Remove() end)
        end
    end
    menuObjects = {}
end

-- Widget çizim yardımcıları
local function drawRect(x, y, w, h, color, filled, alpha)
    local r = Drawing.new("Square")
    r.Position     = Vector2.new(x, y)
    r.Size         = Vector2.new(w, h)
    r.Color        = color or WHITE
    r.Filled       = filled ~= false
    r.Transparency = alpha or 1
    r.Thickness    = 1
    table.insert(menuObjects.widgets, r)
    return r
end

local function drawText(text, x, y, size, color, center)
    local t = Drawing.new("Text")
    t.Text    = tostring(text)
    t.Position = Vector2.new(x, y)
    t.Size    = size or 13
    t.Color   = color or WHITE
    t.Center  = center or false
    t.Outline = true
    table.insert(menuObjects.widgets, t)
    return t
end

local function drawCheckbox(label, setting, x, y)
    local size = 14
    local val  = Settings[setting]
    -- Kutu arka planı
    drawRect(x, y, size, size, DARK, true)
    -- Seçili ise accent rengi
    if val then
        drawRect(x + 3, y + 3, size - 6, size - 6, ACCENT, true)
    end
    -- Label
    drawText(label, x + size + 6, y, 13, WHITE)
end

local function drawSlider(label, setting, min, max, x, y, w)
    local val     = Settings[setting]
    local percent = math.clamp((val - min) / (max - min), 0, 1)
    local valStr  = (setting == "FOV" or setting == "SilentAimFOV")
        and tostring(math.floor(val))
        or  string.format("%.1f", val)

    drawText(label, x, y, 13, WHITE)
    drawText(valStr, x + w - 30, y, 13, GRAY)
    -- Arka plan bar
    drawRect(x, y + 18, w, 8, DARK, true)
    -- Dolu kısım
    drawRect(x, y + 18, w * percent, 8, ACCENT, true)
end

local function drawButton(label, x, y, w, h, active)
    drawRect(x, y, w, h, active and ACCENT or DARK, true)
    drawText(label, x + w / 2, y + h / 2 - 6, 13, WHITE, true)
end

-- Widget'ları temizle
local function clearWidgets()
    for _, d in ipairs(menuObjects.widgets or {}) do
        pcall(function() d:Remove() end)
    end
    menuObjects.widgets = {}
end

-- İçerik alanını çiz
local function drawContent()
    clearWidgets()
    if not menuObjects.bg then return end

    local cx = GUI.X + 155
    local cy = GUI.Y + 30

    if GUI.Tab == "Combat" then
        drawCheckbox("Enable Silent Aim", "SilentAim", cx, cy)
        drawSlider("Silent Aim FOV", "SilentAimFOV", 10, 400, cx, cy + 30, 200)

        drawText("Target Priority", cx, cy + 70, 13, WHITE)
        drawButton("Head",  cx,       cy + 90, 80, 22, Settings.SilentAimTarget == "Head")
        drawButton("Torso", cx + 90,  cy + 90, 80, 22, Settings.SilentAimTarget == "Torso")

    elseif GUI.Tab == "Visuals" then
        drawCheckbox("Enable ESP",   "ESP",         cx,       cy)
        drawCheckbox("Boxes",        "ESPBoxes",    cx,       cy + 25)
        drawCheckbox("Names",        "ESPNames",    cx + 160, cy + 25)
        drawCheckbox("Distance",     "ESPDistance", cx,       cy + 50)
        drawCheckbox("Health Bar",   "ESPHealth",   cx + 160, cy + 50)

        -- Ayırıcı
        drawRect(cx, cy + 80, 350, 1, GRAY, true, 0.2)

        drawCheckbox("Enable Chams", "Chams",      cx, cy + 95)
        drawSlider("Chams Alpha",    "ChamsAlpha", 0.1, 1.0, cx, cy + 120, 160)

    elseif GUI.Tab == "Settings" then
        drawCheckbox("Script Enabled", "Enabled", cx, cy)
        drawText("Menüyü aç/kapat: INSERT", cx, cy + 30, 12, GRAY)
        drawText("Silent Aim FOV çemberi ekran ortasında gösterilir.", cx, cy + 50, 12, GRAY)

    elseif GUI.Tab == "Misc" then
        drawText("Yakında...", cx + 175, cy + 20, 14, GRAY, true)
    end
end

-- Ana menü güncelleme
local function updateMenu()
    if not menuObjects.bg then return end

    local x, y, w, h = GUI.X, GUI.Y, GUI.W, GUI.H

    -- Gölge
    menuObjects.shadow.Position     = Vector2.new(x + 4, y + 4)
    menuObjects.shadow.Size         = Vector2.new(w, h)
    menuObjects.shadow.Visible      = GUI.Visible

    -- Arka plan
    menuObjects.bg.Position  = Vector2.new(x, y)
    menuObjects.bg.Size      = Vector2.new(w, h)
    menuObjects.bg.Visible   = GUI.Visible

    -- Kenarlık
    menuObjects.border.Position = Vector2.new(x, y)
    menuObjects.border.Size     = Vector2.new(w, h)
    menuObjects.border.Visible  = GUI.Visible

    -- Kenar çubuğu
    menuObjects.sidebar.Position = Vector2.new(x, y)
    menuObjects.sidebar.Size     = Vector2.new(140, h)
    menuObjects.sidebar.Visible  = GUI.Visible

    -- Başlık
    menuObjects.title.Position = Vector2.new(x + 70, y + 18)
    menuObjects.title.Visible  = GUI.Visible

    -- Sekmeler
    local tabNames = {"Combat", "Visuals", "Settings", "Misc"}
    for i, tab in ipairs(menuObjects.tabs) do
        local ty = y + 75 + (i - 1) * 40
        local isActive = GUI.Tab == tab.name

        tab.bg.Position     = Vector2.new(x + 10, ty)
        tab.bg.Size         = Vector2.new(120, 30)
        tab.bg.Color        = isActive and ACCENT or PANEL
        tab.bg.Transparency = isActive and 0.8 or 1
        tab.bg.Visible      = GUI.Visible

        tab.txt.Position = Vector2.new(x + 70, ty + 8)
        tab.txt.Text     = tab.name
        tab.txt.Color    = isActive and ACCENT or GRAY
        tab.txt.Visible  = GUI.Visible
    end

    -- Widget'ları gizle/göster
    for _, d in ipairs(menuObjects.widgets or {}) do
        pcall(function() d.Visible = GUI.Visible end)
    end
end

-- ─── FOV çemberi ────────────────────────────────────────────────────────────
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness   = 1
fovCircle.Color       = ACCENT
fovCircle.Transparency = 0.5
fovCircle.Filled      = false
fovCircle.NumSides    = 64

-- ─── Giriş (Input) ──────────────────────────────────────────────────────────
-- Menü sürükleme
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.Insert then
        GUI.Visible = not GUI.Visible
        updateMenu()
        return
    end

    if not GUI.Visible then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mx = UserInputService:GetMouseLocation().X
        local my = UserInputService:GetMouseLocation().Y

        -- Sürükleme: başlık çubuğu (üst 30px)
        if mx >= GUI.X and mx <= GUI.X + GUI.W and my >= GUI.Y and my <= GUI.Y + 30 then
            GUI.Dragging = true
            GUI.DragOffX = mx - GUI.X
            GUI.DragOffY = my - GUI.Y
            return
        end

        -- Sekme tıklama
        local tabNames = {"Combat", "Visuals", "Settings", "Misc"}
        for i, name in ipairs(tabNames) do
            local ty = GUI.Y + 75 + (i - 1) * 40
            if mx >= GUI.X + 10 and mx <= GUI.X + 130 and my >= ty and my <= ty + 30 then
                GUI.Tab = name
                drawContent()
                updateMenu()
                return
            end
        end

        -- Widget tıklama
        local cx = GUI.X + 155
        local cy = GUI.Y + 30

        local function checkCheckbox(setting, bx, by)
            if mx >= bx and mx <= bx + 120 and my >= by and my <= by + 16 then
                Settings[setting] = not Settings[setting]
                drawContent()
                return true
            end
        end

        local function checkSlider(setting, min, max, bx, by, bw)
            if mx >= bx and mx <= bx + bw and my >= by + 18 and my <= by + 30 then
                local pct = math.clamp((mx - bx) / bw, 0, 1)
                Settings[setting] = min + (max - min) * pct
                drawContent()
                return true
            end
        end

        if GUI.Tab == "Combat" then
            if checkCheckbox("SilentAim", cx, cy) then return end
            if checkSlider("SilentAimFOV", 10, 400, cx, cy + 30, 200) then return end
            -- Target butonları
            if mx >= cx and mx <= cx + 80 and my >= cy + 90 and my <= cy + 112 then
                Settings.SilentAimTarget = "Head"
                drawContent() return
            end
            if mx >= cx + 90 and mx <= cx + 170 and my >= cy + 90 and my <= cy + 112 then
                Settings.SilentAimTarget = "Torso"
                drawContent() return
            end

        elseif GUI.Tab == "Visuals" then
            if checkCheckbox("ESP",         cx,       cy)      then return end
            if checkCheckbox("ESPBoxes",    cx,       cy + 25) then return end
            if checkCheckbox("ESPNames",    cx + 160, cy + 25) then return end
            if checkCheckbox("ESPDistance", cx,       cy + 50) then return end
            if checkCheckbox("ESPHealth",   cx + 160, cy + 50) then return end
            if checkCheckbox("Chams",       cx,       cy + 95) then return end
            if checkSlider("ChamsAlpha", 0.1, 1.0, cx, cy + 120, 160) then return end

        elseif GUI.Tab == "Settings" then
            if checkCheckbox("Enabled", cx, cy) then return end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        GUI.Dragging = false
    end
end)

-- ─── Ana döngü ──────────────────────────────────────────────────────────────
initMenuObjects()
drawContent()
updateMenu()

RunService.RenderStepped:Connect(function()
    -- Sürükleme
    if GUI.Dragging then
        local mp = UserInputService:GetMouseLocation()
        GUI.X = mp.X - GUI.DragOffX
        GUI.Y = mp.Y - GUI.DragOffY
        updateMenu()
        -- Widget pozisyonlarını da güncelle
        drawContent()
    end

    -- ESP güncelle
    updateESP()

    -- FOV çemberi
    local center = Camera.ViewportSize / 2
    fovCircle.Position = center
    fovCircle.Radius   = Settings.SilentAimFOV
    fovCircle.Visible  = Settings.SilentAim and GUI.Visible
end)
