-- NR_Header.lua
-- NeatUI-styled draggable header for all Neat Rocco panels.
-- Derives from ISTableLayout. Provides icon, title, close button, optional power/minSize/info buttons.

require "NeatRocco/NR_Config"

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

NR_Header = ISTableLayout:derive("NR_Header")

-- ----------------------------------------------------------------------------------------------------- --
-- Size clamp helper (same pattern as NC_CraftHeader)
-- ----------------------------------------------------------------------------------------------------- --

local function clampWindowSizeAndPos(win, factor)
    if not win or not getCore then return end
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    if not sw or not sh then return end

    local w = win.width or (win.getWidth and win:getWidth()) or 0
    local h = win.height or (win.getHeight and win:getHeight()) or 0

    local changed = false
    local targetW, targetH = w, h

    if w > sw then targetW = math.floor(sw * factor) ; changed = true end
    if h > sh then targetH = math.floor(sh * factor) ; changed = true end

    if changed then
        if win.calculateLayout then
            win:calculateLayout(targetW, targetH)
        else
            if win.setWidth  then win:setWidth(targetW)  end
            if win.setHeight then win:setHeight(targetH) end
        end
    end

    local curW = win.width or targetW
    local curH = win.height or targetH
    local newX = win.x or 0
    local newY = win.y or 0

    if newX < 0 then newX = 0 end
    if newY < 0 then newY = 0 end
    if (newX + curW) > sw then newX = math.max(0, sw - curW) end
    if (newY + curH) > sh then newY = math.max(0, sh - curH) end

    if newX ~= (win.x or 0) then
        if win.setX then win:setX(newX) else win.x = newX end
    end
    if newY ~= (win.y or 0) then
        if win.setY then win:setY(newY) else win.y = newY end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor / initialise
-- ----------------------------------------------------------------------------------------------------- --

function NR_Header:new(x, y, width, height, parentWindow)
    local o = ISTableLayout:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.parentWindow = parentWindow
    o.padding      = NR_Config.padding
    o.buttonSize   = NR_Config.buttonSize
    o.iconSize     = math.floor((height * 0.8) / 4) * 4
    o.moving       = false

    o.closeIcon   = getTexture("media/ui/NeatUI/Icon/Icon_False.png")
    o.minSizeIcon = getTexture("media/ui/NeatRocco/ICON/Icon_MinSize.png")

    return o
end

function NR_Header:initialise()
    ISTableLayout.initialise(self)
end

-- ----------------------------------------------------------------------------------------------------- --
-- createChildren
-- Layout without info : [icon | title | fill | fill | rightBtnPanel]
-- Layout with info    : [leftBtnPanel | icon | title | fill | fill | rightBtnPanel]
-- leftBtnPanel appears only when parentWindow implements onClickInfo()
-- ----------------------------------------------------------------------------------------------------- --

function NR_Header:createChildren()
    self:addRowFill(nil)

    local hasInfo     = (self.parentWindow.getInfoText ~= nil) or (self.parentWindow.onClickInfo ~= nil)
    local hasCollapse = (self.parentWindow.onClickCollapse ~= nil)
    self._hasInfo     = hasInfo
    self._hasCollapse = hasCollapse

    local colIdx = 0

    -- Column left : collapse button and/or info button (optional)
    if hasInfo or hasCollapse then
        local hasBoth = hasInfo and hasCollapse
        local leftColumn = self:addColumn(nil)
        leftColumn.minimumWidth = hasBoth
            and (self.buttonSize * 2 + self.padding * 3)
            or  (self.buttonSize + self.padding * 2)
        self:createLeftButtonPanel()
        self:setElement(colIdx, 0, self.leftButtonPanel)
        colIdx = colIdx + 1
    end

    -- Column icon + title (single column)
    self._iconTitleCol = colIdx
    local titleStr    = self.parentWindow.getWindowTitle and self.parentWindow:getWindowTitle() or ""
    local titleWidth  = getTextManager():MeasureStringX(UIFont.Medium, titleStr)
    local hasIcon     = self.parentWindow.getWindowIcon ~= nil and self.parentWindow:getWindowIcon() ~= nil
    local iconW       = hasIcon and (self.iconSize + self.padding) or 0
    local iconTitleColumn = self:addColumn(nil)
    iconTitleColumn.minimumWidth = iconW + titleWidth + self.padding * 2
    colIdx = colIdx + 1

    -- 2 fill columns (anchors right button panel)
    self:addColumnFill(nil)
    self:addColumnFill(nil)
    colIdx = colIdx + 2

    -- Column right : power (optional) + minSize (optional) + close button panel
    self._hasMinSize = (self.parentWindow.calculateLayout ~= nil)
    self._hasPower   = (self.parentWindow.hasPowerButton == true)
    local powerW    = self._hasPower   and (self.buttonSize * 2 + self.padding) or 0
    local minSizeW  = self._hasMinSize and (self.buttonSize + self.padding)     or 0
    local rightMinW = powerW + minSizeW + self.buttonSize + self.padding
    local rightColumn = self:addColumn(nil)
    rightColumn.minimumWidth = rightMinW
    self:createRightButtonPanel()
    self:setElement(colIdx, 0, self.rightButtonPanel)
end

function NR_Header:createLeftButtonPanel()
    local bsz     = self.buttonSize
    local pad     = self.padding
    local hasBoth = self._hasInfo and self._hasCollapse
    local panelW  = hasBoth and (bsz * 2 + pad * 3) or (bsz + pad * 2)

    self.leftButtonPanel = ISPanel:new(0, 0, panelW, self.height)
    self.leftButtonPanel:noBackground()
    self.leftButtonPanel:initialise()

    local buttonY = math.floor((self.height - bsz) / 2)
    local curX    = pad

    if self._hasCollapse then
        self.collapseButton = NI_SquareButton:new(
            curX, buttonY, bsz,
            getTexture("media/ui/NeatRocco/ICON/Icon_ArrowDown.png"),
            self,
            function() self.parentWindow:onClickCollapse() end
        )
        self.collapseButton:initialise()
        self.collapseButton:setActive(true)
        self.collapseButton:setActiveColor(0.95, 0.5, 0.1)
        self.leftButtonPanel:addChild(self.collapseButton)
        curX = curX + bsz + pad
    end

    if self._hasInfo then
        self.infoButton = NI_SquareButton:new(
            curX, buttonY, bsz,
            getTexture("media/ui/NeatUI/numbers_outline/Query.png"),
            self,
            function()
                if self.parentWindow.onClickInfo then
                    self.parentWindow:onClickInfo()
                else
                    self:onClickInfo()
                end
            end
        )
        self.infoButton:initialise()
        self.infoButton:setActive(false)
        -- When paired with collapse: start hidden, shown dynamically per tab via setInfo()
        if hasBoth then self.infoButton:setVisible(false) end
        self.leftButtonPanel:addChild(self.infoButton)
    end
end


function NR_Header:createRightButtonPanel()
    local bsz        = self.buttonSize
    local pad        = self.padding
    local hasMinSize = self._hasMinSize
    local hasPower   = self._hasPower

    local powerBtnW   = hasPower   and (bsz * 2 + pad) or 0
    local minSizeBtnW = hasMinSize and (bsz + pad)     or 0
    local panelWidth  = powerBtnW + minSizeBtnW + bsz + pad

    self.rightButtonPanel = ISPanel:new(0, 0, panelWidth, self.height)
    self.rightButtonPanel:noBackground()
    self.rightButtonPanel:initialise()

    local buttonY = math.floor((self.height - bsz) / 2)
    local curX    = 0

    -- Power button (optional — only when parentWindow.hasPowerButton == true)
    if hasPower then
        local bgTex      = getTexture("media/ui/NeatUI/Button/Background.png")
        local brdTex     = getTexture("media/ui/NeatUI/Button/Boarder.png")
        local iconOn     = getTexture("media/ui/NeatRocco/ICON/Icon_SwitchOn.png")
        local iconOff    = getTexture("media/ui/NeatRocco/ICON/Icon_SwitchOff.png")
        local _self = self
        local _bsz  = bsz

        self.powerButton = ISButton:new(curX, buttonY, bsz * 2, bsz, "", self, NR_Header.onClickPower)
        self.powerButton:initialise()
        self.powerButton:setDisplayBackground(false)
        self.powerButton.prerender = function(btn)
            local state = _self.parentWindow.getHeaderPowerState and _self.parentWindow:getHeaderPowerState() or "off"
            local r, g, b, icon
            if state == "on" then
                r, g, b = 0.2, 0.7, 0.3
                icon = iconOn
                btn.tooltip = getText("ContextMenu_Turn_Off")
            elseif state == "disabled" then
                r, g, b = NR_Config.panelBg, NR_Config.panelBg, NR_Config.panelBg
                icon = iconOff
                btn.tooltip = nil
            else
                r, g, b = 0.7, 0.2, 0.2
                icon = iconOff
                btn.tooltip = getText("ContextMenu_Turn_On")
            end
            local alpha = btn:isMouseOver() and 0.9 or 0.7
            btn:drawTextureScaled(bgTex,  0, 0, _bsz * 2, _bsz, alpha, r, g, b)
            btn:drawTextureScaled(brdTex, 0, 0, _bsz * 2, _bsz, 1, 0.4, 0.4, 0.4)
            btn:drawTextureScaled(icon,   0, 0, _bsz * 2, _bsz, 1, 0.9, 0.9, 0.9)
        end
        self.rightButtonPanel:addChild(self.powerButton)
        curX = curX + bsz * 2 + pad
    end

    -- MinSize button (only if parentWindow implements calculateLayout)
    if hasMinSize then
        self.minSizeButton = NI_SquareButton:new(
            curX, buttonY, bsz,
            self.minSizeIcon,
            self,
            function() self.parentWindow:calculateLayout(1, 1) end
        )
        self.minSizeButton:initialise()
        self.minSizeButton:setActive(false)
        self.rightButtonPanel:addChild(self.minSizeButton)
        curX = curX + bsz + pad
    end

    -- Close button
    self.closeButton = NI_SquareButton:new(
        curX, buttonY, bsz,
        self.closeIcon,
        self,
        function() self.parentWindow:close() end
    )
    self.closeButton:initialise()
    self.closeButton:setActive(true)
    self.closeButton:setActiveColor(0.8, 0.2, 0.2)
    self.rightButtonPanel:addChild(self.closeButton)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Callbacks
-- ----------------------------------------------------------------------------------------------------- --

function NR_Header:onClickInfo()
    require "NeatRocco/NR_Generic/NR_ModalRichText"
    local pw  = self.parentWindow
    local raw = pw:getInfoText()

    if not self._infoUI then
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        self._infoUI = NR_ModalRichText:new(sw/2 - 300, sh/2 - 200, 600, 400, raw, false)
        self._infoUI:initialise()
        self._infoUI.alwaysOnTop = true
        self._infoUI.chatText:paginate()
        self._infoUI:setHeightToContents()
        self._infoUI:ignoreHeightChange()
        self._infoUI:setY(sh/2 - self._infoUI:getHeight()/2)
        self._infoUI:setVisible(true)
        self._infoUI:addToUIManager()
    elseif self._infoUI:isReallyVisible() then
        self._infoUI:removeFromUIManager()
    else
        self._infoUI:setVisible(true)
        self._infoUI:addToUIManager()
    end
end

function NR_Header:onClickPower()
    if self.parentWindow and self.parentWindow.onClickPower then
        self.parentWindow:onClickPower()
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Mouse (drag) — with NC_CraftHeader-style size clamp on move
-- ----------------------------------------------------------------------------------------------------- --

function NR_Header:onMouseDown()
    self.moving = true
    self:setCapture(true)
    return true
end

function NR_Header:onMouseMove(dx, dy)
    -- Notify parent window for hover-to-peek (e.g. NR_CharInfoPanel collapse)
    if self.parentWindow and self.parentWindow._onHeaderHover then
        self.parentWindow:_onHeaderHover()
    end
    if self.moving and self.parentWindow then
        self.parentWindow:setX(self.parentWindow.x + dx)
        self.parentWindow:setY(self.parentWindow.y + dy)
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        if sw and sh and (self.parentWindow.width > sw or self.parentWindow.height > sh) then
            clampWindowSizeAndPos(self.parentWindow, 0.90)
        end
        return true
    end
    return false
end

function NR_Header:onMouseMoveOutside(dx, dy)
    if self.moving and self.parentWindow then
        self.parentWindow:setX(self.parentWindow.x + dx)
        self.parentWindow:setY(self.parentWindow.y + dy)
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        if sw and sh and (self.parentWindow.width > sw or self.parentWindow.height > sh) then
            clampWindowSizeAndPos(self.parentWindow, 0.90)
        end
        return true
    end
    return false
end

function NR_Header:onMouseUp()
    if self.moving then
        self.moving = false
        self:setCapture(false)
        return true
    end
    return false
end

function NR_Header:onMouseUpOutside()
    if self.moving then
        self.moving = false
        self:setCapture(false)
        return true
    end
    return false
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_Header:prerender()
    local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainTitle_BG.png")
    if bg then
        local c = NR_Config.headerBg
        bg:render(self:getAbsoluteX(), self:getAbsoluteY(), self.width, self.height, c, c, c, NR_Config.bgAlpha)
    end
    self:drawRect(0, self.height - 1, self.width, 2, 1, 0, 0, 0)
end

function NR_Header:render()
    -- Icon + Title (single cell)
    local iconTitleCell = self:cell(self._iconTitleCol or 0, 0)
    if iconTitleCell then
        local pad   = self.padding
        local icon  = self.parentWindow.getWindowIcon and self.parentWindow:getWindowIcon() or nil
        local title = self.parentWindow.getWindowTitle and self.parentWindow:getWindowTitle() or ""
        local textY = iconTitleCell.y + (iconTitleCell.height - FONT_HGT_MEDIUM) / 2
        if icon then
            local iconY  = iconTitleCell.y + (iconTitleCell.height - self.iconSize) / 2
            self:drawTextureScaled(icon, iconTitleCell.x + pad, iconY, self.iconSize, self.iconSize, 1, 1, 1, 1)
            self:drawText(title, iconTitleCell.x + pad + self.iconSize + pad, textY, 1, 1, 1, 1, UIFont.Medium)
        else
            self:drawText(title, iconTitleCell.x + pad, textY, 1, 1, 1, 1, UIFont.Medium)
        end
    end
end
