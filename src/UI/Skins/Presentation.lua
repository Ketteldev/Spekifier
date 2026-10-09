-- Idempotent styling of existing controls.
local _, ns = ...
local S = ns.Spekifier
local function color(texture, value) texture:SetColorTexture(value[1], value[2], value[3], value[4]) end
local function text(font, palette, size, quality)
    font:SetFont(palette.font, size, "")
    if not quality then
        local value = palette.text
        font:SetTextColor(value[1], value[2], value[3], value[4])
    end
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
