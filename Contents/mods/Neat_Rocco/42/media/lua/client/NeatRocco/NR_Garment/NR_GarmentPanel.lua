-- NR_GarmentPanel.lua
-- NeatUI replacement panel for ISGarmentUI.
-- Displays clothing coverage, protection values, damage state, and bottom condition bars.

require "ISUI/ISGarmentUI"
require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Config"

NR_GarmentPanel = NR_BasePanel:derive("NR_GarmentPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

-- ----------------------------------------------------------------------------------------------------- --
-- Texture loading (same mapping as ISGarmentUI)
-- ----------------------------------------------------------------------------------------------------- --

local TEXTURE_MAP = {
    Hand_L     = { tex = "_left-hand",      ovr = "_left_hand"       },
    Hand_R     = { tex = "_right-hand",     ovr = "_right_hand"      },
    ForeArm_L  = { tex = "_lower-left-arm", ovr = "_lower_left_arm"  },
    ForeArm_R  = { tex = "_lower-right-arm",ovr = "_lower_right_arm" },
    UpperArm_L = { tex = "_upper-left-arm", ovr = "_upper_left_arm"  },
    UpperArm_R = { tex = "_upper-right-arm",ovr = "_upper_right_arm" },
    Torso_Upper= { tex = "_chest",          ovr = "_chest"           },
    Torso_Lower= { tex = "_abdomen",        ovr = "_abdomen"         },
    Back       = { tex = "_abdomen",        ovr = "_abdomen"         },
    Head       = { tex = "_head",           ovr = "_head"            },
    Neck       = { tex = "_neck",           ovr = "_neck"            },
    Groin      = { tex = "_groin",          ovr = "_groin"           },
    UpperLeg_L = { tex = "_left-thigh",     ovr = "_left_thigh"      },
    UpperLeg_R = { tex = "_right-thigh",    ovr = "_right_thigh"     },
    LowerLeg_L = { tex = "_left-calf",      ovr = "_left_calf"       },
    LowerLeg_R = { tex = "_right-calf",     ovr = "_right_calf"      },
    Foot_L     = { tex = "_left-foot",      ovr = "_left_foot"       },
    Foot_R     = { tex = "_right-foot",     ovr = "_right_foot"      },
}

local function loadTextures(sex)
    local t = {}
    for partKey, info in pairs(TEXTURE_MAP) do
        local base  = "media/ui/BodyParts/bps_" .. sex .. info.tex .. ".png"
        local pfx   = "media/ui/BodyParts/overlays/" .. sex .. "_clothing_overlays_"
        t[partKey] = {
            texture = getTexture(base),
            hole    = getTexture(pfx .. "holes"   .. info.ovr .. ".png"),
            blood   = getTexture(pfx .. "blood"   .. info.ovr .. ".png"),
            patch   = getTexture(pfx .. "patches" .. info.ovr .. ".png"),
        }
    end
    return t
end

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:new(x, y, character, clothing)
    local playerNum = character:getPlayerNum()
    local pad = NR_Config.padding
    local tm  = getTextManager()
    local sex = character:isFemale() and "female" or "male"

    -- Load body part textures
    local textures = loadTextures(sex)

    -- Build covered parts list (only parts that have a texture)
    local parts = {}
    local minX, minY, maxX, maxY = 1000, 1000, -1000, -1000
    for i = 0, clothing:getCoveredParts():size() - 1 do
        local part    = clothing:getCoveredParts():get(i)
        local partKey = part:toString()
        local entry   = textures[partKey]
        if entry and entry.texture then
            table.insert(parts, part)
            local tex = entry.texture
            minX = math.min(minX, tex:getOffsetX())
            minY = math.min(minY, tex:getOffsetY())
            maxX = math.max(maxX, tex:getOffsetX() + tex:getWidth())
            maxY = math.max(maxY, tex:getOffsetY() + tex:getHeight())
        end
    end

    -- Image area dimensions (from sprite offset bounds)
    local imgW = (maxX > -1000) and (maxX - minX) or 0
    local imgH = (maxY > -1000) and (maxY - minY) or 0

    -- Text columns start after the image area
    local listX    = (imgW > 0) and (pad + imgW + pad) or pad
    local partW    = tm:MeasureStringX(UIFont.Small, getText("IGUI_garment_BodyPart"))
    for _, part in ipairs(parts) do
        partW = math.max(partW, tm:MeasureStringX(UIFont.Small, part:getDisplayName()))
    end
    local biteW    = tm:MeasureStringX(UIFont.Small, getText("IGUI_health_Bite"))
    local scratchW = tm:MeasureStringX(UIFont.Small, getText("IGUI_health_Scratch"))
    local bulletW  = tm:MeasureStringX(UIFont.Small, getText("IGUI_health_Bullet"))

    local biteX    = listX + partW + pad
    local scratchX = biteX + biteW + pad
    local bulletX  = scratchX + scratchW + pad

    -- Bottom bar widths: each bar is at least as wide as its label
    local condW  = tm:MeasureStringX(UIFont.Small, getText("IGUI_invpanel_Condition"))
    local bloodW = tm:MeasureStringX(UIFont.Small, getText("IGUI_garment_GlbBlood"))
    local dirtW  = tm:MeasureStringX(UIFont.Small, getText("IGUI_garment_GlbDirt"))
    local minBarW = 60
    local barW1 = math.max(condW,  minBarW)
    local barW2 = math.max(bloodW, minBarW)
    local barW3 = math.max(dirtW,  minBarW)
    local bar1X = pad
    local bar2X = bar1X + barW1 + pad
    local bar3X = bar2X + barW2 + pad
    local minBarsW = bar3X + barW3 + pad

    local width = math.max(bulletX + bulletW + pad, minBarsW, 300)

    local o = ISPanelJoypad.new(self, x, y, width, NR_Config.headerHeight + 100)
    o.barW1 = barW1 ; o.bar1X = bar1X
    o.barW2 = barW2 ; o.bar2X = bar2X
    o.barW3 = barW3 ; o.bar3X = bar3X
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.playerNum = playerNum
    o.clothing  = clothing

    o.textures  = textures
    o.parts     = parts
    o.listX     = listX
    o.biteX     = biteX
    o.scratchX  = scratchX
    o.bulletX   = bulletX
    o.imgMinX   = (minX < 1000) and minX or 0
    o.imgMinY   = (minY < 1000) and minY or 0
    o.imgW      = imgW
    o.imgH      = imgH

    NR_BasePanel.initBase(o)

    o.rowYPositions    = {}
    o.bodyPartAction   = {}
    o.actionToBodyPart = {}

    -- Register so ISRepairClothing / ISRemovePatch can notify us
    ISGarmentUI.windows[playerNum] = o

    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:getWindowTitle()
    return self.clothing and self.clothing:getDisplayName() or ""
end

function NR_GarmentPanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Tailoring.png")
end

-- ----------------------------------------------------------------------------------------------------- --
-- TimedAction callbacks (called via ISGarmentUI.windows[playerNum])
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:setBodyPartAction(bodyPart, args)
    self.bodyPartAction = self.bodyPartAction or {}
    self.bodyPartAction[bodyPart] = args
end

function NR_GarmentPanel:setBodyPartForAction(action, bodyPart)
    self.actionToBodyPart = self.actionToBodyPart or {}
    self.actionToBodyPart[action] = bodyPart
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle  (initialise + createChildren héritées de NR_BasePanel)
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:update()
    if not self.clothing or not self.clothing:isInPlayerInventory() then
        self:close()
        return
    end
    ISPanelJoypad.update(self)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Context menu (vanilla ISGarmentUI logic preserved 1:1)
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:doPatch(fabric, thread, needle, part, context, submenu)
    if not self.clothing:getFabricType() then return end
    local hole  = self.clothing:getVisual():getHole(part) > 0
    local patch = self.clothing:getPatchType(part)
    local text, allText
    if hole then
        text    = getText("ContextMenu_PatchHole")
        allText = getText("ContextMenu_PatchAllHoles") .. " " .. fabric:getDisplayName()
    elseif not patch then
        text    = getText("ContextMenu_AddPadding")
        allText = getText("ContextMenu_AddPaddingAll") .. " " .. fabric:getDisplayName()
    else
        error "patch ~= nil"
    end
    if not submenu then
        local option = context:addOption(text)
        submenu = context:getNew(context)
        context:addSubMenu(option, submenu)
    end
    local option = submenu:addOption(fabric:getDisplayName(), self.character, ISInventoryPaneContextMenu.repairClothing, self.clothing, part, fabric, thread, needle)
    option.itemForTexture = fabric
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    if self.clothing:canFullyRestore(self.character, part, fabric) then
        tooltip.description = getText("IGUI_perks_Tailoring") .. " :" .. self.character:getPerkLevel(Perks.Tailoring) .. " <LINE>" .. ISGarmentUI.ghs .. getText("Tooltip_FullyRestore")
    else
        tooltip.description = getText("IGUI_perks_Tailoring") .. " :" .. self.character:getPerkLevel(Perks.Tailoring) .. " <LINE>" .. ISGarmentUI.ghs .. getText("Tooltip_ScratchDefense") .. " +" .. Clothing.getScratchDefenseFromItem(self.character, fabric) .. " <LINE> " .. getText("Tooltip_BiteDefense") .. " +" .. Clothing.getBiteDefenseFromItem(self.character, fabric)
    end
    option.toolTip = tooltip
    local allTooltip = ISInventoryPaneContextMenu.addToolTip()
    if self.character:getInventory():getItemCount(fabric:getType(), true) > 1 then
        if hole and self.clothing:getHolesNumber() > 1 then
            local allOption = submenu:addOption(allText, self.character, ISInventoryPaneContextMenu.repairAllClothing, self.clothing, self.parts, fabric, thread, needle, true)
            allOption.itemForTexture = fabric
            allTooltip.description = getText("Tooltip_PatchAllHoles") .. " " .. fabric:getDisplayName()
            allOption.toolTip = allTooltip
        elseif not hole and not patch and ISGarmentUI:getPaddablePartsNumber(self.clothing, self.parts) > 1 then
            local allOption = submenu:addOption(allText, self.character, ISInventoryPaneContextMenu.repairAllClothing, self.clothing, self.parts, fabric, thread, needle, false)
            allOption.itemForTexture = fabric
            allTooltip.description = getText("Tooltip_AddPaddingToAll") .. " " .. fabric:getDisplayName()
            allOption.toolTip = allTooltip
        end
    end
    return submenu
end

function NR_GarmentPanel:doContextMenu(part, x, y)
    local context = ISContextMenu.get(self.character:getPlayerNum(), x, y)
    local thread  = self.character:getInventory():getItemFromType("Thread", true, true) or self.character:getInventory():getItemFromTag(ItemTag.THREAD, true, true)
    local needle  = self.character:getInventory():getItemFromType("Needle", true, true) or self.character:getInventory():getFirstTagRecurse(ItemTag.SEWING_NEEDLE)
    local fabric1 = self.character:getInventory():getItemFromType("RippedSheets", true, true)
    local fabric2 = self.character:getInventory():getItemFromType("DenimStrips", true, true)
    local fabric3 = self.character:getInventory():getItemFromType("LeatherStrips", true, true)
    local patch   = self.clothing:getPatchType(part)
    if patch then
        local removeOption = context:addOption(getText("ContextMenu_RemovePatch"), self.character, ISInventoryPaneContextMenu.removePatch, self.clothing, part, needle)
        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        removeOption.toolTip = tooltip
        local patchesCount = self.clothing:getPatchesNumber()
        local removeAllOption, removeAllTooltip
        if patchesCount > 1 then
            removeAllOption = context:addOption(getText("ContextMenu_RemoveAllPatches"), self.character, ISInventoryPaneContextMenu.removeAllPatches, self.clothing, self.parts, needle)
            removeAllTooltip = ISInventoryPaneContextMenu.addToolTip()
            removeAllOption.toolTip = removeAllTooltip
        end
        if needle then
            tooltip.description = getText("Tooltip_GetPatchBack", ISRemovePatch.chanceToGetPatchBack(self.character)) .. " <LINE>" .. ISGarmentUI.bhs .. getText("Tooltip_ScratchDefense") .. " -" .. patch:getScratchDefense() .. " <LINE> " .. getText("Tooltip_BiteDefense") .. " -" .. patch:getBiteDefense()
            if removeAllTooltip then
                removeAllTooltip.description = getText("Tooltip_GetPatchesBack", ISRemovePatch.chanceToGetPatchBack(self.character)) .. " <LINE>" .. ISGarmentUI.bhs .. getText("Tooltip_ScratchDefense") .. " -" .. (patch:getScratchDefense() * patchesCount) .. " <LINE> " .. getText("Tooltip_BiteDefense") .. " -" .. (patch:getBiteDefense() * patchesCount)
            end
        else
            tooltip.description = getText("ContextMenu_CantRemovePatch")
            removeOption.notAvailable = true
            if removeAllOption then
                removeAllTooltip.description = getText("ContextMenu_CantRemovePatch")
                removeAllOption.notAvailable = true
            end
        end
        return context
    end
    if not thread or not needle or (not fabric1 and not fabric2 and not fabric3) then
        local patchOption = context:addOption(getText("ContextMenu_Patch"))
        patchOption.notAvailable = true
        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip.description = getText("ContextMenu_CantRepair")
        patchOption.toolTip = tooltip
        return context
    end
    local submenu
    if fabric1 then submenu = self:doPatch(fabric1, thread, needle, part, context, submenu) end
    if fabric2 then submenu = self:doPatch(fabric2, thread, needle, part, context, submenu) end
    if fabric3 then submenu = self:doPatch(fabric3, thread, needle, part, context, submenu) end
    return context
end

-- ----------------------------------------------------------------------------------------------------- --
-- Mouse
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:onRightMouseUp(_, y)
    for _, row in ipairs(self.rowYPositions) do
        if y >= row.y and y < row.y + row.h then
            self:doContextMenu(row.part, getMouseX(), getMouseY())
            return true
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:render()
    local clothing = self.clothing
    if not clothing then return end
    ISPanelJoypad.render(self)

    local pad  = NR_Config.padding
    local lh   = NR_Config.smallLineHeight
    local barH = NR_Config.barHeight
    local hh   = NR_Config.headerHeight
    local mx   = self:getMouseX()
    local my   = self:getMouseY()
    local mouseInPanel = mx >= 0 and mx < self.width and my >= 0 and my < self.height

    self.rowYPositions = {}

    local curY = hh + pad

    -- "Can't be repaired" notice
    if not clothing:getFabricType() then
        self:drawText(getText("IGUI_garment_CantRepair"), self.listX, curY, 1, 0.3, 0.3, 1, UIFont.Small)
        curY = curY + lh + pad / 2
    end

    -- Column headers
    self:drawText(getText("IGUI_garment_BodyPart"), self.listX,    curY, 1, 1, 1, 0.6, UIFont.Small)
    self:drawText(getText("IGUI_health_Bite"),      self.biteX,    curY, 1, 1, 1, 0.6, UIFont.Small)
    self:drawText(getText("IGUI_health_Scratch"),   self.scratchX, curY, 1, 1, 1, 0.6, UIFont.Small)
    self:drawText(getText("IGUI_health_Bullet"),    self.bulletX,  curY, 1, 1, 1, 0.6, UIFont.Small)
    curY = curY + lh + 2

    -- Separator under headers
    self:drawRect(self.listX, curY, self.width - self.listX - pad, 1, 0.7, 0.5, 0.5, 0.5)
    curY = curY + pad / 2 + 1

    local bad  = getCore():getBadHighlitedColor()
    local good = getCore():getGoodHighlitedColor()
    local br, bg_, bb = bad:getR(), bad:getG(), bad:getB()
    local gr, gg, gb  = good:getR(), good:getG(), good:getB()

    for _, part in ipairs(self.parts) do
        local rowStartY = curY
        local rowH      = lh

        -- Pre-calculate row height for hover
        if clothing:getVisual():getHole(part) > 0            then rowH = rowH + lh end
        if clothing:getBloodlevelForPart(part) > 0           then rowH = rowH + lh end
        if clothing:getPatchType(part)                        then rowH = rowH + lh end
        local bpa = self.bodyPartAction and self.bodyPartAction[part]
        if not bpa then
            local aq = ISTimedActionQueue.getTimedActionQueue(self.character)
            if aq and aq.queue and aq.queue[1] and self.actionToBodyPart and self.actionToBodyPart[aq.queue[1]] == part then
                bpa = { delta = aq.queue[1]:getJobDelta(), jobType = aq.queue[1].jobType }
            end
        end
        if bpa then rowH = rowH + barH end

        -- Hover highlight
        if mouseInPanel and my >= rowStartY and my < rowStartY + rowH then
            self:drawRect(self.listX, rowStartY, self.width - self.listX, rowH, 0.1, 1, 1, 1)
        end

        -- Protection values
        self:drawText(part:getDisplayName(),                              self.listX,    curY, 1, 1, 1, 1, UIFont.Small)
        self:drawText(clothing:getDefForPart(part, true,  false) .. "%", self.biteX,    curY, 1, 1, 1, 1, UIFont.Small)
        self:drawText(clothing:getDefForPart(part, false, false) .. "%", self.scratchX, curY, 1, 1, 1, 1, UIFont.Small)
        self:drawText(clothing:getDefForPart(part, false, true)  .. "%", self.bulletX,  curY, 1, 1, 1, 1, UIFont.Small)
        curY = curY + lh

        -- Hole
        if clothing:getVisual():getHole(part) > 0 then
            self:drawText(getText("IGUI_garment_Hole"), self.listX + 8, curY, br, bg_, bb, 1, UIFont.Small)
            curY = curY + lh
        end

        -- Blood
        local bloodLevel = clothing:getBloodlevelForPart(part)
        if bloodLevel > 0 then
            self:drawText(getText("IGUI_garment_Blood") .. round(bloodLevel * 100, 0) .. "%", self.listX + 8, curY, br, bg_, bb, 1, UIFont.Small)
            curY = curY + lh
        end

        -- Patch
        local patch = clothing:getPatchType(part)
        if patch then
            self:drawText("- " .. getText("IGUI_TypeOfPatch", patch:getFabricTypeName()), self.listX + 8, curY, gr, gg, gb, 1, UIFont.Small)
            curY = curY + lh
        end

        -- Progress bar (active sewing action on this part)
        if bpa then
            self:drawBar(self.listX, curY, self.width - self.listX - pad, barH, bpa.delta or 0, 0.2, 0.8, 0.4)
            if bpa.jobType then
                self:drawText(bpa.jobType, self.listX + pad, curY + math.floor((barH - FONT_HGT_SMALL) / 2), 1, 1, 1, 1, UIFont.Small)
            end
            curY = curY + barH
        end

        table.insert(self.rowYPositions, { part = part, y = rowStartY, h = rowH })
    end

    -- Clothing silhouette (drawn at left, all parts stacked at same anchor)
    if self.imgW > 0 then
        local texAnchorX = pad - self.imgMinX
        local texAnchorY = hh + pad - self.imgMinY
        for _, part in ipairs(self.parts) do
            local entry = self.textures[part:toString()]
            if entry then
                if entry.texture then
                    self:drawTexture(entry.texture, texAnchorX, texAnchorY, 1, 1, 1, 1)
                end
                if clothing:getVisual():getHole(part) > 0 and entry.hole then
                    self:drawTexture(entry.hole, texAnchorX, texAnchorY, 1, 1, 1, 1)
                end
                if clothing:getBloodlevelForPart(part) > 0 and entry.blood then
                    self:drawTexture(entry.blood, texAnchorX, texAnchorY, clothing:getBloodlevelForPart(part) + 0.1, 1, 1, 1)
                end
                if clothing:getPatchType(part) and entry.patch then
                    self:drawTexture(entry.patch, texAnchorX, texAnchorY, 1, 1, 1, 1)
                end
            end
        end
    end

    -- Separator before bottom bars
    curY = curY + 1
    self:drawSeparator(curY)
    curY = curY + pad

    -- Bottom 3 bars: Condition / Bloodiness / Dirtiness (widths pre-calculated in new())
    self:drawText(getText("IGUI_invpanel_Condition"), self.bar1X, curY, 1, 1, 1, 0.8, UIFont.Small)
    self:drawText(getText("IGUI_garment_GlbBlood"),   self.bar2X, curY, 1, 1, 1, 0.8, UIFont.Small)
    self:drawText(getText("IGUI_garment_GlbDirt"),    self.bar3X, curY, 1, 1, 1, 0.8, UIFont.Small)
    curY = curY + lh + 2

    local condPct  = clothing:getCondition() / clothing:getConditionMax()
    local bloodPct = clothing:getBloodlevel() / 100
    local dirtPct  = clothing:getDirtiness()  / 100
    local cr, cg, cb = self:getBarColor(condPct)
    self:drawBarWithLabel(self.bar1X, curY, self.barW1, barH, condPct,  math.floor(condPct  * 100) .. "%", cr,  cg,   cb)
    self:drawBarWithLabel(self.bar2X, curY, self.barW2, barH, bloodPct, math.floor(bloodPct * 100) .. "%", 0.8, 0.1,  0.1)
    self:drawBarWithLabel(self.bar3X, curY, self.barW3, barH, dirtPct,  math.floor(dirtPct  * 100) .. "%", 0.7, 0.45, 0.1)

    curY = curY + barH + pad
    self:setHeight(curY)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_GarmentPanel:close()
    local pn = self.playerNum
    if ISGarmentUI.windows[pn] == self then
        ISGarmentUI.windows[pn] = nil
    end
    self:closeBase()
end

-- (onGainJoypadFocus, onLoseJoypadFocus, onJoypadDown, isKeyConsumed, onKeyRelease héritées de NR_BasePanel)
