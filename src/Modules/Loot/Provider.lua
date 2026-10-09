-- Request ownership, caching, delivery and bounded retries.
local _, addonTable = ...
local Spekifier = addonTable.Spekifier
local Provider = { cache = {}, cacheOrder = {}, generation = 0 }
Spekifier.LootProvider = Provider
local MAX_ATTEMPTS, MAX_CACHE = 6, 64
local Copy, Key, Validate = addonTable.Loot.Copy, addonTable.Loot.Key, addonTable.Loot.Validate
function Provider:Initialize()
    if self.frame then return end
    self:InitializeJournal()
    self.frame = CreateFrame("Frame")
    for _, event in ipairs({ "EJ_LOOT_DATA_RECIEVED", "GET_ITEM_INFO_RECEIVED",
        "ITEM_DATA_LOAD_RESULT", "CHALLENGE_MODE_MAPS_UPDATE", "PLAYER_REGEN_ENABLED" }) do
        self.frame:RegisterEvent(event)
    end
    self.frame:SetScript("OnEvent", function(_, event, itemID, success)
        self:OnEvent(event, itemID, success)
    end)
end
function Provider:Cancel(token)
    if self.active and (not token or self.active.token == token) then self.active = nil end
end
function Provider:IsCurrent(r)
    return self.active == r and (not r.isCurrent or r.isCurrent(r.context))
end
function Provider:Publish(r)
    if not self:IsCurrent(r) then return end
    local result = { state = "ready", context = Copy(r.context), classID = r.classID,
        specs = Copy(r.results), token = r.token }
    local empty, pending, failure, failureReason = true, false, nil, nil
    for _, id in ipairs(r.specs) do
        local spec = result.specs[id]
        if not spec or spec.state == "loading" then pending = true end
        if spec and (spec.state == "failed" or spec.state == "unsupported") then
            failure, failureReason = spec.state, spec.reason
        end
        if spec and #spec.items > 0 then empty = false end
    end
    result.state = pending and "loading" or failure or (empty and "empty" or "ready")
    result.reason = failureReason
    r.state = result.state
    r.callback(result)
end
function Provider:Remember(key, result)
    if not self.cache[key] then
        self.cacheOrder[#self.cacheOrder + 1] = key
        if #self.cacheOrder > MAX_CACHE then self.cache[table.remove(self.cacheOrder, 1)] = nil end
    end
    self.cache[key] = Copy(result)
end
function Provider:FinishTimeout(r, reason)
    for _, id in ipairs(r.specs) do
        local result = r.results[id]
        if result.state == "loading" then
            result.waitReason = result.reason
            result.state, result.reason = "failed", reason
        end
    end
    self:Publish(r)
end
function Provider:Schedule(r)
    if r.scheduled or not self:IsCurrent(r) or r.state ~= "loading" then return end
    if not C_Timer or not C_Timer.After then self:FinishTimeout(r, "retry-api-unavailable"); return end
    r.scheduled = true
    C_Timer.After(1, function()
        r.scheduled = false
        if self:IsCurrent(r) and r.state == "loading" then self:Run(r) end
    end)
end
function Provider:Run(r)
    if not self:IsCurrent(r) or self.busy then return end
    self.busy = true
    r.attempts = r.attempts + 1
    for _, id in ipairs(r.specs) do
        local result = r.results[id]
        if result.state == "loading" then
            local ok, queried = pcall(self.Query, self, r, id)
            result = ok and queried or { state = "failed", reason = "journal-query-failed", items = {} }
            r.results[id] = result
            if result.state == "ready" or result.state == "empty" then
                self:Remember(Key(r.context, r.classID, id), result)
            end
        end
    end
    self.busy = false
    self:Publish(r)
    if r.attempts >= MAX_ATTEMPTS and r.state == "loading" then self:FinishTimeout(r, "loot-data-timeout")
    else self:Schedule(r) end
end
-- A replacement cancels the previous comparison. Context/visit delivery is
-- separately guarded; cache entries can be reused across targets and visits.
function Provider:Request(context, classID, specs, callback, isCurrent)
    self:Initialize()
    self:Cancel()
    self.generation = self.generation + 1
    local r = { token = self.generation, context = Copy(context), classID = classID,
        specs = Copy(specs), callback = callback, isCurrent = isCurrent, results = {}, attempts = 0 }
    self.active = r
    local reason = Validate(context, classID, specs)
    if reason then
        r.state = "unsupported"
        if self:IsCurrent(r) then callback({ state = "unsupported", reason = reason,
            context = Copy(context), specs = {}, token = r.token }) end
        return r.token
    end
    for _, id in ipairs(specs) do
        r.results[id] = Copy(self.cache[Key(context, classID, id)]) or { state = "loading", items = {} }
    end
    self:Publish(r)
    if self:IsCurrent(r) and r.state == "loading" then
        if self.busy then self:Schedule(r) else self:Run(r) end
    end
    return r.token
end
function Provider:Invalidate()
    self.cache, self.cacheOrder = {}, {}
end
function Provider:ResumeBlocked(reason)
    local r = self.active
    if not r or not self:IsCurrent(r) then return end
    local resumed = false
    for _, result in pairs(r.results) do
        if result.state == "failed" and result.reason == "loot-data-timeout" and result.waitReason == reason then
            result.state, result.reason, result.waitReason = "loading", nil, nil
            resumed = true
        end
    end
    if resumed then r.attempts = 0; self:Publish(r); self:Schedule(r) end
end
