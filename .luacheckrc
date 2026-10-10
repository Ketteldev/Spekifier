-- Standard Lua 5.1 plus the WoW APIs used by Spekifier. Undefined globals
-- remain errors; no other addon's code or configuration is loaded.
std = "lua51"
-- Colon methods retain a receiver even when a particular method does not use it.
self = false
read_globals = {
    "ChatTypeInfo", "EncounterJournal", "IsAddOnLoaded", "hooksecurefunc", "C_AddOns", "C_ChallengeMode", "C_EncounterJournal", "C_Item",
    "C_MythicPlus", "C_SeasonInfo", "C_Timer", "CreateBaseTooltipInfo",
    "CreateFrame", "DEFAULT_CHAT_FRAME", "EJ_GetCreatureInfo", "EJ_GetDifficulty",
    "EJ_GetEncounterInfo", "EJ_GetEncounterInfoByIndex", "EJ_GetLootFilter",
    "EJ_GetNumLoot", "EJ_IsLootListOutOfDate", "EJ_IsValidInstanceDifficulty",
    "EJ_SelectEncounter", "EJ_SelectInstance", "EJ_SetDifficulty", "EJ_SetLootFilter",
    "GameFontHighlight", "GameTooltip", "GetCursorPosition", "GetDifficultyInfo",
    "GetInstanceInfo", "GetLootSpecialization", "GetMinimapShape",
    "GetNumSpecializations", "GetSpecialization", "GetSpecializationInfo",
    "InCombatLockdown", "IsInInstance", "ITEM_QUALITY_COLORS", "Minimap",
    "SetLootSpecialization", "Settings", "UIParent", "UIDropDownMenu_AddButton",
    "UIDropDownMenu_CreateInfo", "UIDropDownMenu_Initialize",
    "UIDropDownMenu_SetText", "UIDropDownMenu_SetWidth", "UnitCanAttack",
    "UnitClass", "UnitExists", "UnitGUID", "UnitIsDeadOrGhost", "UnitName",
    "issecretvalue", "strjoin",
}
globals = { "Spekifier", "SpekifierDB", "SlashCmdList", "UISpecialFrames",
    "SLASH_SPEKIFIER1", "SLASH_SPEKIFIER2" }
