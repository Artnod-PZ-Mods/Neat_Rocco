-- NR_CheckZonePanel.lua
-- NeatUI-styled replacement for ISDesignationZoneAnimalZoneUI ("Check Zone" right-click panel).

require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_Header"
require "NeatRocco/NR_Utils/NR_DrawUtils"

NR_CheckZonePanel = ISDesignationZoneAnimalZoneUI:derive("NR_CheckZonePanel")

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_CheckZonePanel:new(x, y, width, height, player, zone)
    local o = ISDesignationZoneAnimalZoneUI.new(self, x, y, width, height, player, zone)
    setmetatable(o, self)
    self.__index = self
    o.drawFrame  = false
    o.background = false
    o:setWantKeyEvents(true)
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_CheckZonePanel:getWindowTitle()
    return self.zone and self.zone:getName() or ""
end

function NR_CheckZonePanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Fences.png")
end

function NR_CheckZonePanel:getInfoText()
    return getText("IGUI_Animal_ZoneFirstInfo")
end

function NR_CheckZonePanel:getInfoTitle()
    return getText("IGUI_DesignationZone_Title")
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_CheckZonePanel:initialise()
    ISDesignationZoneAnimalZoneUI.initialise(self)

    local hh   = NR_Config.headerHeight
    local bsz  = NR_Config.buttonSize
    local pad  = NR_Config.padding
    local fntS = getTextManager():getFontHeight(UIFont.NewSmall)

    -- Hide vanilla buttons (Close, Reload, Help; AnimalInfo kept for joypad)
    self.ok:setVisible(false)
    self.reloadBtn:setVisible(false)
    self.infoBtn:setVisible(false)

    -- Reposition animalPanel and tickbox to leave room for header
    local animalPanelY = hh + pad + fntS + pad
    self.animalPanel:setY(animalPanelY)
    self.showZoneTickBox:setY(self.animalPanel:getBottom() + pad)

    self.header = NR_Header:new(0, 0, self.width, hh, self)
    self.header:initialise()
    self:addChild(self.header)
    self.header:calculateLayout(self.width, hh)

    -- Reload button anchored to bottom-right; triggers a zone check + animal list refresh
    self.reloadButton = NI_SquareButton:new(
        self.width - bsz - pad,
        self.height - bsz - pad,
        bsz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Reset.png"),
        self,
        function()
            local connectedZones = DesignationZoneAnimal.getAllDZones(nil, self.zone, nil)
            for i = 1, connectedZones:size() do
                connectedZones:get(i-1):check()
            end
            self:reload()
            self:updateAnimals()
        end
    )
    self.reloadButton:initialise()
    self.reloadButton:setActive(true)
    self.reloadButton:setAnchorTop(false)
    self.reloadButton:setAnchorBottom(true)
    self:addChild(self.reloadButton)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Helpers
-- ----------------------------------------------------------------------------------------------------- --

function NR_CheckZonePanel:updateAnimals()
    local FONT_HGT_NEW_SMALL = getTextManager():getFontHeight(UIFont.NewSmall)
    local btnHgt  = math.max(25, FONT_HGT_NEW_SMALL + 3 * 2)
    local infoIcon = getTexture("media/ui/NeatRocco/ICON/Icon_Info.png")
    local z = 1

    local buttonForAnimal = {}
    for _, v in ipairs(self.animalbuttons) do
        v:setVisible(false)
        self.animalPanel:removeChild(v)
        buttonForAnimal[v.animal] = v
    end
    local labelForAnimal = {}
    for _, v in ipairs(self.animalLabels) do
        v:setVisible(false)
        self.animalPanel:removeChild(v)
        labelForAnimal[v.animal] = v
    end

    local animalListSorted = {}
    local animals  = self.zone:getAnimalsConnected()
    local corpses  = self.zone:getCorpsesConnected()
    local hutches  = self.zone:getHutchsConnected()
    for i = 1, hutches:size() do
        animals:addAll(hutches:get(i-1):getAnimalInside():values())
    end
    for i = 1, animals:size() do
        table.insert(animalListSorted, animals:get(i-1))
    end
    table.sort(animalListSorted, function(a, b) return not string.sort(a:getFullName(), b:getFullName()) end)

    local corpsesListSorted = {}
    for i = 1, corpses:size() do
        table.insert(corpsesListSorted, corpses:get(i-1))
    end
    table.sort(corpsesListSorted, function(a, b) return not string.sort(a:getCustomName(), b:getCustomName()) end)

    self.animalbuttons = {}
    self.animalLabels  = {}
    local maxwidth = 0

    for _, v in ipairs(animalListSorted) do
        local btn = buttonForAnimal[v]
        if btn and btn.isNRSquareButton then
            btn:setY(z + self.itemPadY)
        else
            if btn then self.animalPanel:removeChild(btn) end
            local animal = v
            btn = NI_SquareButton:new(0, z + self.itemPadY, btnHgt, infoIcon, self,
                function()
                    if AnimalContextMenu.cheat then
                        AnimalContextMenu.onAnimalInfo(animal, self.player)
                    else
                        ISDesignationZoneAnimalZoneUI.onClick(self, {internal = "INFO", animal = animal})
                    end
                end)
            btn:initialise()
            btn:setActive(true)
            btn.isNRSquareButton = true
            btn.animal = v
        end
        btn:setVisible(getJoypadData(self.playerNum) == nil)
        self.animalPanel:addChild(btn)
        table.insert(self.animalbuttons, btn)

        local txt   = v:getFullName()
        local label = labelForAnimal[v]
        if label then
            label:setY(z + self.itemPadY)
            label:setName(txt)
            label:setVisible(true)
        else
            label = ISLabel:new(10, z + self.itemPadY, btnHgt, txt, 1, 1, 1, 1, UIFont.Small, true)
            label.animal = v
        end
        self.animalPanel:addChild(label)
        table.insert(self.animalLabels, label)
        local w = getTextManager():MeasureStringX(UIFont.Small, txt) + 30
        if w > maxwidth then maxwidth = w end
        z = z + self.itemHgt
    end

    -- Corpses: hidden buttons kept for joypad positioning (vanilla pattern)
    local badColor = getCore():getBadHighlitedColor()
    for _, v in ipairs(corpsesListSorted) do
        local btn = buttonForAnimal[v]
        if btn then
            btn:setY(z + self.itemPadY)
        else
            btn = ISButton:new(0, z + self.itemPadY, 100, btnHgt, getText("IGUI_Animal_Info"), self, ISDesignationZoneAnimalZoneUI.onClick)
            btn.internal = "INFO"
            btn.animal = v
            btn:initialise()
            btn:instantiate()
            btn.borderColor = {r=1, g=1, b=1, a=0.1}
        end
        btn:setVisible(false)
        self.animalPanel:addChild(btn)
        table.insert(self.animalbuttons, btn)

        local txt   = v:getCustomName()
        local label = labelForAnimal[v]
        if label then
            label:setY(z + self.itemPadY)
            label:setName(txt)
            label:setVisible(true)
        else
            label = ISLabel:new(10, z + self.itemPadY, btnHgt, txt, badColor:getR(), badColor:getG(), badColor:getB(), 1, UIFont.Small, true)
            label.animal = v
        end
        self.animalPanel:addChild(label)
        table.insert(self.animalLabels, label)
        local w = getTextManager():MeasureStringX(UIFont.Small, txt) + 30
        if w > maxwidth then maxwidth = w end
        z = z + self.itemHgt
    end

    for _, v in ipairs(self.animalbuttons) do
        v:setX(maxwidth)
    end

    self.animalPanel:setScrollHeight(z)

    local joypadData = getJoypadData(self.playerNum)
    if self.listTakesFocus and joypadData then
        self:clearJoypadFocus(joypadData)
        self.joypadIndexY = 1
        self.joypadIndex  = 1
        self.joypadButtonsY = {}
        self.joypadButtons  = {}
        self:insertNewLineOfButtons(self.animalPanel)
        self:insertNewLineOfButtons(self.infoBtn, self.reloadBtn, self.ok)
        self:restoreJoypadFocus(joypadData)
    end

    return self.animalPanel:getBottom()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_CheckZonePanel:prerender()
    if not self:checkExist() then
        self:close()
        return
    end

    local hh   = NR_Config.headerHeight
    local pad  = NR_Config.padding
    local fntS = getTextManager():getFontHeight(UIFont.NewSmall)
    local x    = pad

    NR_DrawUtils.prerenderPanelBody(self, hh)

    local z = hh + pad
    local nbOfAnimals = self.zone:getAnimalsConnected():size()
    local hutches = self.zone:getHutchsConnected()
    for i = 1, hutches:size() do
        nbOfAnimals = nbOfAnimals + hutches:get(i-1):getAnimalInside():size()
    end
    self:drawText(getText("IGUI_DesignationZone_Animals") .. nbOfAnimals, x, z, 1, 1, 1, 1, UIFont.NewSmall)

    if self.nbOfAnimals ~= nbOfAnimals then
        self:updateAnimals()
        self.nbOfAnimals = nbOfAnimals
    end

    local nbOfCorpses = self.zone:getCorpsesConnected():size()
    if self.nbOfCorpses ~= nbOfCorpses then
        self:updateAnimals()
        self.nbOfCorpses = nbOfCorpses
    end
    local xC = getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_DesignationZone_Animals") .. nbOfAnimals) + 60
    self:drawText(getText("IGUI_DesignationZone_Corpses") .. nbOfCorpses, xC, z, 1, 1, 1, 1, UIFont.Small)

    -- Auto-refresh every 1000 ms
    self.updateTick = self.updateTick - UIManager.getMillisSinceLastRender()
    if self.updateTick <= 0 then
        self.updateTick = 1000
        self:updateAnimals()
        self:reload()
    end

    z = self.showZoneTickBox:getBottom() + pad

    self:drawText(getText("IGUI_FeedingTroughUI_Enclosure") .. self.zone:getFullZoneSize(), x, z, 1, 1, 1, 1, UIFont.NewSmall)
    z = z + fntS + 5

    self:drawText(getText("IGUI_DesignationZone_FeedingTroughs") .. self.zone:getTroughsConnected():size(), x, z, 1, 1, 1, 1, UIFont.NewSmall)
    z = z + fntS + 5

    self:drawText(getText("IGUI_DesignationZone_Hutchs") .. hutches:size(), x, z, 1, 1, 1, 1, UIFont.NewSmall)
    z = z + fntS + 5

    self:drawText(getText("IGUI_DesignationZone_Food") .. self:calcFood(), x, z, 1, 1, 1, 1, UIFont.NewSmall)
    z = z + fntS + 5

    self:drawText(getText("IGUI_DesignationZone_Water") .. self:calcWater() .. " mL", x, z, 1, 1, 1, 1, UIFont.NewSmall)
    z = z + fntS + 5

    self:drawText(getText("IGUI_DesignationZone_NearRiver") .. self:calcNearRiver(), x, z, 1, 1, 1, 1, UIFont.NewSmall)
    z = z + fntS + 5

    self:drawText(getText("IGUI_DesignationZone_RoofArea") .. self.zone:getRoofAreasConnected():size(), x, z, 1, 1, 1, 1, UIFont.NewSmall)
    z = z + fntS + 5

    self:setHeight(z + NR_Config.buttonSize + pad * 2)

    self.animalInfoBtn:setEnable(#self.animalbuttons > 0)
    self.animalInfoBtn:setVisible(getJoypadData(self.playerNum) ~= nil)
end

-- (close() héritée de ISDesignationZoneAnimalZoneUI)
