-- Fixed headers and independently scrollable, reusable item lists.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local rowHeight, listHeight = 64, 420
local reasons = {
    ["loot-data-timeout"] = "Item data did not finish loading. Try again shortly.",
    ["journal-difficulty-unavailable"] = "This difficulty has no supported loot table.",
    ["loot-api-unavailable"] = "Loot data is unavailable on this client.",
    ["adventure-guide-open"] = "Close the Adventure Guide to load loot.",
}
local messages = {
    loading = "Loading loot…", empty = "No eligible loot.",
    unsupported = "Loot source unsupported.", failed = "Unable to load loot.",
}

function Spekifier:RefreshColumnAppearance(column)
    local state = self:GetWindowState()
    local enabled = state.selectionAllowed and state.resolvedContext ~= nil
    local selected = state.resolvedContext ~= nil and state.confirmedSpecID == column.specID
    local hovered = column.frame:IsMouseOver()
    if column.lastEnabled == enabled and column.lastSelected == selected and column.lastHovered == hovered then return end
    column.lastEnabled, column.lastSelected, column.lastHovered = enabled, selected, hovered
    column.visualState = selected and "selected" or (enabled and "available" or "disabled")
    column.frame.bg:SetColorTexture(selected and 0.12 or 0.08, selected and 0.32 or 0.08,
        selected and 0.18 or 0.08, 0.85)
    column.hover:SetAlpha(hovered and 0.18 or 0)
    column.marker:SetText(selected and "Selected" or (enabled and "Click to select" or "Selection unavailable"))
    column.frame.icon:SetAlpha(1)
end

-- Phase 6 supplies the confirmed setter; all column surfaces use this gate.
function Spekifier:HandleSpecColumnClick(specID, button)
    local state = self:GetWindowState()
    if button ~= "LeftButton" or not state.selectionAllowed or not state.resolvedContext or
        InCombatLockdown() then return false end
    if self.SelectLootSpecialization then return self:SelectLootSpecialization(specID) end
    return false
end

local function HideTooltip(row)
    if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function ReadableFont(text, size)
    local font, _, flags = text:GetFont()
    text:SetFont(font, size, flags)
end

local function ShowItemTooltip(row)
    local item = row.item
    if not item or not GameTooltip then return end
    GameTooltip:Hide()
    GameTooltip:SetParent(UIParent)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    if item.link then
        -- Match Blizzard's Journal tooltip path, with native comparisons.
        -- ProcessInfo retains the original link and tooltip-data addon hooks.
        local info = CreateBaseTooltipInfo("GetHyperlink", item.link)
        info.compareItem = true
        GameTooltip:ProcessInfo(info)
    else
        GameTooltip:SetText(item.name or "Loading item...")
    end
    GameTooltip:SetAlpha(1)
    GameTooltip:Show()
end

-- Presentation arrays never mutate provider results or cached pools.
function Spekifier:BuildLootDisplayLists(result)
    local columns, shared, lists, counts, first = self:GetAllSpecColumns(), {}, {}, {}, {}
    local complete = result and (result.state == "ready" or result.state == "empty") and #columns > 0
    for _, column in ipairs(columns) do
        local data = result and result.specs and result.specs[column.specID]
        if not data or (data.state ~= "ready" and data.state ~= "empty") then complete = false end
    end
    if not complete then return shared, lists, false end
    for _, column in ipairs(columns) do
        local seen = {}
        for _, item in ipairs(result.specs[column.specID].items or {}) do
            local id = item.itemID
            if id and not seen[id] then
                seen[id] = true
                counts[id] = (counts[id] or 0) + 1
                first[id] = first[id] or item
            end
        end
    end
    local sharedIDs = {}
    for id, count in pairs(counts) do
        if count == #columns then sharedIDs[id] = true; shared[#shared + 1] = first[id] end
    end
    -- Stable across delayed refreshes and changes in provider ordering.
    table.sort(shared, function(a, b) return a.itemID < b.itemID end)
    for _, column in ipairs(columns) do
        local items, seen = {}, {}
        for _, item in ipairs(result.specs[column.specID].items or {}) do
            if not sharedIDs[item.itemID] and not seen[item.itemID] then
                items[#items + 1] = item
                if item.itemID then seen[item.itemID] = true end
            end
        end
        lists[column.specID] = items
    end
    return shared, lists, true
end

function Spekifier:CreateSharedLootRow()
    local window = self:GetMainWindow()
    if window.sharedLoot then return window.sharedLoot end
    local strip = { icons = {}, offset = 0, range = 0, width = window:GetWidth() - 120 }
    window.sharedLoot = strip
    strip.frame = CreateFrame("Frame", nil, window)
    strip.frame:SetPoint("TOPLEFT", window, "TOPLEFT", 20, -90)
    strip.frame:SetSize(window:GetWidth() - 40, 64)
    strip.label = strip.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    strip.label:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", 0, -12)
    strip.label:SetText("Shared:")
    strip.label:SetWidth(72)
    strip.label:SetJustifyH("LEFT")
    strip.scroll = CreateFrame("ScrollFrame", nil, strip.frame)
    strip.scroll:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", 80, 0)
    strip.scroll:SetSize(strip.width, 44)
    strip.content = CreateFrame("Frame", nil, strip.scroll)
    strip.content:SetSize(strip.width, 44)
    strip.scroll:SetScrollChild(strip.content)
    strip.bar = CreateFrame("Slider", nil, strip.frame)
    strip.bar:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", 80, -48)
    strip.bar:SetSize(strip.width, 10)
    strip.bar:SetOrientation("HORIZONTAL")
    strip.bar:SetMinMaxValues(0, 0)
    strip.bar:SetValueStep(1)
    strip.bar:SetObeyStepOnDrag(true)
    strip.bar.track = strip.bar:CreateTexture(nil, "BACKGROUND")
    strip.bar.track:SetAllPoints()
    strip.bar.track:SetColorTexture(0.03, 0.03, 0.03, 0.8)
    strip.bar.thumb = strip.bar:CreateTexture(nil, "ARTWORK")
    strip.bar.thumb:SetSize(24, 10)
    strip.bar.thumb:SetColorTexture(0.75, 0.64, 0.3, 1)
    strip.bar:SetThumbTexture(strip.bar.thumb)
    function strip:ApplyOffset(value)
        value = math.max(0, math.min(self.range, value))
        if value ~= self.offset then
            for _, icon in ipairs(self.icons) do HideTooltip(icon) end
        end
        self.offset = value
        self.scroll:SetHorizontalScroll(value)
    end
    function strip:SetOffset(value)
        self:ApplyOffset(value)
        self.bar:SetValue(self.offset)
    end
    strip.bar:SetScript("OnValueChanged", function(_, value) strip:ApplyOffset(value) end)
    function strip:Scroll(delta) self:SetOffset(self.offset - delta * 48) end
    for _, surface in ipairs({ strip.frame, strip.scroll, strip.content, strip.bar }) do
        surface:EnableMouseWheel(true)
        surface:SetScript("OnMouseWheel", function(_, delta) strip:Scroll(delta) end)
    end
    strip.frame:SetScript("OnHide", function()
        for _, icon in ipairs(strip.icons) do HideTooltip(icon) end
    end)
    strip.frame:Hide()
    return strip
end

function Spekifier:RenderSharedLoot(items)
    local window, state = self:GetMainWindow(), self:GetWindowState()
    local strip = window.sharedLoot
    if not strip and #items == 0 then return end
    strip = strip or self:CreateSharedLootRow()
    for i, item in ipairs(items) do
        local icon = strip.icons[i]
        if not icon then
            -- A mouse-enabled frame supplies tooltips without spec-click routing.
            icon = CreateFrame("Frame", nil, strip.content)
            icon:SetSize(40, 40)
            icon:SetPoint("TOPLEFT", strip.content, "TOPLEFT", (i - 1) * 48, -2)
            icon.icon = icon:CreateTexture(nil, "ARTWORK")
            icon.icon:SetAllPoints()
            icon:EnableMouse(true)
            icon:EnableMouseWheel(true)
            icon:SetScript("OnMouseWheel", function(_, delta) strip:Scroll(delta) end)
            icon:SetScript("OnEnter", ShowItemTooltip)
            icon:SetScript("OnLeave", HideTooltip)
            icon:SetScript("OnHide", HideTooltip)
            strip.icons[i] = icon
        end
        if icon.item and (icon.item.itemID ~= item.itemID or icon.item.link ~= item.link) then HideTooltip(icon) end
        icon.item = item
        icon.icon:SetTexture(item.icon or 134400)
        icon:Show()
    end
    for i = #items + 1, #strip.icons do
        local icon = strip.icons[i]
        HideTooltip(icon)
        icon.item = nil
        icon.icon:SetTexture(nil)
        icon:Hide()
    end
    strip.items = items
    local width = math.max(strip.width, #items * 48 - 8)
    strip.content:SetWidth(width)
    strip.range = math.max(0, width - strip.width)
    strip.bar:SetMinMaxValues(0, strip.range)
    strip.bar:SetShown(strip.range > 0)
    if strip.contextKey ~= state.lootBinding then strip.offset = 0 end
    strip.contextKey = state.lootBinding
    strip:SetOffset(strip.offset)
    strip.frame:SetShown(#items > 0)
    -- Retain the full column viewport, reclaiming all strip space when absent.
    window:SetHeight(#items > 0 and 784 or 720)
    local columns = self:GetAllSpecColumns()
    local step = (window:GetWidth() - 40) / math.max(1, #columns)
    for i, column in ipairs(columns) do
        column.frame:ClearAllPoints()
        column.frame:SetPoint("TOPLEFT", window, "TOPLEFT", 20 + (i - 1) * step, #items > 0 and -154 or -90)
    end
    self:FitLootWindow()
end

local function CreateRow(self, column, index)
    local row = CreateFrame("Button", nil, column.content)
    row:SetSize(column.listWidth, rowHeight)
    row:SetPoint("TOPLEFT", column.content, "TOPLEFT", 0, -(index - 1) * rowHeight)
    row:RegisterForClicks("LeftButtonUp")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(40, 40)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ReadableFont(row.name, 18)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 52, -4)
    row.name:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 4)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(true)
    row:SetScript("OnClick", function(_, button) self:HandleSpecColumnClick(column.specID, button) end)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) column:Scroll(delta) end)
    row:SetScript("OnEnter", ShowItemTooltip)
    row:SetScript("OnLeave", HideTooltip)
    row:SetScript("OnHide", HideTooltip)
    column.rows[index] = row
    return row
end

function Spekifier:CreateSpecializationColumns()
    local window = self:GetMainWindow()
    if not window or window.specColumns then return end
    local count = GetNumSpecializations() or 0
    if count == 0 then return end
    -- Wait for the complete class catalog rather than keeping partial columns.
    for i = 1, count do
        local id, name, _, icon = GetSpecializationInfo(i)
        if not id or id == 0 or not name or not icon then return end
    end
    window.specColumns = {}
    local width = math.min(1440, math.max(1080, count * 320 + 40))
    window:SetSize(width, 720)
    local step = (width - 40) / count
    for i = 1, count do
        local specID, specName, _, specIcon = GetSpecializationInfo(i)
        if specID then
            local frame = CreateFrame("Button", nil, window)
            frame:SetSize(step - 8, 572)
            frame:SetPoint("TOPLEFT", window, "TOPLEFT", 20 + (i - 1) * step, -90)
            frame:RegisterForClicks("LeftButtonUp")
            frame.bg = frame:CreateTexture(nil, "BACKGROUND")
            frame.bg:SetAllPoints()
            frame.icon = frame:CreateTexture(nil, "ARTWORK")
            frame.icon:SetSize(56, 56)
            frame.icon:SetPoint("TOP", frame, "TOP", 0, -8)
            frame.icon:SetTexture(specIcon)
            frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            ReadableFont(frame.name, 22)
            frame.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -70)
            frame.name:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -70)
            frame.name:SetHeight(44)
            frame.name:SetWordWrap(true)
            frame.name:SetText(specName)
            local column = { frame = frame, specID = specID, specName = specName,
                specIcon = specIcon, rows = {}, listWidth = step - 30, offset = 0, range = 0 }
            column.hover = frame:CreateTexture(nil, "OVERLAY")
            column.hover:SetAllPoints()
            column.hover:SetColorTexture(1, 0.82, 0.25, 1)
            column.hover:SetAlpha(0)
            column.marker = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            column.marker:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 4)
            column.marker:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
            column.marker:SetHeight(20)
            column.scroll = CreateFrame("ScrollFrame", nil, frame)
            column.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -120)
            column.scroll:SetSize(column.listWidth, listHeight)
            column.content = CreateFrame("Frame", nil, column.scroll)
            column.content:SetSize(column.listWidth, listHeight)
            column.scroll:SetScrollChild(column.content)
            column.message = column.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            column.message:SetPoint("TOPLEFT", column.content, "TOPLEFT", 4, -4)
            column.message:SetWidth(column.listWidth - 8)
            column.message:SetWordWrap(true)
            column.bar = CreateFrame("Slider", nil, frame)
            column.bar.track = column.bar:CreateTexture(nil, "BACKGROUND")
            column.bar.track:SetAllPoints()
            column.bar.track:SetColorTexture(0.03, 0.03, 0.03, 0.8)
            column.bar.thumb = column.bar:CreateTexture(nil, "ARTWORK")
            column.bar.thumb:SetSize(10, 24)
            column.bar.thumb:SetColorTexture(0.75, 0.64, 0.3, 1)
            column.bar:SetThumbTexture(column.bar.thumb)
            column.bar:SetOrientation("VERTICAL")
            column.bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -126)
            column.bar:SetSize(12, listHeight - 12)
            column.bar:SetMinMaxValues(0, 0)
            column.bar:SetValueStep(1)
            column.bar:SetObeyStepOnDrag(true)
            function column:SetOffset(value)
                local offset = math.max(0, math.min(self.range, value))
                if offset ~= self.offset then
                    for _, row in ipairs(self.rows) do HideTooltip(row) end
                end
                self.offset = offset
                self.scroll:SetVerticalScroll(self.offset)
                self.bar:SetValue(self.offset)
            end
            function column:Scroll(delta) self:SetOffset(self.offset - delta * rowHeight) end
            column.bar:SetScript("OnValueChanged", function(_, value)
                if column.offset ~= value then
                    for _, row in ipairs(column.rows) do HideTooltip(row) end
                end
                column.offset = math.max(0, math.min(column.range, value))
                column.scroll:SetVerticalScroll(column.offset)
            end)
            for _, surface in ipairs({ frame, column.scroll, column.content, column.bar }) do
                surface:EnableMouse(true)
                surface:EnableMouseWheel(true)
                surface:SetScript("OnMouseWheel", function(_, delta) column:Scroll(delta) end)
            end
            frame:SetScript("OnEnter", function()
                if not GameTooltip then return end
                GameTooltip:Hide()
                GameTooltip:SetParent(UIParent)
                GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
                GameTooltip:SetText(specName)
                GameTooltip:SetAlpha(1)
                GameTooltip:Show()
            end)
            frame:SetScript("OnLeave", HideTooltip)
            frame:SetScript("OnClick", function(_, button) self:HandleSpecColumnClick(specID, button) end)
            -- ScrollFrame/background mouse-up is routed through the same gate.
            for _, surface in ipairs({ column.scroll, column.content }) do
                surface:SetScript("OnMouseUp", function(_, button) self:HandleSpecColumnClick(specID, button) end)
            end
            -- A single rectangle test includes children and scrollbars. Child
            -- enter/leave ordering cannot remove the whole-column highlight.
            frame:SetScript("OnUpdate", function() self:RefreshColumnAppearance(column) end)
            frame:SetScript("OnHide", function()
                column.lastHovered = nil
                column.hover:SetAlpha(0)
                HideTooltip(frame)
            end)
            window.specColumns[#window.specColumns + 1] = column
        end
    end
end

function Spekifier:RenderWindowLoot(result)
    local window, state = self:GetMainWindow(), self:GetWindowState()
    if not window then return end
    local shared, lists, complete = self:BuildLootDisplayLists(result)
    self:RenderSharedLoot(shared)
    for _, column in ipairs(self:GetAllSpecColumns()) do
        local data = result and result.specs and result.specs[column.specID]
        local items = data and data.items or {}
        if complete then items = lists[column.specID] end
        -- Partial or failed pools must never look like a complete loot table.
        if not data or (data.state ~= "ready" and data.state ~= "empty") then items = {} end
        for i, item in ipairs(items) do
            local row = column.rows[i] or CreateRow(self, column, i)
            if row.item and (row.item.itemID ~= item.itemID or row.item.link ~= item.link) then
                HideTooltip(row)
            end
            row.item = item
            row.icon:SetTexture(item.icon or 134400)
            row.name:SetText(item.name or "Loading item…")
            local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
            row.name:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
            row:Show()
        end
        for i = #items + 1, #column.rows do
            local row = column.rows[i]
            HideTooltip(row)
            row.item = nil
            row.name:SetText("")
            row.icon:SetTexture(nil)
            row:Hide()
        end
        local message
        if data then
            message = messages[data.state] or ""
            if complete and #items == 0 and #shared > 0 then message = "All eligible loot is shared above." end
        else
            message = state.resolvedContext and messages.loading or "No supported context."
        end
        column.message:SetText(message)
        column.message:SetShown(message ~= "")
        if data and (data.state == "failed" or data.state == "unsupported") then
            column.message:SetText((message or "") .. "\n" ..
                (data.explanation or reasons[data.reason] or "Try again shortly."))
        end
        if data and data.state == "loading" and reasons[data.reason] then
            column.message:SetText(reasons[data.reason])
        end
        if not state.resolvedContext then HideTooltip(column.frame) end
        local height = math.max(listHeight, #items * rowHeight)
        column.content:SetHeight(height)
        column.range = math.max(0, height - listHeight)
        column.bar:SetMinMaxValues(0, column.range)
        column.bar:SetShown(column.range > 0)
        if column.contextKey ~= state.lootBinding then column.offset = 0 end
        column.contextKey = state.lootBinding
        column:SetOffset(column.offset)
        self:RefreshColumnAppearance(column)
    end
    if state.resolvedContext then
        local text = result and (messages[result.state] or "") or messages.loading
        if result and result.state == "ready" then text = state.selectionAllowed and "Hover items for details. Click a specialization to select it." or "Loot specialization information is unavailable." end
        if state.selectionNotice then text = state.selectionNotice end
        window.status:SetText(text or "Loot comparison")
    end
end

-- UIParent dimensions are in UI units, so this also handles global UI scale.
function Spekifier:FitLootWindow()
    local window = self:GetMainWindow()
    if not window then return end
    local width = window:GetWidth()
    local availableWidth = UIParent.GetWidth and UIParent:GetWidth() or width + 40
    local availableHeight = UIParent.GetHeight and UIParent:GetHeight() or 760
    window:SetScale(math.min(1, (availableWidth - 40) / width, (availableHeight - 40) / window:GetHeight()))
end

function Spekifier:GetSpecColumn(index)
    return self:GetAllSpecColumns()[index]
end
function Spekifier:GetAllSpecColumns()
    local window = self:GetMainWindow()
    return window and window.specColumns or {}
end
