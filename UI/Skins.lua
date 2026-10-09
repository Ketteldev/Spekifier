-- Built-in palettes and idempotent presentation; never touches window lifecycle.
local _, ns = ...
local S = ns.Spekifier
local registry, order = {}, {}
local clientFont = GameFontHighlight and GameFontHighlight:GetFont() or "Fonts\\FRIZQT__.TTF"
function S:RegisterWindowSkin(id, label, palette)
    assert(type(id) == "string" and type(label) == "string" and type(palette) == "table")
    if not registry[id] then order[#order + 1] = id end
    registry[id] = { id = id, label = label, palette = palette }
end
function S:GetWindowSkins()
    local result = {}
    for _, id in ipairs(order) do result[#result + 1] = registry[id] end
    return result
end
S:RegisterWindowSkin("original", "Original", {
    bg = { .08, .08, .08, .85 }, border = { .55, .45, .23, 1 },
    accent = { 1, .82, .25, 1 }, selected = { .12, .32, .18, .85 },
    disabled = { .06, .06, .06, .85 }, text = { 1, 1, 1, 1 }, font = clientFont })
S:RegisterWindowSkin("elles", "Elles", {
    bg = { .067, .082, .11, 1 }, border = { .22, .26, .33, 1 },
    accent = { .27, .75, .85, 1 }, selected = { .094, .29, .26, 1 },
    disabled = { .09, .10, .12, 1 }, text = { .88, .90, .94, 1 }, font = clientFont })
function S:InitializeWindowSkin()
    local id = self:GetSetting("windowSkin")
    if id == nil then
        local function loaded(name)
            if C_AddOns and C_AddOns.IsAddOnLoaded then
                -- The first return includes addons still loading; require completion.
                return select(2, C_AddOns.IsAddOnLoaded(name))
            end
            return IsAddOnLoaded and IsAddOnLoaded(name)
        end
        id = (loaded("EllesmereUI") or loaded("ElvUI")) and "elles" or "original"
    end
    self:SetSetting("windowSkin", registry[id] and id or "original")
end
function S:GetWindowPalette()
    return (registry[self:GetSetting("windowSkin")] or registry.original).palette
end
function S:SetWindowSkin(id)
    self:SetSetting("windowSkin", registry[id] and id or "original")
    self:ApplyWindowSkin()
    self:RefreshSkinDropdown()
end
local function color(texture, value) texture:SetColorTexture(unpack(value)) end
local function text(font, palette, size, quality)
    font:SetFont(palette.font, size, "")
    if not quality then font:SetTextColor(unpack(palette.text)) end
end
-- Owned overlays are reused. Template regions are restored on every switch.
local function surface(frame, palette)
    if not frame.skinBackground then
        frame.skinBackground = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        frame.skinBackground:SetAllPoints()
        frame.skinEdges = {}
        for i = 1, 4 do frame.skinEdges[i] = frame:CreateTexture(nil, "BORDER") end
        local e = frame.skinEdges
        e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(1)
        e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
        e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(1)
        e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)
    end
    color(frame.skinBackground, palette.bg)
    for _, edge in ipairs(frame.skinEdges) do color(edge, palette.border) end
end
function S:StyleLootElement(row, shared)
    local p = self:GetWindowPalette()
    surface(row, p)
    if not shared then row.skinBackground:SetAlpha(0.18) end
    -- Insets leave a visible border without changing tooltip or click hit areas.
    row.icon:ClearAllPoints()
    if shared then
        row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
        row.icon:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    else
        row.icon:SetSize(40, 40); row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
        text(row.name, p, 18, true)
    end
end
function S:StyleScrollbar(bar)
    local p = self:GetWindowPalette()
    color(bar.track, p.disabled); color(bar.thumb, p.accent)
end
function S:ApplyWindowSkin()
    local w = self:GetMainWindow()
    if not w then return end
    local p, elles = self:GetWindowPalette(), self:GetSetting("windowSkin") == "elles"
    surface(w, p)
    w.skinBackground:SetShown(elles)
    for _, edge in ipairs(w.skinEdges) do edge:SetShown(elles) end
    for _, name in ipairs({ "Bg", "TitleBg", "TopBorder", "BottomBorder", "LeftBorder", "RightBorder", "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "BotLeftCorner", "BotRightCorner", "TopTileStreaks", "Inset", "InsetBg", "InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft", "InsetBorderBottomRight", "InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight", "NineSlice" }) do
        if w[name] then w[name]:SetAlpha(elles and 0 or 1) end
    end
    text(w.title, p, 14); text(w.header, p, 18); text(w.status, p, 14)
    if w.CloseButton then
        for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
            local texture = w.CloseButton[getter] and w.CloseButton[getter](w.CloseButton)
            if texture then texture:SetAlpha(elles and 0 or 1) end
        end
        if not w.closeLabel then
            w.closeLabel = w.CloseButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            w.closeLabel:SetAllPoints(); w.closeLabel:SetText("X")
        end
        text(w.closeLabel, p, 16); w.closeLabel:SetShown(elles)
        w.CloseButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    end
    if w.optionsGear then surface(w.optionsGear, p) end
    if w.resizeGrip then
        for _, line in ipairs(w.resizeGrip.lines) do color(line, p.accent) end
    end
    for _, c in ipairs(self:GetAllSpecColumns()) do
        surface(c.frame, p); text(c.frame.name, p, 22); text(c.message, p, 14); text(c.marker, p, 12)
        color(c.hover, p.accent); self:StyleScrollbar(c.bar)
        for _, row in ipairs(c.rows) do self:StyleLootElement(row) end
        c.lastEnabled = nil; self:RefreshColumnAppearance(c)
    end
    if w.sharedLoot then
        text(w.sharedLoot.label, p, 14); self:StyleScrollbar(w.sharedLoot.bar)
        for _, icon in ipairs(w.sharedLoot.icons) do self:StyleLootElement(icon, true) end
    end
end
function S:RefreshSkinDropdown()
    local d = self.optionsPanel and self.optionsPanel.windowSkin
    if d and UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(d, (registry[self:GetSetting("windowSkin")] or registry.original).label)
    end
end
function S:CreateSkinDropdown(panel, anchor)
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -24, -24); label:SetText("Theme")
    local d = CreateFrame("Frame", "SpekifierSkinDropdown", panel, "UIDropDownMenuTemplate")
    d:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -16, -8)
    panel.windowSkin = d
    UIDropDownMenu_SetWidth(d, 180)
    UIDropDownMenu_Initialize(d, function(_, level)
        for _, skin in ipairs(self:GetWindowSkins()) do
            local id = skin.id
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = skin.label, id
            info.checked = self:GetSetting("windowSkin") == id
            info.func = function() self:SetWindowSkin(id) end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

local function dimension(value, fallback, low, high)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then value = fallback end
    return math.max(low, math.min(high, value))
end
function S:WindowSizeLimits()
    -- Scale the minimum layout on very small displays rather than clipping it.
    local lowWidth = math.max(680, #self:GetAllSpecColumns() * 220 + 40)
    return lowWidth, 480, math.max(lowWidth, UIParent:GetWidth() - 40), math.max(480, UIParent:GetHeight() - 40)
end
function S:InitializeWindowSize()
    local w = self:GetMainWindow()
    local lw, lh, hw, hh = self:WindowSizeLimits()
    local width = dimension(self:GetSetting("windowWidth"), w:GetWidth(), lw, hw)
    local height = dimension(self:GetSetting("windowHeight"), w:GetHeight(), lh, hh)
    w:SetSize(width, height)
    self:SetSetting("windowWidth", width); self:SetSetting("windowHeight", height)
    w:SetResizable(true); w:SetResizeBounds(lw, lh, hw, hh)
    local grip = CreateFrame("Button", nil, w)
    w.resizeGrip = grip
    grip:SetSize(24, 24); grip:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(w:GetFrameLevel() + 5)
    grip.lines = {}
    -- Classic diagonal lines use Blizzard's resize art with palette tint.
    grip.art = grip:CreateTexture(nil, "ARTWORK")
    grip.art:SetAllPoints(); grip.art:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    for i = 1, 3 do
        local line = grip:CreateTexture(nil, "OVERLAY")
        line:SetSize(2, 6 + i * 4); line:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -3 - (i - 1) * 5, 3)
        line:SetRotation(-math.pi / 4)
        grip.lines[i] = line
    end
    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then w.resizing = true; w:StartSizing("BOTTOMRIGHT") end
    end)
    local function stop()
        w:StopMovingOrSizing()
        if w.resizing then
            w.resizing = nil
            self:SetSetting("windowWidth", w:GetWidth()); self:SetSetting("windowHeight", w:GetHeight())
        end
    end
    grip:SetScript("OnMouseUp", stop); w:HookScript("OnHide", stop)
    w:SetScript("OnSizeChanged", function() self:LayoutLootWindow(); self:FitLootWindow() end)
    self:LayoutLootWindow()
end
function S:LayoutLootWindow()
    local w = self:GetMainWindow()
    if not w or not w.resizeGrip then return end
    local shared = w.sharedLoot and w.sharedLoot.items and #w.sharedLoot.items > 0
    local top = shared and 154 or 90
    local columns = self:GetAllSpecColumns()
    local step = (w:GetWidth() - 40) / math.max(1, #columns)
    local height = math.max(270, w:GetHeight() - top - 58)
    local viewport = math.max(120, height - 152)
    for i, c in ipairs(columns) do
        c.frame:ClearAllPoints(); c.frame:SetPoint("TOPLEFT", w, "TOPLEFT", 20 + (i - 1) * step, -top)
        c.frame:SetSize(step - 8, height)
        c.listWidth, c.viewportHeight = step - 30, viewport
        c.scroll:SetSize(c.listWidth, viewport); c.content:SetWidth(c.listWidth)
        c.message:SetWidth(c.listWidth - 8); c.bar:SetHeight(viewport - 12)
        for _, row in ipairs(c.rows) do row:SetWidth(c.listWidth) end
        local count = c.itemCount or 0
        c.content:SetHeight(math.max(viewport, count * 64))
        c.range = math.max(0, count * 64 - viewport)
        c.bar:SetMinMaxValues(0, c.range); c.bar:SetShown(c.range > 0); c:SetOffset(c.offset)
    end
    if w.sharedLoot then
        local strip = w.sharedLoot
        strip.width = w:GetWidth() - 120
        strip.frame:SetWidth(w:GetWidth() - 40); strip.scroll:SetWidth(strip.width); strip.bar:SetWidth(strip.width)
        local contentWidth = math.max(strip.width, #(strip.items or {}) * 48 - 8)
        strip.content:SetWidth(contentWidth); strip.range = math.max(0, contentWidth - strip.width)
        strip.bar:SetMinMaxValues(0, strip.range); strip.bar:SetShown(strip.range > 0); strip:SetOffset(strip.offset)
    end
end
