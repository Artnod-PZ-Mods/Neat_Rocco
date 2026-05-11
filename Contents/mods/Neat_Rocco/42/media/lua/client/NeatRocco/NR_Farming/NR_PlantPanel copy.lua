-- NR_PlantPanel.lua
-- NeatUI replacement panel for ISFarmingWindow / ISFarmingInfo.
-- Displays plant status: growth phase, health, compost, diseases, water level.
-- Vanilla source: Farming/ISUI/ISFarmingWindow.lua + Farming/ISUI/ISFarmingInfo.lua

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Utils/NR_CollapseUtils"
require "NeatRocco/NR_Config"

NR_PlantPanel = NR_BasePanel:derive("NR_PlantPanel")
NR_PlantPanel.panels = {}  -- keyed by character

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

-- ----------------------------------------------------------------------------------------------------- --
-- Color helpers
-- ----------------------------------------------------------------------------------------------------- --

local function goodColor()
    local c = getCore():getGoodHighlitedColor()
    return c:getR(), c:getG(), c:getB()
end

local function badColor()
    local c = getCore():getBadHighlitedColor()
    return c:getR(), c:getG(), c:getB()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Data helpers (logic ported from ISFarmingInfo — preserved 1:1)
-- ----------------------------------------------------------------------------------------------------- --

local function getGrowingPhaseText(plant, farmingLevel, cheat)
    if not plant:isAlive() then return getText("UI_FriendState_Unknown") end
    if cheat then
        local prop = farming_vegetableconf.props[plant.typeOfSeed]
        return farming_vegetableconf.getObjectPhase(plant)
            .. " " .. plant.nbOfGrow
            .. " / " .. (prop.fullGrown + 1)
    elseif farmingLevel >= 2 then
        return farming_vegetableconf.getObjectPhase(plant)
    end
    return getText("UI_FriendState_Unknown")
end

local function getNextPhaseText(plant, farmingLevel, cheat)
    if not plant:isAlive() then return getText("UI_No") end
    if cheat then
        local hoursLeft = plant.nextGrowing - CFarmingSystem.instance.hoursElapsed
        if hoursLeft <= 0 then return "0 " .. getText("Farming_Hours") end
        local h = round2(hoursLeft)
        if h <= 24 then
            return h .. " " .. (h == 1 and getText("Farming_Hour") or getText("Farming_Hours"))
        else
            local d = round2(h / 24)
            return d .. " " .. (d == 1 and getText("Farming_Day") or getText("Farming_Days"))
        end
    elseif farmingLevel >= 6 then
        local h = round2(plant.nextGrowing - CFarmingSystem.instance.hoursElapsed)
        if h <= 24 then return getText("Farming_Hours") end
        local d = math.floor(h / 24)
        if d <= 7  then return getText("Farming_Days") end
        if d <= 28 then return getText("Farming_Weeks") end
        return getText("Farming_Months")
    end
    return getText("UI_FriendState_Unknown")
end

local function getHealthTextAndColor(plant, cheat)
    if not plant:isAlive() then
        local r, g, b = badColor()
        return getText("Farming_Dead"), r, g, b
    end
    local h      = plant.health
    local suffix = cheat and (" (" .. round2(h, 2) .. ")") or ""
    local gr, gg, gb = goodColor()
    local br, bg, bb = badColor()
    if h > 80  then return getText("Farming_Flourishing") .. suffix, gr, gg, gb
    elseif h > 60  then return getText("Farming_Verdant")     .. suffix, gr, gg, gb
    elseif h >= 50 then return getText("Farming_Healthy")     .. suffix, gr, gg, gb
    elseif h >= 25 then return getText("Farming_Sickly")      .. suffix, 1.0, 0.5, 0.0
    else               return getText("Farming_Dying")         .. suffix, br, bg, bb
    end
end

-- Water text + color — logic from ISFarmingInfo.getWaterLvl + getWaterLvlColor (preserved 1:1)
local function getWaterTextAndColor(plant, farmingLevel, cheat)
    local w      = plant.waterLvl
    local suffix = cheat and (" (" .. round2(w, 2) .. ")") or ""
    local text
    if     w > 80 then text = getText("Farming_Well_watered") .. suffix
    elseif w > 60 then text = getText("Farming_Fine")         .. suffix
    elseif w > 50 then text = getText("Farming_Thirsty")      .. suffix
    elseif w > 25 then text = getText("Farming_Dry")          .. suffix
    else               text = getText("Farming_Parched")       .. suffix
    end

    if (farmingLevel >= 3 or cheat) and plant:isAlive() then
        local gr, gg, gb = goodColor()
        local br, bg, bb = badColor()
        if plant.nbOfGrow == 1 then
            if plant.waterLvl < plant.waterNeeded then return text, br, bg, bb end
            return text, gr, gg, gb
        else
            local water    = farming_vegetableconf.calcWater(plant.waterNeeded, plant.waterLvl)
            local waterMax = farming_vegetableconf.calcWater(plant.waterLvl, plant.waterNeededMax)
            if water >= 0 and waterMax >= 0 then return text, gr, gg, gb end
            if water == -1 or waterMax == -1 then return text, 1.0, 0.5, 0.0 end
            return text, br, bg, bb
        end
    end
    return text, 1, 1, 1
end

-- Water bar color — from ISFarmingInfo.getWaterLvlBarColor (preserved 1:1)
local function getWaterBarColor(plant)
    if plant.nbOfGrow == 1 then
        if plant.waterLvl < plant.waterNeeded then return 0.70, 0.13, 0.13 end
        return 0.15, 0.3, 0.63
    end
    local water    = farming_vegetableconf.calcWater(plant.waterNeeded, plant.waterLvl)
    local waterMax = farming_vegetableconf.calcWater(plant.waterLvl, plant.waterNeededMax)
    if water >= 0 and waterMax >= 0 then return 0.15, 0.3, 0.63 end
    if water == -1 or waterMax == -1 then return 0.98, 0.55, 0.0 end
    return 0.70, 0.13, 0.13
end

-- Disease severity text — from ISFarmingInfo.getDiseaseString (preserved 1:1)
local function getDiseaseText(lvl, cheat)
    local s
    if     lvl < 10 then s = getText("Farming_Light")
    elseif lvl < 30 then s = getText("Farming_Moderate")
    else                  s = getText("Farming_Heavy")
    end
    if cheat then s = s .. " (" .. tostring(lvl) .. ")" end
    return s
end

-- Largeur de la colonne label (= pivot de right-align, même pattern que NR_FeedingTroughPanel)
local function computeKeyW()
    local tm  = getTextManager()
    local labels = {
        getText("Farming_Current_growing_phase"),
        getText("Farming_Next_growing_phase")   ,
        "hoursElapsed",
        getText("Farming_Fertilized")           ,
        getText("Farming_Compost")              ,
        getText("Farming_Health")               ,
        getText("Farming_Disease")              ,
        getText("Farming_Aphid")                ,
        getText("Farming_Mildew")               ,
        getText("Farming_Pest_Flies")           ,
        getText("Farming_Slugs")                ,
        getText("Farming_Water_levels")         ,
    }
    local maxW = 0
    for _, l in ipairs(labels) do
        maxW = math.max(maxW, tm:MeasureStringX(UIFont.Small, l))
    end
    return maxW
end

-- Largeur de la colonne valeur (worst case, toutes les valeurs possibles)
local function computeValueW()
    local tm = getTextManager()
    local values = {
        getText("Farming_Flourishing"),
        getText("Farming_Verdant"),
        getText("Farming_Healthy"),
        getText("Farming_Sickly"),
        getText("Farming_Dying"),
        getText("Farming_Dead"),
        getText("Farming_Well_watered"),
        getText("Farming_Fine"),
        getText("Farming_Thirsty"),
        getText("Farming_Dry"),
        getText("Farming_Parched"),
        getText("Farming_Compost_True"),
        getText("Farming_Compost_False"),
        getText("Farming_Fertilizer_TooMuch"),
        getText("Farming_Light"),
        getText("Farming_Moderate"),
        getText("Farming_Heavy"),
    }
    local maxW = 0
    for _, v in ipairs(values) do
        maxW = math.max(maxW, tm:MeasureStringX(UIFont.Small, v))
    end
    return maxW
end

local VALUE_GAP = 10  -- espace entre pivot et valeur (même que NR_FeedingTroughPanel)

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:new(x, y, character, plant)
    local pad    = NR_Config.padding
    local keyW   = computeKeyW()
    local width  = pad + keyW + VALUE_GAP + computeValueW() + pad
    local height = NR_Config.headerHeight + NR_Config.padding * 4

    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.character    = character
    o.playerNum    = character:getPlayerNum()
    o.plant        = plant
    o.vegetable    = getTexture(farming_vegetableconf.props[plant.typeOfSeed].icon)
    o._keyW        = keyW
    NR_CollapseUtils.init(o)

    NR_BasePanel.initBase(o)

    NR_PlantPanel.panels[character] = o
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:getWindowTitle()
    if self.plant then
        return getText("Farming_" .. self.plant.typeOfSeed)
    end
    return getText("Farming_Plant_Information")
end

function NR_PlantPanel:getWindowIcon()
    return self.vegetable
end

function NR_PlantPanel:setPlant(plant)
    self.plant     = plant
    self.vegetable = getTexture(farming_vegetableconf.props[plant.typeOfSeed].icon)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Dynamic width (expands panel to fit actual content)
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:updateDynamicWidth(farmingLevel, cheat)
    local tm  = getTextManager()
    local pad = NR_Config.padding
    local hh  = NR_Config.headerHeight

    local xPivot = pad + self._keyW
    local function rowMinW(value)
        return xPivot + VALUE_GAP + tm:MeasureStringX(UIFont.Small, value) + pad
    end

    local minW = 0

    -- Header (icône + titre + bouton close)
    local iconSize = math.floor((hh * 0.8) / 4) * 4
    minW = math.max(minW,
        iconSize + pad * 2
        + tm:MeasureStringX(UIFont.Medium, self:getWindowTitle()) + pad * 2
        + NR_Config.buttonSize + pad
    )

    local isAlive = self.plant:isAlive()

    -- Phase de croissance actuelle
    if cheat or farmingLevel >= 2 then
        minW = math.max(minW, rowMinW(getGrowingPhaseText(self.plant, farmingLevel, cheat)))
    end

    -- Prochaine phase
    if (cheat or farmingLevel >= 6) and isAlive then
        minW = math.max(minW, rowMinW(getNextPhaseText(self.plant, farmingLevel, cheat)))
    end

    -- hoursElapsed (debug + cheat)
    if isDebugEnabled() and cheat then
        minW = math.max(minW, rowMinW(tostring(CFarmingSystem.instance.hoursElapsed)))
    end

    -- Fertilisé (cheat)
    if cheat then
        local fertText
        if self.plant.fertilizer == 1 then
            fertText = getText("Farming_Compost_True")
        elseif self.plant.fertilizer > 1 then
            fertText = getText("Farming_Fertilizer_TooMuch")
        else
            fertText = getText("Farming_Compost_False")
        end
        minW = math.max(minW, rowMinW(fertText))
    end

    -- Compost (toujours visible)
    local compostText = self.plant.compost and getText("Farming_Compost_True") or getText("Farming_Compost_False")
    minW = math.max(minW, rowMinW(compostText))

    -- Santé (cheat) — inclut le suffixe "(xx.x)"
    if cheat then
        local ht = getHealthTextAndColor(self.plant, cheat)
        minW = math.max(minW, rowMinW(ht))
    end

    -- Maladies (cheat ou farmingLevel >= 3) — inclut le suffixe "(xx)" en cheat
    if farmingLevel >= 3 or cheat then
        for _, lvl in ipairs({ self.plant.aphidLvl, self.plant.mildewLvl,
                                self.plant.fliesLvl, self.plant.slugsLvl }) do
            if lvl > 0 then
                minW = math.max(minW, rowMinW(getDiseaseText(lvl, cheat)))
            end
        end
    end

    -- Niveau d'eau (plante vivante) — inclut le suffixe "(xx)" en cheat
    if isAlive then
        local waterText = getWaterTextAndColor(self.plant, farmingLevel, cheat)
        minW = math.max(minW, rowMinW(waterText))
    end

    if minW ~= self.width then
        self:setWidth(minW)
        self.header:setWidth(minW)
        self.header:calculateLayout(minW, hh)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Plant validity (from ISFarmingInfo:isPlantValid)
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:isPlantValid()
    self.plant:updateFromIsoObject()
    return self.plant ~= nil and self.plant:getIsoObject() ~= nil
end

-- ----------------------------------------------------------------------------------------------------- --
-- Background + network update
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:prerender()
    if not self:isPlantValid() then return end

    -- Network sync (from ISFarmingInfo:prerender)
    if isClient() then
        local object = self.plant:getObject()
        if object then
            self.plant:fromModData(object:getModData())
        end
    end

    if not NR_CollapseUtils.isBodyVisible(self) then return end

    local cheat        = ISFarmingMenu.cheat
    local farmingLevel = CFarmingSystem.instance:getXp(self.character)
    self:updateDynamicWidth(farmingLevel, cheat)

    NR_BasePanel.prerender(self)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:render()
    if not self:isPlantValid() then return end
    if not NR_CollapseUtils.isBodyVisible(self) then return end
    ISPanelJoypad.render(self)

    local cheat        = ISFarmingMenu.cheat
    local farmingLevel = CFarmingSystem.instance:getXp(self.character)

    local hasMagnifier = false
    if     self.character:getPrimaryHandItem()   and self.character:getPrimaryHandItem():hasTag(ItemTag.MAGNIFIER)   then hasMagnifier = true
    elseif self.character:getSecondaryHandItem() and self.character:getSecondaryHandItem():hasTag(ItemTag.MAGNIFIER) then hasMagnifier = true
    end
    local magnifierFactor = hasMagnifier and 2 or 0

    local pad  = NR_Config.padding
    local lh   = NR_Config.lineHeight
    local hh   = NR_Config.headerHeight
    local curY = hh + pad

    -- ── Layout pivot (même pattern que NR_FeedingTroughPanel) ───────────────────────────────── --
    local xPivot   = pad + self._keyW          -- labels right-alignés ici
    local valueX   = xPivot + VALUE_GAP        -- valeurs left-alignées ici
    local textOffY = math.floor((lh - FONT_HGT_SMALL) / 2)
    local isAlive  = self.plant:isAlive()

    local function drawRow(label, value, vr, vg, vb)
        self:drawLabelValue(label, value, xPivot, valueX, curY + textOffY, 1.0, vr, vg, vb)
        curY = curY + lh
    end

    -- Current growing phase (farmingLevel >= 2 or cheat)
    if cheat or farmingLevel >= 2 then
        drawRow(getText("Farming_Current_growing_phase"),
            getGrowingPhaseText(self.plant, farmingLevel, cheat), 0.5, 0.5, 0.5)
    end

    -- Next growing phase (farmingLevel >= 6 or cheat, plant alive only)
    if (cheat or farmingLevel >= 6) and isAlive then
        drawRow(getText("Farming_Next_growing_phase"),
            getNextPhaseText(self.plant, farmingLevel, cheat), 0.5, 0.5, 0.5)
    end

    -- hoursElapsed (debug + cheat only)
    if isDebugEnabled() and cheat then
        drawRow("hoursElapsed", tostring(CFarmingSystem.instance.hoursElapsed), 0.5, 0.5, 0.8)
    end

    -- Fertilized (cheat only)
    if cheat then
        local fertText = getText("Farming_Compost_False")
        local fr, fg, fb = 0.5, 0.5, 0.5
        if self.plant.fertilizer == 1 then
            fertText = getText("Farming_Compost_True")
            fr, fg, fb = goodColor()
        elseif self.plant.fertilizer > 1 then
            fertText = getText("Farming_Fertilizer_TooMuch")
            fr, fg, fb = badColor()
        end
        drawRow(getText("Farming_Fertilized"), fertText, fr, fg, fb)
    end

    -- Compost (always visible)
    if self.plant.compost then
        drawRow(getText("Farming_Compost"), getText("Farming_Compost_True"), goodColor())
    else
        drawRow(getText("Farming_Compost"), getText("Farming_Compost_False"), 0.5, 0.5, 0.5)
    end

    -- Health (cheat only)
    if cheat then
        local ht, hr, hg, hb = getHealthTextAndColor(self.plant, cheat)
        drawRow(getText("Farming_Health"), ht, hr, hg, hb)
    end

    -- Disease (farmingLevel + magnifier >= 3, or cheat)
    local hasDisease = self.plant.aphidLvl > 0 or self.plant.mildewLvl > 0
                    or self.plant.fliesLvl > 0  or self.plant.slugsLvl > 0
    if (farmingLevel + magnifierFactor >= 3 or cheat) and hasDisease then
        local br, bg, bb = badColor()
        local diseaseRows = {
            { lvl = self.plant.aphidLvl,  key = "Farming_Aphid"     },
            { lvl = self.plant.mildewLvl, key = "Farming_Mildew"    },
            { lvl = self.plant.fliesLvl,  key = "Farming_Pest_Flies"},
            { lvl = self.plant.slugsLvl,  key = "Farming_Slugs"     },
        }
        for _, d in ipairs(diseaseRows) do
            if d.lvl > 0 then
                drawRow(getText(d.key), getDiseaseText(d.lvl, cheat), br, bg, bb)
            end
        end
    end

    -- ── Water level ─────────────────────────────────────────────────────────────────────────── --
    if isAlive then
        local waterText, wr, wg, wb = getWaterTextAndColor(self.plant, farmingLevel, cheat)
        drawRow(getText("Farming_Water_levels"), waterText, wr, wg, wb)

        -- Water bar (farmingLevel >= 4 — vanilla behavior)
        if farmingLevel >= 4 then
            local barH    = NR_Config.barHeight
            local barX    = pad
            local barW    = self.width - pad * 2
            local pct     = self.plant.waterLvl / 100
            local r, g, b = getWaterBarColor(self.plant)
            self:drawBar(barX, curY, barW, barH, pct, r, g, b)
            curY = curY + barH + math.floor(pad / 2)
        end
    end

    -- Dynamic height update
    self:setHeight(curY + pad)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Update (auto-close: invalid plant or player too far — from ISFarmingInfo:update)
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:update()
    -- Plant object removed (harvested, destroyed)
    if not self.plant:getObject() then
        self:close()
        return
    end

    ISPanelJoypad.update(self)

    if not self:isPlantValid() then
        self:close()
        return
    end

    -- Player moved too far (> 6 tiles)
    local sq = self.plant:getSquare()
    if sq and self.character:DistTo(sq:getX(), sq:getY()) > 6 then
        self:close()
    end

    NR_CollapseUtils.update(self)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Collapse / expand
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:onClickCollapse() NR_CollapseUtils.onClickCollapse(self) end
function NR_PlantPanel:_onHeaderHover()  NR_CollapseUtils.onHeaderHover(self)   end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:close()
    NR_PlantPanel.panels[self.character] = nil
    self:closeBase()
end

-- (onGainJoypadFocus, onLoseJoypadFocus, onJoypadDown, isKeyConsumed, onKeyRelease héritées de NR_BasePanel)
