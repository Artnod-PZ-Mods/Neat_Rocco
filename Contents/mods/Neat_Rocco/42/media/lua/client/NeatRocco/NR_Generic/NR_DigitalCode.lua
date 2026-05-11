-- NR_DigitalCode.lua
-- NeatUI-styled override of ISDigitalCode.
-- Derives from ISDigitalCode so all logic (digits, joypad, destroy) is inherited.
-- NR_MakePatch bypasses NR_DigitalCode:new(), so dimensions are set in initialise()
-- before the vanilla call so ISPanel.initialise() picks up the correct stencil size.

require "NeatRocco/NR_Config"

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

NR_DigitalCode = ISDigitalCode:derive("NR_DigitalCode")

local function layout()
    local btnSz  = NR_Config.buttonSize
    local pad    = NR_Config.padding
    local hpad   = math.floor(pad / 3)
    local fontH  = getTextManager():getFontHeight(UIFont.Small)
    local titleH = fontH + pad * 2

    local colsW  = pad + 3 * btnSz + 2 * pad + pad
    local titleW = math.max(
        getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_SetCode")),
        getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_EnterCode"))
    ) + pad * 2
    local w = math.max(colsW, titleW)
    local h = titleH + btnSz + hpad + btnSz + hpad + btnSz + pad + btnSz + pad

    local groupW   = 3 * btnSz + 2 * pad
    local colStartX = math.floor((w - groupW) / 2)

    return {
        w      = w,    h      = h,
        btnSz  = btnSz, pad   = pad,
        titleH = titleH,
        col1X  = colStartX,
        col2X  = colStartX + btnSz + pad,
        col3X  = colStartX + 2 * (btnSz + pad),
        upY    = titleH,
        numY   = titleH + btnSz + hpad,
        downY  = titleH + btnSz + hpad + btnSz + hpad,
        okY    = titleH + btnSz + hpad + btnSz + hpad + btnSz + pad,
    }
end

-- ----------------------------------------------------------------------------------------------------- --
-- initialise — resize window then redo layout
-- ----------------------------------------------------------------------------------------------------- --

function NR_DigitalCode:initialise()
    local L = layout()

    -- Resize before vanilla initialise so ISPanel stencil uses correct dimensions
    self.width  = L.w
    self.height = L.h

    -- Re-center on screen with new dimensions
    if self.player then
        self:setX(getPlayerScreenLeft(self.player) + math.floor((getPlayerScreenWidth(self.player)  - L.w) / 2))
        self:setY(getPlayerScreenTop(self.player)  + math.floor((getPlayerScreenHeight(self.player) - L.h) / 2))
    end

    ISDigitalCode.initialise(self)

    -- Reposition text entries
    local boxShift = math.floor(L.pad / 2)
    local uiElemBG = {
        left   = getTexture("media/ui/NeatUI/Button/Button_FULL_L.png"),
        middle = getTexture("media/ui/NeatUI/Button/Button_FULL_M.png"),
        right  = getTexture("media/ui/NeatUI/Button/Button_FULL_R.png"),
    }
    for _, pair in ipairs({ {self.number1, L.col1X}, {self.number2, L.col2X}, {self.number3, L.col3X} }) do
        local entry, cx = pair[1], pair[2]
        entry:setX(cx + boxShift) ; entry:setY(L.numY)
        entry:setWidth(L.btnSz) ; entry:setHeight(L.btnSz)
        entry.prerender = function(b)
            NeatTool.ThreePatch.drawHorizontal(
                b, -boxShift, 0, b.width, b.height,
                uiElemBG.left, uiElemBG.middle, uiElemBG.right,
                1, 0.4, 0.4, 0.4
            )
        end
    end

    -- Hide all vanilla buttons
    self.button1p:setVisible(false) ; self.button1m:setVisible(false)
    self.button2p:setVisible(false) ; self.button2m:setVisible(false)
    self.button3p:setVisible(false) ; self.button3m:setVisible(false)
    self.ok:setVisible(false)

    local iconUp   = getTexture("media/ui/NeatRocco/ICON/Icon_ArrowUp.png")
    local iconDown = getTexture("media/ui/NeatRocco/ICON/Icon_ArrowDown.png")

    local function makeBtn(cx, cy, icon, callback, color)
        local btn = NI_SquareButton:new(cx, cy, L.btnSz, icon, self, callback)
        btn:initialise()
        btn:setActive(true)
        if color then btn:setActiveColor(color[1], color[2], color[3]) end
        self:addChild(btn)
        return btn
    end

    self.neatBtn1p = makeBtn(L.col1X, L.upY,   iconUp,   function() self:onClick(self.button1p) end)
    self.neatBtn1m = makeBtn(L.col1X, L.downY, iconDown, function() self:onClick(self.button1m) end)
    self.neatBtn2p = makeBtn(L.col2X, L.upY,   iconUp,   function() self:onClick(self.button2p) end)
    self.neatBtn2m = makeBtn(L.col2X, L.downY, iconDown, function() self:onClick(self.button2m) end)
    self.neatBtn3p = makeBtn(L.col3X, L.upY,   iconUp,   function() self:onClick(self.button3p) end)
    self.neatBtn3m = makeBtn(L.col3X, L.downY, iconDown, function() self:onClick(self.button3m) end)

    local okX = math.floor((L.w - L.btnSz) / 2)
    self.iconOk = makeBtn(okX, L.okY, getTexture("media/ui/NeatUI/Icon/Icon_True.png"),
        function() self:onClick(self.ok) end, {0.2, 0.75, 0.2})
end

-- ----------------------------------------------------------------------------------------------------- --
-- prerender — NeatUI background + title text
-- ----------------------------------------------------------------------------------------------------- --

function NR_DigitalCode:prerender()
    local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainPanelBG_RoundTop.png")
    if bg then
        bg:render(self:getAbsoluteX(), self:getAbsoluteY(), self.width, self.height, 0.12, 0.12, 0.12, NR_Config.bgAlpha)
    else
        self:drawRect(0, 0, self.width, self.height, 0.95, 0.12, 0.12, 0.12)
    end
    local title = self.new and getText("IGUI_SetCode") or getText("IGUI_EnterCode")
    self:drawTextCentre(title, self:getWidth() / 2, NR_Config.padding, 1, 1, 1, 1, UIFont.Small)
end
