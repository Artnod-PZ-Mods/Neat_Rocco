-- NR_CollapseUtils.lua
-- Static module: collapse/peek behaviour for any NeatUI panel.
-- Works regardless of base class (NR_BasePanel, NR_BaseCW, or bare ISPanel).
-- Uses setMaxDrawHeight / clearMaxDrawHeight (ISUIElement API, available on all panels).
--
-- Panel contract:
--   Call NR_CollapseUtils.init(panel)      in new()
--   Call NR_CollapseUtils.update(panel)    in update()
--   Expose onClickCollapse / _onHeaderHover as instance methods (see below)
--   Guard body drawing with NR_CollapseUtils.isBodyVisible(panel)

require "NeatRocco/NR_Config"

NR_CollapseUtils = {}

local ICON_EXPANDED  = "media/ui/NeatRocco/ICON/Icon_ArrowDown.png"
local ICON_COLLAPSED = "media/ui/NeatRocco/ICON/Icon_Arrow_R.png"
local PEEK_FRAMES    = 10

-- ----------------------------------------------------------------------------------------------------- --
-- Init — call in new() after ISPanelJoypad.new() / ISCollapsableWindow:new()
-- ----------------------------------------------------------------------------------------------------- --

function NR_CollapseUtils.init(panel)
    panel._isCollapsed = false
    panel._peekCounter = 0
end

-- ----------------------------------------------------------------------------------------------------- --
-- Guard — use in prerender() / render() to skip body when collapsed and not peeking
-- ----------------------------------------------------------------------------------------------------- --

function NR_CollapseUtils.isBodyVisible(panel)
    return not panel._isCollapsed or panel._peekCounter > 0
end

-- ----------------------------------------------------------------------------------------------------- --
-- Toggle — wire to panel:onClickCollapse()
-- ----------------------------------------------------------------------------------------------------- --

function NR_CollapseUtils.onClickCollapse(panel)
    local hh  = NR_Config.headerHeight
    local btn = panel.header and panel.header.collapseButton
    if panel._isCollapsed then
        panel._isCollapsed = false
        panel._peekCounter = 0
        panel:clearMaxDrawHeight()
        if btn then btn:setIcon(getTexture(ICON_EXPANDED)); btn:setActive(true) end
    else
        panel._isCollapsed = true
        panel._peekCounter = 0
        panel:setMaxDrawHeight(hh)
        if btn then btn:setIcon(getTexture(ICON_COLLAPSED)); btn:setActive(false) end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Hover — wire to panel:_onHeaderHover() (called by NR_Header on mouse move)
-- ----------------------------------------------------------------------------------------------------- --

function NR_CollapseUtils.onHeaderHover(panel)
    if panel._isCollapsed then
        if panel._peekCounter == 0 then
            panel:clearMaxDrawHeight()
        end
        panel._peekCounter = PEEK_FRAMES
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Update — call in panel:update() each frame
-- ----------------------------------------------------------------------------------------------------- --

function NR_CollapseUtils.update(panel)
    if panel._isCollapsed and panel._peekCounter > 0 then
        panel._peekCounter = panel._peekCounter - 1
        if panel._peekCounter == 0 then
            panel:setMaxDrawHeight(NR_Config.headerHeight)
        end
    end
end
