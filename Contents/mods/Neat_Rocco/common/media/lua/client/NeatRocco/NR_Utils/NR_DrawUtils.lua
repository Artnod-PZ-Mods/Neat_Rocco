-- NR_DrawUtils.lua
-- Small drawing helpers shared across NR panels.

require "NeatRocco/NR_Config"

NR_DrawUtils = {}

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

-- Horizontal 1px separator, full panel width minus padding.
function NR_DrawUtils.drawSeparator(panel, y)
    local pad = NR_Config.padding
    local sc  = NR_Config.separatorColor
    panel:drawRect(pad, y, panel.width - pad * 2, 1, sc.a, sc.r, sc.g, sc.b)
end

-- NeatUI tooltip box at explicit screen-relative coords (no clamping — caller handles it).
function NR_DrawUtils.drawTooltip(panel, text, tx, ty)
    local tw = getTextManager():MeasureStringX(UIFont.Small, text) + NR_Config.tooltipPadX
    local th = FONT_HGT_SMALL + NR_Config.tooltipPadY
    panel:drawRect(tx - 1, ty - 1, tw + 2, th + 2, 0.6,  0, 0, 0)
    panel:drawRect(tx,     ty,     tw,     th,     0.95, 0, 0, 0)
    panel:drawRectBorder(tx, ty, tw, th, 1.0, 1, 1, 1)
    panel:drawText(text, tx + 5, ty + 3, 1, 1, 1, 1, UIFont.Small)
end

-- NeatUI tooltip at mouse position, clamped to panel bounds.
function NR_DrawUtils.drawTooltipAtMouse(panel, text)
    local tw  = getTextManager():MeasureStringX(UIFont.Small, text) + NR_Config.tooltipPadX
    local th  = FONT_HGT_SMALL + NR_Config.tooltipPadY
    local pad = NR_Config.padding
    local mx  = panel:getMouseX()
    local my  = panel:getMouseY()
    local tx  = math.min(mx + 20, panel.width  - tw - pad)
    local ty  = math.min(my + 20, panel.height - th - pad)
    NR_DrawUtils.drawTooltip(panel, text, tx, ty)
end

-- Right-aligned label + left-aligned value on the same line (2-column pivot layout).
-- la defaults to 0.7 (dim label); vr/vg/vb default to 1/1/1 (white value).
function NR_DrawUtils.drawLabelValue(panel, label, value, xPivot, valX, y, la, vr, vg, vb)
    panel:drawTextRight(label, xPivot, y, 1, 1, 1, la or 0.7, UIFont.Small)
    panel:drawText(value, valX, y, vr or 1, vg or 1, vb or 1, 1, UIFont.Small)
end

-- NeatUI panel body background (below header). Shared by NR_BasePanel, NR_CheckZonePanel, NR_ModalRichText.
function NR_DrawUtils.prerenderPanelBody(panel, headerHeight)
    local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainPanelBG_FlatTop.png")
    if bg then
        local c = NR_Config.panelBg
        bg:render(panel:getAbsoluteX(), panel:getAbsoluteY() + headerHeight,
                  panel.width, panel.height - headerHeight,
                  c, c, c, NR_Config.bgAlpha)
    end
end

-- Iterates buttons[1..count]; draws tooltip for the first hovered button with a tabName.
function NR_DrawUtils.drawTabTooltips(panel, buttons, count)
    for i = 1, count do
        local btn = buttons[i]
        if btn and btn.tabName and btn:isMouseOver() then
            NR_DrawUtils.drawTooltipAtMouse(panel, btn.tabName)
            break
        end
    end
end
