-- NR_FluidTransferPanel.lua
-- NeatUI replacement for ISFluidTransferUI.
-- Header: "Transfer Liquid" + close button.
-- Body: NR_FluidSlot (left) | center column (swap, max label, slider, pouring label, pour) | NR_FluidSlot (right).

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Config"
require "NeatRocco/NR_Fluid/NR_FluidSlot"

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

NR_FluidTransferPanel = NR_BasePanel:derive("NR_FluidTransferPanel")
NR_FluidTransferPanel.players      = {}
NR_FluidTransferPanel.cheatSkill   = false
NR_FluidTransferPanel.cheatTransfer = false

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT     = FONT_HGT_SMALL + 6

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidTransferPanel:getWindowTitle()
    local base = getText("Fluid_Transfer_Fluids")
    if self._fluidName and self._fluidName ~= "" then
        return base .. " - " .. self._fluidName
    end
    return base
end

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidTransferPanel:new(x, y, width, height, character, container, source)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.character  = character
    o.playerNum  = character:getPlayerNum()
    o.container  = container
    o.source     = source
    o.isIsoPanel = not (container:isItem() or container:isResource())

    o.disableTransfer   = false
    o.disableSwap       = false
    o.action            = false
    o.info              = { maxTransfer = 0, transferring = 0 }
    o.errorDefault      = ""
    o.fromPreviousOwner = nil
    o.toPreviousOwner   = nil
    o.disableJoypadNavigation = true

    o.transferColor = { r = 0.0, g = 1.0, b = 0.0, a = 0.5 }

    o._fluidName        = ""
    o._errorText        = ""
    o._maxTransferStr   = ""
    o._transferringStr  = ""

    NR_BasePanel.initBase(o)
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidTransferPanel:initialise()
    ISPanelJoypad.initialise(self)
end

function NR_FluidTransferPanel:createChildren()
    NR_BasePanel.createChildren(self)

    local pad = NR_Config.padding
    local slh = NR_Config.smallLineHeight
    local bsz = NR_Config.buttonSize
    local hh  = NR_Config.headerHeight
    local tm  = getTextManager()

    -- Pre-compute slot dimensions (same formula as NR_FluidSlot:new)
    local tagW = math.max(
        tm:MeasureStringX(UIFont.Small, getText("Fluid_Capacity") .. ":"),
        tm:MeasureStringX(UIFont.Small, getText("Fluid_Stored")   .. ":"),
        tm:MeasureStringX(UIFont.Small, getText("Fluid_Free")     .. ":")
    )
    local fc = self.container:getFluidContainer()
    local valW = math.max(
        tm:MeasureStringX(UIFont.Small, FluidUtil.getAmountFormatted(fc:getCapacity())),
        tm:MeasureStringX(UIFont.Small, FluidUtil.getAmountFormatted(fc:getAmount())),
        tm:MeasureStringX(UIFont.Small, FluidUtil.getAmountFormatted(fc:getCapacity() - fc:getAmount()))
    )
    local nameW     = tm:MeasureStringX(UIFont.Small, fc:getTranslatedContainerName())
    local contentW  = math.max(pad + tagW + 8 + valW, pad + bsz + pad + nameW)
    local slotW     = contentW + pad + (FONT_HGT_SMALL + 6) + pad
    local slotH  = pad + slh + pad + bsz + slh * 3 + pad

    -- Center column minimum width
    local centerMinW = math.max(
        tm:MeasureStringX(UIFont.Small, getText("Fluid_Max_Transfer") .. ": 9999 mL"),
        tm:MeasureStringX(UIFont.Small, getText("Fluid_Transferring") .. ": 9999 mL"),
        bsz * 3
    ) + pad * 2

    -- Slot Y: below header + error label
    local slotsY  = hh + pad + slh + pad
    local slotLeftX  = pad
    local slotRightX = pad + slotW + pad + centerMinW + pad

    -- Panel size
    local totalW = slotRightX + slotW + pad
    local centerX = slotLeftX + slotW + pad

    -- Center column layout (tracked top-to-bottom)
    local curY = slotsY

    -- Swap button (centered in center column)
    local swapTex = getTexture("media/ui/NeatRocco/ICON/Icon_Switch.png")
    self.btnSwap = NI_SquareButton:new(
        centerX + math.floor((centerMinW - bsz) / 2), curY,
        bsz, swapTex, self,
        function() self:onClickSwap() end
    )
    self.btnSwap:initialise()
    self.btnSwap:setActive(true)
    self:addChild(self.btnSwap)
    curY = curY + bsz + pad

    -- Max transfer label Y (drawn in render)
    self._maxTransferLabelY = curY
    curY = curY + slh + pad

    -- Slider
    self.slider = ISSliderPanel:new(centerX, curY, centerMinW, BUTTON_HGT, self, NR_FluidTransferPanel.onSlider)
    self.slider:initialise()
    self.slider:instantiate()
    self.slider:setValues(0.0, 1.0, 0.01, 0.1, true)
    self.slider:setCurrentValue(0.0, true)
    self.slider.valueLabel = false
    self.slider.customData = {}
    self:addChild(self.slider)
    curY = curY + BUTTON_HGT + pad

    -- Transferring progress bar Y (drawn in render)
    self._transferringBarY = curY
    curY = curY + NR_Config.barHeight + pad

    -- Pour button (centered in center column)
    local pourTex = getTexture("media/ui/NeatRocco/ICON/Icon_ArrowDown.png")
    self.btnPour = NI_SquareButton:new(
        centerX + math.floor((centerMinW - bsz) / 2), curY,
        bsz, pourTex, self,
        function() self:onClickPour() end
    )
    self.btnPour:initialise()
    self.btnPour:setActive(true)
    self:addChild(self.btnPour)

    local centerBottom = curY + bsz

    -- Left slot
    local containerLeft = self.source or not self.container:getFluidContainer():isEmpty()
    self.slotLeft = NR_FluidSlot:new(slotLeftX, slotsY, self.character,
        containerLeft and self.container or nil, true, self.isIsoPanel)
    self.slotLeft.funcTarget        = self
    self.slotLeft.onContainerAdd    = NR_FluidTransferPanel.onContainerAdd
    self.slotLeft.onContainerRemove = NR_FluidTransferPanel.onContainerRemove
    self.slotLeft.onContainerVerify = NR_FluidTransferPanel.onContainerVerify
    self.slotLeft:initialise()
    self.slotLeft:instantiate()
    self:addChild(self.slotLeft)

    -- Right slot
    self.slotRight = NR_FluidSlot:new(slotRightX, slotsY, self.character,
        (not containerLeft) and self.container or nil, false, self.isIsoPanel)
    self.slotRight.funcTarget        = self
    self.slotRight.onContainerAdd    = NR_FluidTransferPanel.onContainerAdd
    self.slotRight.onContainerRemove = NR_FluidTransferPanel.onContainerRemove
    self.slotRight.onContainerVerify = NR_FluidTransferPanel.onContainerVerify
    self.slotRight:initialise()
    self.slotRight:instantiate()
    self:addChild(self.slotRight)

    -- Save geometry for swap / render
    self._slotLeftX   = slotLeftX
    self._slotRightX  = slotRightX
    self._centerX     = centerX
    self._centerMinW  = centerMinW
    self._slotsY      = slotsY

    -- Finalize panel size
    local totalH = math.max(slotsY + slotH, centerBottom) + pad
    self:setWidth(totalW)
    self:setHeight(totalH)

    -- Recalculate header with final width
    self.header:calculateLayout(self.width, hh)

    -- Label positions
    self._errorTextY = hh + pad

    self:setMaxTransfer(0)
    self:setTransferring(0)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Labels
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidTransferPanel:setMaxTransfer(value)
    self._maxTransferStr = getText("Fluid_Max_Transfer") .. ": " .. FluidUtil.getAmountFormatted(value)
end

function NR_FluidTransferPanel:setTransferring(value)
    self._transferringStr = getText("Fluid_Transferring") .. ": " .. FluidUtil.getAmountFormatted(value)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Container callbacks
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidTransferPanel:onContainerAdd(_item, _panel)
    self:validatePanel(true)
    self:resetSlider()
    self:recalculateLayout()
end

function NR_FluidTransferPanel:onContainerRemove(_item, _panel)
    self:validatePanel(true)
    self:resetSlider()
    self:recalculateLayout()
end

function NR_FluidTransferPanel:recalculateLayout()
    local pad = NR_Config.padding
    local bsz = NR_Config.buttonSize

    self.slotLeft:recalculateWidth()
    self.slotRight:recalculateWidth()

    local centerX    = self._slotLeftX + self.slotLeft.width + pad
    local slotRightX = centerX + self._centerMinW + pad

    self._centerX    = centerX
    self._slotRightX = slotRightX
    self.slotRight:setX(slotRightX)

    local btnOffX = math.floor((self._centerMinW - bsz) / 2)
    self.btnSwap:setX(centerX + btnOffX)
    self.slider:setX(centerX)
    self.btnPour:setX(centerX + btnOffX)

    self:setWidth(slotRightX + self.slotRight.width + pad)
    self.header:calculateLayout(self.width, NR_Config.headerHeight)
end

function NR_FluidTransferPanel:onContainerVerify(_item, _panel)
    if self.action then return false end
    if _item and _item:getFluidContainer() and _item:getFluidContainer():canPlayerEmpty() then
        if not _item:isInPlayerInventory() then return false end
        if _panel == self.slotLeft  and self.slotRight:getContainerOwner() then
            return _item ~= self.slotRight:getContainerOwner()
        end
        if _panel == self.slotRight and self.slotLeft:getContainerOwner() then
            return _item ~= self.slotLeft:getContainerOwner()
        end
        return true
    end
    return false
end

function NR_FluidTransferPanel:resetSlider()
    if self.slotLeft:getContainer() and self.slotRight:getContainer()
       and FluidContainer.CanTransfer(self.slotLeft:getContainer(), self.slotRight:getContainer()) then
        self.slider:setCurrentValue(self.slider.maxValue)
    else
        self.slider:setCurrentValue(0.0)
    end
end

function NR_FluidTransferPanel:onSlider(_value, _slider)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Validate (logic preserved from ISFluidTransferUI)
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidTransferPanel:validatePanel(forceUpdate)
    if self.isIsoPanel then
        if ISFluidUtil.validateContainer(self.container) and self.container:getOwner()
           and self.container:getOwner():getSquare() and self.character then
            local square = self.container:getOwner():getSquare()
            local dist   = ISFluidUtil.isoMaxPanelDist
            local cx, cy = self.character:getX(), self.character:getY()
            local sx, sy = square:getX(), square:getY()
            if cx < sx - dist or cx > sx + dist or cy < sy - dist or cy > sy + dist then
                self:close() ; return
            end
        else
            self:close() ; return
        end
    end

    self.disableTransfer = false
    self.disableSwap     = false
    self.slotLeft:setPanelLocked(false)
    self.slotRight:setPanelLocked(false)

    if self.action then
        if ISTimedActionQueue.hasAction(self.action) then
            self.disableTransfer = true
            self.disableSwap     = true
            self.slotLeft:setPanelLocked(true)
            self.slotRight:setPanelLocked(true)
        else
            self.action = false
        end
    end

    local maxTransfer  = 0
    local transferring = 0
    local from = self.slotLeft:getContainer()
    local to   = self.slotRight:getContainer()

    if from and from:getPrimaryFluid() then
        self._fluidName = (from:getUiName()):gsub("%b()$", "")
    else
        self._fluidName = ""
    end

    local fromOwnerDiff = self.fromPreviousOwner ~= nil
        and from ~= nil
        and self.fromPreviousOwner ~= self.slotLeft:getContainerOwnerObject()
    local toOwnerDiff = self.toPreviousOwner ~= nil
        and to ~= nil
        and self.toPreviousOwner ~= self.slotRight:getContainerOwnerObject()

    if (from and not ISFluidUtil.validateContainer(self.slotLeft.container))
       or (to and not ISFluidUtil.validateContainer(self.slotRight.container))
       or fromOwnerDiff or toOwnerDiff then
        self:close() ; return
    end

    self.fromPreviousOwner = from and self.slotLeft:getContainerOwnerObject()  or nil
    self.toPreviousOwner   = to   and self.slotRight:getContainerOwnerObject() or nil

    self.slotLeft.fluidBar:resetRatioNew()
    self.slotLeft.fluidBar:setContainerAdd(nil)
    self.slotLeft.fluidBar:setContainerMixed(nil)
    self.slotRight.fluidBar:resetRatioNew()
    self.slotRight.fluidBar:setContainerAdd(nil)
    self.slotRight.fluidBar:setContainerMixed(nil)

    self.slotLeft:setInvalid(false)
    self.slotRight:setInvalid(false)

    if (not self.disableTransfer) and from and to and FluidContainer.CanTransfer(from, to) then
        self._errorText  = self.errorDefault
        local fromAmount = from:getAmount()
        local toFree     = to:getCapacity() - to:getAmount()
        maxTransfer = PZMath.min(fromAmount, toFree)
        maxTransfer = FluidUtil.roundTransfer(maxTransfer)

        if maxTransfer <= 0 then
            self.disableTransfer = true
        else
            transferring = maxTransfer * self.slider:getCurrentValue()
            transferring = FluidUtil.roundTransfer(transferring)
            if transferring <= 0 then
                transferring = 0
                self.disableTransfer = true
            end
            self.slotLeft.fluidBar:setRatioNew((from:getAmount() - transferring) / from:getCapacity())
            self.slotRight.fluidBar:setRatioNew((to:getAmount() + transferring) / to:getCapacity())
            self.slotRight.fluidBar:setContainerAdd(from)
            if NR_FluidTransferPanel.cheatSkill then
                self.slotRight.fluidBar:setContainerMixed(self.slotRight.containerCopy, true)
            end
        end
    else
        if not self.disableTransfer then
            self._errorText = FluidContainer.GetTransferReason(from, to)
            if not from or from:isEmpty() then
                self.slotLeft:setInvalid(true)
            elseif not to or to:isFull() then
                self.slotRight:setInvalid(true)
            else
                self.slotLeft:setInvalid(true)
                self.slotRight:setInvalid(true)
            end
        else
            self._errorText = getText("Fluid_Reason_Transfer")
            self.slotLeft:setInvalid(true)
            self.slotRight:setInvalid(true)
        end
        self.disableTransfer = true
    end

    if self.info.maxTransfer ~= maxTransfer or forceUpdate then
        self.info.maxTransfer = maxTransfer
        self:setMaxTransfer(maxTransfer)
    end
    if self.info.transferring ~= transferring or forceUpdate then
        self.info.transferring = transferring
        self:setTransferring(transferring)
        if from and self.slotRight.containerCopy and self.slotRight:getContainer() then
            self.slotRight.containerCopy:copyFluidsFrom(self.slotRight:getContainer())
            FluidContainer.Transfer(from, self.slotRight.containerCopy, transferring, true)
        end
    end

    self.btnPour:setActive(not self.disableTransfer)
    self.btnSwap:setActive(not self.disableSwap)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Update
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidTransferPanel:update()
    self:validatePanel()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidTransferPanel:prerender()
    NR_BasePanel.prerender(self)
end

function NR_FluidTransferPanel:render()
    ISPanelJoypad.render(self)

    -- Error text (centered, red-ish)
    if self._errorText ~= "" then
        self:drawTextCentre(self._errorText, self.width / 2, self._errorTextY, 0.9, 0.4, 0.4, 1, UIFont.Small)
    end

    -- Max transfer label (center column)
    if self._maxTransferStr ~= "" then
        local cx = self._centerX + math.floor(self._centerMinW / 2)
        self:drawTextCentre(self._maxTransferStr, cx, self._maxTransferLabelY, 1, 1, 1, 0.7, UIFont.Small)
    end

    -- Transferring progress bar (center column)
    local barH = NR_Config.barHeight
    local pct  = (self.action and self.action.action) and self.action:getJobDelta() or 0
    self:drawBarWithLabel(self._centerX, self._transferringBarY, self._centerMinW, barH, pct, self._transferringStr, 0.2, 0.8, 0.3)

    -- Joypad bumper hints
    if getJoypadData(self.playerNum) then
        if self.slotLeft and self.slotLeft.itemDropBox then
            local tex = Joypad.Texture.LBumper
            self:drawTextureScaled(tex,
                self.slotLeft.x + self.slotLeft.width / 2 - tex:getWidth() / 2,
                self.slotLeft.y - tex:getHeight(),
                tex:getWidth(), tex:getHeight(), 1, 1, 1, 1)
        end
        local tex = Joypad.Texture.RBumper
        self:drawTextureScaled(tex,
            self.slotRight.x + self.slotRight.width / 2 - tex:getWidth() / 2,
            self.slotRight.y - tex:getHeight(),
            tex:getWidth(), tex:getHeight(), 1, 1, 1, 1)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Button callbacks
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidTransferPanel:onClickPour()
    if getCore():getDebug() and NR_FluidTransferPanel.cheatTransfer and not isClient() then
        FluidContainer.Transfer(self.slotLeft:getContainer(), self.slotRight:getContainer(), self.info.transferring)
        self.slider:setCurrentValue(0)
        return
    end
    if (not self.isIsoPanel) or ISFluidUtil.doWalkTo(self.character, self.container) then
        if (not self.disableTransfer)
           and FluidContainer.CanTransfer(self.slotLeft:getContainer(), self.slotRight:getContainer()) then
            local leftCopy  = self.slotLeft.container:copy()
            local rightCopy = self.slotRight.container:copy()
            self.action = ISFluidTransferAction:new(
                self.character,
                leftCopy,  leftCopy:getFluidObject(),
                rightCopy, rightCopy:getFluidObject(),
                self.info.transferring
            )
            ISTimedActionQueue.add(self.action)
            self.slider:setCurrentValue(0)
            self.disableTransfer = true
            self.slotLeft:setPanelLocked(true)
            self.slotRight:setPanelLocked(true)
        end
    end
end

function NR_FluidTransferPanel:onClickSwap()
    local tmp      = self.slotLeft
    self.slotLeft  = self.slotRight
    self.slotLeft:setX(self._slotLeftX)
    self.slotLeft:setIsLeft(true)

    self.slotRight = tmp
    self.slotRight:setIsLeft(false)

    local tmpOwner         = self.toPreviousOwner
    self.toPreviousOwner   = self.fromPreviousOwner
    self.fromPreviousOwner = tmpOwner

    self:validatePanel()
    self:recalculateLayout()
    self:resetSlider()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidTransferPanel:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self:setISButtonForA(self.btnPour)
    self:setISButtonForB(nil)
    self:setISButtonForX(self.btnSwap)
    self.joypadButtonsY = {}
    self.joypadButtons  = {}
    self.joypadIndexY   = 1
    self.joypadIndex    = 1
    self:insertNewLineOfButtons(self.slider)
    self.slider:setJoypadFocused(true, joypadData)
end

function NR_FluidTransferPanel:onJoypadDown(button, joypadData)
    if button == Joypad.BButton then self:close() ; return end
    if button == Joypad.LBumper then self:setOrClearItem(self.slotLeft)  ; return end
    if button == Joypad.RBumper then self:setOrClearItem(self.slotRight) ; return end
    ISPanelJoypad.onJoypadDown(self, button, joypadData)
end

function NR_FluidTransferPanel:setOrClearItem(slot)
    if slot.itemDropBox then
        if slot.itemDropBox.boxOccupied then
            slot.itemDropBox:onRightMouseUp(0, 0)
        else
            slot.itemDropBox:onMouseDown(0, 0)
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidTransferPanel:close()
    local playerNum = self.playerNum
    if NR_FluidTransferPanel.players[playerNum] then
        NR_FluidTransferPanel.players[playerNum].x        = self:getX()
        NR_FluidTransferPanel.players[playerNum].y        = self:getY()
        NR_FluidTransferPanel.players[playerNum].instance = nil
    end
    if self.slotLeft  then self.slotLeft:onClose()  end
    if self.slotRight then self.slotRight:onClose() end
    self:closeBase()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Open
-- ----------------------------------------------------------------------------------------------------- --

function NR_FluidTransferPanel.OpenPanel(character, container, source)
    if not ISFluidUtil.validateContainer(container) then return end
    if not container:isValid()                       then return end
    if not character                                 then return end

    local playerNum = character:getPlayerNum()
    local x = getMouseX() + 10
    local y = getMouseY() + 10
    local adjustPos = true

    if NR_FluidTransferPanel.players[playerNum] then
        if NR_FluidTransferPanel.players[playerNum].instance then
            NR_FluidTransferPanel.players[playerNum].instance:close()
        end
        if NR_FluidTransferPanel.players[playerNum].x then
            x = NR_FluidTransferPanel.players[playerNum].x
            y = NR_FluidTransferPanel.players[playerNum].y
            adjustPos = false
        end
    else
        NR_FluidTransferPanel.players[playerNum] = {}
    end

    local panel = NR_FluidTransferPanel:new(x, y, 100, 100, character, container, source)
    panel:initialise()
    panel:instantiate()
    panel:setVisible(true)
    panel:addToUIManager()

    NR_FluidTransferPanel.players[playerNum].instance = panel

    if getJoypadData(playerNum) or (adjustPos and instanceof(container:getOwner(), "IsoObject")) then
        panel:centerOnScreen(playerNum)
        NR_FluidTransferPanel.players[playerNum].x = panel.x
        NR_FluidTransferPanel.players[playerNum].y = panel.y
    end

    if getJoypadData(playerNum) then
        setJoypadFocus(playerNum, panel)
    end
end
