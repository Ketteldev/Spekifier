local _, addonTable = ...
local Spekifier = addonTable.Spekifier
-- UIParent dimensions are in UI units, so this also handles global UI scale.
function Spekifier:FitLootWindow()
    local window = self:GetMainWindow()
    if not window then return end
    local width = window:GetWidth()
    local availableWidth = UIParent.GetWidth and UIParent:GetWidth() or width + 40
    local availableHeight = UIParent.GetHeight and UIParent:GetHeight() or 760
    window:SetScale(math.min(1, (availableWidth - 40) / width, (availableHeight - 40) / window:GetHeight()))
end
