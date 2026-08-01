-- NR_GeneratorPanel.lua
-- NeatUI replacement panel for ISGeneratorInfoWindow.
-- Displays fuel, condition, power consumption list, and toxicity warning.

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Config"
require "NeatRocco/NR_Generator/NR_PowerRange"

NR_GeneratorPanel = NR_BasePanel:derive("NR_GeneratorPanel")
NR_GeneratorPanel.panels = {}  -- keyed by character


-- ----------------------------------------------------------------------------------------------------- --
-- Helpers
-- ----------------------------------------------------------------------------------------------------- --

-- Formate un nombre d'heures en "(X jours, Y heures)"
local function formatTimeLeft(hoursLeft)
    local hours = math.floor(hoursLeft)
    local days  = math.floor(hours / 24)
    if days >= 1 then hours = hours % 24 end

    if days > 1 then
        if hours > 1 then
            return string.format("(%d %s, %d %s)", days, getText("IGUI_NR_Days"),  hours, getText("IGUI_NR_Hours"))
        elseif hours == 1 then
            return string.format("(%d %s, %d %s)", days, getText("IGUI_NR_Days"),  hours, getText("IGUI_NR_Hour"))
        else
            return string.format("(%d %s)", days, getText("IGUI_NR_Days"))
        end
    elseif days == 1 then
        if hours > 1 then
            return string.format("(%d %s, %d %s)", days, getText("IGUI_NR_Day"),   hours, getText("IGUI_NR_Hours"))
        elseif hours == 1 then
            return string.format("(%d %s, %d %s)", days, getText("IGUI_NR_Day"),   hours, getText("IGUI_NR_Hour"))
        else
            return string.format("(%d %s)", days, getText("IGUI_NR_Day"))
        end
    else
        if hours > 1 then
            return string.format("(%d %s)", hours, getText("IGUI_NR_Hours"))
        elseif hours == 1 then
            return string.format("(%d %s)", hours, getText("IGUI_NR_Hour"))
        else
            return string.format("(%d %s)", math.floor(hoursLeft * 60), getText("IGUI_NR_Minutes"))
        end
    end
end

-- Convertit des heures in-game en heures réelles selon la durée du jour sandbox
local function toRealTime(hoursDec)
    if not NR_Config.convertToRT then return hoursDec end
    local sb = getSandboxOptions()
    if not sb then return hoursDec end
    local dayLength = sb:getDayLengthMinutes()
    if dayLength == 1440 then return hoursDec end
    return hoursDec / 24 * dayLength / 60
end

-- Calcule litres restants et heures restantes (en temps réel) depuis l'objet générateur
function NR_GeneratorPanel:calcFuelTime(object, fuel, active)
    if not active or fuel <= 0 then return nil, nil end
    local totalStr = object:getTotalPowerUsingString() or ""
    local lph = tonumber(totalStr:match("([%d%.]+)%s*[Ll]/%s*[Hh]"))
    if not lph or lph <= 0 then return nil, nil end
    local liters = object.getFuelAmount and object:getFuelAmount()
    if type(liters) ~= "number" then liters = (fuel / 100.0) * 10.0 end
    return liters, toRealTime(liters / lph)
end

-- Dessine le tooltip hover sur la barre carburant
function NR_GeneratorPanel:drawFuelTooltip(barX, barY, barW, barH, fuel, liters, hoursLeft)
    local mx, my = self:getMouseX(), self:getMouseY()
    if mx < barX or mx > barX + barW or my < barY or my > barY + barH then return end
    local pad = NR_Config.padding
    local tip = getText("IGUI_NR_FuelTooltip", fuel, string.format("%.1f", liters), string.format("%.1f", hoursLeft))
    local tw  = getTextManager():MeasureStringX(UIFont.Small, tip) + 10
    local tx  = math.min(mx + 20, self.width - tw - pad)
    NR_DrawUtils.drawTooltip(self, tip, tx, my + 20)
end

-- Met à jour la hauteur et la largeur dynamiques du panel
function NR_GeneratorPanel:updateDynamicSize(active, items, itemCount, indoor, object)
    local pad = NR_Config.padding
    local hh  = NR_Config.headerHeight
    local lh  = NR_Config.lineHeight

    local requiredH = hh + pad + lh + lh  -- header + fuel + condition
    if active then
        requiredH = requiredH + lh + itemCount * lh + lh + lh
    end
    if indoor then
        requiredH = requiredH + pad + lh
    end
    self:setHeight(requiredH + pad)

    if active then
        local minW = self.width
        local tm   = getTextManager()
        for i = 0, itemCount - 1 do
            minW = math.max(minW, pad + 4 + tm:MeasureStringX(UIFont.Small, "  " .. items:get(i)) + pad)
        end
        local baseLine = getText("IGUI_Generator_TypeGas") .. " (" .. object:getBasePowerConsumptionString() .. ")"
        minW = math.max(minW, pad + 4 + tm:MeasureStringX(UIFont.Small, "  " .. baseLine) + pad)
        if minW > self.width then
            self:setWidth(minW)
            self.header:setWidth(minW)
            self.header:calculateLayout(minW, hh)
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_GeneratorPanel:new(x, y, character, object)
    local width  = 320 + 30 * getCore():getOptionFontSizeReal()
    local height = NR_Config.headerHeight + NR_Config.padding * 4

    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.character      = character
    o.playerNum      = character:getPlayerNum()
    o.object         = object
    o.hasPowerButton = true

    NR_BasePanel.initBase(o)

    NR_GeneratorPanel.panels[character] = o
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_GeneratorPanel:getWindowTitle()
    return getText("IGUI_Generator_TypeGas")
end

function NR_GeneratorPanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Generator.png")
end

function NR_GeneratorPanel:setObject(object)
    self.object = object
end

function NR_GeneratorPanel:getHeaderPowerState()
    local obj = self.object
    if not obj then return "off" end
    return obj:isActivated() and "on" or "off"
end

function NR_GeneratorPanel:onClickPower()
    local gen  = self.object
    local char = self.character
    if not gen or not char then return end
    local activate = not gen:isActivated()
    if luautils.walkAdj(char, gen:getSquare()) then
        ISTimedActionQueue.add(ISActivateGenerator:new(char, gen, activate))
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_GeneratorPanel:createChildren()
    NR_BasePanel.createChildren(self)
    NR_PowerRange.start(self.object)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_GeneratorPanel:render()
    local object = self.object
    if not object or object:getObjectIndex() == -1 then
        self:close()
        return
    end
    ISPanelJoypad.render(self)
    NR_PowerRange.update()

    local pad  = NR_Config.padding
    local lh   = NR_Config.lineHeight
    local barH = NR_Config.barHeight

    -- Live data
    local fuel      = math.ceil(object:getFuelPercentage())
    local cond      = object:getCondition()
    local active    = object:isActivated()
    local square    = object:getSquare()
    local indoor    = square and not square:isOutside() and square:getBuilding()
    local items     = active and object:getItemsPowered() or nil
    local itemCount = items and items:size() or 0

    self:updateDynamicSize(active, items, itemCount, indoor, object)

    local curY    = NR_Config.headerHeight + pad
    local iconSize = lh * 2
    local textX    = pad + iconSize + pad

    -- ── Icône générateur ──
    local iconTex = getTexture(object:getTextureName())
    if iconTex then
        self:drawTextureScaled(iconTex, pad, curY, iconSize, iconSize, 1, 1, 1, 1)
    end

    -- ── Barre carburant ──
    local fuelLabel = getText("IGUI_NR_FuelLabel")
    local labelW    = getTextManager():MeasureStringX(UIFont.Small, fuelLabel)
    self:drawText(fuelLabel, textX, curY, 1, 1, 1, 1, UIFont.Small)

    local barX = textX + labelW + pad
    local barY = curY + math.floor((lh - barH) / 2)

    local liters, hoursLeft = self:calcFuelTime(object, fuel, active)
    local timeText  = hoursLeft and formatTimeLeft(hoursLeft)
    local barLabel  = timeText and (fuel .. "% " .. timeText) or (fuel .. "%")
    local barLabelW = getTextManager():MeasureStringX(UIFont.Small, barLabel)

    -- Élargir si le texte dans la barre dépasse la largeur actuelle
    local minW = barX + barLabelW + pad * 3
    if minW > self.width then
        self:setWidth(minW)
        self.header:setWidth(minW)
        self.header:calculateLayout(minW, NR_Config.headerHeight)
    end

    local barW = self.width - barX - pad
    local fr, fg, fb = self:getBarColor(fuel / 100)
    self:drawBarWithLabel(barX, barY, barW, barH, fuel / 100, barLabel, fr, fg, fb)

    curY = curY + lh

    -- ── Barre condition ──
    local condLabel  = getText("IGUI_NR_ConditionLabel")
    local condLabelW = getTextManager():MeasureStringX(UIFont.Small, condLabel)
    self:drawText(condLabel, textX, curY, 1, 1, 1, 1, UIFont.Small)

    local condBarX = textX + condLabelW + pad
    local condBarW = self.width - condBarX - pad
    local condBarY = curY + math.floor((lh - barH) / 2)

    local cr, cg, cb = self:getBarColor(cond / 100)
    self:drawBarWithLabel(condBarX, condBarY, condBarW, barH, cond / 100, cond .. "%", cr, cg, cb)

    curY = curY + lh

    -- ── Consommation ──
    if active then
        self:drawText(getText("IGUI_PowerConsumption") .. ":", pad, curY, 1, 1, 1, 0.7, UIFont.Small)
        curY = curY + lh

        for i = 0, itemCount - 1 do
            self:drawText("  " .. items:get(i), pad + 4, curY, 1, 1, 1, 0.85, UIFont.Small)
            curY = curY + lh
        end

        local baseLine = getText("IGUI_Generator_TypeGas") .. " (" .. object:getBasePowerConsumptionString() .. ")"
        self:drawText("  " .. baseLine, pad + 4, curY, 1, 1, 1, 0.85, UIFont.Small)
        curY = curY + lh

        self:drawText(getText("IGUI_Total") .. ": " .. object:getTotalPowerUsingString(), pad, curY, 1, 1, 1, 1, UIFont.Small)
        curY = curY + lh
    end

    -- ── Avertissement toxique ──
    if indoor then
        self:drawRect(pad, curY, self.width - pad * 2, 1, 0.7, 0.7, 0.2, 0.2)
        curY = curY + pad
        self:drawText(getText("IGUI_Generator_IsToxic"), pad, curY, 0.9, 0.25, 0.2, 1, UIFont.Small)
    end

    -- ── Tooltip hover carburant ──
    if liters and hoursLeft then
        self:drawFuelTooltip(barX, barY, barW, barH, fuel, liters, hoursLeft)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_GeneratorPanel:close()
    NR_GeneratorPanel.panels[self.character] = nil
    NR_PowerRange.stop()
    self:closeBase()
end

-- (onGainJoypadFocus, onLoseJoypadFocus, onJoypadDown, isKeyConsumed, onKeyRelease héritées de NR_BasePanel)
