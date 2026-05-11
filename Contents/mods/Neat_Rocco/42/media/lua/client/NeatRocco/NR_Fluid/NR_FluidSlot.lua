-- NR_FluidSlot.lua
-- NeatUI-styled sub-panel for a single fluid container slot.
-- Replaces ISFluidContainerPanel. Used within NR_FluidTransferPanel.
-- Exposes the same API as ISFluidContainerPanel (getContainer, setPanelLocked,
-- setInvalid, fluidBar.*, containerCopy, funcTarget callbacks).

require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_DrawUtils"

NR_FluidSlot = ISPanel:derive("NR_FluidSlot")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FLUID_BAR_W    = FONT_HGT_SMALL + 6
local VALUE_GAP      = 8

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidSlot:new(x, y, player, container, isLeft, isoHeight)
    local pad = NR_Config.padding
    local slh = NR_Config.smallLineHeight
    local bsz = NR_Config.buttonSize
    local tm  = getTextManager()

    local tagW = math.max(
        tm:MeasureStringX(UIFont.Small, getText("Fluid_Capacity") .. ":"),
        tm:MeasureStringX(UIFont.Small, getText("Fluid_Stored")   .. ":"),
        tm:MeasureStringX(UIFont.Small, getText("Fluid_Free")     .. ":")
    )

    -- Measure actual values if container known, else fallback estimate
    local valW
    if container and container:getFluidContainer() then
        local fc = container:getFluidContainer()
        valW = math.max(
            tm:MeasureStringX(UIFont.Small, FluidUtil.getAmountFormatted(fc:getCapacity())),
            tm:MeasureStringX(UIFont.Small, FluidUtil.getAmountFormatted(fc:getAmount())),
            tm:MeasureStringX(UIFont.Small, FluidUtil.getAmountFormatted(fc:getCapacity() - fc:getAmount()))
        )
    else
        valW = tm:MeasureStringX(UIFont.Small, "9999 mL")
    end

    -- Container name width (dropbox row: pad + bsz + pad + name)
    local nameW = 0
    if container and container:getFluidContainer() then
        nameW = tm:MeasureStringX(UIFont.Small, container:getFluidContainer():getTranslatedContainerName())
    end
    local dropboxRowW = pad + bsz + pad + nameW

    -- Width = max of all content rows + fluid bar
    local contentW = math.max(pad + tagW + VALUE_GAP + valW, dropboxRowW)
    local w = contentW + pad + FLUID_BAR_W + pad
    local h = pad + slh + pad + bsz + slh * 3 + pad

    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.background = false
    o.drawFrame  = false

    o.player    = player
    o.isLeft    = isLeft
    o.isoHeight = isoHeight
    o._pad  = pad
    o._slh  = slh
    o._bsz  = bsz
    o._tagW = tagW

    if container then
        o.container     = container
        o.isIso         = container:isIsoPanel()
        o.isItem        = container:isItem()
        o.containerCopy = container:getFluidContainer():copy()
    else
        o.isItem = true
    end

    o.isInvalid     = false
    o.isPanelLocked = false

    o.funcTarget         = false
    o.onContainerAdd     = false
    o.onContainerRemove  = false
    o.onContainerVerify  = false
    o.overrideAddFull    = false
    o.overrideRemoveFull = false

    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidSlot:initialise()
    ISPanel.initialise(self)
end

function NR_FluidSlot:createChildren()
    local pad = self._pad
    local slh = self._slh
    local bsz = self._bsz

    local barH = bsz + slh * 3
    local barX = self.width - pad - FLUID_BAR_W
    local barY = pad + slh + pad

    self.fluidBar = ISFluidBar:new(barX, barY, FLUID_BAR_W, barH, self.player)
    self.fluidBar:initialise()
    self.fluidBar:instantiate()
    self:addChild(self.fluidBar)

    if self.isItem then
        self.itemDropBox = ISItemDropBox:new(
            pad, barY, bsz, bsz,
            true,
            self,
            NR_FluidSlot.addItem,
            NR_FluidSlot.removeItem,
            NR_FluidSlot.verifyItem,
            nil
        )
        self.itemDropBox.allowDropAlways = true
        self.itemDropBox.onMouseDown     = NR_FluidSlot.clickedDropBox
        self.itemDropBox.player          = self.player
        self.itemDropBox:initialise()
        if self.container then
            self.itemDropBox:setStoredItem(self.container:getOwner())
        end
        self.itemDropBox:setToolTip(true, getText("Fluid_Drag_Container"))
        self.itemDropBox.toolTipTextItem = getText("Fluid_Dropbox_Remove")
        self:addChild(self.itemDropBox)
    end

    if self.container and self.container:getFluidContainer() then
        self.fluidBar:setContainer(self.container:getFluidContainer())
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidSlot:prerender()
    self:drawRect(0, 0, self.width, self.height, 0.9, 0.08, 0.08, 0.08)
    if self.isInvalid then
        self:drawRect(0, 0, self.width, self.height, 0.3, 0.6, 0.1, 0.1)
    end
end

function NR_FluidSlot:render()
    local pad  = self._pad
    local slh  = self._slh
    local bsz  = self._bsz
    local tagW = self._tagW

    self:drawRectBorder(0, 0, self.width, self.height, 0.6, 0.25, 0.25, 0.25)

    -- Title: Source / Target
    local titleStr = self.isLeft and getText("Fluid_Source") or getText("Fluid_Target")
    local titleY   = pad + (slh - FONT_HGT_SMALL) / 2
    self:drawTextCentre(titleStr, self.width / 2, titleY, 1, 1, 1, 0.7, UIFont.Small)

    -- Container name (next to dropbox if any)
    local nameX = pad + (self.isItem and (bsz + pad) or 0)
    local nameY = pad + slh + pad
    local nameStr = ""
    if self.container and self.container:getFluidContainer() then
        nameStr = self.container:getFluidContainer():getTranslatedContainerName()
    elseif self.itemDropBox and self.itemDropBox.storedItem then
        nameStr = self.itemDropBox.storedItem:getFluidContainer():getTranslatedContainerName()
    end
    if nameStr ~= "" then
        self:drawText(nameStr, nameX, nameY, 1, 1, 1, 0.9, UIFont.Small)
    end

    -- Capacity / Used / Free
    local fc = self:getContainer()
    if fc then
        local capacity = fc:getCapacity()
        local stored   = fc:getAmount()
        local free     = capacity - stored
        local hidden   = fc:isHiddenAmount()

        local capStr  = hidden and getText("Fluid_Unknown") or FluidUtil.getAmountFormatted(capacity)
        local usedStr = hidden and getText("Fluid_Unknown") or FluidUtil.getAmountFormatted(stored)
        local freeStr = hidden and getText("Fluid_Unknown") or FluidUtil.getAmountFormatted(free)

        local capLabel  = getText("Fluid_Capacity") .. ":"
        local usedLabel = getText("Fluid_Stored")   .. ":"
        local freeLabel = getText("Fluid_Free")     .. ":"

        local xPivot = pad + tagW
        local valX   = xPivot + VALUE_GAP
        local curY   = pad + slh + pad + bsz

        NR_DrawUtils.drawLabelValue(self,capLabel,  capStr,  xPivot, valX, curY)
        curY = curY + slh
        NR_DrawUtils.drawLabelValue(self,usedLabel, usedStr, xPivot, valX, curY)
        curY = curY + slh
        NR_DrawUtils.drawLabelValue(self,freeLabel, freeStr, xPivot, valX, curY)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Resize
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidSlot:recalculateWidth()
    local pad  = self._pad
    local bsz  = self._bsz
    local tm   = getTextManager()

    local valW, nameW = 0, 0
    if self.container and self.container:getFluidContainer() then
        local fc = self.container:getFluidContainer()
        valW = math.max(
            tm:MeasureStringX(UIFont.Small, FluidUtil.getAmountFormatted(fc:getCapacity())),
            tm:MeasureStringX(UIFont.Small, FluidUtil.getAmountFormatted(fc:getAmount())),
            tm:MeasureStringX(UIFont.Small, FluidUtil.getAmountFormatted(fc:getCapacity() - fc:getAmount()))
        )
        nameW = tm:MeasureStringX(UIFont.Small, fc:getTranslatedContainerName())
    else
        valW = tm:MeasureStringX(UIFont.Small, "9999 mL")
    end

    local contentW = math.max(pad + self._tagW + VALUE_GAP + valW, pad + bsz + pad + nameW)
    local newW     = contentW + pad + FLUID_BAR_W + pad

    if newW ~= self.width then
        self:setWidth(newW)
        self.fluidBar:setX(newW - pad - FLUID_BAR_W)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- API — ISFluidContainerPanel-compatible
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidSlot:getContainer()
    if self.container and self.container:getFluidContainer() then
        return self.container:getFluidContainer()
    end
    return nil
end

function NR_FluidSlot:getContainerOwner()
    if self.container then
        return self.container:getOwner()
    end
    return nil
end

function NR_FluidSlot:getContainerOwnerObject()
    local itemOrObject = self:getContainerOwner()
    if instanceof(itemOrObject, "InventoryItem") then
        return itemOrObject:getContainer()
    end
    if instanceof(itemOrObject, "IsoObject") then
        return itemOrObject:getSquare()
    end
    return nil
end

function NR_FluidSlot:setPanelLocked(b)
    if self.itemDropBox then
        self.itemDropBox.isLocked = b
    end
    self.isPanelLocked = b
end

function NR_FluidSlot:setInvalid(b)
    self.isInvalid = b
end

function NR_FluidSlot:setIsLeft(b)
    self.isLeft = b
end

function NR_FluidSlot:onClose()
    if self.containerCopy then
        FluidContainer.DisposeContainer(self.containerCopy)
        self.containerCopy = nil
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Item drop box callbacks (logic preserved from ISFluidContainerPanel)
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidSlot:clickedDropBox(_, _)
    -- self here is ISItemDropBox; self.parent is the NR_FluidSlot
    local slot      = self.parent
    local validItems = slot.itemDropBox:getValidItems()
    if #validItems == 0 then return end
    local playerNum = slot.player:getPlayerNum()
    local oldFocus  = JoypadState.players[playerNum + 1] and JoypadState.players[playerNum + 1].focus or nil
    local cx = slot.parent:getAbsoluteX() + slot.parent:getWidth()
    local cy = slot.parent:getAbsoluteY() + slot:getY()
    local context = ISContextMenu.get(playerNum, cx, cy)
    local addedItems = {}
    for _, item in ipairs(validItems) do
        local name = item:getName() .. " (" .. round(item:getFluidContainer():getAmount() * 1000, 2) .. " mL)"
        if not addedItems[name] then
            addedItems[name] = item
        end
    end
    for name, v in pairs(addedItems) do
        context:addOption(name, slot.itemDropBox, ISItemDropBox.onDropItem, v)
    end
    if slot.isLeft then
        cx = slot.parent:getAbsoluteX() - context:getWidth()
        context:setSlideGoalX(cx + 20, cx)
    end
    context:bringToTop()
    if oldFocus then
        context.origin    = oldFocus
        context.mouseOver = 1
        setJoypadFocus(playerNum, context)
    end
end

function NR_FluidSlot:addItem(_items)
    local list = ArrayList.new()
    for _, item in ipairs(_items) do
        if not list:contains(item) then list:add(item) end
    end
    if list:size() == 1 then
        self:addItemAux(_items[1])
        return
    end
    local playerNum = self.player:getPlayerNum()
    local context = ISContextMenu.get(playerNum, self.itemDropBox:getAbsoluteX() + 16, self.itemDropBox:getAbsoluteY() + 16)
    list:clear()
    for _, item in ipairs(_items) do
        if not list:contains(item) then
            local option = context:addColorBoxOption(item:getName(), self, self.addItemAux, item)
            local c = item:getFluidContainer():getColor()
            option.color.r = c:getRedFloat()
            option.color.g = c:getGreenFloat()
            option.color.b = c:getBlueFloat()
            list:add(item)
        end
    end
    context.mouseOver = 1
end

function NR_FluidSlot:addItemAux(_item)
    if not (self.funcTarget and self.onContainerAdd) or not self.overrideAddFull then
        self.itemDropBox:setStoredItem(_item)
        self.fluidBar:setContainer(_item:getFluidContainer())
        self.container     = ISFluidContainer:new(_item:getFluidContainer())
        self.containerCopy = _item:getFluidContainer():copy()
    end
    if self.funcTarget and self.onContainerAdd then
        self.onContainerAdd(self.funcTarget, _item, self)
    end
end

function NR_FluidSlot:removeItem()
    local oldItem = self.itemDropBox.storedItem
    if not (self.funcTarget and self.onContainerRemove) or not self.overrideRemoveFull then
        self.itemDropBox:setStoredItem(nil)
        self.container = nil
        self.fluidBar:setContainer(nil)
        if self.containerCopy then
            FluidContainer.DisposeContainer(self.containerCopy)
        end
        self.containerCopy = nil
    end
    if self.funcTarget and self.onContainerRemove then
        self.onContainerRemove(self.funcTarget, oldItem, self)
    end
end

function NR_FluidSlot:verifyItem(_item)
    if self.funcTarget and self.onContainerVerify then
        return self.onContainerVerify(self.funcTarget, _item, self)
    end
    return _item and _item:getFluidContainer()
end
