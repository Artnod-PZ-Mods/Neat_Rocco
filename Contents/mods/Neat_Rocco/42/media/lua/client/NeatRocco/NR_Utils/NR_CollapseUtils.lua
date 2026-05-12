-- NR_CollapseUtils.lua
-- Static module: collapse/peek behaviour for any NeatUI panel.
-- Works regardless of base class (NR_BasePanel, NR_BaseCW, or bare ISPanel).
-- Uses setMaxDrawHeight / clearMaxDrawHeight (ISUIElement API, available on all panels).
--
-- Behaviour matches vanilla ISCollapsableWindow exactly (same formula, same threshold,
-- same event-driven mechanism):
--
--   onMouseMove (inside bbox):
--       collapseTimer = 0
--       if collapsed and mouse over no button is held and getMouseY < headerHeight
--           expand body (uncollapse)
--
--   onMouseMoveOutside (mouse moved while outside bbox):
--       if collapsed and body shown and really outside:
--           collapseTimer += getMultiplier / getTrueMultiplier / 0.8
--           if collapseTimer > 20: hide body (re-collapse)
--
-- Differences from vanilla ISCollapsableWindow:
--   - Auto-hide only kicks in after the user clicked the collapse button (_isCollapsed=true).
--     A panel that was never collapsed will never auto-hide. Equivalent to vanilla pin=true.
--   - _isCollapsed tracks user intent; _bodyShown tracks current visual state.
--     The collapse-button icon reflects user intent, not the transient peek state.
--
-- Panel contract (unchanged):
--   Call NR_CollapseUtils.init(panel)      in new()
--   Call NR_CollapseUtils.update(panel)    in update()   -- still called, kept as a no-op
--   Expose onClickCollapse / _onHeaderHover as instance methods
--   Guard body drawing with NR_CollapseUtils.isBodyVisible(panel)

require "NeatRocco/NR_Config"

NR_CollapseUtils = {}

local ICON_EXPANDED       = "media/ui/NeatRocco/ICON/Icon_ArrowDown.png"
local ICON_COLLAPSED      = "media/ui/NeatRocco/ICON/Icon_Arrow_R.png"
-- Threshold is read live from NR_Config.collapseThreshold (default 20 = vanilla).
-- Adjustable via Mod Options. See NR_ModOptions.lua.

-- ----------------------------------------------------------------------------------------------------- --
-- Internal helpers
-- ----------------------------------------------------------------------------------------------------- --

local function _showBody(panel)
    panel._bodyShown     = true
    panel._collapseTimer = 0
    panel:clearMaxDrawHeight()
end

local function _hideBody(panel)
    panel._bodyShown     = false
    panel._collapseTimer = 0
    panel:setMaxDrawHeight(NR_Config.headerHeight)
end

local function _setButton(panel, icon, active)
    local btn = panel.header and panel.header.collapseButton
    if btn then
        btn:setIcon(getTexture(icon))
        btn:setActive(active)
    end
end

local function _isAnyMouseButtonDown()
    return isMouseButtonDown(0) or isMouseButtonDown(1) or isMouseButtonDown(2)
end

-- Vanilla `onMouseMove` + `uncollapse()` semantics, scoped to our intent flag.
local function _handleMouseMove(panel)
    if not panel._isCollapsed then return end
    panel._collapseTimer = 0
    if panel._bodyShown then return end
    if _isAnyMouseButtonDown() then return end
    if panel:getMouseY() < NR_Config.headerHeight then
        _showBody(panel)
    end
end

-- Vanilla `onMouseMoveOutside` auto-collapse semantics.
local function _handleMouseMoveOutside(panel)
    if not panel._isCollapsed then return end
    if not panel._bodyShown   then return end
    local mx, my = panel:getMouseX(), panel:getMouseY()
    if mx < 0 or my < 0 or mx > panel:getWidth() or my > panel:getHeight() then
        local gt = getGameTime()
        local tm = gt:getTrueMultiplier()
        if tm > 0 then
            panel._collapseTimer = panel._collapseTimer + (gt:getMultiplier() / tm) / 0.8
        end
        if panel._collapseTimer > (NR_Config.collapseThreshold or 20) then
            _hideBody(panel)
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Init — call in new() after ISPanelJoypad.new() / ISCollapsableWindow:new()
-- Installs instance-level hooks on onMouseMove / onMouseMoveOutside.
-- ----------------------------------------------------------------------------------------------------- --

function NR_CollapseUtils.init(panel)
    panel._isCollapsed   = false  -- user intent (toggled by collapse button)
    panel._bodyShown     = true   -- current visual state
    panel._collapseTimer = 0      -- vanilla-style weighted frame counter

    local origMove = panel.onMouseMove
    panel.onMouseMove = function(self, dx, dy)
        if origMove then origMove(self, dx, dy) end
        _handleMouseMove(self)
    end

    local origMoveOut = panel.onMouseMoveOutside
    panel.onMouseMoveOutside = function(self, dx, dy)
        if origMoveOut then origMoveOut(self, dx, dy) end
        _handleMouseMoveOutside(self)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Guard — use in prerender() / render() to skip body when collapsed and not peeking
-- ----------------------------------------------------------------------------------------------------- --

function NR_CollapseUtils.isBodyVisible(panel)
    return panel._bodyShown
end

-- ----------------------------------------------------------------------------------------------------- --
-- Toggle — wire to panel:onClickCollapse()
-- ----------------------------------------------------------------------------------------------------- --

function NR_CollapseUtils.onClickCollapse(panel)
    if panel._isCollapsed then
        panel._isCollapsed = false
        _showBody(panel)
        _setButton(panel, ICON_EXPANDED, true)
    else
        panel._isCollapsed = true
        _hideBody(panel)
        _setButton(panel, ICON_COLLAPSED, false)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Header hover — wire to panel:_onHeaderHover() (called by NR_Header on mouse move)
-- Equivalent path to _handleMouseMove (since NR_Header sits inside the panel header zone).
-- Kept as a public entry point for panels that route header mouse events here.
-- ----------------------------------------------------------------------------------------------------- --

function NR_CollapseUtils.onHeaderHover(panel)
    if not panel._isCollapsed then return end
    panel._collapseTimer = 0
    if panel._bodyShown then return end
    if _isAnyMouseButtonDown() then return end
    _showBody(panel)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Update — no-op. Kept for contract compatibility with existing panels.
-- The mechanism is now fully event-driven via the onMouseMove / onMouseMoveOutside hooks
-- installed in init(), matching vanilla ISCollapsableWindow exactly.
-- ----------------------------------------------------------------------------------------------------- --

function NR_CollapseUtils.update()
end
