-- NR_PlantPanel.lua
-- NeatUI replacement panel for ISFarmingWindow / ISFarmingInfo.
-- Derives from ISFarmingInfo and calls ISFarmingInfo.render() — all mod patches
-- (Plant_Highlight from "Improved Farming Info Window", etc.) run automatically.
-- Draw calls are intercepted during the vanilla chain and re-emitted in NeatUI style.

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Utils/NR_CollapseUtils"
require "NeatRocco/NR_Config"

NR_PlantPanel = ISFarmingInfo:derive("NR_PlantPanel")
NR_PlantPanel.panels = {}  -- keyed by character

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local VALUE_GAP = 10  -- gap between label pivot and value (same as NR_FeedingTroughPanel)

-- ----------------------------------------------------------------------------------------------------- --
-- Width helpers
-- ----------------------------------------------------------------------------------------------------- --

local function computeKeyW()
    local tm  = getTextManager()
    -- include " : " separator in keyW so labels like "Phase : " fit in the pivot
    local sep = tm:MeasureStringX(UIFont.Small, " : ")
    local labels = {
        getText("Farming_Current_growing_phase"),
        getText("Farming_Next_growing_phase"),
        "hoursElapsed",
        getText("Farming_Fertilized"),
        getText("Farming_Compost"),
        getText("Farming_Health"),
        getText("Farming_Aphid"),
        getText("Farming_Mildew"),
        getText("Farming_Pest_Flies"),
        getText("Farming_Slugs"),
        getText("Farming_Water_levels"),
    }
    local maxW = 0
    for _, l in ipairs(labels) do
        maxW = math.max(maxW, tm:MeasureStringX(UIFont.Small, l))
    end
    return maxW + sep
end

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
        getText("UI_FriendState_Unknown"),
    }
    local maxW = 0
    for _, v in ipairs(values) do
        maxW = math.max(maxW, tm:MeasureStringX(UIFont.Small, v))
    end
    return maxW
end

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

    o.character = character
    o.playerNum = character:getPlayerNum()
    o.plant     = plant
    o.vegetable = getTexture(farming_vegetableconf.props[plant.typeOfSeed].icon)
    o._keyW     = keyW
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
-- Dynamic width — header title only; content width is fixed at construction
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:updateDynamicWidth()
    local tm  = getTextManager()
    local hh  = NR_Config.headerHeight
    local pad = NR_Config.padding
    local iconSize = math.floor((hh * 0.8) / 4) * 4
    local minW = iconSize + pad * 2
                 + tm:MeasureStringX(UIFont.Medium, self:getWindowTitle()) + pad * 2
                 + NR_Config.buttonSize + pad
    if minW > self.width then
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
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:createChildren()
    NR_BasePanel.createChildren(self)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Prerender
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:prerender()
    if not self:isPlantValid() then return end

    -- Network sync + automatic mod patches on prerender
    ISFarmingInfo.prerender(self)

    if not NR_CollapseUtils.isBodyVisible(self) then return end

    self:updateDynamicWidth()
    NR_BasePanel.prerender(self)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- Intercept ISFarmingInfo.render() draw calls (phase 1), then emit in NeatUI style (phase 2).
-- Any mod that patches ISFarmingInfo.render() — including Plant_Highlight() — runs automatically.
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:render()
    if not self:isPlantValid() then return end
    if not NR_CollapseUtils.isBodyVisible(self) then return end
    ISPanelJoypad.render(self)

    local pad      = NR_Config.padding
    local lh       = NR_Config.lineHeight
    local barH     = NR_Config.barHeight
    local fhgt     = FONT_HGT_SMALL
    local textOffY = math.floor((lh - fhgt) / 2)
    local xPivot   = pad + self._keyW
    local valX     = xPivot + VALUE_GAP

    -- ── Phase 1 : collect draw ops by intercepting ISFarmingInfo.render() ────────────────────── --
    local ops = {}
    local pendLbl = nil
    local pendLR, pendLG, pendLB = 1, 1, 1

    -- drawText: capture labels (x <= 50 = label/standalone; x > 50 = title, skip)
    self.drawText = function(_, text, x, _, r, g, b)
        if x > 50 then return end
        if pendLbl then
            -- flush: previous label had no value → standalone text
            table.insert(ops, { t = "text", text = pendLbl,
                                 r = pendLR, g = pendLG, b = pendLB })
        end
        pendLbl = text
        pendLR, pendLG, pendLB = r or 1, g or 1, b or 1
    end

    -- drawTextRight: emit label-value row, or value-only if no pending label
    self.drawTextRight = function(_, text, _, _, r, g, b)
        if pendLbl then
            table.insert(ops, { t = "row", lbl = pendLbl, val = text,
                                 vr = r or 1, vg = g or 1, vb = b or 1 })
            pendLbl = nil
        else
            -- value without label (e.g. pest info multi-value loop)
            table.insert(ops, { t = "val", val = text,
                                 vr = r or 1, vg = g or 1, vb = b or 1 })
        end
    end

    -- drawRect: capture water bar fill only (x=14, h=10); suppress all others
    self.drawRect = function(_, x, _, w, h, _, r, g, b)
        if x == 14 and h == 10 then
            local totalW = self.width - 27  -- from ISFarmingInfo.getWaterBarWidth
            local pct = (totalW > 0) and (w / totalW) or 0
            table.insert(ops, { t = "bar", pct = pct,
                                 r = r or 0.15, g = g or 0.3, b = b or 0.63 })
        end
    end

    self.drawRectBorder           = function() end
    self.drawTextureScaled        = function() end
    self.setHeightAndParentHeight = function() end

    -- Run vanilla chain — Plant_Highlight() and all mod patches execute here
    ISFarmingInfo.render(self)

    -- Remove instance-level intercepts
    self.drawText                 = nil
    self.drawTextRight            = nil
    self.drawRect                 = nil
    self.drawRectBorder           = nil
    self.drawTextureScaled        = nil
    self.setHeightAndParentHeight = nil

    -- Flush trailing pending label (standalone with no value following it)
    if pendLbl then
        table.insert(ops, { t = "text", text = pendLbl,
                             r = pendLR, g = pendLG, b = pendLB })
    end

    -- Resize panel to fit actual value content (dynamic texts like "Almost Ready 3 / 5")
    local tm = getTextManager()
    local maxValW = 0
    for _, op in ipairs(ops) do
        if op.val then
            maxValW = math.max(maxValW, tm:MeasureStringX(UIFont.Small, op.val))
        end
    end
    local neededW = pad + self._keyW + VALUE_GAP + maxValW + pad
    if neededW > self.width then
        self:setWidth(neededW)
        self.header:setWidth(neededW)
        self.header:calculateLayout(neededW, NR_Config.headerHeight)
    end

    -- ── Phase 2 : emit collected ops in NeatUI style ─────────────────────────────────────────── --
    local curY = NR_Config.headerHeight + pad

    for _, op in ipairs(ops) do
        if op.t == "row" then
            NR_DrawUtils.drawLabelValue(self, op.lbl, op.val,
                xPivot, valX, curY + textOffY, 0.7, op.vr, op.vg, op.vb)
            curY = curY + lh
        elseif op.t == "text" then
            ---@diagnostic disable-next-line: redundant-parameter
            self:drawText(op.text, pad, curY + textOffY, op.r, op.g, op.b, 1)
            curY = curY + lh
        elseif op.t == "val" then
            ---@diagnostic disable-next-line: redundant-parameter
            self:drawText(op.val, valX, curY + textOffY, op.vr, op.vg, op.vb, 1)
            curY = curY + lh
        elseif op.t == "bar" then
            NR_DrawBar.drawBar(self, pad, curY, self.width - pad * 2,
                               barH, op.pct, op.r, op.g, op.b)
            curY = curY + barH + math.floor(pad / 2)
        end
    end

    self:setHeight(curY + pad)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Update (auto-close: invalid plant or player too far — from ISFarmingInfo:update)
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:update()
    if not self.plant:getObject() then
        self:close()
        return
    end

    ISPanelJoypad.update(self)

    if not self:isPlantValid() then
        self:close()
        return
    end

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
    NR_BasePanel.closeBase(self)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad / keyboard (NR_BasePanel style — no self.parent dependency unlike ISFarmingInfo)
-- ----------------------------------------------------------------------------------------------------- --

function NR_PlantPanel:onGainJoypadFocus(_) self.drawJoypadFocus = true  end
function NR_PlantPanel:onLoseJoypadFocus(_) self.drawJoypadFocus = false end

function NR_PlantPanel:onJoypadDown(button, joypadData)
    if button == Joypad.BButton then self:close(); return end
    ISPanelJoypad.onJoypadDown(self, button, joypadData)
end

function NR_PlantPanel:isKeyConsumed(_) return false end

function NR_PlantPanel:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:close(); return true end
end
