-- NR_VehicleMechanicsPanel_v2.lua
-- NeatUI-styled replacement for ISVehicleMechanics (Vehicle Mechanics window).
-- Vanilla logic preserved 1:1 — visual layer only.
-- v2: 3rd-party mod compatibility (AutoMechanics, etc.)

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Utils/NR_ScrollingList"
require "NeatRocco/NR_Utils/NR_ResizeWidget"
require "NeatRocco/NR_Config"

NR_VehicleMechanicsPanel = NR_BasePanel:derive("NR_VehicleMechanicsPanel")
NR_VehicleMechanicsPanel.panels = {}  -- [playerNum] = instance

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

-- Vanilla ISCollapsableWindow titleBarHeight = max(16, UIFont.Small+1). Car image has exactly that
-- many transparent pixels at top, aligning content with the info rect (titleBarHeight+10).
-- Shift the car down by the delta so content aligns with our headerHeight+10.
local VANILLA_TITLE_H = math.max(16, FONT_HGT_SMALL + 1)
local CAR_Y_OFFSET    = math.max(0, NR_Config.headerHeight - VANILLA_TITLE_H)

-- Vanilla layout constants (mirror ISVehicleMechanics geometry)
local INFO_GAP_TOP    = 10               -- 10, gap between header bottom and info rect top
local INFO_PAD        = INFO_GAP_TOP / 2 -- 5, inner top padding of info rect
local INFO_STAT_LINES = 6                -- number of Small-font stat lines in info rect
local INFO_GAP_BOT    = INFO_GAP_TOP     -- 10, gap between info rect bottom and listboxes
local RESIZE_H        = 16               -- resize widget size (matches ISResizeWidget default)
-- Y where listboxes start (= header + info gap + inner pad + name line + stat lines + bottom gap)
local LIST_Y = NR_Config.headerHeight + INFO_GAP_TOP + INFO_PAD + FONT_HGT_MEDIUM + FONT_HGT_SMALL * INFO_STAT_LINES + INFO_GAP_BOT

-- Width constants
local MECH_CAR_W    = 300   -- fixed by car overlay art assets
local MECH_LIST_GAP = NR_Config.padding

-- Returns the required list column width for a given vehicle (mirrors vanilla initParts logic).
-- vehicle can be nil on first creation (set later by the patch before initParts runs).
local function computeListWidth(vehicle)
    if not vehicle then return math.floor(FONT_HGT_SMALL * 14) end
    local scrollW  = 16
    local maxWidth = 0
    for i = 1, vehicle:getPartCount() do
        local part = vehicle:getPartByIndex(i - 1)
        if part:getCategory() ~= "nodisplay" then
            local name = getText("IGUI_VehiclePart" .. part:getId())
            local w = 20 + getTextManager():MeasureStringX(UIFont.Small, name)
                       + 2 + getTextManager():MeasureStringX(UIFont.Small, "(100%)")
                       + scrollW + 2
            if w > maxWidth then maxWidth = w end
        end
    end
    return maxWidth
end


-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_VehicleMechanicsPanel:new(x, y, character, vehicle)
    local listWidth = computeListWidth(vehicle)
    local width  = MECH_CAR_W + listWidth * 2 + MECH_LIST_GAP + NR_Config.padding
    local height = CAR_Y_OFFSET + 600 - RESIZE_H  -- full car, lists fill to window bottom
    if x == 0 and y == 0 then
        x = math.floor(getCore():getScreenWidth()  / 2 - width  / 2)
        y = math.floor(getCore():getScreenHeight() / 2 - height / 2)
    end

    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.chr                = character
    o.playerNum          = character:getPlayerNum()
    o.vehicle            = vehicle
    o.partCatRGB         = {r=1,   g=1,   b=1,   a=1}
    o.partRGB            = {r=0.8, g=0.8, b=0.8, a=1}
    o.borderColor        = {r=0.3, g=0.3, b=0.3}
    o.xCarTexOffset      = MECH_CAR_W
    o.checkEngine        = true
    o.leftListHasFocus   = true
    o.leftListSelection  = 1
    o.rightListSelection = 1
    o.flashFailure       = false
    o.flashTimer         = 0
    o.flashTimerAlpha    = 1
    o.flashTimerAlphaInc = false
    o.listWidth          = listWidth

    NR_BasePanel.initBase(o)
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_VehicleMechanicsPanel:getWindowTitle()
    return getText("ContextMenu_VehicleMechanics")
end

function NR_VehicleMechanicsPanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Mechanics.png")
end

function NR_VehicleMechanicsPanel:titleBarHeight()
    return NR_Config.headerHeight
end

function NR_VehicleMechanicsPanel:getInfoText()
    return getText("IGUI_InfoPanel_Mechanics")
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_VehicleMechanicsPanel:createChildren()
    NR_BasePanel.createChildren(self)

    self.rectY = self:titleBarHeight() + 10  -- used by vanilla renderPartDetail (42.18+)

    local listH = self.height - LIST_Y - RESIZE_H

    self.listbox                = NR_ScrollingList.new(self, self.xCarTexOffset, LIST_Y, self.listWidth, listH)
    self.listbox.doDrawItem     = ISVehicleMechanics.doDrawItem
    self.listbox.onRightMouseUp = ISVehicleMechanics.onListRightMouseUp
    self.listbox.onMouseDown    = ISVehicleMechanics.onListMouseDown

    self.bodyworklist                = NR_ScrollingList.new(self, self.xCarTexOffset + self.listWidth + MECH_LIST_GAP, LIST_Y, self.listWidth, listH)
    self.bodyworklist.doDrawItem     = ISVehicleMechanics.doDrawItem
    self.bodyworklist.onRightMouseUp = ISVehicleMechanics.onListRightMouseUp
    self.bodyworklist.onMouseDown    = ISVehicleMechanics.onListMouseDown

    -- All car overlay textures are 600px tall (scale=1, props.y=0 for all vanilla vehicles).
    -- Minimum = bottom of car image + small margin.
    -- minimumWidth must be set to prevent ISResizeWidget from resetting minimumHeight to 0.
    self.minimumWidth  = self.width
    self.minimumHeight = CAR_Y_OFFSET + 600 - RESIZE_H

    -- Resize widget with NeatUI icon (Y-only, matching vanilla).
    -- No explicit instantiate() — addChild triggers it with the parent already set,
    -- so the Java anchor reference is established correctly.
    self.resizeWidget = NR_ResizeWidget.create(self,
        function(target, w, h) target:calculateLayout(w, h) end,
        { yonly = true })
end

-- ----------------------------------------------------------------------------------------------------- --
-- Visibility / Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_VehicleMechanicsPanel:setVisible(bVisible, joypadData)
    if self.javaObject == nil then
        self:instantiate()
    end
    self:setEnabled(bVisible)
    self.javaObject:setVisible(bVisible)

    if self.vehicle then
        self.vehicle:setActiveInBullet(bVisible)
        self.vehicle:setMechanicUIOpen(bVisible)
    end
    if self.tooltip then
        self.tooltip:setVisible(false)
    end
    if bVisible and joypadData then
        joypadData.focus = self
        updateJoypadFocus(joypadData)
    end
    if self.usedHood then
        if not bVisible then
            if self.chr and self.vehicle and self.vehicle:isInArea(self.usedHood:getArea(), self.chr) then
                ISTimedActionQueue.add(ISCloseVehicleDoor:new(self.chr, self.vehicle, self.usedHood))
            end
            self.usedHood = nil
        else
            if self.chr and self.vehicle then
                ISTimedActionQueue.add(ISOpenVehicleDoor:new(self.chr, self.vehicle, self.usedHood))
            end
        end
    end
end

function NR_VehicleMechanicsPanel:close()
    NR_VehicleMechanicsPanel.panels[self.playerNum] = nil
    self:closeBase()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Layout
-- ----------------------------------------------------------------------------------------------------- --

function NR_VehicleMechanicsPanel:updateLayout()
    -- initParts (vanilla) sets self.listWidth from actual part names then calls updateLayout.
    -- We detect the change, update widths, and recalculate layout to fit content exactly.
    if self.listbox:getWidth() == self.listWidth then return end
    NR_ScrollingList.setWidth(self.listbox, self.listWidth)
    NR_ScrollingList.setWidth(self.bodyworklist, self.listWidth)
    local newW = MECH_CAR_W + self.listWidth * 2 + MECH_LIST_GAP + NR_Config.padding
    self.minimumWidth = newW
    self:calculateLayout(newW, self.height)
end

function NR_VehicleMechanicsPanel:calculateLayout(_, h)
    local width  = MECH_CAR_W + self.listWidth * 2 + MECH_LIST_GAP + NR_Config.padding
    local height = math.max(h or self.height, self.minimumHeight or 0)
    local listH = math.max(height - LIST_Y - RESIZE_H, FONT_HGT_SMALL)
    NR_ScrollingList.setHeight(self.listbox, listH)
    self.bodyworklist:setX(self.listbox:getRight() + MECH_LIST_GAP)
    NR_ScrollingList.setHeight(self.bodyworklist, listH)
    if self.header then
        self.header:setWidth(width)
        self.header:calculateLayout(width, NR_Config.headerHeight)
    end
    self:setWidth(width)
    self:setHeight(height)
    if self.resizeWidget then
        self.resizeWidget:setX(width - RESIZE_H)
        self.resizeWidget:setY(height - RESIZE_H)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Update
-- ----------------------------------------------------------------------------------------------------- --

function NR_VehicleMechanicsPanel:update()
    if self.vehicle and self.chr:DistTo(self.vehicle:getX(), self.vehicle:getY()) > 6 then
        self:close()
    elseif not self.vehicle or not self.vehicle:getSquare()
            or self.vehicle:getSquare():getMovingObjects():indexOf(self.vehicle) < 0 then
        self:close()
    else
        self:recalculGeneralCondition()
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Prerender / Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_VehicleMechanicsPanel:prerender()
    NR_BasePanel.prerender(self)
    self:updateLayout()
    -- Car rendered here (before children) with CAR_Y_OFFSET so content aligns with the info rect.
    -- Transparent pixels above the content are covered naturally by the NR_Header child.
    if self.vehicle then
        self:renderCarOverlay()
    end
end

function NR_VehicleMechanicsPanel:render()
    ISPanelJoypad.render(self)
    if not self.vehicle then return end

    self:checkEngineFull()

    local fgBar   = {r=getCore():getGoodHighlitedColor():getR(), g=getCore():getGoodHighlitedColor():getG(), b=getCore():getGoodHighlitedColor():getB(), a=1}
    local lineHgt = FONT_HGT_SMALL
    local rectHgt = 5 + FONT_HGT_MEDIUM + FONT_HGT_SMALL * 6

    -- Info rect
    local rx    = self.xCarTexOffset
    local ry    = self:titleBarHeight() + 10
    local rectW = self:getWidth() - self.xCarTexOffset - 10
    self:drawRectBorder(rx, ry, rectW, rectHgt, 1, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local x = rx + 5
    local y = ry + 5

    local debugLine = ""
    if getCore():getDebug() or getSandboxOptions():isUnstableScriptNameSpam() then
        debugLine = " ( Vehicle Report: " .. self.vehicle:getScript():getName() .. " )"
    end
    local carName = self.vehicle:getScript():getCarModelName() or self.vehicle:getScript():getName()
    local name    = getText("IGUI_VehicleName" .. carName)
    if string.match(self.vehicle:getScript():getName(), "Burnt") then
        local unburnt = string.gsub(self.vehicle:getScript():getName(), "Burnt", "")
        if getTextOrNull("IGUI_VehicleName" .. unburnt) then
            name = getText("IGUI_VehicleName" .. unburnt)
        end
        name = getText("IGUI_VehicleNameBurntCar", name)
    end
    self:drawTextCentre(name .. debugLine, x + rectW / 2, y, self.partCatRGB.r, self.partCatRGB.g, self.partCatRGB.b, self.partCatRGB.a, UIFont.Medium)
    y = y + FONT_HGT_MEDIUM
    self:drawText(getText("Tooltip_item_Mechanic") .. ": " .. getText("IGUI_VehicleType_" .. self.vehicle:getScript():getMechanicType()), x, y, self.partCatRGB.r, self.partCatRGB.g, self.partCatRGB.b, self.partCatRGB.a, UIFont.Small)
    y = y + lineHgt
    self:drawText(getText("IGUI_OverallCondition") .. ": ", x, y, self.partCatRGB.r, self.partCatRGB.g, self.partCatRGB.b, self.partCatRGB.a, UIFont.Small)
    self:drawText(self.generalCondition .. "%", x + getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_OverallCondition") .. ": ") + 2, y, self.generalCondRGB.r, self.generalCondRGB.g, self.generalCondRGB.b, self.partCatRGB.a, UIFont.Small)
    y = y + lineHgt
    self:drawText(getText("IGUI_char_Weight") .. ": " .. self.vehicle:getMass(), x, y, self.partCatRGB.r, self.partCatRGB.g, self.partCatRGB.b, self.partCatRGB.a, UIFont.Small)
    y = y + lineHgt
    if self.vehicle:getPartById("Engine") then
        self:drawText(getText("IGUI_EnginePower") .. ": " .. (self.vehicle:getEnginePower() / 10) .. " hp", x, y, self.partCatRGB.r, self.partCatRGB.g, self.partCatRGB.b, self.partCatRGB.a, UIFont.Small)
    end

    -- Progress bar / flash at the bottom of the info rect
    local progressY = ry + rectHgt - lineHgt - 4
    local actionQueue = ISTimedActionQueue.getTimedActionQueue(self.chr)
    local progress    = false
    if actionQueue and actionQueue.queue and actionQueue.queue[1]
            and actionQueue.queue[1].jobType and actionQueue.queue[1].jobType ~= "" then
        self:drawProgressBar(x, progressY, rectW - 10, lineHgt - 2, actionQueue.queue[1]:getJobDelta(), fgBar)
        self:drawTextCentre(actionQueue.queue[1].jobType, (self.width - 12 + x) / 2, progressY - 2, 0.8, 0.8, 0.8, 1, UIFont.Small)
        progress = true
    end
    if not progress and self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - 1
        if self.flashFailure then
            self:drawProgressBar(x, progressY, rectW - 10, lineHgt - 2, 100, {r=0.5, g=0.1, b=0.1, a=self.flashTimerAlpha})
            self:drawTextCentre(getText("IGUI_Failure"), (self.width - 12 + x) / 2, progressY - 2, 0.8, 0.8, 0.8, 1, UIFont.Small)
        else
            self:drawProgressBar(x, progressY, rectW - 10, lineHgt - 2, 100, {r=0.1, g=0.6, b=0.1, a=self.flashTimerAlpha})
            self:drawTextCentre(getText("IGUI_Success"), (self.width - 12 + x) / 2, progressY - 2, 0.8, 0.8, 0.8, 1, UIFont.Small)
        end
        if self.flashTimerAlphaInc then
            self.flashTimerAlpha = self.flashTimerAlpha + 0.06
            if self.flashTimerAlpha >= 1 then self.flashTimerAlpha = 1; self.flashTimerAlphaInc = false end
        else
            self.flashTimerAlpha = self.flashTimerAlpha - 0.06
            if self.flashTimerAlpha <= 0 then self.flashTimerAlpha = 0; self.flashTimerAlphaInc = true end
        end
    end

    -- Part detail (right half of info rect)
    local selectedPart
    if self.listbox.items[self.listbox.selected] then
        selectedPart = self.listbox.items[self.listbox.selected].item.part
    elseif self.bodyworklist.items[self.bodyworklist.selected] then
        selectedPart = self.bodyworklist.items[self.bodyworklist.selected].item.part
    end
    if selectedPart then self:renderPartDetail(selectedPart) end

    -- Joypad focus border
    if self.drawJoypadFocus and self.leftListHasFocus then
        local ui = self.listbox
        self:drawRectBorder(ui:getX(),   ui:getY(),   ui:getWidth(),   ui:getHeight(),   0.4, 0.2, 1.0, 1.0)
        self:drawRectBorder(ui:getX()+1, ui:getY()+1, ui:getWidth()-2, ui:getHeight()-2, 0.4, 0.2, 1.0, 1.0)
    elseif self.drawJoypadFocus then
        local ui = self.bodyworklist
        self:drawRectBorder(ui:getX(),   ui:getY(),   ui:getWidth(),   ui:getHeight(),   0.4, 0.2, 1.0, 1.0)
        self:drawRectBorder(ui:getX()+1, ui:getY()+1, ui:getWidth()-2, ui:getHeight()-2, 0.4, 0.2, 1.0, 1.0)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Mouse
-- ----------------------------------------------------------------------------------------------------- --

function NR_VehicleMechanicsPanel:onMouseDown(x, y)
    ISPanelJoypad.onMouseDown(self, x, y)
    local part = self:getMouseOverPart(self:getMouseX(), self:getMouseY())
    self:selectPart(part)
end

function NR_VehicleMechanicsPanel:onRightMouseUp(x, y)
    local playerObj = getSpecificPlayer(self.playerNum)
    local part = self:getMouseOverPart(x, y)
    self.context = nil
    if part then
        self:selectPart(part)
        self:doPartContextMenu(part, x, y)
    elseif ISVehicleMechanics.cheat then
        if UIManager.getSpeedControls():getCurrentGameSpeed() == 0 then return end
        self.context = ISContextMenu.get(self.playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY())
        if self.vehicle:getScript() and self.vehicle:getScript():getWheelCount() > 0 then
            if self.vehicle:getPartById("Engine") then
                self.context:addOption("CHEAT: Get Key", playerObj, ISVehicleMechanics.onCheatGetKey, self.vehicle)
                if self.vehicle:isHotwired() then
                    self.context:addOption("CHEAT: Remove Hotwire", playerObj, ISVehicleMechanics.onCheatHotwire, self.vehicle, false, false)
                else
                    self.context:addOption("CHEAT: Hotwire", playerObj, ISVehicleMechanics.onCheatHotwire, self.vehicle, true, false)
                end
            end
            self.context:addOption("CHEAT: Repair Vehicle", playerObj, ISVehicleMechanics.onCheatRepair, self.vehicle)
            self.context:addOption("CHEAT: Set Rust", playerObj, ISVehicleMechanics.onCheatSetRust, self.vehicle)
        end
        self.context:addOption("CHEAT: Remove Vehicle", playerObj, ISVehicleMechanics.onCheatRemove, self.vehicle)
    end
    if not part and getDebug() then
        if not self.context then
            self.context = ISContextMenu.get(self.playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY())
        end
        if ISVehicleMechanics.cheat then
            self.context:addOption("DBG: ISVehicleMechanics.cheat=false", playerObj, ISVehicleMechanics.onCheatToggle)
        else
            self.context:addOption("DBG: ISVehicleMechanics.cheat=true", playerObj, ISVehicleMechanics.onCheatToggle)
        end
    end
    if not self.context then
        self.context = ISContextMenu.get(self.playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY())
    end
    if rawget(ISVehicleMechanics, "addAutoMechanicsButtons") then
        self:addAutoMechanicsButtons()
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad
-- ----------------------------------------------------------------------------------------------------- --

function NR_VehicleMechanicsPanel:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self.drawJoypadFocus = true
end

function NR_VehicleMechanicsPanel:onJoypadDown(button)
    if button == Joypad.AButton then
        local listbox = self.leftListHasFocus and self.listbox or self.bodyworklist
        local item    = listbox.items[listbox.selected]
        if item and not item.item.cat then
            local menuX = listbox:getX() + 20
            local menuY = listbox:getY() + listbox:topOfItem(listbox.selected) + item.height + listbox:getYScroll()
            self:doPartContextMenu(item.item.part, menuX, menuY)
        end
    elseif button == Joypad.BButton then
        self:close()
    end
end

function NR_VehicleMechanicsPanel:onJoypadDirUp()
    if self.leftListHasFocus then
        self:onListboxJoypadDirUp(self.listbox)
    else
        self:onListboxJoypadDirUp(self.bodyworklist)
    end
end

function NR_VehicleMechanicsPanel:onJoypadDirDown()
    if self.leftListHasFocus then
        self:onListboxJoypadDirDown(self.listbox)
    else
        self:onListboxJoypadDirDown(self.bodyworklist)
    end
end

function NR_VehicleMechanicsPanel:onJoypadDirLeft()
    if self.leftListHasFocus then return end
    self.leftListHasFocus   = true
    self.rightListSelection = self.bodyworklist.selected
    self.bodyworklist.selected = -1
    self.listbox.selected   = self.leftListSelection or -1
end

function NR_VehicleMechanicsPanel:onJoypadDirRight()
    if not self.leftListHasFocus then return end
    self.leftListHasFocus  = false
    self.leftListSelection = self.listbox.selected
    self.listbox.selected  = -1
    self.bodyworklist.selected = self.rightListSelection or 1
end

-- ----------------------------------------------------------------------------------------------------- --
-- Keyboard
-- ----------------------------------------------------------------------------------------------------- --

function NR_VehicleMechanicsPanel:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE or getCore():isKey("VehicleMechanics", key)
end

function NR_VehicleMechanicsPanel:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then
        if isPlayerDoingActionThatCanBeCancelled(self.chr) then
            stopDoingActionThatCanBeCancelled(self.chr)
        else
            self:close()
        end
    end
    if getCore():isKey("VehicleMechanics", key) then
        self:close()
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Vanilla logic (delegated)
-- ----------------------------------------------------------------------------------------------------- --

NR_VehicleMechanicsPanel.initParts                   = ISVehicleMechanics.initParts
NR_VehicleMechanicsPanel.recalculGeneralCondition    = ISVehicleMechanics.recalculGeneralCondition
NR_VehicleMechanicsPanel.checkEngineFull             = ISVehicleMechanics.checkEngineFull
NR_VehicleMechanicsPanel.doMenuTooltip               = ISVehicleMechanics.doMenuTooltip
NR_VehicleMechanicsPanel.getConditionRGB             = ISVehicleMechanics.getConditionRGB
NR_VehicleMechanicsPanel.roundContainerContentAmount = ISVehicleMechanics.roundContainerContentAmount
-- Shift the car image down by CAR_Y_OFFSET so its visible content aligns with the info rect.
function NR_VehicleMechanicsPanel:renderCarOverlay()
    local overlayName = self.vehicle:getScriptName()
    if self.vehicle:getScript():getCarMechanicsOverlay() then
        overlayName = self.vehicle:getScript():getCarMechanicsOverlay()
    end
    local props = ISCarMechanicsOverlay.CarList[overlayName]
    if props then
        local origY = props.y
        props.y = origY + CAR_Y_OFFSET
        ISVehicleMechanics.renderCarOverlay(self)
        props.y = origY
    else
        ISVehicleMechanics.renderCarOverlay(self)
    end
end

-- Compensate the y-shift for mouse hit-testing.
function NR_VehicleMechanicsPanel:isMouseOverPart(x, y, part)
    return ISVehicleMechanics.isMouseOverPart(self, x, y - CAR_Y_OFFSET, part)
end

NR_VehicleMechanicsPanel.renderCarOverlayTooltip     = ISVehicleMechanics.renderCarOverlayTooltip
NR_VehicleMechanicsPanel.renderPartDetail            = ISVehicleMechanics.renderPartDetail
NR_VehicleMechanicsPanel.getMouseOverPart            = ISVehicleMechanics.getMouseOverPart
NR_VehicleMechanicsPanel.selectPart                  = ISVehicleMechanics.selectPart
NR_VehicleMechanicsPanel.startFlashGreen             = ISVehicleMechanics.startFlashGreen
NR_VehicleMechanicsPanel.startFlashRed               = ISVehicleMechanics.startFlashRed
NR_VehicleMechanicsPanel.onListboxJoypadDirUp        = ISVehicleMechanics.onListboxJoypadDirUp
NR_VehicleMechanicsPanel.onListboxJoypadDirDown      = ISVehicleMechanics.onListboxJoypadDirDown
NR_VehicleMechanicsPanel.getWrench                   = ISVehicleMechanics.getWrench
NR_VehicleMechanicsPanel.getScrewdriver              = ISVehicleMechanics.getScrewdriver
NR_VehicleMechanicsPanel.getTirePump                 = ISVehicleMechanics.getTirePump

-- ----------------------------------------------------------------------------------------------------- --
-- 3rd-party mod compatibility
-- ----------------------------------------------------------------------------------------------------- --

-- Dynamic dispatch: picks up any patch applied to ISVehicleMechanics.doPartContextMenu at call time
-- (e.g. AutoMechanics injects its buttons via this function).
function NR_VehicleMechanicsPanel:doPartContextMenu(part, x, y)
    ISVehicleMechanics.doPartContextMenu(self, part, x, y)
end

-- Generic __index fallback to ISVehicleMechanics.
-- Mods that add methods directly to ISVehicleMechanics (e.g. AutoMechanics adds
-- addAutoMechanicsButtons, called by onListRightMouseUp on self.parent = this panel)
-- become automatically callable on NR_VehicleMechanicsPanel instances.
-- rawget limits the fallback to methods defined directly on ISVehicleMechanics, not its
-- own parent chain (ISCollapsableWindowJoypad ...), which would conflict with our
-- ISPanelJoypad base.
local _parentMT = getmetatable(NR_VehicleMechanicsPanel)  -- NR_BasePanel, set by derive()
setmetatable(NR_VehicleMechanicsPanel, {
    __index = function(_, k)
        local v = _parentMT[k]
        if v ~= nil then return v end
        return rawget(ISVehicleMechanics, k)
    end
})
