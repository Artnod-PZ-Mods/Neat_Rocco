-- NR_RoostPanel.lua
-- Derives from ISHutchRoostParentPanel and calls its vanilla chain.
-- Mod compatibility: any mod patching ISHutchRoostParentPanel.createChildren
-- or .render runs automatically (bars via drawProgressBar override,
-- ISButtons auto-detected and wrapped as NI_SquareButtons).

require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_DrawBar"
require "NeatRocco/NR_Utils/NR_DrawUtils"

NR_RoostPanel = ISHutchRoostParentPanel:derive("NR_RoostPanel")

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

-- Vanilla constants (synced with ISHutchUI.lua)
local FONT_HGT_SMALL    = getTextManager():getFontHeight(UIFont.Small)
local NEST_BOX_HEIGHT   = 130
local PADXY             = 20
local UI_BORDER_SPACING = 10
-- BAR_Y = vanilla boxY in ISHutchRoostParentPanel:render()
local BAR_Y = PADXY + NEST_BOX_HEIGHT + (NEST_BOX_HEIGHT + 10) * 3 + UI_BORDER_SPACING -- 580
local BAR_H = FONT_HGT_SMALL

-- Builds a callback that delegates to the vanilla ISButton's onclick
local function makeModBtnCallback(vanillaBtn)
    return function()
        if vanillaBtn.onclick then vanillaBtn.onclick(vanillaBtn.target, vanillaBtn) end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_RoostPanel:new(x, y, width, height, hutchUI)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:noBackground()
    o.hutchUI              = hutchUI
    o.disableJoypadNavigation = true
    o._nrModBtns           = {}  -- must exist before createChildren (which calls configJoypad)

    NR_DrawBar.initTextures(o)
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- createChildren — calls the vanilla chain (all mods run here),
-- then auto-detects mod-added ISButtons and wraps them as NI_SquareButtons.
-- ----------------------------------------------------------------------------------------------------- --

function NR_RoostPanel:createChildren()
    ISHutchRoostParentPanel.createChildren(self)

    -- Override closedDoorPanel background (vanilla black -> NeatUI dark)
    function self.closedDoorPanel:prerender()
        local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainTitle_BG.png")
        if bg then
            bg:render(self:getAbsoluteX(), self:getAbsoluteY(), self.width, self.height,
                      0.08, 0.08, 0.08, NR_Config.bgAlpha)
        end
    end

    local bsz = NR_Config.buttonSize

    -- Auto-detect mod-added ISButtons: collect first, then wrap (avoids mutating self.children during iteration).
    -- self.children is indexed by ID (not sequential), so pairs() is required.
    local knownVanilla = { [self.birdPooCleanBtn]=true, [self.doorBtn]=true }
    local modCandidates = {}
    for _, child in pairs(self.children) do
        if not knownVanilla[child] and child ~= self.closedDoorPanel and child.onclick then
            table.insert(modCandidates, child)
        end
    end
    for _, child in ipairs(modCandidates) do
        child:setVisible(false)
        local nrBtn = NI_SquareButton:new(0, 0, bsz,
            getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Mechanics.png"),
            self, makeModBtnCallback(child))
        nrBtn._vanillaBtn = child
        nrBtn:initialise()
        nrBtn:setActive(true)
        nrBtn:setActiveColor(0.7, 0.45, 0.1)
        nrBtn:setVisible(false)
        self:addChild(nrBtn)
        table.insert(self._nrModBtns, nrBtn)
    end

    self.birdPooCleanBtn:setVisible(false)
    self.doorBtn:setVisible(false)
    self.openDoorBtn:setVisible(false)

    self._nrCleanBtn = NI_SquareButton:new(
        PADXY, BAR_Y + BAR_H + 2,
        bsz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Clean.png"),
        self, NR_RoostPanel.onCleanFloor
    )
    self._nrCleanBtn:initialise()
    self._nrCleanBtn:setActive(true)
    self._nrCleanBtn:setActiveColor(0.95, 0.5, 0.1)
    self._nrCleanBtn:setVisible(false)
    self:addChild(self._nrCleanBtn)

    -- repositioned each frame in prerender()
    self._nrDoorBtn = NI_SquareButton:new(
        self.width - PADXY - bsz, self.height - UI_BORDER_SPACING - bsz,
        bsz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Door.png"),
        self, NR_RoostPanel.onToggleDoor
    )
    self._nrDoorBtn:initialise()
    self._nrDoorBtn:setActive(true)
    self._nrDoorBtn:setActiveColor(0.95, 0.5, 0.1)
    self:addChild(self._nrDoorBtn)

    local bigBsz = bsz * 2
    self._nrOpenDoorBtn = NI_SquareButton:new(
        math.floor((self.width - bigBsz) / 2),
        math.floor((self.height - bigBsz) / 2),
        bigBsz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Door.png"),
        self, NR_RoostPanel.onToggleDoor
    )
    self._nrOpenDoorBtn:initialise()
    self._nrOpenDoorBtn:setActive(true)
    self._nrOpenDoorBtn:setActiveColor(0.2, 0.75, 0.2)
    self.closedDoorPanel:addChild(self._nrOpenDoorBtn)

    self:configJoypad()
end

-- ----------------------------------------------------------------------------------------------------- --
-- drawProgressBar — NeatUI ThreePatch override
-- Called by ISHutchRoostParentPanel.render (dirt bar)
-- and by any mod patching render (e.g. BetterHutches woodchips bar).
-- Color logic: dirt bar (x <= PADXY) uses inverted progress (full = bad),
-- mod bars use direct progress (full = good).
-- ----------------------------------------------------------------------------------------------------- --

function NR_RoostPanel:drawProgressBar(x, y, w, h, progress)
    local r, g, b
    if x <= PADXY + 1 then
        -- dirt bar: full = bad
        r, g, b = NR_DrawBar.getBarColor(1 - progress)
    else
        -- mod bars (e.g. woodchips): full = good
        r, g, b = NR_DrawBar.getBarColor(progress)
    end
    NR_DrawBar.drawBar(self, x, y, w, h, progress, r, g, b)
end

-- ----------------------------------------------------------------------------------------------------- --
-- prerender
-- ----------------------------------------------------------------------------------------------------- --

function NR_RoostPanel:prerender()
    ISPanelJoypad.prerender(self)
    local bsz = NR_Config.buttonSize
    self._nrDoorBtn:setX(self.width - PADXY - bsz)
    self._nrDoorBtn:setY(self.height - UI_BORDER_SPACING - bsz)
end

-- ----------------------------------------------------------------------------------------------------- --
-- render — calls the full vanilla+mods chain (ThreePatch bars via drawProgressBar override,
-- vanilla ISButton state management), then syncs NI_SquareButtons.
-- ----------------------------------------------------------------------------------------------------- --

function NR_RoostPanel:render()
    -- Full vanilla + mods chain (bars, text labels, button states)
    ISHutchRoostParentPanel.render(self)

    if not self.hutchUI.hutch:isOpen() then
        self._nrCleanBtn:setVisible(false)
        for _, nrBtn in ipairs(self._nrModBtns) do nrBtn:setVisible(false) end
        return
    end

    -- Sync clean button from vanilla then re-hide it
    self._nrCleanBtn:setX(PADXY)
    self._nrCleanBtn:setY(BAR_Y + BAR_H + 2)
    self._nrCleanBtn:setVisible(self.birdPooCleanBtn:isReallyVisible())
    self._nrCleanBtn.enable  = self.birdPooCleanBtn.enable
    self._nrCleanBtn:setActive(self.birdPooCleanBtn.enable)
    self._nrCleanBtn.tooltip = self.birdPooCleanBtn.tooltip
    self.birdPooCleanBtn:setVisible(false)

    -- Auto-sync mod buttons: position and state read from vanilla button, then re-hide it
    for _, nrBtn in ipairs(self._nrModBtns) do
        local vBtn = nrBtn._vanillaBtn
        nrBtn:setX(vBtn:getX())
        nrBtn:setY(vBtn:getY())
        nrBtn:setVisible(vBtn:isReallyVisible())
        nrBtn.enable = vBtn.enable
        nrBtn:setActive(vBtn.enable)
        nrBtn.tabName = vBtn.tooltip or vBtn.title
        if nrBtn:isMouseOver() then
            NR_DrawUtils.drawTooltipAtMouse(self, nrBtn.tabName)
        end
        vBtn:setVisible(false)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Callbacks
-- ----------------------------------------------------------------------------------------------------- --

function NR_RoostPanel:onCleanFloor()
    self.hutchUI:onCleanFloor()
end

function NR_RoostPanel:onToggleDoor()
    self.hutchUI:onToggleDoor()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad
-- ----------------------------------------------------------------------------------------------------- --

function NR_RoostPanel:configJoypad()
    local joypadData = getJoypadData(self.hutchUI.playerNum)
    if not joypadData then return end
    self:clearJoypadFocus(joypadData)
    self.joypadIndexY = 1
    self.joypadIndex  = 1
    self.joypadButtonsY = {}
    self.joypadButtons  = {}
    if self.closedDoorPanel:isVisible() then
        self:insertNewLineOfButtons(self._nrOpenDoorBtn)
        self:setISButtonForX(self._nrOpenDoorBtn)
    else
        local boxPerRow  = 5
        local joypadBtns = {}
        for _, panel in ipairs(self.roostUI) do
            table.insert(joypadBtns, panel)
            if #joypadBtns == boxPerRow then
                self:insertNewListOfButtons(joypadBtns)
                joypadBtns = {}
            end
        end
        if #joypadBtns > 0 then
            self:insertNewListOfButtons(joypadBtns)
        end
        self:setISButtonForY(self._nrCleanBtn)
        for _, nrBtn in ipairs(self._nrModBtns) do
            self:setISButtonForY(nrBtn)
        end
        self:setISButtonForX(self._nrDoorBtn)
    end
    self:restoreJoypadFocus(joypadData)
end

function NR_RoostPanel:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    if self.closedDoorPanel:isVisible() then
        self:setISButtonForX(self._nrOpenDoorBtn)
    else
        self:setISButtonForY(self._nrCleanBtn)
        self:setISButtonForX(self._nrDoorBtn)
    end
    self:restoreJoypadFocus(joypadData)
end

function NR_RoostPanel:onLoseJoypadFocus(joypadData)
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
    self:clearISButtons()
    self:clearJoypadFocus(joypadData)
end

function NR_RoostPanel:hasConflictWithJoypadNavigateStart()
    return true
end
