-- NR_ButcherHookPanel.lua
-- NeatUI-styled replacement for ISButcherHookUI.
-- Vanilla logic preserved 1:1 — visual layer only.

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Config"

NR_ButcherHookPanel = NR_BasePanel:derive("NR_ButcherHookPanel")
NR_ButcherHookPanel.ui = {}

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local NR_BODY_HEIGHT = 300  -- body area below header

local function predicateNotBroken(item)
    return not item:isBroken()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_ButcherHookPanel:new(x, y, hook, player)
    local playerNum = player:getPlayerNum()
    if NR_ButcherHookPanel.ui[playerNum] then
        return NR_ButcherHookPanel.ui[playerNum]
    end

    local width  = 400 + 50 * getCore():getOptionFontSizeReal()
    local height = NR_Config.headerHeight + NR_BODY_HEIGHT

    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.hook        = hook
    o.chr         = player
    o.playerNum   = playerNum
    o.corpse      = nil
    o.animal3D    = nil
    o.doingAction = false
    o.actionText  = nil
    o.progress    = 0

    NR_BasePanel.initBase(o)

    NR_ButcherHookPanel.ui[playerNum] = o
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_ButcherHookPanel:getWindowTitle()
    return getText("ContextMenu_ButcherHook")
end

function NR_ButcherHookPanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_ButchHook.png")
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_ButcherHookPanel:createChildren()
    NR_BasePanel.createChildren(self)

    -- Mirror vanilla create() : set animal3D and register LuaHook first
    self.animal3D = self.hook:getAnimal()
    self.hook:setLuaHook(self)

    local hh  = NR_Config.headerHeight
    local bsz = NR_Config.buttonSize
    local pad = NR_Config.padding

    -- -------------------------------------------------------------------------
    -- State 1 : no animal on hook
    -- -------------------------------------------------------------------------
    self.noAnimalPanel = ISPanel:new(0, hh, self.width, NR_BODY_HEIGHT)
    self.noAnimalPanel:noBackground()
    self.noAnimalPanel:initialise()
    self:addChild(self.noAnimalPanel)

    local addLabel  = getText("ContextMenu_AddCorpse")
    local textW     = getTextManager():MeasureStringX(UIFont.Small, addLabel)
    local totalW    = textW + pad + bsz
    local startX    = math.floor((self.width - totalW) / 2)
    local addBtnY   = math.floor((NR_BODY_HEIGHT - bsz) / 2)
    local addBtnX   = startX + textW + pad
    local textY     = addBtnY + math.floor((bsz - FONT_HGT_SMALL) / 2)

    self.addCorpseBtn = NI_SquareButton:new(
        addBtnX, addBtnY, bsz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Add.png"),
        self, NR_ButcherHookPanel.onClickAddCorpse
    )
    self.addCorpseBtn:initialise()
    self.addCorpseBtn:setActive(true)
    self.addCorpseBtn:setActiveColor(0.2, 0.75, 0.2)
    self.noAnimalPanel:addChild(self.addCorpseBtn)

    local _startX = startX
    local _textY  = textY
    local _label  = addLabel
    self.noAnimalPanel.render = function(np)
        np:drawText(_label, _startX, _textY, 1, 1, 1, 0.85, UIFont.Small)
    end


    -- -------------------------------------------------------------------------
    -- State 2 : animal on hook
    -- -------------------------------------------------------------------------
    self.animalPanel = ISPanel:new(0, hh, self.width, NR_BODY_HEIGHT)
    self.animalPanel:noBackground()
    self.animalPanel:initialise()
    self:addChild(self.animalPanel)

    -- Avatar area coordinates (relative to animalPanel)
    self.avatarX      = NR_Config.padding + 3
    self.avatarY      = NR_Config.padding + 3
    self.avatarWidth  = 148
    self.avatarHeight = 230

    local avatarBottom = self.avatarY + self.avatarHeight

    -- Remove Corpse button (red, below avatar)
    self.removeCorpseBtn = NI_SquareButton:new(
        self.avatarX, avatarBottom + pad,
        bsz,
        getTexture("media/ui/NeatRocco/ICON/Icon_DropDown.png"),
        self, NR_ButcherHookPanel.removeCorpseAction
    )
    self.removeCorpseBtn:initialise()
    self.removeCorpseBtn:setActive(true)
    self.removeCorpseBtn:setActiveColor(0.8, 0.2, 0.2)
    self.removeCorpseBtn:setVisible(true)
    self.animalPanel:addChild(self.removeCorpseBtn)

    -- Labels (ISLabel — text updated each frame via setName)
    self.leatherLabel     = ISLabel:new(0, 0, FONT_HGT_SMALL, "", 1,   1,   1,   0.9, UIFont.Small, false)
    self.leatherInfoLabel = ISLabel:new(0, 0, FONT_HGT_SMALL, "", 0.7, 0.7, 0.7, 0.9, UIFont.Small, false)
    self.bloodLabel       = ISLabel:new(0, 0, FONT_HGT_SMALL, "", 1,   1,   1,   0.9, UIFont.Small, false)
    self.bloodInfoLabel   = ISLabel:new(0, 0, FONT_HGT_SMALL, "", 0.7, 0.7, 0.7, 0.9, UIFont.Small, false)
    self.headLabel        = ISLabel:new(0, 0, FONT_HGT_SMALL, "", 1,   1,   1,   0.9, UIFont.Small, false)
    self.headInfoLabel    = ISLabel:new(0, 0, FONT_HGT_SMALL, "", 0.7, 0.7, 0.7, 0.9, UIFont.Small, false)
    self.meatLabel        = ISLabel:new(0, 0, FONT_HGT_SMALL, "", 1,   1,   1,   0.9, UIFont.Small, false)
    self.meatInfoLabel    = ISLabel:new(0, 0, FONT_HGT_SMALL, "", 0.7, 0.7, 0.7, 0.9, UIFont.Small, false)

    for _, lbl in ipairs({
        self.leatherLabel, self.leatherInfoLabel,
        self.bloodLabel,   self.bloodInfoLabel,
        self.headLabel,    self.headInfoLabel,
        self.meatLabel,    self.meatInfoLabel,
    }) do
        lbl:initialise()
        self.animalPanel:addChild(lbl)
    end

    -- Action buttons (NI_SquareButton — orange, hidden by default, positioned by updatePositions)
    local gatherIcon = getTexture("media/ui/NeatRocco/ICON/Icon_Gather.png")

    -- Blood button icons
    self.iconGather = getTexture("media/ui/NeatRocco/ICON/Icon_BloodGather.png")
    self.iconBleed  = getTexture("media/ui/NeatRocco/ICON/Icon_Bleed.png")

    self.removeLeatherBtn = NI_SquareButton:new(0, 0, bsz, gatherIcon, self, NR_ButcherHookPanel.onRemoveLeather)
    self.removeLeatherBtn:initialise()
    self.removeLeatherBtn:setActive(true)
    self.removeLeatherBtn:setActiveColor(0.95, 0.5, 0.1)
    self.removeLeatherBtn:setVisible(false)
    self.animalPanel:addChild(self.removeLeatherBtn)

    self.removeBloodBtn = NI_SquareButton:new(0, 0, bsz, self.iconGather, self, NR_ButcherHookPanel.onRemoveBlood)
    self.removeBloodBtn:initialise()
    self.removeBloodBtn:setActive(true)
    self.removeBloodBtn:setActiveColor(0.95, 0.5, 0.1)
    self.removeBloodBtn:setVisible(false)
    self.animalPanel:addChild(self.removeBloodBtn)

    self.removeHeadBtn = NI_SquareButton:new(0, 0, bsz, gatherIcon, self, NR_ButcherHookPanel.onRemoveHead)
    self.removeHeadBtn:initialise()
    self.removeHeadBtn:setActive(true)
    self.removeHeadBtn:setActiveColor(0.95, 0.5, 0.1)
    self.removeHeadBtn:setVisible(false)
    self.animalPanel:addChild(self.removeHeadBtn)

    self.removeMeatBtn = NI_SquareButton:new(0, 0, bsz, gatherIcon, self, NR_ButcherHookPanel.onRemoveMeat)
    self.removeMeatBtn:initialise()
    self.removeMeatBtn:setActive(true)
    self.removeMeatBtn:setActiveColor(0.95, 0.5, 0.1)
    self.removeMeatBtn:setVisible(false)
    self.animalPanel:addChild(self.removeMeatBtn)

    -- Dummy progressBar table: Java calls ISButcherHookUI.onStopBleedingAnimal(self) directly
    -- and writes self.progressBar.progress = 0 — we keep this stub to avoid a nil-index error.
    self.progressBar = { progress = 0 }

    -- Load initial corpse data (animal3D already set at top of createChildren)
    self:updateCorpseDatas()

    if self.animal3D then
        self.noAnimalPanel:setVisible(false)
        self:setAnimalAvatar()
    else
        self.animalPanel:setVisible(false)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_ButcherHookPanel:render()
    if not self.hook then return end
    ISPanelJoypad.render(self)

    -- Reset height in case debug mode extended it
    self:setHeight(NR_Config.headerHeight + NR_BODY_HEIGHT)

    self:checkAnimalOnHook()

    if not self.animal3D then
        if not self.noAnimalPanel:isVisible() then
            self.noAnimalPanel:setVisible(true)
            self.animalPanel:setVisible(false)
        end
        -- Enable addCorpseBtn only when no action is in progress
        local busy = isPlayerDoingActionThatCanBeCancelled(self.chr) or self.hook:getUsingPlayer() ~= nil
        self.addCorpseBtn.enable = not busy
        self.addCorpseBtn:setActive(not busy)
        if not busy then
            self.addCorpseBtn:setActiveColor(0.2, 0.75, 0.2)
        end
        self:checkDistance()
        return
    end

    if self.noAnimalPanel:isVisible() then
        self.noAnimalPanel:setVisible(false)
        self.animalPanel:setVisible(true)
    end

    -- Border around avatar area
    local x, y, w, h = self.avatarX, self.avatarY, self.avatarWidth, self.avatarHeight
    self.animalPanel:drawRectBorder(x - 2, y - 2, w + 4, h + 4, 1, 0.3, 0.3, 0.3)

    self:updateLabelAndButtons()
    self:drawProgressBar()
    self:checkDistance()
end

function NR_ButcherHookPanel:drawProgressBar()
    if not self.doingAction then return end

    local barX = self.progressBarX or 0
    local barY = self.progressBarY or 0
    local barW = self.progressBarW or 0
    local barH = math.floor(FONT_HGT_SMALL * 1.2)

    -- Lerp toward target for smooth animation
    local target = math.min(math.max(self.progress or 0, 0), 1)
    self._displayProgress = self._displayProgress or 0
    self._displayProgress = self._displayProgress + (target - self._displayProgress) * 0.25

    -- Background (ThreePatch — NeatUI_Framework)
    local bg = self.progressBGTextures
    NeatTool.ThreePatch.drawHorizontal(self.animalPanel, barX, barY, barW, barH, bg.left, bg.middle, bg.right, 0.8, 0.4, 0.4, 0.4)

    -- Fill (ThreePatch clipped via stencil)
    local fillW = math.min(math.floor(barW * self._displayProgress), barW)
    if fillW > 0 then
        local fill = self.progressFillTextures
        self.animalPanel:setStencilRect(barX, barY, fillW, barH)
        NeatTool.ThreePatch.drawHorizontal(self.animalPanel, barX, barY, barW, barH, fill.left, fill.middle, fill.right, 1.0, 0.2, 0.8, 0.4)
        self.animalPanel:clearStencilRect()
    end

    -- Action text centered in bar
    if self.actionText then
        local textW = getTextManager():MeasureStringX(UIFont.Small, self.actionText)
        local textX = barX + math.floor((barW - textW) / 2)
        local textY = barY + math.floor((barH - FONT_HGT_SMALL) / 2)
        self.animalPanel:drawText(self.actionText, textX, textY, 1, 1, 1, 1, UIFont.Small)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Vanilla logic — preserved 1:1
-- ----------------------------------------------------------------------------------------------------- --

function NR_ButcherHookPanel:checkAnimalOnHook()
    if self.hook == nil or self.hook:getAnimal() == self.animal3D then
        return
    end
    self.animal3D = self.hook:getAnimal()
    self:setAnimalAvatar()
    self:updateCorpseDatas()
end

function NR_ButcherHookPanel:checkDistance()
    if not self.hook
    or not self.hook:isExistInTheWorld()
    or not self.hook:getSquare()
    or not self.chr:getCurrentSquare()
    or self.hook:getSquare():DistToProper(self.chr:getCurrentSquare()) > 4 then
        self:close()
    end
end

function NR_ButcherHookPanel:updateLabelAndButtons()
    self.knife = self.chr:getInventory():getFirstTagEvalRecurse(ItemTag.BUTCHER_ANIMAL, predicateNotBroken)

    self.biggestLabelWidth = 0
    self.biggestWidth      = 0
    local yoffset = self.avatarY - 2

    -- Update label texts and measure biggest label width
    self.leatherLabel:setName(getText("IGUI_ButcherHook_Leather"))
    self.biggestLabelWidth = self.leatherLabel:getWidth()

    self.bloodLabel:setName(getText("IGUI_ButcherHook_Blood"))
    self.biggestLabelWidth = math.max(self.biggestLabelWidth, self.bloodLabel:getWidth())

    self.headLabel:setName(getText("IGUI_ButcherHook_Head"))
    self.biggestLabelWidth = math.max(self.biggestLabelWidth, self.headLabel:getWidth())

    self.meatLabel:setName(getText("IGUI_ButcherHook_Meat"))
    self.biggestLabelWidth = math.max(self.biggestLabelWidth, self.meatLabel:getWidth())

    -- Update info label texts
    self.leatherInfoLabel:setName(self.leather and getText("IGUI_Yes") or getText("IGUI_No"))

    if self.blood and self.blood > 0 then
        self.bloodInfoLabel:setName(getText("IGUI_Yes") .. " (" .. round(self.blood, 2) .. "L)")
    else
        self.bloodInfoLabel:setName(getText("IGUI_No"))
    end

    self.headInfoLabel:setName(self.head and getText("IGUI_Yes") or getText("IGUI_No"))
    self.meatInfoLabel:setName(self.meat and getText("IGUI_Yes") or getText("IGUI_No"))

    -- Measure biggest total row width (label + info) for button alignment
    self.biggestWidth = math.max(
        self.leatherLabel:getWidth() + self.leatherInfoLabel:getWidth(),
        self.bloodLabel:getWidth()   + self.bloodInfoLabel:getWidth(),
        self.headLabel:getWidth()    + self.headInfoLabel:getWidth(),
        self.meatLabel:getWidth()    + self.meatInfoLabel:getWidth()
    )

    -- Switch blood button icon based on bucket availability
    if self:getBuckets() and not self:getBuckets():isEmpty() then
        self.removeBloodBtn:setIcon(self.iconGather)
    else
        self.removeBloodBtn:setIcon(self.iconBleed)
    end

    -- Layout rows
    yoffset = self:updatePositions(self.leather,              self.removeLeatherBtn, self.leatherLabel, self.leatherInfoLabel, yoffset)
    yoffset = self:updatePositions(self.blood and self.blood > 0, self.removeBloodBtn,  self.bloodLabel,   self.bloodInfoLabel,   yoffset)
    yoffset = self:updatePositions(self.head,                 self.removeHeadBtn,    self.headLabel,    self.headInfoLabel,    yoffset)
    yoffset = self:updatePositions(self.meat,                 self.removeMeatBtn,    self.meatLabel,    self.meatInfoLabel,    yoffset)

    -- Hide all action buttons when doing an action
    if self.doingAction or self.hook:getUsingPlayer() ~= nil then
        self.removeLeatherBtn:setVisible(false)
        self.removeHeadBtn:setVisible(false)
        self.removeMeatBtn:setVisible(false)
        self.removeBloodBtn:setVisible(false)
        self.removeCorpseBtn:setVisible(false)
    else
        self.removeCorpseBtn:setVisible(true)
    end

    -- Blood removal in progress
    if self.hook:isRemovingBlood() then
        self.doingAction = true
        self.actionText  = getText("IGUI_ButcherHook_Bleed")
        self:updateProgressBar(self.hook:getRemovingBloodProgress())
        self:updateCorpseDatas()
        -- Allow gathering if bucket is available
        if self:getBuckets() and not self:getBuckets():isEmpty() then
            self.removeBloodBtn:setVisible(true)
        end
    end

    yoffset = self:renderDebugStuff(yoffset)

    -- Progress bar Y (stored for drawProgressBar)
    local pad = NR_Config.padding
    if self.doingAction then
        local barX = self.avatarX + self.avatarWidth + pad
        if AnimalContextMenu.cheat then
            self.progressBarY = yoffset
        else
            local barH = math.floor(FONT_HGT_SMALL * 1.2)
            self.progressBarY = self.avatarY + self.avatarHeight - barH + 2
        end
        self.progressBarX = barX
        self.progressBarW = self.width - pad - barX
    else
        self.actionText        = nil
        self.progress          = 0
        self._displayProgress  = 0
    end
end

function NR_ButcherHookPanel:renderDebugStuff(yoffset)
    if not AnimalContextMenu.cheat or not self.animalPanel:isVisible() or not self.animal3D then return yoffset end

    self.animalPanel:drawText("DEBUG INFOS:", self.avatarX + self.avatarWidth + 10, yoffset, 1, 1, 1, 1, UIFont.Small)
    yoffset = yoffset + FONT_HGT_SMALL

    for i, v in pairs(self.animal3D:getModData()) do
        local value = v
        if instanceof(value, "Double") then value = round(value, 2) end
        self.animalPanel:drawText("- " .. i .. ": " .. tostring(value), self.avatarX + self.avatarWidth + 10, yoffset, 1, 1, 1, 1, UIFont.Small)
        yoffset = yoffset + FONT_HGT_SMALL
    end

    if self.animal3D:getModData()["pregnancyTime"] and self.animal3D:getModData()["pregnancyTime"] > 0.3 then
        self.animalPanel:drawText("- shouldDropBaby: true",  self.avatarX + self.avatarWidth + 10, yoffset, 1, 1, 1, 1, UIFont.Small)
    else
        self.animalPanel:drawText("- shouldDropBaby: false", self.avatarX + self.avatarWidth + 10, yoffset, 1, 1, 1, 1, UIFont.Small)
    end
    yoffset = yoffset + FONT_HGT_SMALL

    local bsz = NR_Config.buttonSize
    local pad = NR_Config.padding
    if self:getHeight() < NR_Config.headerHeight + yoffset + bsz * 2 + pad * 2 then
        self:setHeight(NR_Config.headerHeight + yoffset + bsz * 2 + pad * 2)
    end
    self.animalPanel:setHeight(self.height - NR_Config.headerHeight)

    return yoffset
end

function NR_ButcherHookPanel:updatePositions(test, button, label, infoLabel, yoffset)
    local xoffset = self.avatarX + self.avatarWidth
    local pad     = NR_Config.padding
    local bsz     = NR_Config.buttonSize

    -- Vertical centering of labels within the button row
    local labelY = yoffset + math.floor((bsz - FONT_HGT_SMALL) / 2)

    label:setX(xoffset + pad)
    label:setY(labelY)

    infoLabel:setX(xoffset + self.biggestLabelWidth + pad * 2)
    infoLabel:setY(labelY)

    -- Button just after the widest label+info row (vertically aligned, not at far right edge)
    button:setX(xoffset + pad + self.biggestWidth + pad * 4)
    button:setY(yoffset)
    button:setVisible(test == true)  -- "== true" handles nil test

    if not self.knife then
        button.enable = false
        button:setActive(false)
        button.tooltip = getText("Tooltip_Animal_NoKnifeButcher")
    else
        button.enable = true
        button:setActive(true)
        button:setActiveColor(0.95, 0.5, 0.1)
        button.tooltip = nil
    end

    return yoffset + bsz + pad
end

function NR_ButcherHookPanel:updateCorpseDatas()
    if ButcheringUtil.updateCorpseDatas(self, self.animal3D, self.hook) then
        if self.hook:isRemovingBlood() then
            self.doingAction = true
            self.actionText  = getText("IGUI_ButcherHook_Bleed")
        end
    end
end

function NR_ButcherHookPanel:updateProgressBar(progress)
    self.progress = progress
end

function NR_ButcherHookPanel:setAnimalAvatar(newModData, newCorpse)
    if not self.animal3D and not newModData then
        if self.avatarPanel then
            self.avatarPanel:setVisible(false)
            self.avatarPanel:removeFromUIManager()
            self.avatarPanel = nil
        end
        return
    end

    self.animal3D = self.hook:getAnimal()
    local modData = newModData or self.animal3D:getModData()

    -- Recreate avatar panel each time (avoids animation issues — same as vanilla)
    self.avatarPanel = ISCharacterScreenAvatar:new(self.avatarX, self.avatarY, self.avatarWidth, self.avatarHeight)
    self.animalPanel:addChild(self.avatarPanel)

    if self.animal3D then
        self.animal3D:setHook(self.hook)
    end

    self.avatarPanel:setZoom(AnimalAvatarDefinition[modData["AnimalType"]].butcherHookZoom)
    self.avatarPanel:setXOffset(AnimalAvatarDefinition[modData["AnimalType"]].butcherHookXoffset)
    self.avatarPanel:setYOffset(AnimalAvatarDefinition[modData["AnimalType"]].butcherHookYoffset)
    self.animal3D:setVariable("onhook", true)
    self.avatarPanel:setState("idle")
    self.avatarPanel:setVariable("onhook", true)
    self.avatarPanel:setDirection(IsoDirections.NE)
    self.avatarPanel:setIsometric(false)
    self.avatarPanel:setAnimSetName(self.animal3D:GetAnimSetName())
    self.avatarPanel:setCharacter(self.animal3D)
    self.avatarPanel:setVisible(true)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Add Corpse
-- ----------------------------------------------------------------------------------------------------- --

function NR_ButcherHookPanel:onClickAddCorpse()
    local context = ISContextMenu.get(self.playerNum, self.addCorpseBtn:getAbsoluteX() + 10, self.addCorpseBtn:getAbsoluteY() + 10)

    local corpseList = self:lookForCorpse()
    for i, v in ipairs(corpseList) do
        local text
        if instanceof(v, "InventoryItem") then
            text = v:getDisplayName()
        end
        if instanceof(v, "IsoDeadBody") then
            if v:isAnimalSkeleton() then
                text = getText("IGUI_Item_AnimalSkeleton", v:getCustomName())
            else
                text = getText("IGUI_Item_AnimalCorpse",   v:getCustomName())
            end
        end
        if text then
            local option = context:addOption(text, self, NR_ButcherHookPanel.addCorpseAction, v)
            option.iconTexture = self:getAnimalCorpseItemTexture(v)
            if not self:isCorpseValid(v) then
                option.notAvailable = true
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                tooltip:setName(getText("Tooltip_ButcherUI_CantAddThis"))
                option.toolTip = tooltip
            end
            if instanceof(v, "IsoDeadBody") then
                ISWorldObjectContextMenu.initWorldItemHighlightOption(option, v)
            end
        end
    end

    if #corpseList == 0 then
        local option = context:addOption(getText("IGUI_ButcherHook_NoAnimalFound"), self, nil)
        option.notAvailable = true
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip:setName(getText("Tooltip_ButcherUI_AddAnimalCorpse"))
        option.toolTip = tooltip
    end

    if getJoypadData(self.playerNum) then
        context.mouseOver = 1
        context.origin    = self
        setJoypadFocus(self.playerNum, context)
    end
end

function NR_ButcherHookPanel:getAnimalCorpseItemTexture(itemOrCorpse)
    if instanceof(itemOrCorpse, "InventoryItem") then
        return itemOrCorpse:getTex()
    end
    if instanceof(itemOrCorpse, "IsoDeadBody") then
        return itemOrCorpse:getInvIcon() and getTexture(itemOrCorpse:getInvIcon())
    end
    return nil
end

function NR_ButcherHookPanel:onAddedCorpse(corpse)
    if not corpse then return end
    local newCorpse = ButcheringUtil.onAddedCorpseOnHook(self.hook, corpse, self.chr)
    self:setAnimalAvatar(corpse:getModData(), newCorpse)
    self:updateCorpseDatas()
    return corpse
end

function NR_ButcherHookPanel:addCorpseAction(corpse)
    if luautils.walkAdj(self.chr, self.hook:getSquare(), false) then
        ISTimedActionQueue.add(ISPutAnimalOnHook:new(self.chr, corpse, self.hook, self))
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Remove Corpse
-- ----------------------------------------------------------------------------------------------------- --

function NR_ButcherHookPanel:onClickRemoveCorpse()
    if not self.animal3D then return end
    local body = ButcheringUtil.onRemoveCorpseFromHook(self.hook, self.animal3D)
    self.animal3D = nil
    self:setAnimalAvatar()
    self:updateCorpseDatas()
    return body
end

function NR_ButcherHookPanel:removeCorpseAction()
    if luautils.walkAdj(self.chr, self.hook:getSquare(), false) then
        ISTimedActionQueue.add(ISRemoveAnimalFromHook:new(self.chr, self.animal3D, self.hook, self))
    end
end

function NR_ButcherHookPanel:resetCorpse()
    self.animal3D = nil
    self:setAnimalAvatar()
    if self.hook:getAnimal() then
        self:setAnimalAvatar(self.hook:getAnimal():getModData(), nil)
    end
    self:updateCorpseDatas()
    self.animal3D = self.hook:getAnimal()
    if self.animal3D then
        self.hook:updateAnimalModel()
    end
end

function NR_ButcherHookPanel:createCorpse(item)
    if instanceof(item, "IsoDeadBody") or instanceof(item, "IsoAnimal") then
        return item
    end
    return self.chr:getCurrentSquare():createAnimalCorpseFromItem(item)
end

function NR_ButcherHookPanel:isCorpseValid(corpse)
    local modData = corpse:getModData()
    if not modData then return false end
    if instanceof(corpse, "Food") and corpse:isFrozen() then return false end
    if not AnimalAvatarDefinition[modData["AnimalType"]] or not AnimalAvatarDefinition[modData["AnimalType"]].hook then return false end
    if modData["animalSize"] < 0.4 then return false end
    return not modData["skeleton"]
end

function NR_ButcherHookPanel:lookForCorpse()
    local result = {}
    local corpses = self.chr:getInventory():FindAll("CorpseAnimal")
    if corpses then
        for i = 0, corpses:size() - 1 do
            table.insert(result, corpses:get(i))
        end
    end
    local radius = 2
    for x = self.chr:getCurrentSquare():getX() - radius, self.chr:getCurrentSquare():getX() + radius do
        for y = self.chr:getCurrentSquare():getY() - radius, self.chr:getCurrentSquare():getY() + radius do
            local sq = getCell():getGridSquare(x, y, self.chr:getCurrentSquare():getZ())
            if sq and sq:getStaticMovingObjects() then
                for i = 0, sq:getStaticMovingObjects():size() - 1 do
                    local object = sq:getStaticMovingObjects():get(i)
                    if instanceof(object, "IsoDeadBody") and object:isAnimal() then
                        table.insert(result, object)
                    end
                end
            end
        end
    end
    return result
end

-- ----------------------------------------------------------------------------------------------------- --
-- Action handlers — meat / leather / head / blood
-- ----------------------------------------------------------------------------------------------------- --

function NR_ButcherHookPanel:onRemoveLeather()
    if luautils.walkAdj(self.chr, self.hook:getSquare(), false) then
        ISWorldObjectContextMenu.equip(self.chr, self.chr:getPrimaryHandItem(), self.knife, true)
        ISTimedActionQueue.add(ISRemoveLeatherFromAnimal:new(self.chr, self.animal3D, self.hook, self))
    end
end

function NR_ButcherHookPanel:onRemoveHead()
    if luautils.walkAdj(self.chr, self.hook:getSquare(), false) then
        ISWorldObjectContextMenu.equip(self.chr, self.chr:getPrimaryHandItem(), self.knife, true)
        ISTimedActionQueue.add(ISRemoveHeadFromAnimal:new(self.chr, self.animal3D, self.hook, self))
    end
end

function NR_ButcherHookPanel:onRemoveMeat()
    if luautils.walkAdj(self.chr, self.hook:getSquare(), false) then
        ISWorldObjectContextMenu.equip(self.chr, self.chr:getPrimaryHandItem(), self.knife, true)
        ISTimedActionQueue.add(ISRemoveMeatFromAnimal:new(self.chr, self.animal3D, self.hook, self))
    end
end

function NR_ButcherHookPanel:onRemoveBlood()
    local context = ISContextMenu.get(0, self.removeBloodBtn:getAbsoluteX() + 10, self.removeBloodBtn:getAbsoluteY() + 10)
    context:addOption(getText("IGUI_None"), self, NR_ButcherHookPanel.onBleedAnimal)

    local bucketList = self:getBuckets()
    if bucketList then
        for i = 0, bucketList:size() - 1 do
            local bucket = bucketList:get(i)
            local text   = bucket:getDisplayName() .. " " .. bucket:getFluidContainer():getAmount() .. "/" .. bucket:getFluidContainer():getCapacity()
            context:addOption(text, self, NR_ButcherHookPanel.onSelectBucketForBlood, bucket)
        end
    end

    if getJoypadData(self.playerNum) then
        context.mouseOver = 1
        context.origin    = self
        setJoypadFocus(self.playerNum, context)
    end
end

function NR_ButcherHookPanel:onBleedAnimal()
    if luautils.walkAdj(self.chr, self.hook:getSquare(), false) then
        ISWorldObjectContextMenu.equip(self.chr, self.chr:getPrimaryHandItem(), self.knife, true)
        ISTimedActionQueue.add(ISCutAnimalOnHook:new(self.chr, self.animal3D, self.hook, self))
    end
end

function NR_ButcherHookPanel:onSelectBucketForBlood(bucket)
    if luautils.walkAdj(self.chr, self.hook:getSquare(), false) then
        ISWorldObjectContextMenu.equip(self.chr, self.chr:getPrimaryHandItem(), self.knife, true)
        ISTimedActionQueue.add(ISCutAnimalOnHook:new(self.chr, self.animal3D, self.hook, self))
        ISTimedActionQueue.add(ISGatherBloodFromAnimal:new(self.chr, self.animal3D, self.hook, self, bucket))
    end
end

function NR_ButcherHookPanel:getBuckets()
    return ButcheringUtil.getBuckets(self.chr)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Java callbacks (called via hook:setLuaHook(self))
-- ----------------------------------------------------------------------------------------------------- --

function NR_ButcherHookPanel.onCutCorpse(self)
    self.hook:startRemovingBlood(self)
end

function NR_ButcherHookPanel.onStopBleedingAnimal(self)
    self.progress    = 0
    self.doingAction = false
    self.actionText  = nil
    self:updateCorpseDatas()
end

function NR_ButcherHookPanel.onHookReceivedNetUpdate(self)
    self:resetCorpse()
    self:updateCorpseDatas()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_ButcherHookPanel:close()
    self.hook:setLuaHook(nil)
    NR_ButcherHookPanel.ui[self.playerNum] = nil
    self:closeBase()
end

-- (onGainJoypadFocus, onLoseJoypadFocus, onJoypadDown, isKeyConsumed, onKeyRelease héritées de NR_BasePanel)
