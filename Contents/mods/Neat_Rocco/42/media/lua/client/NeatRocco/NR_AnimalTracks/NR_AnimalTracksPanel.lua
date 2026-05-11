-- NR_AnimalTracksPanel.lua
-- NeatUI replacement for ISAnimalTracksUI (animal tracks inspection window).

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Config"

NR_AnimalTracksPanel = NR_BasePanel:derive("NR_AnimalTracksPanel")
NR_AnimalTracksPanel.panels = {}

local ICON_SIZE = 70

-- ----------------------------------------------------------------------------------------------------- --
-- Static helper
-- ----------------------------------------------------------------------------------------------------- --

function NR_AnimalTracksPanel.computeAnimalType(track, trackingLevel)
    if not MigrationGroupDefinitions[track:getAnimalType()] then
        return "???"
    end
    if trackingLevel > 4 then
        return getText("IGUI_MigrationGroup_" .. track:getAnimalType())
    else
        return getText("IGUI_MigrationGroup_" .. MigrationGroupDefinitions[track:getAnimalType()].trackSize)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_AnimalTracksPanel:new(x, y, track, player)
    local pad = NR_Config.padding
    local hh  = NR_Config.headerHeight
    local lh  = NR_Config.lineHeight
    local tm  = getTextManager()

    local trackObj      = track:getAnimalTracks()
    local trackingLevel = player:getPerkLevel(Perks.Tracking)
    local hasDir        = trackObj:getDir() ~= nil
    local lineCount     = 2 + (hasDir and 1 or 0)

    -- Measure label column
    local labelW = tm:MeasureStringX(UIFont.Small, getText("IGUI_AnimalTracks_Animal"))
    labelW = math.max(labelW, tm:MeasureStringX(UIFont.Small, getText("IGUI_AnimalTracks_Freshness")))
    if hasDir then
        labelW = math.max(labelW, tm:MeasureStringX(UIFont.Small, getText("IGUI_AnimalTracks_Direction")))
    end

    -- Measure value column
    local valueW = tm:MeasureStringX(UIFont.Small, NR_AnimalTracksPanel.computeAnimalType(trackObj, trackingLevel))
    valueW = math.max(valueW, tm:MeasureStringX(UIFont.Small, trackObj:getFreshnessString(trackingLevel)))
    if hasDir then
        valueW = math.max(valueW, tm:MeasureStringX(UIFont.Small, trackObj:getDir():toString()))
    end

    local labelX = pad + ICON_SIZE + pad
    local valueX = labelX + labelW + pad
    local width  = valueX + valueW + pad
    local height = hh + pad + math.max(ICON_SIZE, lineCount * lh) + pad

    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.character     = player
    o.playerNum     = player:getPlayerNum()
    o.track         = trackObj
    o.trackingLevel = trackingLevel
    o.hasDir        = hasDir
    o.labelX        = labelX
    o.valueX        = valueX

    o.isSprite = instanceof(track, "IsoAnimalTrack")
    if o.isSprite then
        o.texture = getTexture(track:getSprite():getName())
    else
        o.texture = track:getTexture()
    end

    NR_BasePanel.initBase(o)

    NR_AnimalTracksPanel.panels[player] = o
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_AnimalTracksPanel:getWindowTitle()
    return getText("IGUI_AnimalTracks_" .. self.track:getTrackType())
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_AnimalTracksPanel:render()
    if not self.track then self:close() ; return end
    ISPanelJoypad.render(self)

    local pad    = NR_Config.padding
    local lh     = NR_Config.lineHeight
    local hh     = NR_Config.headerHeight
    local curY   = hh + pad
    local labelX = self.labelX
    local valueX = self.valueX

    -- Icon
    self:drawRect(pad, curY, ICON_SIZE, ICON_SIZE, 0.5, 0.8, 0.8, 0.8)
    self:drawRectBorder(pad, curY, ICON_SIZE, ICON_SIZE, 1, 0.3, 0.3, 0.3)
    if self.texture then
        self:drawTextureScaled(self.texture, pad + 3, curY + 3, ICON_SIZE - 6, ICON_SIZE - 6, 1, 1, 1, 1)
    end

    -- Rows
    if self.hasDir then
        self:drawText(getText("IGUI_AnimalTracks_Direction"), labelX, curY, 0.6, 0.6, 0.6, 1, UIFont.Small)
        self:drawText(self.track:getDir():toString(),         valueX, curY, 1, 1, 1, 1, UIFont.Small)
        curY = curY + lh
    end

    self:drawText(getText("IGUI_AnimalTracks_Animal"),   labelX, curY, 0.6, 0.6, 0.6, 1, UIFont.Small)
    self:drawText(NR_AnimalTracksPanel.computeAnimalType(self.track, self.trackingLevel), valueX, curY, 1, 1, 1, 1, UIFont.Small)
    curY = curY + lh

    self:drawText(getText("IGUI_AnimalTracks_Freshness"), labelX, curY, 0.6, 0.6, 0.6, 1, UIFont.Small)
    self:drawText(self.track:getFreshnessString(self.trackingLevel), valueX, curY, 1, 1, 1, 1, UIFont.Small)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_AnimalTracksPanel:close()
    NR_AnimalTracksPanel.panels[self.character] = nil
    self:closeBase()
end
