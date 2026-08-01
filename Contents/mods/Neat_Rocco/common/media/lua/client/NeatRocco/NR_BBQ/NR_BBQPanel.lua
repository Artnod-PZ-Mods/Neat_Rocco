-- NR_BBQPanel.lua
-- NeatUI replacement for ISBBQInfoWindow (BBQ / campfire info).

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Config"

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

NR_BBQPanel = NR_BasePanel:derive("NR_BBQPanel")
NR_BBQPanel.panels = {}

local ICON_FIRE         = "media/ui/NeatRocco/ICON/Icon_Fire.png"
local ICON_FIRE_GREEN   = "media/ui/NeatRocco/ICON/Icon_Fire_Green.png"
local ICON_FIRE_RED     = "media/ui/NeatRocco/ICON/Icon_Fire_Red.png"
local ICON_REMOVE_TANK  = "media/ui/NeatRocco/ICON/Icon_RemoveTank.png"
local ICON_ADD_TANK     = "media/ui/NeatRocco/ICON/Icon_AddTank.png"
local ICON_ADD          = "media/ui/NeatRocco/ICON/Icon_Add.png"

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_BBQPanel:new(x, y, character, object)
    local width  = 280 + 30 * getCore():getOptionFontSizeReal()
    local height = NR_Config.headerHeight + NR_Config.padding * 4

    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.playerNum = character:getPlayerNum()
    o.object    = object

    NR_BasePanel.initBase(o)

    NR_BBQPanel.panels[character] = o
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_BBQPanel:getWindowTitle()
    return self.object and self.object:getTileName() or ""
end

function NR_BBQPanel:getWindowIcon()
    return getTexture(ICON_FIRE)
end

function NR_BBQPanel:setObject(object)
    self.object = object
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_BBQPanel:createChildren()
    NR_BasePanel.createChildren(self)

    local bsz = NR_Config.buttonSize

    local function makeBtn(icon, callback)
        local btn = NI_SquareButton:new(0, 0, bsz, icon, self, callback)
        btn:initialise()
        btn:setActive(true)
        btn:setVisible(false)
        self:addChild(btn)
        return btn
    end

    -- Unified fire button (3 states: light/extinguish/none)
    self.btnFire = makeBtn(getTexture(ICON_FIRE), function() self:onClickFire() end)
    self.btnFire:setActiveColor(1.0, 0.55, 0.1)

    -- Propane tank buttons
    self.btnRemoveTank = makeBtn(getTexture(ICON_REMOVE_TANK), function() self:onClickRemoveTank() end)
    self.btnAddTank    = makeBtn(getTexture(ICON_ADD_TANK),    function() self:onClickAddTank() end)

    -- Wood / campfire fuel button
    self.btnDestroyFuel = makeBtn(getTexture(ICON_ADD), function() self:onClickDestroyFuel() end)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Button actions
-- ----------------------------------------------------------------------------------------------------- --

function NR_BBQPanel:onClickFire()
    local obj = self.object
    if not obj then return end

    local isLit     = obj:isLit()
    local isPropane = obj:isPropaneBBQ()

    if isLit then
        -- Extinguish
        if luautils.walkAdj(self.character, obj:getSquare()) then
            if isPropane then
                ISTimedActionQueue.add(ISBBQToggle:new(self.character, obj))
            else
                ISTimedActionQueue.add(ISBBQExtinguish:new(self.character, obj))
            end
        end
    elseif isPropane then
        -- Light propane: requires fuel + tank
        if obj:hasFuel() and obj:hasPropaneTank() then
            if luautils.walkAdj(self.character, obj:getSquare()) then
                ISTimedActionQueue.add(ISBBQToggle:new(self.character, obj))
            end
        end
    else
        -- Light wood/campfire: requires fuel
        if obj:hasFuel() then
            local btn = self.btnFire
            local x   = btn:getAbsoluteX() + btn:getWidth()
            local y   = btn:getAbsoluteY()
            local fuelInfo = ISCampingMenu.getNearbyFuelInfo(self.character)
            local context  = ISContextMenu.get(self.playerNum, x, y)
            local campfire = CCampfireSystem.instance:getLuaObjectOnSquare(obj:getSquare())
            if campfire then
                local fuelAmt = campfire.fuelAmt or 0
                ISCampingMenu.doLightFireOption(self.character, context, nil, fuelAmt > 0, fuelInfo,
                    campfire, ISLightFromPetrol, ISLightFromLiterature, ISLightFromKindle)
            else
                ISCampingMenu.doLightFireOption(self.character, context, nil, obj:hasFuel(), fuelInfo,
                    obj, ISBBQLightFromPetrol, ISBBQLightFromLiterature, ISBBQLightFromKindle)
            end
        end
    end
end

function NR_BBQPanel:onClickRemoveTank()
    local obj = self.object
    if not obj then return end
    ISBBQMenu.onRemovePropaneTank(nil, self.playerNum, obj, nil)
end

function NR_BBQPanel:onClickAddTank()
    local obj  = self.object
    if not obj then return end
    local tank = ISBBQMenu.FindPropaneTank(self.character, obj)
    if tank then
        ISBBQMenu.onInsertPropaneTank(nil, self.playerNum, obj, tank)
    end
end

function NR_BBQPanel:onClickDestroyFuel()
    local obj = self.object
    if not obj then return end
    local btn  = self.btnDestroyFuel
    local x    = btn:getAbsoluteX() + btn:getWidth()
    local y    = btn:getAbsoluteY()
    local fuelInfo = ISCampingMenu.getNearbyFuelInfo(self.character)
    local context  = ISContextMenu.get(self.playerNum, x, y)
    ISCampingMenu.doAddFuelOption(context, nil, obj:getFuelAmount(), fuelInfo, obj, ISBBQAddFuel)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_BBQPanel:render()
    local object = self.object
    if not object or object:getObjectIndex() == -1 then
        self:close()
        return
    end
    ISPanelJoypad.render(self)

    local pad  = NR_Config.padding
    local lh   = NR_Config.lineHeight
    local hh   = NR_Config.headerHeight
    local bsz  = NR_Config.buttonSize

    local fuelAmount  = object:getFuelAmount()
    local isLit       = object:isLit()
    local isSmoul     = object:isSmouldering()
    local isPropane   = object:isPropaneBBQ()
    local needsProp   = isPropane and not object:hasPropaneTank()

    -- Fire button: 3 states
    local fireState
    if isLit then
        fireState = "extinguish"
    elseif isPropane then
        fireState = (object:hasFuel() and object:hasPropaneTank()) and "light" or "none"
    else
        fireState = object:hasFuel() and "light" or "none"
    end

    if fireState == "extinguish" then
        self.btnFire:setIcon(getTexture(ICON_FIRE_RED))
        self.btnFire:setActive(true)
    elseif fireState == "light" then
        self.btnFire:setIcon(getTexture(ICON_FIRE_GREEN))
        self.btnFire:setActive(true)
    else
        self.btnFire:setIcon(getTexture(ICON_FIRE))
        self.btnFire:setActive(false)
    end

    -- Which secondary buttons are visible
    local showRemoveTank  = isPropane and object:hasPropaneTank()
    local showAddTank     = isPropane and not object:hasPropaneTank()
                            and ISBBQMenu.FindPropaneTank(self.character, object) ~= nil
    local showDestroyFuel = not isPropane

    local iconSize = lh * 2
    local textX    = pad + iconSize + pad

    -- Hauteur réelle du sprite (largeur fixe = iconSize, hauteur proportionnelle)
    local iconTex = getTexture(object:getTextureName())
    local iconDH  = iconSize
    if iconTex then
        local tw, th = iconTex:getWidth(), iconTex:getHeight()
        iconDH = math.floor(th * (iconSize / tw))
    end

    -- Dynamic height : content = max(sprite, colonne droite = 2 lignes + boutons)
    local rightH    = lh + lh + bsz
    local contentH  = math.max(iconDH, rightH)
    local requiredH = hh + pad + contentH + pad
    if needsProp then requiredH = requiredH + pad + getTextManager():getFontHeight(UIFont.Small) end
    self:setHeight(requiredH)

    local curY = hh + pad

    -- Object icon
    if iconTex then
        self:drawTextureScaled(iconTex, pad, curY, iconSize, iconDH, 1, 1, 1, 1)
    end

    -- Fuel line
    local fuelStr = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(fuelAmount))
    self:drawText(fuelStr, textX, curY, 1, 1, 1, 1, UIFont.Small)
    local fuelW = getTextManager():MeasureStringX(UIFont.Small, fuelStr)
    curY = curY + lh

    -- Fire state line
    local stateStr, sr, sg, sb
    if isLit then
        stateStr = getText("IGUI_Fireplace_Burning")
        sr, sg, sb = 1.0, 0.55, 0.1
    elseif isSmoul then
        stateStr = getText("IGUI_Fireplace_Smouldering")
        sr, sg, sb = 0.9, 0.7, 0.2
    else
        stateStr = getText("IGUI_Fireplace_Unlit")
        sr, sg, sb = 0.5, 0.5, 0.5
    end
    self:drawText(stateStr, textX, curY, sr, sg, sb, 1, UIFont.Small)
    local stateW = getTextManager():MeasureStringX(UIFont.Small, stateStr)
    local btnY = curY + lh  -- boutons juste sous la 2e ligne de texte (colonne droite)

    -- Dynamic width — update header column minimumWidth for current title (handles shrink)
    local hdrIconSz    = math.floor((hh * 0.8) / 4) * 4
    local currentTitleW = getTextManager():MeasureStringX(UIFont.Medium, self:getWindowTitle())
    local titleCol = self.header:column(self.header._iconTitleCol)
    if titleCol then
        titleCol.minimumWidth = hdrIconSz + pad + currentTitleW + pad * 2
    end
    local titleW = hdrIconSz + pad * 2 + currentTitleW + pad * 2 + bsz + pad
    local minW   = math.max(textX + fuelW + pad, textX + stateW + pad, titleW)
    if needsProp then
        local warnW = getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_BBQ_NeedsPropaneTank"))
        minW = math.max(minW, pad + warnW + pad)
    end
    if minW ~= self.width then
        self:setWidth(minW)
        self.header:setWidth(minW)
        self.header:calculateLayout(minW, hh)
    end

    -- Position buttons (btnFire always first, then secondary) — colonne droite, sous le texte
    local visibleBtns = { self.btnFire }
    self.btnRemoveTank:setVisible(false)
    self.btnAddTank:setVisible(false)
    self.btnDestroyFuel:setVisible(false)

    if showRemoveTank  then table.insert(visibleBtns, self.btnRemoveTank)  end
    if showAddTank     then table.insert(visibleBtns, self.btnAddTank)     end
    if showDestroyFuel then table.insert(visibleBtns, self.btnDestroyFuel) end

    for i, btn in ipairs(visibleBtns) do
        btn:setVisible(true)
        btn:setX(textX + (i - 1) * (bsz + pad))
        btn:setY(btnY)
    end

    -- Propane warning (sous le contenu entier : sprite ou colonne droite)
    if needsProp then
        local warnStr = getText("IGUI_BBQ_NeedsPropaneTank")
        local warnY = hh + pad + contentH + pad
        self:drawText(warnStr, pad, warnY, 0.9, 0.2, 0.2, 1, UIFont.Small)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_BBQPanel:close()
    NR_BBQPanel.panels[self.character] = nil
    self:closeBase()
end
