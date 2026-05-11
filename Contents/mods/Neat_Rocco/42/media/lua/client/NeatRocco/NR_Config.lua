NR_Config = {}
local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local _good           = getCore():getGoodHighlitedColor()

NR_Config = {
    barHeight         = math.floor(FONT_HGT_SMALL * 1.2),
    bgAlpha           = 1.0,
    buttonSize        = math.floor(FONT_HGT_MEDIUM),
    convertToRT       = false,
    headerHeight      = math.floor(FONT_HGT_MEDIUM * 1.5),
    itemHeight        = math.floor(FONT_HGT_SMALL * 2.0),
    lineHeight        = math.floor(FONT_HGT_SMALL * 1.3),
    smallLineHeight   = math.floor(FONT_HGT_SMALL + 4),
    padding           = math.floor(FONT_HGT_SMALL * 0.4),
    perGenColor       = { r = _good:getR(), g = _good:getG(), b = _good:getB(), a = 0.08 },
    scrollBarMinHeight = 20,
    scrollBarWidth    = math.floor(FONT_HGT_SMALL * 0.6),
    tooltipPadX       = 10,
    tooltipPadY       = 6,
    showPerGenOverlay = true,
    showUnionOverlay  = false,
    unionColor        = { r = 0.69, g = 0.878, b = 0.902, a = 0.28 },
    warningLineHeight = math.floor(FONT_HGT_SMALL * 1.4),

    -- Theme colors
    headerBg         = 0.08,   -- MainTitle_BG gray tint (r = g = b)
    panelBg          = 0.15,   -- panel body background gray (r = g = b)
    separatorColor   = { a = 0.6, r = 0.4, g = 0.4, b = 0.4 },
    selectionColor   = { a = 0.15, r = 0.3, g = 0.7, b = 0.35 },
}

-- Livestock
NR_Config.actionBarHeight   = NR_Config.buttonSize + NR_Config.padding * 2
NR_Config.warningAreaHeight = NR_Config.warningLineHeight * 2 + NR_Config.padding
NR_Config.minListHeight     = NR_Config.itemHeight * 6
NR_Config.minWindowHeight   = NR_Config.headerHeight + NR_Config.minListHeight + NR_Config.actionBarHeight + NR_Config.warningAreaHeight + NR_Config.padding * 3
NR_Config.minActionBarWidth = NR_Config.padding + (NR_Config.buttonSize + NR_Config.padding) * 3
-- Hutch
NR_Config.tabBarHeight      = NR_Config.buttonSize + NR_Config.padding * 2
