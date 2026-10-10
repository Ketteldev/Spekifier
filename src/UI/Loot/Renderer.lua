-- Bind display lists and status messages to existing controls.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local UI = addonTable.LootUI
local HideTooltip = UI.HideTooltip
local rowHeight, listHeight = UI.rowHeight, UI.listHeight
local CreateRow = UI.CreateRow
local reasons = {
    ["loot-data-timeout"] = "Item data did not finish loading. Try again shortly.",
    ["journal-difficulty-unavailable"] = "This difficulty has no supported loot table.",
    ["loot-api-unavailable"] = "Loot data is unavailable on this client.",
    ["adventure-guide-open"] = "Close the Adventure Guide to load loot.",
}
local messages = {
    loading = "Loading lootâ€¦", empty = "No eligible loot.",
    unsupported = "Loot source unsupported.", failed = "Unable to load loot.",
}

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
            row.name:SetText(item.name or "Loading itemâ€¦")
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
        column.itemCount = #items
        local viewport = column.viewportHeight or listHeight
        local height = math.max(viewport, #items * rowHeight)
        column.content:SetHeight(height)
        column.range = math.max(0, height - viewport)
        column.bar:SetMinMaxValues(0, column.range)
        column.bar:SetShown(column.range > 0)
        if column.contextKey ~= state.lootBinding then column.offset = 0 end
        column.contextKey = state.lootBinding
        column:SetOffset(column.offset)
        self:RefreshColumnAppearance(column)
    end
    if state.resolvedContext then
        local text = result and (messages[result.state] or "") or messages.loading
        if result and result.state == "ready" then
            text = state.selectionAllowed and "Hover items for details. Click a specialization to select it." or
                "Loot specialization information is unavailable."
        end
        if state.selectionNotice then text = state.selectionNotice end
        window.status:SetText(text or "Loot comparison")
    end
end
