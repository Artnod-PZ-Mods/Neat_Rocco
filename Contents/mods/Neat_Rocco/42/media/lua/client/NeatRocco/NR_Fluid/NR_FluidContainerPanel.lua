-- NR_FluidContainerPanel.lua
-- NeatUI replacement for ISFluidInfoUI.
-- Header: owner icon + container name + close button.
-- Body: Capacity / Used / Free labels + ISFluidBar.

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Config"

NR_FluidContainerPanel = NR_BasePanel:derive("NR_FluidContainerPanel")
NR_FluidContainerPanel.players = {}

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FLUID_BAR_W    = FONT_HGT_SMALL + 6
local VALUE_GAP      = 8

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidContainerPanel:getWindowTitle()
    local fc = self.container and self.container:getFluidContainer()
    return fc and fc:getTranslatedContainerName() or ""
end

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidContainerPanel:new(x, y, width, height, character, container, textAreaW)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.character  = character
    o.playerNum  = character:getPlayerNum()
    o.container  = container
    o.owner      = container:getOwner()
    o.isIsoPanel = container:isIsoPanel()
    o._textAreaW = textAreaW

    NR_BasePanel.initBase(o)
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidContainerPanel:createChildren()
    NR_BasePanel.createChildren(self)

    local hh  = NR_Config.headerHeight
    local pad = NR_Config.padding
    local slh = NR_Config.smallLineHeight

    local barX = pad + self._textAreaW + pad
    local barY = hh + pad
    local barH = slh * 3

    self.fluidBar = ISFluidBar:new(barX, barY, FLUID_BAR_W, barH, self.character)
    self.fluidBar:initialise()
    self.fluidBar:instantiate()
    self:addChild(self.fluidBar)

    local fc = self.container and self.container:getFluidContainer()
    if fc then
        self.fluidBar:setContainer(fc)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Update — distance check for world objects
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidContainerPanel:update()
    if not self.isIsoPanel then return end
    if not ISFluidUtil.validateContainer(self.container) then
        self:close()
        return
    end
    local owner = self.owner
    if not owner or not instanceof(owner, "IsoObject") then return end
    local square = owner:getSquare()
    if not square then self:close() return end
    local dist = ISFluidUtil.isoMaxPanelDist
    local px, py = self.character:getX(), self.character:getY()
    local sx, sy = square:getX(), square:getY()
    if px < sx - dist or px > sx + dist or py < sy - dist or py > sy + dist then
        self:close()
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidContainerPanel:prerender()
    NR_BasePanel.prerender(self)
end

function NR_FluidContainerPanel:render()
    local fc = self.container and self.container:getFluidContainer()
    if not fc then self:close() return end

    ISPanelJoypad.render(self)

    local pad = NR_Config.padding
    local hh  = NR_Config.headerHeight
    local slh = NR_Config.smallLineHeight

    local capacity = fc:getCapacity()
    local stored   = fc:getAmount()
    local free     = capacity - stored

    local capLabel  = getText("Fluid_Capacity") .. ":"
    local usedLabel = getText("Fluid_Stored") .. ":"
    local freeLabel = getText("Fluid_Free") .. ":"

    local tagW = math.max(
        getTextManager():MeasureStringX(UIFont.Small, capLabel),
        getTextManager():MeasureStringX(UIFont.Small, usedLabel),
        getTextManager():MeasureStringX(UIFont.Small, freeLabel)
    )
    local xPivot = pad + tagW
    local valX   = xPivot + VALUE_GAP

    local curY = hh + pad

    self:drawLabelValue(capLabel,  FluidUtil.getAmountFormatted(capacity), xPivot, valX, curY)
    curY = curY + slh
    self:drawLabelValue(usedLabel, FluidUtil.getAmountFormatted(stored),   xPivot, valX, curY)
    curY = curY + slh
    self:drawLabelValue(freeLabel, FluidUtil.getAmountFormatted(free),     xPivot, valX, curY)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Open
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidContainerPanel.OpenPanel(character, container)
    if not ISFluidUtil.validateContainer(container) then return end
    if not container:isValid() then return end
    if not character then return end

    local playerNum = character:getPlayerNum()

    if NR_FluidContainerPanel.players[playerNum] then
        NR_FluidContainerPanel.players[playerNum]:close()
    end

    local pad = NR_Config.padding
    local slh = NR_Config.smallLineHeight
    local tm  = getTextManager()

    local capLabel  = getText("Fluid_Capacity") .. ":"
    local usedLabel = getText("Fluid_Stored") .. ":"
    local freeLabel = getText("Fluid_Free") .. ":"

    local fc = container:getFluidContainer()

    local tagW = math.max(
        tm:MeasureStringX(UIFont.Small, capLabel),
        tm:MeasureStringX(UIFont.Small, usedLabel),
        tm:MeasureStringX(UIFont.Small, freeLabel)
    )
    local valW = math.max(
        tm:MeasureStringX(UIFont.Small, FluidUtil.getAmountFormatted(fc:getCapacity())),
        tm:MeasureStringX(UIFont.Small, FluidUtil.getAmountFormatted(fc:getAmount())),
        tm:MeasureStringX(UIFont.Small, FluidUtil.getAmountFormatted(fc:getCapacity() - fc:getAmount()))
    )

    local textAreaW  = tagW + VALUE_GAP + valW
    local bodyW      = pad + textAreaW + pad + FLUID_BAR_W + pad
    local headerMinW = tm:MeasureStringX(UIFont.Medium, fc:getTranslatedContainerName())
                     + NR_Config.buttonSize + NR_Config.padding * 3
    local width  = math.max(bodyW, headerMinW)
    local height = NR_Config.headerHeight + pad + slh * 3 + pad

    local x = getMouseX() + 10
    local y = getMouseY() + 10

    local panel = NR_FluidContainerPanel:new(x, y, width, height, character, container, textAreaW)
    panel:initialise()
    panel:instantiate()
    panel:setVisible(true)
    panel:addToUIManager()

    NR_FluidContainerPanel.players[playerNum] = panel

    if getJoypadData(playerNum) or container:isIsoPanel() then
        panel:centerOnScreen(playerNum)
    end
    if getJoypadData(playerNum) then
        setJoypadFocus(playerNum, panel)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidContainerPanel:close()
    NR_FluidContainerPanel.players[self.playerNum] = nil
    self:closeBase()
end
