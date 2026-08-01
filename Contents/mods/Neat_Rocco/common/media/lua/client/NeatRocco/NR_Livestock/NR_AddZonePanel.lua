-- NR_AddZonePanel.lua
-- NeatUI-styled replacement for ISAddDesignationAnimalZoneUI.
-- Derives from ISAddDesignationAnimalZoneUI — all zone drag/joypad logic inherited 1:1.

NR_AddZonePanel = ISAddDesignationAnimalZoneUI:derive("NR_AddZonePanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_AddZonePanel:new(x, y, width, height, player)
    local pad   = NR_Config.padding
    local hh    = NR_Config.headerHeight
    local btnSz = NR_Config.buttonSize

    -- Height: header + name row + instruction + W/H/Size rows + joypad ADD button row
    height = hh  + pad
           + FONT_HGT_SMALL + pad   -- zone name row
           + FONT_HGT_SMALL + pad   -- instruction row
           + FONT_HGT_SMALL * 3     -- width / height / total size (always reserved)
           + pad + btnSz + pad      -- joypad ADD button (hidden on mouse)

    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.drawFrame  = false
    o.background = false
    o:setWantKeyEvents(true)

    if y == 0 then o.y = o:getMouseY() - (height / 2) ; o:setY(o.y) end
    if x == 0 then o.x = o:getMouseX() - (width  / 2) ; o:setX(o.x) end

    o.player          = player
    o.playerNum       = player:getPlayerNum()
    o.startingX       = nil
    o.startingY       = nil
    o.endX            = nil
    o.endY            = nil
    o.drawTileMouse   = true
    o.startRenderTile = false
    o.widthCorrect    = true
    o.heightCorrect   = true
    o.waitingConfirm  = false
    o.zoneColor       = {
        r = DesignationZoneAnimal.ZONE_COLOR_R,
        g = DesignationZoneAnimal.ZONE_COLOR_G,
        b = DesignationZoneAnimal.ZONE_COLOR_B,
        a = 0.5,
    }

    ISAddDesignationAnimalZoneUI.instance = o  -- vanilla compatibility
    NR_AddZonePanel.instance = o
    player:setSeeDesignationZone(true)
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_AddZonePanel:getWindowTitle()
    return getText("IGUI_PvpZone_AddZone")
end

function NR_AddZonePanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Fences.png")
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_AddZonePanel:initialise()
    ISPanelJoypad.initialise(self)

    local pad   = NR_Config.padding
    local hh    = NR_Config.headerHeight
    local btnSz = NR_Config.buttonSize
    local btnW  = btnSz * 3
    local btnY  = self.height - btnSz - pad

    self.header = NR_Header:new(0, 0, self.width, hh, self)
    self.header:initialise()
    self:addChild(self.header)
    self.header:calculateLayout(self.width, hh)
    if self.header.closeButton then self.header.closeButton:setVisible(false) end

    local zoneid = DesignationZoneAnimal.getAllZones():size() + 1
    local title  = getText("IGUI_DesignationZone_Type_" .. DesignationZoneAnimal.ZONE_TYPE) .. " #" .. zoneid
    while DesignationZoneAnimal.getZoneByName(title) do
        zoneid = zoneid + 1
        title  = getText("IGUI_DesignationZone_Type_" .. DesignationZoneAnimal.ZONE_TYPE) .. " #" .. zoneid
    end
    self.titleEntry = ISLabel:new(0, 0, FONT_HGT_SMALL + 4, title, 1, 1, 1, 0.9, UIFont.Small)
    self.titleEntry:initialise()
    self.titleEntry:instantiate()
    self:addChild(self.titleEntry)

    -- Joypad-only ADD button; hidden on mouse (ISAddDesignationAnimalZoneUI.onClick handles the confirm flow)
    self.buttonAdd = ISButton:new(
        pad, btnY, btnW, btnSz,
        getText("IGUI_DesignationZone_SetPosition"), self, ISAddDesignationAnimalZoneUI.onClick
    )
    self.buttonAdd.internal     = "ADD"
    self.buttonAdd.anchorTop    = false
    self.buttonAdd.anchorBottom = true
    self.buttonAdd:enableAcceptColor()
    self.buttonAdd:initialise()
    self.buttonAdd:instantiate()
    self:addChild(self.buttonAdd)
    self.buttonAdd:setVisible(false)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Actions
-- ----------------------------------------------------------------------------------------------------- --

function NR_AddZonePanel:onMouseDownOutside(x, y)
    if self.waitingConfirm then return end
    ISAddDesignationAnimalZoneUI.onMouseDownOutside(self, x, y)
end

function NR_AddZonePanel:onMouseUpOutside(x, y)
    if self.waitingConfirm then return end
    ISAddDesignationAnimalZoneUI.onMouseUpOutside(self, x, y)
end

function NR_AddZonePanel:onCreateZone(button)
    -- override: vanilla ISAddDesignationAnimalZoneUI.onCreateZone references cancel.enable which no longer exists
    if button.internal == "YES" then
        self:addZone()
    else
        self:undisplay()
    end
    self.waitingConfirm = false
end

function NR_AddZonePanel:askCreateZone()
    if not self.drawTileMouse or not self.startingX or not self.startingY
       or not self.widthCorrect or not self.heightCorrect then
        self:undisplay()
        return
    end
    self.drawTileMouse  = false
    self.waitingConfirm = true

    local modal = ISModalDialog:new(
        0, 0, 350, 150,
        getText("IGUI_DesignationZone_AddZone"),
        true, self, NR_AddZonePanel.onCreateZone
    )
    modal:initialise()
    modal:addToUIManager()
    modal.moveWithMouse = true
    if getJoypadData(self.playerNum) then
        modal:centerOnScreen(self.playerNum)
        modal.prevFocus = self
        setJoypadFocus(self.playerNum, modal)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_AddZonePanel:close()
    -- undisplay() is the vanilla close method: clears tile highlights, removes from UIManager
    self:undisplay()
    if self.parentUI then
        self.parentUI:setVisible(true)
        self.parentUI:populateList()
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad
-- ----------------------------------------------------------------------------------------------------- --

function NR_AddZonePanel:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self:setISButtonForA(self.buttonAdd)
    -- B left unmapped: no cancel button in this panel
    self.joypadWorldX = self.player:getCurrentSquare():getX()
    self.joypadWorldY = self.player:getCurrentSquare():getY()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Helpers
-- ----------------------------------------------------------------------------------------------------- --

function NR_AddZonePanel:updateButtons()
    if self.buttonAdd then
        self.buttonAdd:setVisible(getJoypadData(self.playerNum) ~= nil)
        self.buttonAdd.enable = (self.startingX ~= nil)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_AddZonePanel:prerender()
    local pad = NR_Config.padding
    local hh  = NR_Config.headerHeight

    local bg = NinePatchTexture.getSharedTexture("media/ui/NeatUI/DefaultPanel/MainPanelBG_FlatTop.png")
    if bg then
        bg:render(self:getAbsoluteX(), self:getAbsoluteY() + hh, self.width, self.height - hh, 0.15, 0.15, 0.15, NR_Config.bgAlpha)
    end

    local x = pad
    local y = hh + pad

    local nameKey  = getText("IGUI_PvpZone_ZoneName") .. " "
    local nameKeyW = getTextManager():MeasureStringX(UIFont.Small, nameKey)
    self:drawText(nameKey, x, y, 1, 1, 1, 0.7, UIFont.Small)
    self.titleEntry:setX(x + nameKeyW)
    self.titleEntry:setY(y)
    y = y + FONT_HGT_SMALL + pad

    local howTo = getText("IGUI_DesignationZone_HowTo")
    if getJoypadData(self.playerNum) then
        howTo = self.startingX == nil
            and getText("IGUI_DesignationZone_HowToJoypadStart")
            or  getText("IGUI_DesignationZone_HowToJoypadEnd")
    end
    self:drawText(howTo, x, y, 0.8, 0.8, 0.8, 0.9, UIFont.Small)

    -- Expand panel width if the instruction text is wider
    local needed = pad * 2 + getTextManager():MeasureStringX(UIFont.Small, howTo)
    if needed > self.width then
        self:setWidth(needed)
        if self.header then
            self.header:calculateLayout(needed, NR_Config.headerHeight)
        end
    end
    y = y + FONT_HGT_SMALL + pad

    if self.startingX and self.startRenderTile then
        local sx, sy = self.startingX, self.startingY
        local ex, ey = self.endX, self.endY
        if sx > ex then sx, ex = ex, sx end
        if sy > ey then sy, ey = ey, sy end

        local w    = (ex - sx) + 1
        local h    = (ey - sy) + 1
        local size = w * h

        self.widthCorrect  = (w >= 2 and w <= 40)
        self.heightCorrect = (h >= 2 and h <= 40)

        local wR, wG, wB = self.widthCorrect  and 1 or 0.9, self.widthCorrect  and 1 or 0.1, self.widthCorrect  and 1 or 0.1
        local hR, hG, hB = self.heightCorrect and 1 or 0.9, self.heightCorrect and 1 or 0.1, self.heightCorrect and 1 or 0.1

        self:drawText(getText("IGUI_DesignationZone_Type_Width")     .. ": " .. w,    x, y, wR, wG, wB, 1, UIFont.Small)
        y = y + FONT_HGT_SMALL
        self:drawText(getText("IGUI_DesignationZone_Type_Height")    .. ": " .. h,    x, y, hR, hG, hB, 1, UIFont.Small)
        y = y + FONT_HGT_SMALL
        self:drawText(getText("IGUI_DesignationZone_Type_TotalSize") .. ": " .. size, x, y, 1,  1,  1,  1, UIFont.Small)

        local r, g, b, a = self.zoneColor.r, self.zoneColor.g, self.zoneColor.b, self.zoneColor.a
        if not self.widthCorrect or not self.heightCorrect then r, g, b = 1, 0, 0 end
        addAreaHighlightForPlayer(
            self.playerNum, sx, sy, ex + 1, ey + 1,
            self.player:getCurrentSquare():getZ(), r, g, b, a
        )
    end

    self:highlightSquareAtMousePointer()
    self:highlightSquareAtStartPosition()
    self:updateButtons()
end
