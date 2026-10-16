-- Saved dimensions and responsive loot geometry.
local _, ns = ...
local S = ns.Spekifier
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
    -- Use the native grey resize triangle in both skins.
    grip.art = grip:CreateTexture(nil, "ARTWORK")
    grip.art:SetAllPoints(); grip.art:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
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
    local shared = w.sharedLoot and (w.sharedLoot.pickerShown or (w.sharedLoot.items and #w.sharedLoot.items > 0))
    local top = shared and 166 or 102
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
    self:LayoutSharedLootRow()
end
