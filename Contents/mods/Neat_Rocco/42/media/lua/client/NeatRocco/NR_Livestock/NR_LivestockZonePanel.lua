-- NR_LivestockZonePanel.lua
-- NeatUI replacement panel for ISDesignationZonePanel.
-- Displays and manages livestock designation zones.

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Utils/NR_ModalRichText"
require "NeatRocco/NR_Utils/NR_SelectableList"
require "NeatRocco/NR_Utils/NR_ResizeWidget"

NR_LivestockZonePanel = NR_BasePanel:derive("NR_LivestockZonePanel")

local NIScrollView   = require("NeatUI_Framework/ScrollView/NIScrollView")
local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_LivestockZonePanel:new(x, y, width, height, player)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.player        = player
    o.playerNum     = player:getPlayerNum()
    o.selectedZone  = nil
    o.zoneRows      = {}
    o.warningY      = 0
    o.moveWithMouse = true

    NR_BasePanel.initBase(o)
    NR_LivestockZonePanel.instance = o
    player:setSeeDesignationZone(true)

    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_LivestockZonePanel:getWindowTitle()
    return getText("IGUI_DesignationZone_Title")
end

function NR_LivestockZonePanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Fences.png")
end

function NR_LivestockZonePanel:getInfoText()
    return getText("IGUI_DesignationZone_Info")
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_LivestockZonePanel:createChildren()
    NR_BasePanel.createChildren(self)
    self:createScrollView()
    self:createActionBar()
    self:createResizeWidget()
    self:calculateLayout(self.width, self.height)
    self:populateList()
end

function NR_LivestockZonePanel:createScrollView()
    local pad = NR_Config.padding
    local hh  = NR_Config.headerHeight
    local svW = self.width - pad * 2
    local svH = NR_Config.minListHeight

    self.scrollView = NIScrollView:new(pad, hh + pad, svW, svH)
    self.scrollView:initialise()
    self:addChild(self.scrollView)
end

function NR_LivestockZonePanel:createActionBar()
    local pad    = NR_Config.padding
    local btnSz  = NR_Config.buttonSize
    local barH   = NR_Config.actionBarHeight
    local barY   = self.scrollView:getBottom() + pad
    local barW   = self.width - pad * 2

    self.actionBar = ISPanel:new(pad, barY, barW, barH)
    self.actionBar:noBackground()
    self.actionBar:initialise()
    self:addChild(self.actionBar)

    local btnY  = math.floor((barH - btnSz) / 2)

    self.btnAdd = NI_SquareButton:new(
        0, btnY, btnSz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Add.png"),
        self, function() self:onClickAdd() end
    )
    self.btnAdd:initialise()
    self.btnAdd:setActive(true)
    self.actionBar:addChild(self.btnAdd)

    self.btnRename = NI_SquareButton:new(
        btnSz + pad, btnY, btnSz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Rename.png"),
        self, function() self:onClickRename() end
    )
    self.btnRename:initialise()
    self.btnRename.enable = false
    self.btnRename:setActive(false)
    self.actionBar:addChild(self.btnRename)

    self.btnRemove = NI_SquareButton:new(
        (btnSz + pad) * 2, btnY, btnSz,
        getTexture("media/ui/NeatRocco/ICON/Icon_Remove.png"),
        self, function() self:onClickRemove() end
    )
    self.btnRemove:initialise()
    self.btnRemove.enable = false
    self.btnRemove:setActive(false)
    self.actionBar:addChild(self.btnRemove)

end

function NR_LivestockZonePanel:createResizeWidget()
    self.resizeWidget = NR_ResizeWidget.create(self,
        function(target, w, h) target:calculateLayout(w, h) end)
end

-- ----------------------------------------------------------------------------------------------------- --
-- calculateLayout
-- ----------------------------------------------------------------------------------------------------- --

function NR_LivestockZonePanel:calculateLayout(_w, _h)
    local width  = math.max(_w or self.width,  self._contentMinWidth or NR_Config.minActionBarWidth)
    local height = math.max(_h or self.height, NR_Config.minWindowHeight)

    local pad  = NR_Config.padding
    local hh   = NR_Config.headerHeight
    local barH = NR_Config.actionBarHeight
    local wrnH = NR_Config.warningAreaHeight

    -- Header
    if self.header then
        self.header:setX(0)
        self.header:setY(0)
        self.header:setWidth(width)
        self.header:setHeight(hh)
        if self.header.calculateLayout then
            self.header:calculateLayout(width, hh)
        end
    end

    -- ScrollView
    local svY = hh + pad
    local svW = width - pad * 2
    local svH = height - hh - pad - barH - pad - wrnH - pad
    svH = math.max(svH, NR_Config.minListHeight)

    if self.scrollView then
        self.scrollView:setX(pad)
        self.scrollView:setY(svY)
        self.scrollView:setWidth(svW)
        self.scrollView:setHeight(svH)
    end

    -- Action bar
    local barY = svY + svH + pad
    if self.actionBar then
        self.actionBar:setX(pad)
        self.actionBar:setY(barY)
        self.actionBar:setWidth(width - pad * 2)
    end

    -- Warning area Y position (used in render)
    self.warningY = barY + barH + pad

    -- Recalculate actual height to fit everything
    height = self.warningY + NR_Config.warningAreaHeight

    self:setWidth(width)
    self:setHeight(height)
    if self.resizeWidget then
        local sz = NR_ResizeWidget.SIZE
        self.resizeWidget:setX(width - sz)
        self.resizeWidget:setY(height - sz)
    end

    -- Resize existing zone rows to new width
    self:layoutZoneRows()
end

function NR_LivestockZonePanel:layoutZoneRows()
    if not self.scrollView then return end
    local rowW = self.scrollView.width
    for _, row in ipairs(self.zoneRows) do
        if row and row.setWidth then
            row:setWidth(rowW)
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Zone list population
-- ----------------------------------------------------------------------------------------------------- --

function NR_LivestockZonePanel:populateList()
    -- Remove existing rows
    if self.scrollView then
        for _, row in ipairs(self.zoneRows) do
            self.scrollView:removeScrollChild(row)
        end
    end
    self.zoneRows     = {}
    self.selectedZone = nil

    local allZones     = DesignationZoneAnimal.getAllZones()
    local shownAlready = ArrayList.new()
    local rowY  = 0
    local rowW  = self.scrollView and self.scrollView.width or (self.width - NR_Config.padding * 2)
    local pad   = NR_Config.padding
    local tm    = getTextManager()
    local maxW  = 0

    for i = 0, allZones:size() - 1 do
        local zone = allZones:get(i)
        if not shownAlready:contains(zone) and zone:isStillStreamed() then
            local row = self:createZoneRow(zone, rowY, rowW)
            self.scrollView:addScrollChild(row)
            table.insert(self.zoneRows, row)
            rowY = rowY + NR_Config.itemHeight

            local nameW   = tm:MeasureStringX(UIFont.Small, zone:getName() or "")
            local sizeStr = "Size: " .. tostring(zone:getW() * zone:getH())
            local sizeW   = tm:MeasureStringX(UIFont.Small, sizeStr)
            local cw = pad + nameW + pad * 3 + sizeW + pad
            if cw > maxW then maxW = cw end

            local connectedZones = DesignationZoneAnimal.getAllDZones(nil, zone, nil)
            for j = 0, connectedZones:size() - 1 do
                shownAlready:add(connectedZones:get(j))
            end
        end
    end

    if self.scrollView then
        self.scrollView:setScrollHeight(rowY)
    end

    -- Warning texts also constrain minimum width
    local w1 = tm:MeasureStringX(UIFont.Small, getText("IGUI_DesignationZone_WanderInfo"))
    local w2 = tm:MeasureStringX(UIFont.Small, getText("IGUI_DesignationZone_WanderInfo2"))
    maxW = math.max(maxW, pad + math.max(w1, w2) + pad)

    -- Store for calculateLayout to use as floor (minSize button, resize clamp)
    self._contentMinWidth = math.max(maxW, NR_Config.minActionBarWidth)

    if maxW > 0 then
        self:calculateLayout(maxW, self.height)
    end

    self:updateButtonState()
end

function NR_LivestockZonePanel:createZoneRow(zone, yOffset, rowW)
    local ih    = NR_Config.itemHeight
    local pad   = NR_Config.padding
    local panel = self

    return NR_SelectableList.newRow(yOffset, rowW, ih,
        function() return panel.selectedZone == zone end,
        function() panel:selectZone(zone) end,
        function(row)
            local name = zone:getName() or ""
            row:drawText(name, pad, math.floor((ih - FONT_HGT_SMALL) / 2), 1, 1, 1, 0.9, UIFont.Small)
            local sizeStr = "Size: " .. tostring(zone:getW() * zone:getH())
            local sizeW   = getTextManager():MeasureStringX(UIFont.Small, sizeStr)
            row:drawText(sizeStr, row.width - sizeW - pad, math.floor((ih - FONT_HGT_SMALL) / 2), 0.7, 0.7, 0.7, 0.9, UIFont.Small)
        end
    )
end

-- ----------------------------------------------------------------------------------------------------- --
-- Selection
-- ----------------------------------------------------------------------------------------------------- --

function NR_LivestockZonePanel:selectZone(zone)
    if self.selectedZone ~= zone then
        self.player:resetSelectedZonesForHighlight()
    end
    self.selectedZone = zone
    self:updateButtonState()
end

function NR_LivestockZonePanel:updateButtonState()
    local has = (self.selectedZone ~= nil)

    if self.btnRename then
        self.btnRename.enable   = has
        self.btnRename:setActive(has)
    end
    if self.btnRemove then
        self.btnRemove.enable   = has
        self.btnRemove:setActive(has)
        if has then
            self.btnRemove:setActiveColor(0.8, 0.2, 0.2)
        end
    end
    self:updateJoypadProxies()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Actions
-- ----------------------------------------------------------------------------------------------------- --

function NR_LivestockZonePanel:onClickAdd()
    local ui = NR_AddZonePanel:new(
        getPlayerScreenLeft(self.playerNum) + 10,
        getPlayerScreenTop(self.playerNum) + 10,
        320, FONT_HGT_MEDIUM * 8,
        self.player
    )
    ui:initialise()
    ui:addToUIManager()
    ui.parentUI = self
    self:setVisible(false)
    if getJoypadData(self.playerNum) then
        setJoypadFocus(self.playerNum, ui)
    end
end

function NR_LivestockZonePanel:onClickRename()
    if not self.selectedZone then return end
    local modal = ISTextBox:new(
        0, 0, 280, 180,
        getText("ContextMenu_RenameBag"),
        self.selectedZone:getName(),
        self, NR_LivestockZonePanel.onRenameConfirm
    )
    modal:initialise()
    modal:addToUIManager()
    modal.maxChars = 30
    if getJoypadData(self.playerNum) then
        modal:centerOnScreen(self.playerNum)
        modal.prevFocus = self
        setJoypadFocus(self.playerNum, modal)
    end
end

function NR_LivestockZonePanel:onRenameConfirm(button)
    if button.internal == "OK" then
        local text = button.parent.entry:getText()
        if text and text ~= "" then
            self.selectedZone:setName(text)
            self:populateList()
        end
    end
end

function NR_LivestockZonePanel:onClickRemove()
    if not self.selectedZone then return end
    local modal = ISModalDialog:new(
        0, 0, 350, 150,
        getText("IGUI_Designation_RemoveConfirm", self.selectedZone:getName()),
        true, self,
        NR_LivestockZonePanel.onRemoveConfirm,
        nil, self.selectedZone
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

function NR_LivestockZonePanel.onRemoveConfirm(target, button, param1)
    if button.internal == "YES" then
        local zone = param1
        DesignationZoneAnimal.removeZone(zone, true)
        getSquare(zone:getX(), zone:getY(), zone:getZ()):flagForHotSave()
        target:populateList()
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_LivestockZonePanel:close()
    self.player:setSeeDesignationZone(false)
    self.player:resetSelectedZonesForHighlight()
    self:closeBase()
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad — proxy ISButton invisibles car NI_SquareButton ne supporte pas setISButtonForA/B/X/Y
-- ----------------------------------------------------------------------------------------------------- --

function NR_LivestockZonePanel:createJoypadProxies()
    if self.joypadProxiesCreated then return end
    self.joypadProxiesCreated = true

    local function makeProxy(internal, onclick)
        local btn = ISButton:new(0, 0, 0, 0, "", self, onclick)
        btn.internal = internal
        btn:initialise()
        btn:instantiate()
        btn:setVisible(false)
        self:addChild(btn)
        return btn
    end

    -- A = close (vanilla: closeButton "OK")
    self.joypadClose  = makeProxy("JOYPAD_CLOSE",  function(btn) self:close() end)
    -- B = remove (vanilla: removeZone)
    self.joypadRemove = makeProxy("JOYPAD_REMOVE", function(btn) self:onClickRemove() end)
    -- X = rename (vanilla: renameZone)
    self.joypadRename = makeProxy("JOYPAD_RENAME", function(btn) self:onClickRename() end)
    -- Y = add zone (vanilla: addZone)
    self.joypadAdd    = makeProxy("JOYPAD_ADD",    function(btn) self:onClickAdd() end)
end

function NR_LivestockZonePanel:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self:createJoypadProxies()
    -- Mirror vanilla ISDesignationZonePanel (listTakesFocus=false path)
    self:setISButtonForA(self.joypadClose)
    self:setISButtonForB(self.joypadRemove)
    self:setISButtonForX(self.joypadRename)
    self:setISButtonForY(self.joypadAdd)
end

function NR_LivestockZonePanel:onLoseJoypadFocus(joypadData)
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
    self:clearISButtons()
end

function NR_LivestockZonePanel:onJoypadDown(button, joypadData)
    ISPanelJoypad.onJoypadDown(self, button, joypadData)
end

-- Update proxy enable state to match button state (called from updateButtonState)
function NR_LivestockZonePanel:updateJoypadProxies()
    local has = (self.selectedZone ~= nil)
    if self.joypadRemove then self.joypadRemove.enable = has end
    if self.joypadRename then self.joypadRename.enable = has end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Keyboard
-- ----------------------------------------------------------------------------------------------------- --

function NR_LivestockZonePanel:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

-- (onKeyRelease héritée de NR_BasePanel)

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_LivestockZonePanel:render()
    ISPanelJoypad.render(self)

    -- Zone highlight
    self.player:setSeeDesignationZone(true)
    if self.selectedZone then
        local connectedZones = DesignationZoneAnimal.getAllDZones(nil, self.selectedZone, nil)
        for i = 0, connectedZones:size() - 1 do
            self.player:addSelectedZoneForHighlight(connectedZones:get(i):getId())
        end
    end

    -- Warning text
    local BHC = getCore():getBadHighlitedColor()
    local r, g, b = BHC:getR(), BHC:getG(), BHC:getB()
    self:drawText(getText("IGUI_DesignationZone_WanderInfo"),  NR_Config.padding, self.warningY,                              r, g, b, 1, UIFont.Small)
    self:drawText(getText("IGUI_DesignationZone_WanderInfo2"), NR_Config.padding, self.warningY + NR_Config.warningLineHeight, r, g, b, 1, UIFont.Small)

    -- Empty list message
    if self.scrollView and #self.zoneRows == 0 then
        local msg  = getText("IGUI_Animal_NoZoneFound")
        local msgW = getTextManager():MeasureStringX(UIFont.Small, msg)
        local msgX = self.scrollView.x + math.floor((self.scrollView.width - msgW) / 2)
        local msgY = self.scrollView.y + math.floor((self.scrollView.height - FONT_HGT_SMALL) / 2)
        -- Clamp so it never renders outside the scroll area
        msgX = math.max(self.scrollView.x, msgX)
        self:drawText(msg, msgX, msgY, 0.6, 0.6, 0.6, 0.8, UIFont.Small)
    end
end

return NR_LivestockZonePanel
