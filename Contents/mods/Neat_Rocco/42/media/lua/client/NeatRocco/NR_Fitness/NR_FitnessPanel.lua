-- NR_FitnessPanel.lua
-- NeatUI-styled replacement for ISFitnessUI.
-- Derives from ISFitnessUI so all logic (exercises, time, actions, joypad) is inherited.
-- NR_MakePatch bypasses new(), so dimensions are set in initialise().

require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_Header"
require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Utils/NR_SelectableList"

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")
local NIScrollView    = require("NeatUI_Framework/ScrollView/NIScrollView")

NR_FitnessPanel = ISFitnessUI:derive("NR_FitnessPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

-- ----------------------------------------------------------------------------------------------------- --
-- Layout helper (computed once in initialise after vanilla widgets are created)
-- ----------------------------------------------------------------------------------------------------- --

local function buildLayout(self)
    local pad  = NR_Config.padding
    local hh   = NR_Config.headerHeight
    local lh   = NR_Config.lineHeight
    local bsz  = NR_Config.buttonSize
    local barH = NR_Config.barHeight

    -- Exercise list dimensions (from vanilla ISRadioButtons options)
    local itemH    = lh
    local opts     = self.exercises.options
    local numItems = #opts
    local listW    = 0
    for _, opt in ipairs(opts) do
        local exeData = FitnessExercises.exercisesType[opt.data]
        local name    = exeData and exeData.name or opt.text
        local w = getTextManager():MeasureStringX(UIFont.Small, name)
        if w > listW then listW = w end
    end
    listW = listW + pad * 2
    local listH = numItems * itemH

    -- Window width: list + description (sized to first line of tooltip text)
    local tooltipText = self.tooltipLbl and self.tooltipLbl.text or ""
    local firstLine   = tooltipText:match("^(.-)%s*<LINE>") or tooltipText
    local descMinW    = getTextManager():MeasureStringX(UIFont.Small, firstLine) + pad * 3
    local timeSlotW   = getTextManager():MeasureStringX(UIFont.Small, "60") + pad * 2
    local hdrIconSz = math.floor((hh * 0.8) / 4) * 4
    local titleW    = hdrIconSz + pad * 2 + getTextManager():MeasureStringX(UIFont.Medium, getText("ContextMenu_Fitness")) + pad * 2 + bsz + pad
    local w = math.max(pad + listW + pad + descMinW + pad, titleW)

    -- Y positions
    local listY    = hh + pad
    local timeRowY = listY + listH + pad   -- left col: +/- buttons; right col: "Temps (minutes)"
    local btnRowY  = timeRowY + bsz + pad  -- left col: OK/Cancel;   right col: regularity bar
    local h        = btnRowY + bsz + pad

    return {
        w = w, h = h,
        pad = pad, hh = hh, lh = lh, bsz = bsz, barH = barH,
        itemH       = itemH,
        listX       = pad,   listY  = listY,
        listW       = listW, listH  = listH,
        listRightX  = pad + listW,
        descX       = pad + listW + pad,
        timeSlotW   = timeSlotW,
        timeRowY    = timeRowY,
        btnRowY     = btnRowY,
    }
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_FitnessPanel:getWindowTitle()
    return getText("ContextMenu_Fitness")
end

function NR_FitnessPanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Fitness.png")
end

-- ----------------------------------------------------------------------------------------------------- --
-- initialise — vanilla logic first, then NeatUI layout
-- ----------------------------------------------------------------------------------------------------- --

function NR_FitnessPanel:initialise()
    ISFitnessUI.initialise(self)

    -- Save vanilla close button, then clear field so metatable lookup finds NR_FitnessPanel:close()
    self._vanillaCloseBtn = self.close
    self.close = nil

    -- Hide vanilla widgets (tooltipLbl kept visible — repositioned below)
    self.ok:setVisible(false)
    self.cancel:setVisible(false)
    self._vanillaCloseBtn:setVisible(false)
    self.exercises:setVisible(false)
    self.timeLbl:setVisible(false)
    self.exeTime:setVisible(false)
    self.plusBtn:setVisible(false)
    self.minusBtn:setVisible(false)

    local L = buildLayout(self)

    -- Set tooltipLbl width and paginate so autosetheight computes the real height
    self.tooltipLbl:setWidth(L.w - L.descX - L.pad)
    self.tooltipLbl.background = false
    self.tooltipLbl:paginate()

    -- If description (with stiffness text) is taller than the list, push everything down
    local descH = self.tooltipLbl:getHeight()
    if descH > L.listH then
        local extra = descH - L.listH
        L.barY     = L.barY     + extra
        L.timeLblY = L.timeLblY + extra
        L.timeRowY = L.timeRowY + extra
        L.btnRowY  = L.btnRowY  + extra
        L.h        = L.h        + extra
        L.listH    = descH
    end

    self._layout = L

    -- Resize and re-center (setWidth/setHeight met à jour l'objet Java)
    self:setWidth(L.w)
    self:setHeight(L.h)
    local pn = self.player:getPlayerNum()
    self:setX(getPlayerScreenLeft(pn) + math.floor((getPlayerScreenWidth(pn)  - L.w) / 2))
    self:setY(getPlayerScreenTop(pn)  + math.floor((getPlayerScreenHeight(pn) - L.h) / 2))

    -- Reposition ISRichTextPanel
    self.tooltipLbl:setX(L.descX)
    self.tooltipLbl:setY(L.listY)

    -- NIScrollView for exercise list
    self.exeScrollView = NIScrollView:new(L.listX, L.listY, L.listW, L.listH)
    self.exeScrollView:initialise()
    self:addChild(self.exeScrollView)
    self.exeScrollView:setScrollHeight(L.listH)

    self.exeRows = {}
    for i, opt in ipairs(self.exercises.options) do
        local exeData     = FitnessExercises.exercisesType[opt.data]
        local displayText = exeData and exeData.name or opt.text
        local isEnabled   = opt.enabled ~= false
        local data        = opt.data
        local rowY        = (i - 1) * L.lh

        local tooltipFn = nil
        if not isEnabled and exeData and exeData.item then
            local item = exeData.item
            tooltipFn = function()
                return getText("IGUI_FitnessNeedItem", getItemDisplayName(item))
            end
        end

        local row = NR_SelectableList.newRow(rowY, L.listW, L.lh,
            function() return self.selectedExe == data end,
            function()
                if isEnabled then
                    self.selectedExe = data
                    self:selectedNewExercise()
                end
            end,
            function(r)
                local gr    = isEnabled and 1 or 0.45
                local textY = math.floor((L.lh - FONT_HGT_SMALL) / 2)
                r:drawText(displayText, NR_Config.padding, textY, gr, gr, gr, 1, UIFont.Small)
            end,
            tooltipFn
        )
        self.exeScrollView:addScrollChild(row)
        table.insert(self.exeRows, row)
    end

    -- Progress bar textures (NeatUI theme)
    self.progressBGTextures   = {
        left   = getTexture("media/ui/NeatRocco/Progress/Background_L.png"),
        middle = getTexture("media/ui/NeatRocco/Progress/Background_M.png"),
        right  = getTexture("media/ui/NeatRocco/Progress/Background_R.png"),
    }
    self.progressFillTextures = {
        left   = getTexture("media/ui/NeatRocco/Progress/Progress_L.png"),
        middle = getTexture("media/ui/NeatRocco/Progress/Progress_M.png"),
        right  = getTexture("media/ui/NeatRocco/Progress/Progress_R.png"),
    }
    self.uiElemBGTextures = {
        left   = getTexture("media/ui/NeatUI/Button/Button_FULL_L.png"),
        middle = getTexture("media/ui/NeatUI/Button/Button_FULL_M.png"),
        right  = getTexture("media/ui/NeatUI/Button/Button_FULL_R.png"),
    }

    -- NR_Header
    self.header = NR_Header:new(0, 0, L.w, L.hh, self)
    self.header:initialise()
    self:addChild(self.header)
    self.header:calculateLayout(L.w, L.hh)

    -- Helper to create NI_SquareButton children
    local function makeBtn(x, y, icon, callback, color)
        local btn = NI_SquareButton:new(x, y, L.bsz, icon, self, callback)
        btn:initialise()
        btn:setActive(true)
        if color then btn:setActiveColor(color[1], color[2], color[3]) end
        self:addChild(btn)
        return btn
    end

    local iconUp   = getTexture("media/ui/NeatRocco/ICON/Icon_ArrowUp.png")
    local iconDown = getTexture("media/ui/NeatRocco/ICON/Icon_ArrowDown.png")
    local iconOk   = getTexture("media/ui/NeatUI/Icon/Icon_True.png")
    local iconStop = getTexture("media/ui/NeatUI/Icon/Icon_False.png")

    local rX = L.listRightX
    self.neatBtnTimeDown = makeBtn(rX - L.bsz,                                                                    L.timeRowY, iconDown, function() self:onClickTime(self.minusBtn) end)
    self.neatBtnTimeUp   = makeBtn(rX - L.bsz - math.floor(L.pad/2) - L.timeSlotW - math.floor(L.pad/2) - L.bsz, L.timeRowY, iconUp,   function() self:onClickTime(self.plusBtn)  end)
    self.neatBtnCancel   = makeBtn(rX - L.bsz,           L.btnRowY, iconStop, function() self:onClick(self.cancel) end, {1.0, 0.5,  0.1})
    self.neatBtnOK       = makeBtn(rX - L.bsz - L.pad - L.bsz, L.btnRowY, iconOk,   function() self:onClick(self.ok)     end, {0.2, 0.75, 0.2})

    self:insertNewLineOfButtons(self.neatBtnTimeUp, self.neatBtnTimeDown)
    self:insertNewLineOfButtons(self.neatBtnCancel, self.neatBtnOK)
end

-- ----------------------------------------------------------------------------------------------------- --
-- close — called by NR_Header close button
-- ----------------------------------------------------------------------------------------------------- --

function NR_FitnessPanel:close()
    self:setVisible(false)
    self:removeFromUIManager()
    local pn = self.player:getPlayerNum()
    ISFitnessUI.instance[pn + 1] = nil
    if JoypadState.players[pn + 1] then
        setJoypadFocus(pn, nil)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- prerender — NeatUI background
-- ----------------------------------------------------------------------------------------------------- --

function NR_FitnessPanel:prerender()
    local hh = NR_Config.headerHeight
    local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainPanelBG_FlatTop.png")
    if bg then
        bg:render(self:getAbsoluteX(), self:getAbsoluteY() + hh, self.width, self.height - hh, 0.15, 0.15, 0.15, NR_Config.bgAlpha)
    end
    if self.joyfocus and self.neatBtnOK and self:getJoypadFocus() == self.neatBtnOK then
        self:setISButtonForA(self.neatBtnOK)
    else
        self.ISButtonA = nil
        if self.neatBtnOK then self.neatBtnOK.isJoypad = false end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- render — exercise list, description, regularity bar, time display
-- ----------------------------------------------------------------------------------------------------- --

function NR_FitnessPanel:render()
    ISPanelJoypad.render(self)

    -- Vanilla logic: enable/disable ok/cancel based on player state
    local actionQueue  = ISTimedActionQueue.getTimedActionQueue(self.player)
    local currentAction = actionQueue.queue[1]
    self:updateButtons(currentAction)

    -- Sync NeatUI button states
    self.neatBtnOK:setActive(self.ok.enable ~= false)
    self.neatBtnCancel:setActive(self.cancel.enable ~= false)

    local L   = self._layout
    if not L then return end
    local pad = L.pad

    -- ── Right col: "Temps (minutes)" centré dans bsz + barre centrée dans bsz ──
    local barX    = L.descX
    local barW    = self.width - L.descX - pad
    local timeLblY = L.timeRowY + math.floor((L.bsz - FONT_HGT_SMALL) / 2)
    local barY     = L.btnRowY  + math.floor((L.bsz - L.barH) / 2)
    local reg      = math.min(self:getCurrentRegularity() * 1.5, 1)
    self:drawText(getText("IGUI_FitnessTime"), barX, timeLblY, 1, 1, 1, 0.7, UIFont.Small)
    NR_DrawBar.drawBarWithLabel(self, barX, barY, barW, L.barH, reg, getText("IGUI_FitnessRegularity"), 0.2, 0.8, 0.3)

    -- ── Left col: time value ──
    local timeStr  = self.exeTime:getInternalText() or "10"
    local timeStrW = getTextManager():MeasureStringX(UIFont.Small, timeStr)
    local timeSlotX = L.listRightX - L.bsz - math.floor(L.pad/2) - L.timeSlotW
    NeatTool.ThreePatch.drawHorizontal(
        self,
        timeSlotX, L.timeRowY, L.timeSlotW, L.bsz,
        self.uiElemBGTextures.left,
        self.uiElemBGTextures.middle,
        self.uiElemBGTextures.right,
        1, 0.4, 0.4, 0.4
    )
    local timeValX = timeSlotX + math.floor((L.timeSlotW - timeStrW) / 2)
    local timeValY = L.timeRowY + math.floor((L.bsz - FONT_HGT_SMALL) / 2)
    self:drawText(timeStr, timeValX, timeValY, 1, 1, 1, 1, UIFont.Small)

    NR_SelectableList.drawTooltips(self, self.exeRows)
end
