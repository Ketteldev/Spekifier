-- Phase 5.5 production presentation and provider integration acceptance.
local output = print
local fixture = assert(loadfile("spec/Modules/Context/AutoShow.lua"))()
local checks = 0
local function expect(value, label) assert(value, label); checks = checks + 1 end
local function item(id)
    return { itemID = id, name = "Item " .. id, link = "item:" .. id, icon = id, quality = 4 }
end
local function pool(a, ids)
    local r = { state = "ready", specs = {} }
    for i, c in ipairs(a:GetAllSpecColumns()) do
        local items = {}
        for _, id in ipairs(ids[i] or {}) do items[#items + 1] = item(id) end
        r.specs[c.specID] = { state = #items == 0 and "empty" or "ready", items = items }
    end
    return r
end
local function shownIDs(column)
    local ids = {}
    for _, row in ipairs(column.rows) do if row.item then ids[#ids + 1] = row.item.itemID end end
    return table.concat(ids, ",")
end

for _, count in ipairs({ 2, 3, 4 }) do
    for _, size in ipairs({ {1920,1080}, {800,600}, {600,400} }) do
        local a = fixture({ numSpecs = count, uiWidth = size[1], uiHeight = size[2] })
        local ids = {}
        for i = 1, count do ids[i] = { 90, 10, 90, i } end
        local r = pool(a, ids)
        local original = r.specs[1].items
        a:RenderWindowLoot(r)
        local w, strip = a:GetMainWindow(), a:GetMainWindow().sharedLoot
        expect(#strip.items == 2 and strip.items[1].itemID == 10 and strip.items[2].itemID == 90,
            "universal IDs deduplicated and deterministically ordered for every spec count")
        expect(r.specs[1].items == original and #original == 4 and original[1].itemID == 90 and
            original[2].itemID == 10 and original[3].itemID == 90, "source array/order/duplicates intact")
        for i, c in ipairs(a:GetAllSpecColumns()) do
            expect(shownIDs(c) == tostring(i), "universal loot removed from every column")
            expect(c.frame.point[5] == -166 and c.scroll.height == 420, "strip keeps fixed full column viewports")
        end
        expect(strip.frame.point[5] == -102 and strip.label.text == "Shared:" and
            strip.icons[1].name == nil and strip.icons[2].point[4] == 48, "icon-only horizontal strip beneath header")
        expect(w.height == 784 and w.width*w.scale <= size[1]-40+0.00001 and
            w.height*w.scale <= size[2]-40+0.00001, "shared layout fits UI dimensions")
        a:RenderWindowLoot(pool(a, ids))
        expect(strip.icons[1].item.itemID == 10, "equivalent refreshed ordering stable")
        local empty = {}; for i=1,count do empty[i]={} end
        a:RenderWindowLoot(pool(a, empty))
        expect(not strip.frame:IsShown() and w.height == 720 and a:GetSpecColumn(1).frame.point[5] == -102,
            "no-shared layout reclaims all strip space")
        expect(strip.icons[1].item == nil and strip.icons[1].icon.texture == nil,
            "obsolete shared icon bindings removed")
    end
end

local a, state, event, frames = fixture()
local w = a:GetMainWindow()
local r = pool(a, {{1,2,3,3}, {1,2,4}, {1,5}})
a:RenderWindowLoot(r)
expect(#w.sharedLoot.items == 1 and w.sharedLoot.items[1].itemID == 1, "three-spec intersection excludes pairwise loot")
expect(shownIDs(a:GetSpecColumn(1)) == "2,3" and shownIDs(a:GetSpecColumn(2)) == "2,4" and
    shownIDs(a:GetSpecColumn(3)) == "5", "pairwise and unique loot stay in eligible columns only")
local strip = w.sharedLoot
function CreateBaseTooltipInfo(getter, link) return { getterName=getter, getterArgs={link} } end
GameTooltip = { shown=false, strata="TOOLTIP" }
function GameTooltip:SetParent(parent) self.parent=parent end
function GameTooltip:SetOwner(owner) self.owner=owner end
function GameTooltip:IsOwned(owner) return self.owner==owner end
function GameTooltip:ClearLines() end
function GameTooltip:ProcessInfo(info) self.info=info end
function GameTooltip:SetAlpha(alpha) self.alpha=alpha end
function GameTooltip:Show() self.shown=true end
function GameTooltip:Hide() self.shown=false end
strip.icons[1]:Fire("OnEnter")
expect(GameTooltip.shown and GameTooltip.info.getterArgs[1] == "item:1" and GameTooltip.info.compareItem and
    GameTooltip.parent==UIParent and GameTooltip.strata=="TOOLTIP", "shared icons use original native comparison tooltip")
a:RenderWindowLoot(r)
expect(GameTooltip.shown, "equivalent refresh preserves shared tooltip")
strip.icons[1]:Fire("OnLeave")
expect(not GameTooltip.shown, "shared leave hides owned tooltip")
a:GetWindowState().selectionAllowed=true
local clicks=0
function a:SelectLootSpecialization() clicks=clicks+1 end
strip.icons[1]:Fire("OnClick", "LeftButton")
strip.icons[1]:Fire("OnMouseUp", "LeftButton")
for _, c in ipairs(a:GetAllSpecColumns()) do c.frame:Fire("OnUpdate"); expect(c.hover.alpha==0,"shared hover never highlights specs") end
expect(clicks==0 and strip.icons[1].scripts.OnClick==nil and strip.icons[1].scripts.OnMouseUp==nil,
    "shared icons never select a spec")

for _, status in ipairs({"loading","failed","unsupported"}) do
    a:RenderWindowLoot(r)
    strip.icons[1]:Fire("OnEnter")
    local partial=pool(a,{{1,2},{1,2},{1,2}})
    partial.specs[3].state=status
    a:RenderWindowLoot(partial) -- Even an incorrectly final aggregate fails closed.
    expect(not strip.frame:IsShown() and not GameTooltip.shown and strip.icons[1].item==nil,
        status .. " spec prevents false intersection and removes tooltip")
    expect(shownIDs(a:GetSpecColumn(1))=="1,2" and shownIDs(a:GetSpecColumn(3))=="",
        "complete individual pool stays intact while partial pool is hidden")
    partial.specs[3].state="ready"
    partial.state=status
    a:RenderWindowLoot(partial)
    expect(not strip.frame:IsShown(), status .. " aggregate prevents shared classification")
    partial.state="ready"
    a:RenderWindowLoot(partial)
    expect(#strip.items==2 and strip.frame:IsShown(), "delayed completion recomputes intersection")
end
local missing=pool(a,{{1},{1},{1}}); missing.specs[3]=nil
a:RenderWindowLoot(missing)
expect(not strip.frame:IsShown(), "missing displayed spec cannot classify shared loot")
a:RenderWindowLoot(pool(a,{{1},{1},{}}))
expect(not strip.frame:IsShown() and shownIDs(a:GetSpecColumn(1))=="1", "empty complete spec makes intersection empty")
local all=pool(a,{{9,8},{8,9},{9,8}})
a:RenderWindowLoot(all)
for _, c in ipairs(a:GetAllSpecColumns()) do
    expect(shownIDs(c)=="" and c.message.text=="All eligible loot is shared above." and c.message:IsShown() and
        c.range==0 and not c.bar:IsShown(), "all-shared columns explain empty lists without scroll remnants")
end
local long={}; for i=1,80 do long[i]=i end
local overflow=pool(a,{long,long,long})
a:RenderWindowLoot(overflow)
local first, frameCount=strip.icons[1],#frames
expect(strip.range==80*48-8-strip.width and strip.bar:IsShown(), "overflow has full horizontal range")
first:Fire("OnEnter"); first:Fire("OnMouseWheel",-1)
expect(strip.offset==48 and strip.scroll.horizontalOffset==48 and not GameTooltip.shown,
    "wheel over shared icons scrolls horizontally and clears tooltip")
strip.bar:SetValue(strip.range)
expect(strip.offset==strip.range and strip.scroll.horizontalOffset==strip.range, "slider reaches last shared icon")
a:RenderWindowLoot(overflow)
expect(strip.offset==strip.range and strip.icons[1]==first and #frames==frameCount,
    "same-context update preserves horizontal offset and reuses icons")
a:RenderWindowLoot(all)
expect(strip.offset==0 and strip.range==0 and not strip.bar:IsShown() and strip.icons[3].item==nil,
    "shrinking shared pool clamps scrolling and clears obsolete frames")
strip.icons[1]:Fire("OnEnter")
local changed=pool(a,{{7},{7},{7}})
a:RenderWindowLoot(changed)
expect(not GameTooltip.shown and strip.icons[1].item.itemID==7, "changed shared item clears old tooltip")
a:RenderWindowLoot(overflow); strip:SetOffset(100); first:Fire("OnEnter")
state.difficultyID=16; event("PLAYER_DIFFICULTY_CHANGED")
expect(not strip.frame:IsShown() and strip.offset==0 and first.item==nil and not GameTooltip.shown,
    "difficulty invalidation clears shared items/scroll/tooltips synchronously")
a:RenderWindowLoot(overflow); first:Fire("OnEnter")
state.exists=false; event("PLAYER_TARGET_CHANGED")
expect(not strip.frame:IsShown() and first.item==nil and not GameTooltip.shown, "context loss removes shared row")
GameTooltip=nil

-- Real provider callback and cache ownership, including ordinary Mythic preview.
local setup = assert(loadfile("spec/UI/Window/LootBinding.lua"))()
local journal
a,state,event,journal = setup({instanceType="party",instanceID=100,difficultyID=23})
C_EncounterJournal.GetLootInfoByIndex=function() return item(900) end
a.LootProvider:Invalidate()
state.difficultyID=8; event("CHALLENGE_MODE_START")
w=a:GetMainWindow(); strip=w.sharedLoot
expect(w.encounterData.state=="ready" and #strip.items==1 and strip.items[1].itemID==900,
    "real provider final callback renders universal item exactly once")
for _, c in ipairs(a:GetAllSpecColumns()) do
    expect(#w.encounterData.specs[c.specID].items==1 and shownIDs(c)=="", "display split preserves production result pools")
end
local cachePools=0
for _, cached in pairs(a.LootProvider.cache) do
    expect(#cached.items==1 and cached.items[1].itemID==900, "provider cache retains shared items")
    cachePools=cachePools+1
end
expect(cachePools==3, "all spec cache pools inspected")
a:HideWindow("dismissed")
expect(not strip.frame:IsShown() and strip.icons[1].item==nil, "closing clears shared row")
a:ShowWindow("manual")
expect(strip.frame:IsShown() and #strip.items==1, "cached reopen rederives shared loot")
local pending=true
C_EncounterJournal.GetLootInfoByIndex=function()
    local loot=item(901)
    if pending and journal.specID==3 then loot.link=nil end
    return loot
end
a.LootProvider:Invalidate()
state.difficultyID=23; event("PLAYER_DIFFICULTY_CHANGED")
expect(w.encounterData.state=="loading" and not strip.frame:IsShown() and strip.icons[1].item==nil,
    "real delayed spec clears formerly shared pool before classification")
expect(shownIDs(a:GetSpecColumn(1))=="901" and shownIDs(a:GetSpecColumn(3))=="",
    "real partial result retains completed column and hides incomplete column")
pending=false; state:Tick()
expect(w.encounterData.state=="ready" and #strip.items==1 and strip.items[1].itemID==901,
    "real delayed completion moves universal item into shared row")
expect(shownIDs(a:GetSpecColumn(1))=="" and #w.encounterData.specs[1].items==1,
    "real delayed display derivation leaves result pool untouched")
state.combat=true; event("PLAYER_REGEN_DISABLED")
expect(not strip.frame:IsShown() and strip.icons[1].item==nil, "combat clears shared loot through existing lifecycle")
output("Passed " .. checks .. " shared loot acceptance checks")
