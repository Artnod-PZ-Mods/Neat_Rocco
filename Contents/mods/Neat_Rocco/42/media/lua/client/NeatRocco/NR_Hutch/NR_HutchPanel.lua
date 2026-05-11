-- NR_HutchPanel.lua
-- NeatUI-styled replacement for ISHutchUI.
-- Main window: header + custom tab bar + NR_NestPanel + NR_RoostPanel.

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Utils/NR_TabBar"
require "NeatRocco/NR_Config"
require "NeatRocco/NR_Hutch/NR_NestPanel"
require "NeatRocco/NR_Hutch/NR_RoostPanel"

NR_HutchPanel = NR_BasePanel:derive("NR_HutchPanel")
NR_HutchPanel.ui = {}

-- Vanilla constants (fixed — must match ISHutchUI.lua exactly)
local FONT_HGT_SMALL    = getTextManager():getFontHeight(UIFont.Small)
local NEST_BOX_HEIGHT   = 130
local ROOST_WIDTH       = 90
local PADXY             = 20
local UI_BORDER_SPACING = 10

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_HutchPanel:new(x, y, hutch, player)
    local playerNum = player:getPlayerNum()

    local hh      = NR_Config.headerHeight
    local tabBarH = NR_Config.tabBarHeight
    local bsz     = NR_Config.buttonSize

    -- Window width = roost panel width (widest sub-panel)
    local windowW = PADXY + ROOST_WIDTH * 5 + 10 * 4 + PADXY  -- 530

    -- Sub-panel heights (computed using vanilla constants + NeatUI button size)
    local numNestBoxes = hutch:getMaxNestBox() + 1  -- zero-based; typically 4
    local boxPerRow    = 2
    local numRows      = math.ceil(numNestBoxes / boxPerRow)
    local nestPanelH   = PADXY + NEST_BOX_HEIGHT * numRows + 10 * (numRows - 1)
                        + UI_BORDER_SPACING + bsz + UI_BORDER_SPACING

    -- barY in roost panel = PADXY + NEST_BOX_HEIGHT + (NEST_BOX_HEIGHT+10)*3 + UI_BORDER_SPACING = 580
    local barY_roost   = PADXY + NEST_BOX_HEIGHT + (NEST_BOX_HEIGHT + 10) * 3 + UI_BORDER_SPACING
    local roostPanelH  = barY_roost + FONT_HGT_SMALL + 2 + bsz + UI_BORDER_SPACING

    -- Start at tab 1 (nest) height; switchTab() resizes when changing tabs
    local windowH  = hh + tabBarH + nestPanelH

    local o = ISPanelJoypad.new(self, x, y, windowW, windowH)
    setmetatable(o, self)
    self.__index = self

    o.hutch      = hutch
    o.chr        = player
    o.playerNum  = playerNum
    o.activeTab  = 1
    o.tabButtons = {}

    -- Propriétés lues par ISHutchRoostParentPanel.createChildren() via self.hutchUI
    o.btnBorder = {r=1, g=1, b=1, a=0.7}

    -- Cached sub-panel dimensions for switchTab()
    o._nestPanelH  = nestPanelH
    o._roostPanelH = roostPanelH

    NR_BasePanel.initBase(o)

    -- Forces hutch to update (same as vanilla ISHutchUI:new)
    hutch:reforceUpdate()

    NR_HutchPanel.ui[playerNum] = o
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_HutchPanel:getWindowTitle()
    return getText("ContextMenu_Hutch_Info")
end

function NR_HutchPanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Hutch.png")
end

function NR_HutchPanel:getInfoText()
    return getText("IGUI_Hutch_Info")
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_HutchPanel:createChildren()
    NR_BasePanel.createChildren(self)

    local hh      = NR_Config.headerHeight
    local tabBarH = NR_Config.tabBarHeight

    -- Tab bar
    self.tabBar = NR_TabBar.create(self, hh)

    self.tabButtons[1] = NR_TabBar.addButton(self.tabBar, self, 1,
        getTexture("media/ui/NeatRocco/ICON/Icon_Tab_Nest.png"),
        getText("IGUI_Hutch_EggLayingBox"), true)
    self.tabButtons[2] = NR_TabBar.addButton(self.tabBar, self, 2,
        getTexture("media/ui/NeatRocco/ICON/Icon_Tab_Roost.png"),
        getText("IGUI_Hutch_CoopRoosting"), false)

    -- NR_NestPanel (below tab bar, visible by default)
    local subY = hh + tabBarH
    self.nestPanel = NR_NestPanel:new(0, subY, self.width, self._nestPanelH, self)
    self.nestPanel:initialise()
    self:addChild(self.nestPanel)
    self.nestPanel:setVisible(true)

    -- NR_RoostPanel (same Y as nestPanel, hidden by default)
    self.roostPanel = NR_RoostPanel:new(0, subY, self.width, self._roostPanelH, self)
    self.roostPanel:initialise()
    self:addChild(self.roostPanel)
    self.roostPanel:setVisible(false)

    self._tabPanels = { self.nestPanel, self.roostPanel }
end

-- ----------------------------------------------------------------------------------------------------- --
-- Tab switching
-- ----------------------------------------------------------------------------------------------------- --

function NR_HutchPanel:switchTab(n)
    self.activeTab = n
    NR_TabBar.switch(self.tabButtons, self._tabPanels, 2, n)
    local contentH = n == 1 and self._nestPanelH or self._roostPanelH
    self:setHeight(NR_Config.headerHeight + NR_Config.tabBarHeight + contentH)
    local joypadData = getJoypadData(self.playerNum)
    if joypadData then
        joypadData.focus = self._tabPanels[n]
        updateJoypadFocus(joypadData)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_HutchPanel:prerender()
    NR_BasePanel.prerender(self)
    -- Separator below tab bar
    self:drawRect(0, NR_Config.headerHeight + NR_Config.tabBarHeight - 1, self.width, 2, 1, 0, 0, 0)
end

function NR_HutchPanel:render()
    if not self.hutch then return end
    ISPanelJoypad.render(self)
    self:checkDistance()
    self:drawTabTooltips(self.tabButtons, 2)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Vanilla logic — preserved 1:1 (NR_NestPanel/NR_RoostPanel delegates to these)
-- ----------------------------------------------------------------------------------------------------- --

function NR_HutchPanel:add3DAnimal(panel, animal, _chickenX, _chickenY)
    if panel:getCharacter() then
        -- Grace period: wait for the Java 3D model to finish loading before showing
        if panel._nfPendingFrames and panel._nfPendingFrames > 0 then
            panel._nfPendingFrames = panel._nfPendingFrames - 1
            return
        end
        self:checkAnimalSit(panel, animal)
        if animal:isDead() then
            panel:setVariable("HutchAnimation", "dead")
        end
        panel:setVisible(true)
        return
    end
    -- First-time init: give the Java model 3 extra frames to load before showing
    panel._nfPendingFrames = 3
    panel:setAnimSetName(animal:GetAnimSetName())
    panel:setCharacter(animal)
    panel:setDirection(IsoDirections.W)
    panel:setVariable("HutchAnimation", "idle1")
    if ZombRand(2) == 0 then
        panel:setDirection(IsoDirections.E)
    end
end

function NR_HutchPanel:checkAnimalSit(panel, _animal)
    local currentState = panel:getVariable("HutchAnimation")
    if "sitting" == currentState then return end
    if ZombRand(200) == 0 then
        panel:setVariable("HutchAnimation", "sitting1")
    end
end

function NR_HutchPanel:checkAnimal(index, _chickenX, _chickenY, _rowY, _shelfH, _btnGrabOffset)
    local animal = self.hutch:getAnimal(index)
    local panel  = self.roostPanel.avatarPanel[index + 1]
    if animal then
        self:add3DAnimal(panel, animal, _chickenX, _chickenY)
    else
        panel:setCharacter(nil)
        panel._nfPendingFrames = nil
        panel:setVisible(false)
    end
end

function NR_HutchPanel:onCleanFloor()
    if luautils.walkAdj(self.chr, self.hutch:getEntrySq()) then
        local water  = self.chr:getInventory():getFirstWaterFluidSources(true, true)
        local bleach = self.chr:getInventory():getFirstCleaningFluidSources()
        local mop    = self.chr:getInventory():getFirstTagEvalRecurse(ItemTag.CLEAN_STAINS,
                                                                       function(item) return not item:isBroken() end)
        ISWorldObjectContextMenu.equip(self.chr, self.chr:getPrimaryHandItem(), mop, true, false)
        ISTimedActionQueue.add(ISHutchCleanFloor:new(self.chr, self.hutch, water, mop, bleach))
    end
end

function NR_HutchPanel:onCleanNest()
    if luautils.walkAdj(self.chr, self.hutch:getEntrySq()) then
        ISTimedActionQueue.add(ISHutchCleanNest:new(self.chr, self.hutch))
    end
end

function NR_HutchPanel:onToggleDoor()
    ISHutchMenu.onToggleDoor(self.hutch, self.chr)
end

function NR_HutchPanel:onToggleEggHatchDoor()
    ISHutchMenu.onToggleEggHatchDoor(self.hutch, self.chr)
end

function NR_HutchPanel:onGrabNest(index)
    self.nestPanel.nestBoxUI[index + 1]:onButtonGrab()
end

function NR_HutchPanel:onGrabRoost(index)
    self.roostPanel.roostUI[index + 1]:onButtonGrab()
end

function NR_HutchPanel:showRoosts()
    self:switchTab(2)
end

function NR_HutchPanel:showNestBoxes()
    self:switchTab(1)
end

function NR_HutchPanel:checkDistance()
    if not self.chr or not self.chr:getCurrentSquare()
    or self.chr:getCurrentSquare():DistToProper(self.hutch:getEntrySq()) > 5 then
        self:close()
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_HutchPanel:close()
    NR_HutchPanel.ui[self.playerNum] = nil
    self:closeBase()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad
-- ----------------------------------------------------------------------------------------------------- --

function NR_HutchPanel:onGainJoypadFocus(joypadData)
    NR_BasePanel.onGainJoypadFocus(self, joypadData)
    -- Redirect focus into the active sub-panel
    local activePanel = self.activeTab == 1 and self.nestPanel or self.roostPanel
    if activePanel then
        joypadData.focus = activePanel
        updateJoypadFocus(joypadData)
    end
end

-- (onLoseJoypadFocus, onJoypadDown, isKeyConsumed, onKeyRelease héritées de NR_BasePanel)

function NR_HutchPanel:onJoypadDown_Descendant(descendant, button, joypadData)
    if button == Joypad.BButton then
        self:close()
        return
    end
    if button == Joypad.LBumper or button == Joypad.RBumper then
        local nextTab
        if button == Joypad.LBumper then
            nextTab = self.activeTab == 1 and 2 or 1
        else
            nextTab = self.activeTab == 2 and 1 or 2
        end
        getSoundManager():playUISound("UIActivateTab")
        self:switchTab(nextTab)
        return
    end
    ISPanelJoypad.onJoypadDown_Descendant(self, descendant, button, joypadData)
end
