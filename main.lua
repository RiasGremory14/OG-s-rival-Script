-- Modern GUI & Silent Aim Implementation for OG Rivals Script
-- Tema rengi: #96C83C
local ACCENT = {0.588, 0.784, 0.235, 1}
local BG_COLOR = {0.1, 0.1, 0.1, 0.95}
local PANEL_COLOR = {0.15, 0.15, 0.15, 1}

-- Settings table: bu değerleri oyunun içinde kullanabilirsin
local Settings = {
    Enabled = false,      -- Açık / Kapalı
    Smoothness = 1.0,     -- 0.5 – 3.0 arası
    FOV = 600,            -- 300 / 600 / 900
    ActionKey = "space",  -- Örnek: bir özelliğe atanabilecek tuş
    ActionKey2 = "lshift", -- İkinci bir özelliğe atanabilecek tuş
    ESP = false,          -- ESP açık / kapalı
    ESPBoxes = true,      -- Kutu çiz
    ESPNames = true,      -- İsim göster
    ESPDistance = true,   -- Mesafe göster
    ESPHealth = true,     -- Can barı göster
    Chams = false,        -- Chams açık / kapalı
    ChamsAlpha = 0.5,     -- 0.1 – 1.0 arası şeffaflık
    ChamsVisibleColor  = "green",  -- görünür hedef rengi
    ChamsOccludedColor = "red",    -- duvar arkası hedef rengi
    SilentAim = false,             -- Silent Aim açık / kapalı
    SilentAimFOV = 100,            -- Aimbot FOV yarıçapı
    SilentAimTarget = "Head",      -- Head / Chest
}

-- GUI State
local GUI = {
    Visible = true,
    X = 100,
    Y = 100,
    W = 550,
    H = 400,
    Tab = "Combat", -- "Combat", "Visuals", "Settings", "Misc"
    Dragging = false,
    DragX = 0,
    DragY = 0,
    BindingKey = nil, -- Şablon: {setting = "ActionKey", label = "Action Key 1"}
    HoveredID = nil,
    ActiveID = nil,
}

-- ESP: Sahte hedef listesi (gerçek projede oyun verisiyle değiştirilir)
local espTargets = {
    { name = "Player1", x = 150, y = 180, w = 40, h = 70, health = 80,  dist = 12, visible = true  },
    { name = "Player2", x = 400, y = 220, w = 40, h = 70, health = 45,  dist = 27, visible = false },
    { name = "Player3", x = 520, y = 150, w = 40, h = 70, health = 100, dist = 5,  visible = true  },
}

-- Target selection for Silent Aim
local currentTarget = nil

-- Helper: Check if mouse is in rectangle
local function mouseInRect(x, y, w, h)
    local mx, my = love.mouse.getPosition()
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- UI Components
local function uiCheckbox(label, setting, x, y)
    local size = 16
    local hovered = mouseInRect(x, y, 100, size)
    
    if hovered then
        love.graphics.setColor(1, 1, 1, 0.1)
        love.graphics.rectangle("fill", x - 2, y - 2, 120, size + 4, 4)
    end

    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x, y, size, size, 2)
    
    if Settings[setting] then
        love.graphics.setColor(ACCENT)
        love.graphics.rectangle("fill", x + 3, y + 3, size - 6, size - 6, 1)
    end
    
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(label, x + size + 8, y + 1)
    
    return hovered
end

local function uiSlider(label, setting, min, max, x, y, w)
    local h = 14
    local barW = w
    local hovered = mouseInRect(x, y + 18, barW, h)
    
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print(label, x, y)
    
    local val = Settings[setting]
    local valText = string.format("%.1f", val)
    if setting == "FOV" or setting == "SilentAimFOV" then valText = tostring(math.floor(val)) end
    love.graphics.printf(valText, x, y, barW, "right")

    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x, y + 18, barW, h, 7)
    
    local percent = (val - min) / (max - min)
    love.graphics.setColor(ACCENT)
    love.graphics.rectangle("fill", x, y + 18, barW * percent, h, 7)
    
    if GUI.ActiveID == setting then
        local mx = love.mouse.getX()
        local newPerc = math.max(0, math.min(1, (mx - x) / barW))
        local newVal = min + (max - min) * newPerc
        if setting == "FOV" then
            if newVal < 450 then newVal = 300
            elseif newVal < 750 then newVal = 600
            else newVal = 900 end
        end
        Settings[setting] = newVal
    end

    return hovered
end

local function uiKeybind(label, setting, x, y)
    local w, h = 120, 24
    local hovered = mouseInRect(x, y + 18, w, h)
    
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print(label, x, y)
    
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x, y + 18, w, h, 4)
    
    local text = tostring(Settings[setting]):upper()
    if GUI.BindingKey and GUI.BindingKey.setting == setting then
        text = "..."
        love.graphics.setColor(ACCENT)
    else
        love.graphics.setColor(0.8, 0.8, 0.8)
    end
    
    love.graphics.printf(text, x, y + 22, w, "center")
    
    return hovered
end

local function uiColorCycle(label, setting, x, y)
    local w, h = 120, 24
    local hovered = mouseInRect(x, y + 18, w, h)
    
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print(label, x, y)
    
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x, y + 18, w, h, 4)
    
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf(tostring(Settings[setting]):upper(), x, y + 22, w, "center")
    
    return hovered
end

-- Render Mock-game functions
local function drawChams()
    if not Settings.Chams then return end
    local function colorFromName(name, i)
        if name == "green"   then return 0.1, 1, 0.1
        elseif name == "red"    then return 1, 0.1, 0.1
        elseif name == "blue"   then return 0.1, 0.4, 1
        elseif name == "yellow" then return 1, 1, 0
        elseif name == "purple" then return 0.8, 0.1, 1
        elseif name == "rainbow" then
            local hue = (love.timer.getTime() * 0.5 + i * 0.3) % 1
            local s = math.floor(hue * 6)
            local f = hue * 6 - s
            local q = 1 - f
            if s == 0 then return 1, f, 0
            elseif s == 1 then return q, 1, 0
            elseif s == 2 then return 0, 1, f
            elseif s == 3 then return 0, q, 1
            elseif s == 4 then return f, 0, 1
            else return 1, 0, q end
        end
        return 1, 1, 1
    end
    for i, t in ipairs(espTargets) do
        local r, g, b = colorFromName(t.visible and Settings.ChamsVisibleColor or Settings.ChamsOccludedColor, i)
        love.graphics.setColor(r, g, b, t.visible and Settings.ChamsAlpha or Settings.ChamsAlpha * 0.5)
        love.graphics.rectangle("fill", t.x, t.y, t.w, t.h, 3, 3)
        love.graphics.setColor(r, g, b, t.visible and 1 or 0.8)
        love.graphics.setLineWidth(t.visible and 2 or 1.5)
        love.graphics.rectangle("line", t.x, t.y, t.w, t.h, 3, 3)
    end
end

local function drawESP()
    if not Settings.ESP then return end
    for _, t in ipairs(espTargets) do
        local r = math.min(1, 2 * (1 - t.health / 100))
        local g = math.min(1, 2 * (t.health / 100))
        if Settings.ESPBoxes then
            love.graphics.setColor(r, g, 0, 1)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", t.x, t.y, t.w, t.h, 2, 2)
        end
        if Settings.ESPNames then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(t.name, t.x, t.y - 16, t.w, "center")
        end
        if Settings.ESPDistance then
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.printf(t.dist .. "m", t.x, t.y + t.h + 2, t.w, "center")
        end
        if Settings.ESPHealth then
            local barH = t.h * (t.health / 100)
            love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
            love.graphics.rectangle("fill", t.x - 6, t.y, 4, t.h)
            love.graphics.setColor(r, g, 0, 1)
            love.graphics.rectangle("fill", t.x - 6, t.y + (t.h - barH), 4, barH)
        end
    end
end

-- Silent Aim Logic
local function updateSilentAim()
    if not Settings.SilentAim then 
        currentTarget = nil
        return 
    end

    local sw, sh = love.graphics.getDimensions()
    local cx, cy = sw / 2, sh / 2
    local closestDist = Settings.SilentAimFOV
    local bestTarget = nil

    for _, t in ipairs(espTargets) do
        local tx, ty = t.x + t.w / 2, t.y + t.h / 4 -- Head position mock
        if Settings.SilentAimTarget == "Chest" then
            ty = t.y + t.h / 2
        end
        
        local dx, dy = tx - cx, ty - cy
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist < closestDist then
            closestDist = dist
            bestTarget = t
        end
    end
    currentTarget = bestTarget
end

-- Love Load
function love.load()
    love.window.setTitle("OG Rivals Premium GUI")
    love.window.setMode(800, 600)
end

function love.update(dt)
    if GUI.Dragging then
        local mx, my = love.mouse.getPosition()
        GUI.X = mx - GUI.DragX
        GUI.Y = my - GUI.DragY
    end
    updateSilentAim()
end

function love.draw()
    -- Game World Mockup
    love.graphics.clear(0.08, 0.08, 0.1)
    
    -- Grid effect
    love.graphics.setColor(1, 1, 1, 0.02)
    local screenW, screenH = love.graphics.getDimensions()
    for i = 0, screenW, 40 do love.graphics.line(i, 0, i, screenH) end
    for i = 0, screenH, 40 do love.graphics.line(0, i, screenW, i) end
    
    drawChams()
    drawESP()

    -- Silent Aim Visuals
    if Settings.SilentAim then
        love.graphics.setColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.15)
        love.graphics.circle("line", screenW / 2, screenH / 2, Settings.SilentAimFOV)
        
        if currentTarget then
            local tx, ty = currentTarget.x + currentTarget.w / 2, currentTarget.y + currentTarget.h / 4
            if Settings.SilentAimTarget == "Chest" then ty = currentTarget.y + currentTarget.h / 2 end
            
            love.graphics.setColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.4)
            love.graphics.line(screenW / 2, screenH / 2, tx, ty)
            love.graphics.circle("fill", tx, ty, 4)
        end
    end

    -- GUI Render
    if not GUI.Visible then return end
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", GUI.X + 4, GUI.Y + 4, GUI.W, GUI.H, 10)

    -- Main Panel
    love.graphics.setColor(BG_COLOR)
    love.graphics.rectangle("fill", GUI.X, GUI.Y, GUI.W, GUI.H, 8)
    
    -- Accent Border
    love.graphics.setColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.3)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", GUI.X, GUI.Y, GUI.W, GUI.H, 8)
    
    -- Sidebar
    love.graphics.setColor(PANEL_COLOR)
    love.graphics.rectangle("fill", GUI.X, GUI.Y, 140, GUI.H, 8)
    
    -- Title
    love.graphics.setColor(ACCENT)
    local oldFont = love.graphics.getFont()
    local titleFont = love.graphics.newFont(18)
    love.graphics.setFont(titleFont)
    love.graphics.printf("OG RIVALS", GUI.X, GUI.Y + 20, 140, "center")
    love.graphics.setFont(oldFont)

    -- Tabs
    local tabs = {"Combat", "Visuals", "Settings", "Misc"}
    for i, t in ipairs(tabs) do
        local ty = GUI.Y + 80 + (i-1) * 40
        local hover = mouseInRect(GUI.X + 10, ty, 120, 30)
        
        if GUI.Tab == t then
            love.graphics.setColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.2)
            love.graphics.rectangle("fill", GUI.X + 10, ty, 120, 30, 4)
            love.graphics.setColor(ACCENT)
        elseif hover then
            love.graphics.setColor(1, 1, 1, 0.05)
            love.graphics.rectangle("fill", GUI.X + 10, ty, 120, 30, 4)
            love.graphics.setColor(0.8, 0.8, 0.8)
        else
            love.graphics.setColor(0.6, 0.6, 0.6)
        end
        love.graphics.printf(t, GUI.X + 10, ty + 8, 120, "center")
    end

    -- Content Area
    local cx, cy = GUI.X + 160, GUI.Y + 30
    GUI.HoveredID = nil

    if GUI.Tab == "Combat" then
        if uiCheckbox("Enable Silent Aim", "SilentAim", cx, cy) then GUI.HoveredID = "SilentAim" end
        if uiSlider("FOV", "SilentAimFOV", 10, 400, cx, cy + 40, 200) then GUI.HoveredID = "SilentAimFOV" end
        
        love.graphics.setColor(1, 1, 1, 0.1)
        love.graphics.line(cx, cy + 100, cx + 350, cy + 100)
        
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print("Target Priority", cx, cy + 120)
        
        local targetPoints = {"Head", "Chest"}
        for i, t in ipairs(targetPoints) do
            local bx, by = cx + (i-1) * 100, cy + 150
            local hover = mouseInRect(bx, by, 80, 24)
            if Settings.SilentAimTarget == t then
                love.graphics.setColor(ACCENT)
            elseif hover then
                love.graphics.setColor(1, 1, 1, 0.2)
                if GUI.HoveredID == nil then GUI.HoveredID = "Target_" .. t end
            else
                love.graphics.setColor(0.2, 0.2, 0.2)
            end
            love.graphics.rectangle("fill", bx, by, 80, 24, 4)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(t, bx, by + 4, 80, "center")
        end

    elseif GUI.Tab == "Visuals" then
        if uiCheckbox("Enable ESP", "ESP", cx, cy) then GUI.HoveredID = "ESP" end
        if uiCheckbox("Box", "ESPBoxes", cx + 180, cy) then GUI.HoveredID = "ESPBoxes" end
        
        if uiCheckbox("Names", "ESPNames", cx, cy + 30) then GUI.HoveredID = "ESPNames" end
        if uiCheckbox("Distance", "ESPDistance", cx + 180, cy + 30) then GUI.HoveredID = "ESPDistance" end
        
        if uiCheckbox("Health Bar", "ESPHealth", cx, cy + 60) then GUI.HoveredID = "ESPHealth" end
        
        love.graphics.setColor(1, 1, 1, 0.1)
        love.graphics.line(cx, cy + 100, cx + 350, cy + 100)
        
        if uiCheckbox("Enable Chams", "Chams", cx, cy + 120) then GUI.HoveredID = "Chams" end
        if uiSlider("Chams Alpha", "ChamsAlpha", 0.1, 1.0, cx, cy + 150, 160) then GUI.HoveredID = "ChamsAlpha" end
        
        if uiColorCycle("Visible Color", "ChamsVisibleColor", cx, cy + 200) then GUI.HoveredID = "ChamsVisibleColor" end
        if uiColorCycle("Occluded Color", "ChamsOccludedColor", cx + 180, cy + 200) then GUI.HoveredID = "ChamsOccludedColor" end

    elseif GUI.Tab == "Settings" then
        if uiCheckbox("Enabled", "Enabled", cx, cy) then GUI.HoveredID = "Enabled" end
        if uiSlider("Smoothness", "Smoothness", 0.5, 3.0, cx, cy + 40, 200) then GUI.HoveredID = "Smoothness" end
        if uiSlider("FOV", "FOV", 300, 900, cx, cy + 90, 200) then GUI.HoveredID = "FOV" end
        
        if uiKeybind("Action Key 1", "ActionKey", cx, cy + 150) then GUI.HoveredID = "ActionKey" end
        if uiKeybind("Action Key 2", "ActionKey2", cx + 180, cy + 150) then GUI.HoveredID = "ActionKey2" end

    elseif GUI.Tab == "Misc" then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("Misc settings coming soon...", cx, cy + 20, 350, "center")
    end
end

function love.mousepressed(x, y, button)
    if not GUI.Visible or button ~= 1 then return end
    
    -- Drag check
    if mouseInRect(GUI.X, GUI.Y, GUI.W, 30) then
        GUI.Dragging = true
        GUI.DragX = x - GUI.X
        GUI.DragY = y - GUI.Y
        return
    end
    
    -- Tab check
    local tabs = {"Combat", "Visuals", "Settings", "Misc"}
    for i, t in ipairs(tabs) do
        if mouseInRect(GUI.X + 10, GUI.Y + 80 + (i-1) * 40, 120, 30) then
            GUI.Tab = t
            return
        end
    end
    
    -- Widget logic
    if GUI.HoveredID then
        local id = GUI.HoveredID
        if id:find("Target_") then
            Settings.SilentAimTarget = id:sub(8)
        elseif type(Settings[id]) == "boolean" then
            Settings[id] = not Settings[id]
        elseif id == "ChamsAlpha" or id == "Smoothness" or id == "FOV" or id == "SilentAimFOV" then
            GUI.ActiveID = id
        elseif id == "ActionKey" or id == "ActionKey2" then
            GUI.BindingKey = {setting = id}
        elseif id == "ChamsVisibleColor" or id == "ChamsOccludedColor" then
            local cycle = {"green", "red", "blue", "yellow", "purple", "rainbow"}
            local cur = Settings[id]
            local idx = 1
            for i, v in ipairs(cycle) do if v == cur then idx = i break end end
            Settings[id] = cycle[(idx % #cycle) + 1]
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        GUI.Dragging = false
        GUI.ActiveID = nil
    end
end

function love.keypressed(key)
    if key == "insert" then
        GUI.Visible = not GUI.Visible
        return
    end
    
    if GUI.BindingKey then
        if key ~= "escape" then
            Settings[GUI.BindingKey.setting] = key
        end
        GUI.BindingKey = nil
        return
    end

    if not GUI.Visible then
        if key == "escape" then
            GUI.Visible = true
        end
    end
end
