-- NR_FeedingTroughPanel.lua
-- NeatUI-styled replacement for ISFeedingTroughUI.

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Config"

NR_FeedingTroughPanel = NR_BasePanel:derive("NR_FeedingTroughPanel")

local VALUE_GAP = 10

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_FeedingTroughPanel:new(x, y, trough, player)
    local hh  = NR_Config.headerHeight
    local pad = NR_Config.padding
    local lh  = NR_Config.smallLineHeight

    -- Key column: widest key label
    local keyW = getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_FeedingTroughUI_AttachedAnimals"))
    keyW = math.max(keyW, getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_Animal_TroughLinkedTo")))
    keyW = math.max(keyW, getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_FeedingTroughUI_Feeding")))
    keyW = math.max(keyW, getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_FeedingTroughUI_Water")))

    -- Width: driven by the widest info line
    local infoW = getTextManager():MeasureStringX(UIFont.Small, getText("Tooltip_trough_info1"))
    infoW = math.max(infoW, getTextManager():MeasureStringX(UIFont.Small, getText("Tooltip_trough_info2")))
    infoW = math.max(infoW, getTextManager():MeasureStringX(UIFont.Small, getText("Tooltip_trough_info3")))
    local width = pad + infoW + pad

    -- Height: header + data section + gap + separator + gap + info section + bottom pad
    local height = hh + 4*pad + 7*lh

    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.item      = trough
    o.chr       = player
    o.playerNum = player:getPlayerNum()
    o._keyW     = keyW

    NR_BasePanel.initBase(o)

    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_FeedingTroughPanel:getWindowTitle()
    return getText("ContextMenu_FeedingTrough")
end

function NR_FeedingTroughPanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Trough.png")
end

function NR_FeedingTroughPanel:getInfoText()
    return getText("IGUI_Trough_Info")
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_FeedingTroughPanel:createChildren()
    NR_BasePanel.createChildren(self)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_FeedingTroughPanel:close()
    self:closeBase()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_FeedingTroughPanel:prerender()
    if self.item:getObjectIndex() == -1 then
        self:close()
        return
    end

    local hh  = NR_Config.headerHeight
    local pad = NR_Config.padding

    -- Adapt width to widest info line (text can change with locale)
    local infoW = getTextManager():MeasureStringX(UIFont.Small, getText("Tooltip_trough_info1"))
    infoW = math.max(infoW, getTextManager():MeasureStringX(UIFont.Small, getText("Tooltip_trough_info2")))
    infoW = math.max(infoW, getTextManager():MeasureStringX(UIFont.Small, getText("Tooltip_trough_info3")))
    local w = pad + infoW + pad
    if w ~= self.width then
        self:setWidth(w)
        if self.header then
            self.header:setWidth(w)
            self.header:calculateLayout(w, hh)
        end
    end

    NR_BasePanel.prerender(self)
end

function NR_FeedingTroughPanel:render()
    if self.item:getObjectIndex() == -1 then return end
    ISPanelJoypad.render(self)

    local pad    = NR_Config.padding
    local hh     = NR_Config.headerHeight
    local lh     = NR_Config.smallLineHeight
    local xPivot = pad + self._keyW
    local valX   = xPivot + VALUE_GAP

    local zone = DesignationZoneAnimal.getZone(
        self.item:getSquare():getX(),
        self.item:getSquare():getY(),
        self.item:getSquare():getZ()
    )

    local y = hh + pad
    self:drawLabelValue(getText("IGUI_FeedingTroughUI_AttachedAnimals"), tostring(self.item:getLinkedAnimals():size()),                                            xPivot, valX, y, 1.0, 0.5, 0.5, 0.5)
    y = y + lh
    self:drawLabelValue(getText("IGUI_Animal_TroughLinkedTo"),            zone and zone:getName() or getText("IGUI_Animal_TroughNotLinked"),                        xPivot, valX, y, 1.0, 0.5, 0.5, 0.5)
    y = y + lh
    self:drawLabelValue(getText("IGUI_FeedingTroughUI_Feeding"),          tostring(round(self.item:getCurrentFeedAmount(), 2)),                                    xPivot, valX, y, 1.0, 0.5, 0.5, 0.5)
    y = y + lh
    self:drawLabelValue(getText("IGUI_FeedingTroughUI_Water"),            round(self.item:getWater(), 2) * 1000 .. " / " .. self.item:getMaxWater() * 1000 .. " mL", xPivot, valX, y, 1.0, 0.5, 0.5, 0.5)

    y = y + lh + pad
    self:drawSeparator(y)
    y = y + pad

    self:drawText(getText("Tooltip_trough_info1"), pad, y, 0.6, 0.6, 0.6, 1, UIFont.Small)
    y = y + lh
    self:drawText(getText("Tooltip_trough_info2"), pad, y, 0.6, 0.6, 0.6, 1, UIFont.Small)
    y = y + lh
    self:drawText(getText("Tooltip_trough_info3"), pad, y, 0.6, 0.6, 0.6, 1, UIFont.Small)
end

-- (onGainJoypadFocus, onLoseJoypadFocus, onJoypadDown, isKeyConsumed, onKeyRelease héritées de NR_BasePanel)
