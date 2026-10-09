-- Built-in appearances.
local _, ns = ...
local S = ns.Spekifier
local clientFont = GameFontHighlight and GameFontHighlight:GetFont() or "Fonts\\FRIZQT__.TTF"
S:RegisterWindowSkin("original", "Original", {
    bg = { .08, .08, .08, .85 }, border = { .55, .45, .23, 1 },
    accent = { 1, .82, .25, 1 }, selected = { .12, .32, .18, .85 },
    disabled = { .06, .06, .06, .85 }, text = { 1, 1, 1, 1 }, font = clientFont })
S:RegisterWindowSkin("elles", "Elles", {
    bg = { .067, .082, .11, 1 }, border = { .22, .26, .33, 1 },
    accent = { .27, .75, .85, 1 }, selected = { .094, .29, .26, 1 },
    disabled = { .09, .10, .12, 1 }, text = { .88, .90, .94, 1 }, font = clientFont })
