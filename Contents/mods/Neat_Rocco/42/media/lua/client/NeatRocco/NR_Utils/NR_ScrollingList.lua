-- NR_ScrollingList.lua
-- Factory and lifecycle helpers for ISScrollingListBox with NeatUI style.
-- Disables Java anchors that cause desync, applies the NeatUI scrollbar render.

require "NeatRocco/NR_Config"

NR_ScrollingList = {}

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

-- Creates an ISScrollingListBox with NeatUI defaults and adds it to parent.
-- The caller sets panel-specific callbacks (doDrawItem, onRightMouseUp, onMouseDown, etc.).
function NR_ScrollingList.new(parent, x, y, w, h)
    local lb = ISScrollingListBox:new(x, y, w, h)
    lb:initialise()
    lb:setAnchorLeft(true)
    lb:setAnchorRight(false)
    lb:setAnchorTop(true)
    lb:setAnchorBottom(false)
    lb.itemheight        = FONT_HGT_SMALL
    lb.drawBorder        = false
    lb.backgroundColor.a = 0
    lb.parent            = parent
    parent:addChild(lb)
    lb.vscroll:setAnchorBottom(false)
    lb.vscroll:setAnchorRight(false)
    NR_ScrollingList.applyNeatStyle(lb.vscroll)
    return lb
end

-- Applies the NeatUI scrollbar render to a vscroll element.
function NR_ScrollingList.applyNeatStyle(vscroll)
    vscroll.render = function(s)
        if not s.vertical then return end
        local sh2 = s.parent:getScrollHeight()
        if sh2 <= s:getHeight() then
            s.barx = 0; s.bary = 0; s.barwidth = 0; s.barheight = 0
            return
        end
        local del   = s:getHeight() / sh2
        local boxH  = math.max(math.ceil(del * s:getHeight()), NR_Config.scrollBarMinHeight)
        local dif   = math.ceil((s:getHeight() - boxH) * s.pos)
        s.barwidth  = s.width * 0.5
        s.barheight = boxH
        s.barx      = (s.width - s.barwidth) / 2
        s.bary      = dif
        local mx, my = s:getMouseX(), s:getMouseY()
        local hover  = s.scrolling or (s:isMouseOver() and s:isPointOverThumb(mx, my))
        local bright = hover and 1.0 or 0.8
        local tex = NinePatchTexture.getSharedTexture("media/ui/NeatUI/ScrollView/ScrollBar_V.png")
        if tex then
            tex:render(s:getAbsoluteX() + s.barx, s:getAbsoluteY() + s.bary,
                       s.barwidth, s.barheight, bright, bright, bright, 0.8)
        end
    end
end

-- Sets list height and syncs the vscroll (call in calculateLayout).
function NR_ScrollingList.setHeight(lb, h)
    lb:setHeight(h)
    lb.vscroll:setY(0)
    lb.vscroll:setHeight(h)
end

-- Sets list width and repositions the vscroll (call in updateLayout / calculateLayout).
function NR_ScrollingList.setWidth(lb, w)
    lb:setWidth(w)
    lb.vscroll:setX(w - NR_Config.scrollBarWidth)
end
