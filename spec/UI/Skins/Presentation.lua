local output = print
local fixture = dofile("spec/Modules/Context/AutoShow.lua")
local count = 0
local function expect(value, label) assert(value, label); count = count + 1 end
local function setup(extra, saved)
    local args = { skins = true, discovery = true, uiWidth = 1920, uiHeight = 1080 }
    for k, v in pairs(extra or {}) do args[k] = v end
    return fixture(args, saved)
end
for _, addons in ipairs({ {}, { EllesmereUI = true }, { ElvUI = true }, { EllesmereUI = true, ElvUI = true }, { EllesmereUI = false, ElvUI = false } }) do
    local expected = (addons.EllesmereUI or addons.ElvUI) and "elles" or "original"
    for _, saved in ipairs({ { settings = {} }, { settings = { enabled = false } } }) do
        local a = setup({ loadedAddons = addons }, saved)
        expect(a:GetSetting("windowSkin") == expected, "fresh/upgrade default uses loaded addons")
    end
    for _, id in ipairs({ "original", "elles" }) do
        local a = setup({ loadedAddons = addons }, { settings = { windowSkin = id } })
        expect(a:GetSetting("windowSkin") == id, "saved choice wins")
    end
end
for _, id in ipairs({ "EllesmereUI", "ElvUI" }) do
    local a = setup({ startupAddon = id })
    expect(a:GetSetting("windowSkin") == "elles", "addon loaded after Spekifier before login")
end
for _, invalid in ipairs({ "bad", false, 42, {} }) do
    local a = setup({ loadedAddons = { ElvUI = true } }, { settings = { windowSkin = invalid } })
    expect(a:GetSetting("windowSkin") == "original", "invalid saved value falls back")
end
local a, state, event, frames = setup()
local w, c, runtime = a:GetMainWindow(), a:GetSpecColumn(1), a:GetWindowState()
local panel = a.optionsPanel
expect(#a:GetWindowSkins() == 2, "exactly two initial registry entries")
panel.windowSkin.initialize(panel.windowSkin, 1)
expect(#state.menu == 2 and state.menu[1].text == "Original" and state.menu[2].text == "Elles", "registry menu labels")
local items = {}
for i = 1, 60 do items[i] = { itemID = i, name = "Long localized loot name " .. i, quality = 4, icon = i } end
local result = { state = "ready", specs = {} }
for _, column in ipairs(a:GetAllSpecColumns()) do
    result.specs[column.specID] = { state = "ready", items = column == c and items or {} }
end
w.encounterData = result
a:RenderWindowLoot(result)
c:SetOffset(192)
runtime.confirmedSpecID, runtime.selectionAllowed = c.specID, true
a:RefreshColumnAppearance(c)
local point, width, height, opening = w.point, w.width, w.height, runtime.openingReason
local bindings, registrations = w.bindings, w.registrations
for i = 1, 10 do
    for _, id in ipairs({ "elles", "original" }) do
        a:SetWindowSkin(id)
        expect(w.point == point and w.width == width and w.height == height and w.encounterData == result, "switch retains position/size/data")
        expect(c.offset == 192 and runtime.confirmedSpecID == c.specID and runtime.openingReason == opening, "switch retains scroll/selection/lifecycle")
        expect(w.TitleBg.alpha == 0 and w.TopTileStreaks.alpha == 0, "skin switches keep obsolete title bar hidden")
        expect(w.title.point[1] == "TOPRIGHT" and w.title.fontSize == 22 and w.logo.width == 64, "left logo and title header persists across skins")
        expect(w.dragArea.height == 88, "replacement header remains draggable")
        expect(w.Bg.alpha == (id == "elles" and 0 or 1) and w.closeLabel:IsShown() == (id == "elles"), "chrome replaced and restored")
        expect(w.InsetBg.alpha == (id == "elles" and 0 or 1) and w.BotLeftCorner.alpha == (id == "elles" and 0 or 1), "inset and bottom template corners restored")
        expect(w.CloseButton.normalRegion.alpha == (id == "elles" and 0 or 1) and w.CloseButton.pushedRegion.alpha == (id == "elles" and 0 or 1), "close textures restored")
        expect(c.frame.bg.color[2] == a:GetWindowPalette().selected[2], "confirmed selection palette")
    end
end
local stable = #frames
a:ApplyWindowSkin(); a:ApplyWindowSkin()
expect(#frames == stable and w.bindings == bindings and w.registrations == registrations, "idempotent frames and handlers")
local row = c.rows[1]
local quality = { .65, .2, .9, 1 }
row.name:SetTextColor(quality[1], quality[2], quality[3], quality[4])
a:SetWindowSkin("elles")
expect(row.name.textColor[1] == quality[1] and row.name.textColor[3] == quality[3], "switch preserves item quality text color")
expect(row.skinBackground.color[1] == a:GetWindowPalette().bg[1] and row.name.fontSize == 18, "existing row styled")
items[61] = { itemID = 61, name = "New delayed row", icon = 61 }
a:RenderWindowLoot(result)
expect(c.rows[61].skinBackground.color[1] == a:GetWindowPalette().bg[1], "new row current skin")
for _, column in ipairs(a:GetAllSpecColumns()) do result.specs[column.specID].items = items end
a:RenderWindowLoot(result)
local strip = w.sharedLoot
strip:SetOffset(80)
local sharedOffset = strip.offset
a:SetWindowSkin("original"); a:SetWindowSkin("elles")
expect(strip.offset == sharedOffset and strip.icons[1].skinBackground.color[1] == a:GetWindowPalette().bg[1], "shared icons/scroll preserved and styled")
expect(strip.bar.thumb.color[2] == a:GetWindowPalette().accent[2], "shared overflow palette")
local savedSize = { w.width, w.height }
a:SetAutoShowPreference("enabled", false)
expect(not w:IsShown(), "auto-show disables automatic preview")
state.menu = {}; panel.windowSkin.initialize(panel.windowSkin, 1); state.menu[1].func()
expect(a:GetSetting("windowSkin") == "original" and not w:IsShown(), "dropdown usable with auto-show off without opening")
local dismissal = runtime.dismissedContextKey
state.combat = true; event("PLAYER_REGEN_DISABLED")
a:SetWindowSkin("elles")
expect(not w:IsShown() and runtime.dismissedContextKey == dismissal, "hidden/combat switch preserves dismissal")
state.combat = false; event("PLAYER_REGEN_ENABLED"); a:ShowWindow("manual")
expect(w.Bg.alpha == 0 and w.width == savedSize[1], "reopen uses selected appearance and size")
local lw, lh, hw, hh = a:WindowSizeLimits()
w.resizeGrip:Fire("OnMouseDown", "RightButton")
expect(not w.resizing, "only left button resizes")
w.resizeGrip:Fire("OnMouseDown", "LeftButton")
expect(w.resizing and w.sizing == "BOTTOMRIGHT", "corner initiates resizing")
w:SetSize(lw, lh)
w.resizeGrip:Fire("OnMouseUp", "LeftButton")
expect(a:GetSetting("windowWidth") == lw and a:GetSetting("windowHeight") == lh and not w.resizing, "resize persists dimensions")
expect(strip.width == lw - 120, "shared strip adapts")
a:SetWindowSkin("original")
expect(w.width == lw and w.height == lh, "skin preserves resize")
local saved = SpekifierDB
local b = setup(nil, saved)
expect(b:GetMainWindow().width == lw and b:GetMainWindow().height == lh and b:GetSetting("windowSkin") == "original", "login restores size/skin")
for _, bad in ipairs({ "bad", math.huge, -math.huge, 0/0 }) do
    local b = setup(nil, { settings = { windowWidth = bad, windowHeight = bad } })
    expect(b:GetMainWindow().width == 1080 and b:GetMainWindow().height == 720, "invalid dimensions default")
end
for _, specs in ipairs({ 2, 3, 4 }) do
    for _, screen in ipairs({ {1920,1080}, {1000,800}, {600,400} }) do
        local b = setup({ numSpecs = specs, uiWidth = screen[1], uiHeight = screen[2] })
        local window = b:GetMainWindow()
        local minW, minH = b:WindowSizeLimits()
        for _, id in ipairs({ "original", "elles" }) do
            b:SetWindowSkin(id); window:SetSize(minW, minH)
            expect(window.width * window.scale <= screen[1] - 40 + .001 and window.height * window.scale <= screen[2] - 40 + .001, "minimum layout fits screen")
            local r = { state = "ready", specs = {} }
            for _, col in ipairs(b:GetAllSpecColumns()) do r.specs[col.specID] = { state = "ready", items = col == b:GetSpecColumn(1) and items or {} } end
            b:RenderWindowLoot(r)
            local right = 0
            for _, col in ipairs(b:GetAllSpecColumns()) do
                expect(col.frame.point[4] >= right and col.frame.point[4] + col.frame.width <= window.width - 20, "columns do not overlap")
                right = col.frame.point[4] + col.frame.width
                expect(col.viewportHeight >= 120 and col.listWidth >= 190, "minimum content usable")
                col:SetOffset(col.range)
                expect(col.offset == col.range and col.content.height - col.offset == col.viewportHeight, "last row reachable")
            end
        end
    end
end
local late, catalog = setup({ numSpecs = 0 })
catalog.numSpecs = 4
late:CreateSpecializationColumns()
expect(#late:GetAllSpecColumns() == 4 and late:GetSpecColumn(4).frame.skinEdges ~= nil, "late specialization catalog receives skin")
expect(late:GetMainWindow().width >= 920, "late catalog enforces minimum width")
local pending = setup()
pending:SetSetting("windowSkin", nil)
C_AddOns.IsAddOnLoaded = function() return true, false end
pending:InitializeWindowSkin()
expect(pending:GetSetting("windowSkin") == "original", "loading but not loaded addon excluded")
for _, values in ipairs({ {0, -5}, {1e9, 1e9} }) do
    local bounded = setup(nil, { settings = { windowWidth = values[1], windowHeight = values[2] } })
    local minW, minH, maxW, maxH = bounded:WindowSizeLimits()
    local window = bounded:GetMainWindow()
    expect(window.width >= minW and window.width <= maxW and window.height >= minH and window.height <= maxH, "finite saved dimensions clamped")
end
a, state = setup(); panel = a.optionsPanel
local palette = a:GetWindowPalette()
a:RegisterWindowSkin("future", "Future", palette)
state.menu = {}; panel.windowSkin.initialize(panel.windowSkin, 1)
expect(#state.menu == 3 and state.menu[3].value == "future", "registry extends options without rewriting control")
state.menu[3].func()
expect(a:GetSetting("windowSkin") == "future" and panel.windowSkin.text == "Future", "future skin selection")
output("Passed " .. count .. " focused skin and resizing checks")

