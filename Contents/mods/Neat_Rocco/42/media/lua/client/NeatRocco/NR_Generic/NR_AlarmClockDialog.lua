-- NR_AlarmClockDialog.lua
-- NeatUI-styled override of ISAlarmClockDialog.
-- Derives from ISAlarmClockDialog so all logic (hours/mins, tickbox, joypad, destroy) is inherited.
-- NR_MakePatch bypasses new(), so dimensions are set in initialise() before the vanilla call.

require "NeatRocco/NR_Config"

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

NR_AlarmClockDialog = ISAlarmClockDialog:derive("NR_AlarmClockDialog")

local function layout()
    local btnSz  = NR_Config.buttonSize
    local pad    = NR_Config.padding
    local hpad   = math.floor(pad / 3)
    local fontH  = getTextManager():getFontHeight(UIFont.Small)
    local titleH = fontH + pad * 2
    local tickH  = NR_Config.smallLineHeight

    -- Row 2: [boxH][boxM][checkbox]["Alarme"]
    -- Row 3: [↓H][↓M][OK]
    local alarmTextW = getTextManager():MeasureStringX(UIFont.Small, getText("UI_Alarm"))
    local row2W = pad + btnSz + pad + btnSz + pad + tickH + pad + alarmTextW + pad
    local row3W = pad + btnSz + pad + btnSz + pad + btnSz + pad
    local titleW = getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_SetAlarm")) + pad * 2
    local w = math.max(row2W, row3W, titleW)

    -- Y positions (3 rows)
    local upY   = titleH
    local numY  = upY   + btnSz + hpad
    local downY = numY  + btnSz + hpad
    local h     = downY + btnSz + pad

    -- X positions (left to right)
    local x1 = pad                          -- ↑H / boxH / ↓H
    local x2 = x1 + btnSz + pad            -- ↑M / boxM / ↓M
    local x3 = x2 + btnSz + pad            -- checkbox (row2) / OK (row3)

    return {
        w = w, h = h,
        btnSz = btnSz, pad = pad, hpad = hpad,
        titleH = titleH, tickH = tickH,
        x1 = x1, x2 = x2, x3 = x3,
        upY = upY, numY = numY, downY = downY,
    }
end

-- ----------------------------------------------------------------------------------------------------- --
-- initialise — resize window then redo layout
-- ----------------------------------------------------------------------------------------------------- --

function NR_AlarmClockDialog:initialise()
    local L = layout()

    -- Resize before vanilla initialise so ISPanel stencil uses correct dimensions
    self.width  = L.w
    self.height = L.h

    -- Re-center on screen with new dimensions
    if self.player then
        self:setX(getPlayerScreenLeft(self.player) + math.floor((getPlayerScreenWidth(self.player)  - L.w) / 2))
        self:setY(getPlayerScreenTop(self.player)  + math.floor((getPlayerScreenHeight(self.player) - L.h) / 2))
    end

    ISAlarmClockDialog.initialise(self)
    self:setHeight(L.h)   -- vanilla line 67 overwrites height, restore ours

    -- Reposition text entries: shifted right by pad/2 so text has visual left margin inside bubble
    local boxShift = math.floor(L.pad / 2)
    self.hours:setX(L.x1 + boxShift) ; self.hours:setY(L.numY)
    self.hours:setWidth(L.btnSz) ; self.hours:setHeight(L.btnSz)
    self.mins:setX(L.x2 + boxShift) ; self.mins:setY(L.numY)
    self.mins:setWidth(L.btnSz) ; self.mins:setHeight(L.btnSz)

    local uiElemBG = {
        left   = getTexture("media/ui/NeatUI/Button/Button_FULL_L.png"),
        middle = getTexture("media/ui/NeatUI/Button/Button_FULL_M.png"),
        right  = getTexture("media/ui/NeatUI/Button/Button_FULL_R.png"),
    }
    local function addBubblePrerender(box)
        box.prerender = function(b)
            -- Draw bubble at -boxShift so it starts at the original x1/x2, same visual size as btnSz
            NeatTool.ThreePatch.drawHorizontal(
                b, -boxShift, 0, b.width, b.height,
                uiElemBG.left, uiElemBG.middle, uiElemBG.right,
                1, 0.4, 0.4, 0.4
            )
        end
    end
    addBubblePrerender(self.hours)
    addBubblePrerender(self.mins)

    -- Reposition tickbox (row 2, aligned with boxes)
    local tickCenterY = L.numY + math.floor((L.btnSz - L.tickH) / 2)
    self.setAlarm:setX(L.x3)
    self.setAlarm:setY(tickCenterY)

    -- Hide all vanilla buttons
    self.button1p:setVisible(false) ; self.button1m:setVisible(false)
    self.button2p:setVisible(false) ; self.button2m:setVisible(false)
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

    self.neatBtn1p = makeBtn(L.x1, L.upY,   iconUp,   function() self:onClick(self.button1p) end)
    self.neatBtn1m = makeBtn(L.x1, L.downY, iconDown, function() self:onClick(self.button1m) end)
    self.neatBtn2p = makeBtn(L.x2, L.upY,   iconUp,   function() self:onClick(self.button2p) end)
    self.neatBtn2m = makeBtn(L.x2, L.downY, iconDown, function() self:onClick(self.button2m) end)

    self.iconOk = makeBtn(L.x3, L.downY, getTexture("media/ui/NeatUI/Icon/Icon_True.png"),
        function() self:onClick(self.ok) end, {0.2, 0.75, 0.2})
end

-- ----------------------------------------------------------------------------------------------------- --
-- prerender — NeatUI background + title text
-- ----------------------------------------------------------------------------------------------------- --

function NR_AlarmClockDialog:prerender()
    local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainPanelBG_RoundTop.png")
    if bg then
        bg:render(self:getAbsoluteX(), self:getAbsoluteY(), self.width, self.height, 0.12, 0.12, 0.12, NR_Config.bgAlpha)
    else
        self:drawRect(0, 0, self.width, self.height, 0.95, 0.12, 0.12, 0.12)
    end
    self:drawTextCentre(getText("IGUI_SetAlarm"), self:getWidth() / 2, NR_Config.padding, 1, 1, 1, 1, UIFont.Small)
end
