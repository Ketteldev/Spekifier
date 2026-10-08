local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local pending, noticeGeneration = nil, 0
local function Read(api, ...)
    if type(api) ~= 'function' then return nil end
    local ok, value = pcall(api, ...)
    if not ok or (issecretvalue and issecretvalue(value)) then return nil end
    return value
end
local function PlayerSpecs()
    local specs = {}
    for index = 1, Read(GetNumSpecializations) or 0 do
        local id = Read(GetSpecializationInfo, index)
        if type(id) == 'number' and id > 0 then specs[id] = true end
    end
    return specs
end
function Spekifier:ClearLootSelectionNotice()
    pending = nil
    noticeGeneration = noticeGeneration + 1
    self:GetWindowState().selectionNotice = nil
end
function Spekifier:SetSelectionNotice(text)
    local state = self:GetWindowState()
    noticeGeneration = noticeGeneration + 1
    local generation, key = noticeGeneration, state.contextKey
    state.selectionNotice = text
    local window = self:GetMainWindow()
    if window then self:RenderWindowLoot(window.encounterData) end
    if text and C_Timer and C_Timer.After then
        C_Timer.After(3, function()
            if generation ~= noticeGeneration or state.contextKey ~= key then return end
            state.selectionNotice = nil
            if window then self:RenderWindowLoot(window.encounterData) end
        end)
    end
end
function Spekifier:RefreshLootSpecialization()
    local state = self:GetWindowState()
    local raw, specs = Read(GetLootSpecialization), PlayerSpecs()
    local effective = raw
    if raw == 0 then
        local index = Read(GetSpecialization)
        effective = index and Read(GetSpecializationInfo, index)
    end
    state.lootSpecSetting = raw
    state.confirmedSpecID = specs[effective] and effective or nil
    state.selectionAllowed = state.resolvedContext ~= nil and not InCombatLockdown() and
        type(SetLootSpecialization) == 'function' and state.confirmedSpecID ~= nil
    if pending and raw == pending.specID then
        local request = pending
        pending = nil
        if state.contextKey == request.contextKey then
            self:HideWindow('dismissed')
            local color = ChatTypeInfo and ChatTypeInfo.SYSTEM
            DEFAULT_CHAT_FRAME:AddMessage('Spekifier has set your loot specialization to ' .. request.name .. '.',
                color and color.r or 1, color and color.g or 1, color and color.b or 0)
        end
    end
    for _, column in ipairs(self:GetAllSpecColumns()) do self:RefreshColumnAppearance(column) end
end
function Spekifier:SelectLootSpecialization(specID)
    local state, window = self:GetWindowState(), self:GetMainWindow()
    local key, difficulty, source = state.contextKey, state.difficultyID, state.sourceKey
    if not window or not window:IsShown() then return false end
    -- Resolve actual target/instance/visit at click time without automatic opening.
    self:RefreshAutoShow(nil, false)
    self:RefreshLootSpecialization()
    if not state.selectionAllowed or not window:IsShown() or state.contextKey ~= key or
        state.difficultyID ~= difficulty or state.sourceKey ~= source then
        self:SetSelectionNotice('Selection unavailable: the context changed or combat began.')
        return false
    end
    local name
    for _, column in ipairs(self:GetAllSpecColumns()) do
        if column.specID == specID then name = column.specName end
    end
    if not name or not PlayerSpecs()[specID] then return false end
    local request = { specID = specID, contextKey = key, name = name }
    pending = request -- Update event may fire synchronously inside the setter.
    self:SetSelectionNotice('Waiting for loot specialization confirmation...')
    local ok = pcall(SetLootSpecialization, specID)
    self:RefreshLootSpecialization()
    if not ok and pending == request then
        pending = nil
        self:SetSelectionNotice('Unable to set loot specialization. Try again outside combat.')
        return false
    end
    if pending == request and C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            if pending ~= request then return end
            self:RefreshLootSpecialization()
            if pending == request then
                pending = nil
                if state.contextKey == key then
                    self:SetSelectionNotice('Loot specialization was not confirmed. Try again.')
                end
            end
        end)
    end
    return ok
end
function Spekifier:InitializeLootSpecialization()
    if self.lootSpecFrame then return end
    local frame = CreateFrame('Frame')
    self.lootSpecFrame = frame
    for _, event in ipairs({ 'PLAYER_LOOT_SPEC_UPDATED', 'PLAYER_SPECIALIZATION_CHANGED',
        'PLAYER_TALENT_UPDATE', 'PLAYER_ENTERING_WORLD', 'PLAYER_LOGIN' }) do frame:RegisterEvent(event) end
    frame:SetScript('OnEvent', function(_, event, unit)
        if event == 'PLAYER_SPECIALIZATION_CHANGED' and unit and unit ~= 'player' then return end
        self:CreateSpecializationColumns()
        self:RefreshLootSpecialization()
        local window = self:GetMainWindow()
        if window and window:IsShown() then self:UpdateWindowContext(self:GetAutoShowState().contextKey) end
    end)
    self:RefreshLootSpecialization()
end
