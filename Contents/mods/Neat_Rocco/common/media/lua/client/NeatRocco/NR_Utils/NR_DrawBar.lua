-- NR_DrawBar.lua
-- Shared progress bar drawing helpers for all NR panels.
-- panel must have progressBGTextures and progressFillTextures set (done by NR_BasePanel.initBase).

require "NeatUI_Framework/NeatTool/NeatTool_3Patch"

NR_DrawBar = {}

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

function NR_DrawBar.initTextures(o)
    o.progressBGTextures = {
        left   = getTexture("media/ui/NeatRocco/Progress/Background_L.png"),
        middle = getTexture("media/ui/NeatRocco/Progress/Background_M.png"),
        right  = getTexture("media/ui/NeatRocco/Progress/Background_R.png"),
    }
    o.progressFillTextures = {
        left   = getTexture("media/ui/NeatRocco/Progress/Progress_L.png"),
        middle = getTexture("media/ui/NeatRocco/Progress/Progress_M.png"),
        right  = getTexture("media/ui/NeatRocco/Progress/Progress_R.png"),
    }
end

-- pct : 0.0 - 1.0, (fr, fg, fb) = fill colour
function NR_DrawBar.drawBar(panel, x, y, w, h, pct, fr, fg, fb)
    NeatTool.ThreePatch.drawHorizontal(panel, x, y, w, h,
        panel.progressBGTextures.left, panel.progressBGTextures.middle, panel.progressBGTextures.right,
        0.8, 0.4, 0.4, 0.4)
    local fillW = math.floor(w * math.max(0, math.min(pct, 1)))
    if fillW > 0 then
        panel:setStencilRect(x, y, fillW, h)
        NeatTool.ThreePatch.drawHorizontal(panel, x, y, w, h,
            panel.progressFillTextures.left, panel.progressFillTextures.middle, panel.progressFillTextures.right,
            1.0, fr, fg, fb)
        panel:clearStencilRect()
    end
end

-- pct : 0.0 - 1.0 -> returns (r, g, b) : green above 50%, orange above 25%, red below
function NR_DrawBar.getBarColor(pct)
    if pct > 0.5 then return 0.2, 0.8, 0.3
    elseif pct > 0.25 then return 0.9, 0.5, 0.1
    else return 0.85, 0.2, 0.2 end
end

-- Barre de progression avec label centré (label optionnel ou vide)
function NR_DrawBar.drawBarWithLabel(panel, x, y, w, h, pct, label, fr, fg, fb)
    NR_DrawBar.drawBar(panel, x, y, w, h, pct, fr, fg, fb)
    if label and label ~= "" then
        local ty = y + math.floor((h - FONT_HGT_SMALL) / 2)
        panel:drawTextCentre(label, x + math.floor(w / 2), ty, 1, 1, 1, 1, UIFont.Small)
    end
end
