-- Phase 5 presentation and interaction checks using production UI modules.
local output = print
local fixture = assert(loadfile("spec/Modules/Context/AutoShow.lua"))()
local checks = 0
local function expect(value, label) assert(value, label); checks = checks + 1 end
local function resultFor(column, count, status)
    local items = {}
    for i = 1, count do
        items[i] = { itemID = i, name = "A very long localized item name " .. i,
            icon = i, link = "item:" .. i, quality = 4 }
    end
    return { state = status or "ready", specs = { [column.specID] = {
        state = status or "ready", items = items } } }
end

for _, count in ipairs({ 2, 3, 4 }) do
    for _, size in ipairs({ { 1920, 1080 }, { 800, 600 }, { 600, 400 } }) do
        local a = fixture({ numSpecs = count, uiWidth = size[1], uiHeight = size[2] })
        local w = a:GetMainWindow()
        expect(#a:GetAllSpecColumns() == count, "each player spec gets a column")
        expect(w.width * w.scale <= size[1] - 40 + 0.000001 and w.height * w.scale <= size[2] - 40 + 0.000001,
            "window fits scaled UI dimensions")
        local right = 0
        for _, column in ipairs(a:GetAllSpecColumns()) do
            local f = column.frame
            expect(f.point[4] >= right and f.point[4] + f.width <= w.width - 20,
                "columns fit without overlap")
            right = f.point[4] + f.width
            expect(column.scroll.width == column.listWidth and column.listWidth > 150,
                "readable list width retained at smaller UI dimensions")
        end
    end
end
local a, state, event, frames = fixture()
local w, column = a:GetMainWindow(), a:GetSpecColumn(1)
local runtime = a:GetWindowState()
expect(w.header.text:find("Localized Boss", 1, true) and w.header.text:find("14", 1, true),
    "raid header identifies boss and difficulty")
expect(w.width >= 1080 and w.height == 720 and w.strata == "FULLSCREEN_DIALOG" and w.level == 100,
    "larger preview stays below tooltip strata")
expect(w.scripts.OnDragStart == nil and w.dragArea.scripts.OnDragStart ~= nil,
    "only title area initiates movement")
a:RenderWindowLoot(resultFor(column, 60))
expect(#column.rows == 60 and column.rows[60]:IsShown() and column.range == 60 * 64 - 420,
    "long pool has full scroll range")
expect(column.message.text == "" and not column.message:IsShown(),
    "ready loot clears and hides loading message")
local originalRow, frameCount = column.rows[1], #frames
column.scroll:Fire("OnMouseWheel", -1)
expect(column.offset == 64 and column.scroll.scrollOffset == 64, "wheel scrolls list")
column.rows[1]:Fire("OnMouseWheel", -1)
expect(column.offset == 128, "wheel over rows scrolls the same list")
column.bar:SetValue(column.range)
expect(column.offset == column.range and column.scroll.scrollOffset == column.range,
    "scrollbar reaches last row")
a:RenderWindowLoot(resultFor(column, 60))
expect(column.offset == column.range and #frames == frameCount and column.rows[1] == originalRow,
    "same-context refresh preserves scroll and reuses frames")
expect(column.frame.name.point[2] == column.frame and column.scroll.point[5] == -120,
    "spec header stays outside scrolling content")
function CreateBaseTooltipInfo(getterName, link)
    return { getterName = getterName, getterArgs = { link } }
end
GameTooltip = { owner = nil, shown = false, strata = "TOOLTIP", alpha = 0 }
function GameTooltip:SetParent(parent) self.parent = parent end
function GameTooltip:ClearLines() self.cleared = true end
function GameTooltip:SetAlpha(alpha) self.alpha = alpha end
function GameTooltip:ProcessInfo(info)
    self.info = info
    self.link = info.getterArgs[1]
end
function GameTooltip:SetFrameStrata(strata) self.strata = strata end
function GameTooltip:SetFrameLevel(level) self.level = level end
function GameTooltip:SetOwner(owner) self.owner = owner end
function GameTooltip:IsOwned(owner) return self.owner == owner end
function GameTooltip:SetHyperlink(link) self.link = link end
function GameTooltip:SetText(text) self.text = text end
function GameTooltip:Show() self.shown = true end
function GameTooltip:Hide() self.shown = false end
column.rows[1]:Fire("OnEnter")
expect(GameTooltip.shown and GameTooltip.link == "item:1", "row shows provider item link tooltip")
expect(GameTooltip.info.getterName == "GetHyperlink" and GameTooltip.info.compareItem and
    GameTooltip.parent == UIParent and GameTooltip.alpha == 1 and GameTooltip.cleared,
    "primary item tooltip uses native item comparison path and resets hidden display state")
expect(column.frame.icon.width == 56 and column.frame.name.fontSize == 22 and
    column.rows[1].icon.width == 40 and column.rows[1].name.fontSize == 18,
    "spec and loot icons and text use larger readable sizes")
a:RenderWindowLoot(resultFor(column, 60))
expect(GameTooltip.shown, "equivalent refreshed item data does not dismiss hovered tooltip")
column:Scroll(1)
expect(not GameTooltip.shown, "scrolling clears moving tooltip")
column.rows[1]:Fire("OnEnter")
column.rows[1]:Fire("OnLeave")
expect(not GameTooltip.shown, "leaving row hides owned tooltip")
column.frame.mouseOver = true
for i = 1, 10 do
    column.rows[i]:Fire("OnEnter")
    column.rows[i]:Fire("OnLeave")
    column.frame:Fire("OnUpdate")
    expect(column.hover.alpha == 0.18, "row transitions retain whole-column highlight")
end
column.frame.mouseOver = false; column.frame:Fire("OnUpdate")
expect(column.hover.alpha == 0, "leaving column clears highlight")
expect(column.visualState == "disabled" and column.marker.text == "Selection unavailable",
    "disabled selection state remains clear")
local clicks = 0
function a:SelectLootSpecialization(specID) clicks = clicks + 1; return specID end
column.frame:Fire("OnClick", "LeftButton")
column.rows[1]:Fire("OnClick", "LeftButton")
expect(clicks == 0, "Phase 5 does not enable unconfirmed selection")
runtime.selectionAllowed = true
column.frame:Fire("OnUpdate")
expect(column.visualState == "available" and column.frame.icon.alpha == 1, "eligible state is distinct")
column.frame:Fire("OnClick", "LeftButton")
column.scroll:Fire("OnMouseUp", "LeftButton")
column.content:Fire("OnMouseUp", "LeftButton")
column.rows[1]:Fire("OnClick", "LeftButton")
expect(clicks == 4, "header, background and item rows use one handler")
column.rows[1]:Fire("OnClick", "RightButton")
state.combat = true; column.rows[1]:Fire("OnClick", "LeftButton"); state.combat = false
expect(clicks == 4, "right clicks and combat never select")
runtime.confirmedSpecID = column.specID; column.frame:Fire("OnUpdate")
expect(column.visualState == "selected" and column.marker.text == "Selected" and column.frame.bg.color[2] == 0.32,
    "confirmed selected state is visually distinct")
runtime.confirmedSpecID = nil
for _, status in ipairs({ "loading", "empty", "unsupported", "failed" }) do
    local r = resultFor(column, status == "loading" and 1 or 0, status)
    r.specs[column.specID].reason = "test-reason"
    a:RenderWindowLoot(r)
    expect(column.message.text ~= "" and column.rows[1].item == nil and not column.rows[1]:IsShown(),
        status .. " shows explicit message and removes stale loot")
    expect(column.offset == 0 and not column.bar:IsShown(), status .. " clears stale scroll extent")
end
a:RenderWindowLoot(resultFor(column, 2))
expect(column.rows[1] == originalRow and #frames == frameCount, "shorter result reuses row pool")
column.rows[1]:Fire("OnEnter")
state.exists = false; event("PLAYER_TARGET_CHANGED")
expect(column.rows[1].item == nil and not GameTooltip.shown and w.encounterData == nil,
    "context loss removes old rows and tooltip synchronously")
a, state, event = fixture({ instanceType = "party", instanceID = 100, difficultyID = 23 })
expect(a:GetMainWindow().header.text == "Test Dungeon: Mythic+",
    "ordinary Mythic entry uses compact Mythic+ header")
local scale = a:GetMainWindow().scale
state.uiWidth = 600; a:GetMainWindow():Fire("OnEvent", "UI_SCALE_CHANGED")
expect(a:GetMainWindow().scale < scale, "scale changes refit visible window")
GameTooltip = nil
output("Passed " .. checks .. " loot window presentation checks")
