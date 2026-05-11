-- NR_SelectableList.lua
-- Factory for selectable rows in a NIScrollView: selection highlight, separator, optional tooltip.

require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_DrawUtils"

NR_SelectableList = {}

-- Creates a selectable ISPanel row for use in a NIScrollView.
-- y            : Y position within the scrollView
-- w, h         : dimensions
-- isSelectedFn : function() -> bool
-- onClickFn    : function() called on click
-- drawFn       : function(row) draws row content
-- tooltipFn    : function() -> string|nil  (optional, shown on hover)
function NR_SelectableList.newRow(y, w, h, isSelectedFn, onClickFn, drawFn, tooltipFn)
    local row = ISPanel:new(0, y, w, h)
    row:noBackground()
    row:initialise()

    row.render = function(self2)
        if isSelectedFn() then
            local sc = NR_Config.selectionColor
            self2:drawRect(0, 0, self2.width, self2.height - 1, sc.a, sc.r, sc.g, sc.b)
        end
        self2:drawRect(0, self2.height - 1, self2.width, 1, 1, 0, 0, 0)
        if drawFn then drawFn(self2) end
    end

    row.onMouseDown = function(self2, x, y)
        if onClickFn then onClickFn() end
        return true
    end

    row.tooltipFn = tooltipFn
    return row
end

-- Draws tooltips for any hovered row that has a tooltipFn.
-- Call from the parent panel's render().
function NR_SelectableList.drawTooltips(panel, rows)
    for _, row in ipairs(rows) do
        if row.tooltipFn and row:isMouseOver() then
            local text = row.tooltipFn()
            if text then
                NR_DrawUtils.drawTooltipAtMouse(panel, text)
            end
        end
    end
end
