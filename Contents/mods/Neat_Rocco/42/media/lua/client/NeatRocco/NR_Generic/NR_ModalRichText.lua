-- NR_ModalRichText.lua
-- NeatUI-styled override of ISModalRichText.
-- Derives from ISModalRichText so all logic (rich text, scroll, joypad, callbacks) is inherited.
-- Strategy: call ISModalRichText.initialise() to create vanilla ok ISButton (needed for joypad),
-- hide it, add NR_Header at top with close button, move chatText below header.

require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_Header"
require "NeatRocco/NR_Utils/NR_DrawUtils"
require "NeatRocco/NR_Utils/NR_ScrollingList"

NR_ModalRichText = ISModalRichText:derive("NR_ModalRichText")

-- ----------------------------------------------------------------------------------------------------- --
-- Text analysis helpers (static)
-- ----------------------------------------------------------------------------------------------------- --

local CANDIDATE_PATTERN  = "<SIZE:medium>%s*(.-)%s*<LINE>"
local BODY_PATTERN_A     = "<LEFT>%s*<SIZE:small>%s*(.+)$"
local BODY_PATTERN_B     = "<SIZE:small>%s*<LEFT>%s*(.+)$"
local LONG_TITLE_THRESHOLD = 30

function NR_ModalRichText.getTitle(rawText)
    return rawText:match(CANDIDATE_PATTERN) or ""
end

function NR_ModalRichText.getBody(rawText)
    return rawText:match(BODY_PATTERN_A)
        or rawText:match(BODY_PATTERN_B)
        or rawText
end
function NR_ModalRichText.hasTitle(rawText)
    return NR_ModalRichText.getTitle(rawText) ~= ""
end

function NR_ModalRichText.isLongTitle(rawText)
    return #NR_ModalRichText.getTitle(rawText) > LONG_TITLE_THRESHOLD
end



-- ----------------------------------------------------------------------------------------------------- --
-- Static constructor
-- no title in text    → vanilla fallback key as title, full raw text as body
-- long title in text  → vanilla fallback key as title, full raw text as body
-- short title in text → extracted title in header, body without title
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText.newFromRichText(x, y, w, h, rawText, fallbackTitle)
    local title, body
    if NR_ModalRichText.hasTitle(rawText) then
        if NR_ModalRichText.isLongTitle(rawText) then
            title = fallbackTitle or ""
            body  = rawText
        else
            title = NR_ModalRichText.getTitle(rawText)
            body  = NR_ModalRichText.getBody(rawText)
        end
    else
        title = fallbackTitle or ""
        body  = rawText
    end
    local ui = NR_ModalRichText:new(x, y, w, h, body, false)
    ui.windowTitle = title
    return ui
end

-- ----------------------------------------------------------------------------------------------------- --
-- Title (used by NR_Header)
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:getWindowTitle()
    return self.windowTitle or ""
end

-- close() called by NR_Header X button
function NR_ModalRichText:close()
    ISModalRichText.onClick(self, { internal = "OK" })
end

-- ----------------------------------------------------------------------------------------------------- --
-- initialise
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:initialise()
    -- Create vanilla ok ISButton + chatText (needed for joypad + scroll logic)
    ISModalRichText.initialise(self)

    local hh = NR_Config.headerHeight

    -- Hide vanilla ok button — joypad still uses it via setISButtonForA
    self.ok:setVisible(false)

    -- NR_Header (draggable, close button → calls self:close())
    self.header = NR_Header:new(0, 0, self.width, hh, self)
    self.header:initialise()
    self:addChild(self.header)
    self.header:calculateLayout(self.width, hh)

    -- Move chatText below header (vanilla placed it at y=2)
    self.chatText:setY(hh + 2)
    self.chatText:setHeight(self.height - hh - 2)
    if self.chatText.vscroll then
        NR_ScrollingList.applyNeatStyle(self.chatText.vscroll)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- updateButtons — no bottom buttons to reposition
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:updateButtons()
    -- nothing: vanilla ok is hidden, NR_Header handles the close button
end

-- ----------------------------------------------------------------------------------------------------- --
-- setHeightToContents — account for header instead of bottom button area
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:setHeightToContents()
    local hh = NR_Config.headerHeight
    local minHeight = self.chatText:getScrollHeight() + hh + 2
    self:setHeight(minHeight)
    self:ignoreHeightChange()
end

-- ----------------------------------------------------------------------------------------------------- --
-- update — auto-resize window, keep chatText filling space below header
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:update()
    ISPanelJoypad.update(self)

    local hh        = NR_Config.headerHeight
    local maxHeight = getCore():getScreenHeight() - 40
    local minHeight = math.min(self.chatText:getScrollHeight() + hh + 2, maxHeight)

    if self:getHeight() < minHeight then
        local dh = minHeight - self:getHeight()
        self:setHeight(minHeight)
        self:ignoreHeightChange()
        self:setY(math.max(self:getY() - dh / 2, 20))
    elseif self:getHeight() > maxHeight then
        self:setHeight(maxHeight)
        self:ignoreHeightChange()
        self:setY(20)
    end

    self.chatText:setHeight(self.height - hh - 2)
    self.chatText:updateScrollbars()

    if self.alwaysOnTop then
        self:bringToTop()
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- prerender — NeatUI background (below header)
-- ----------------------------------------------------------------------------------------------------- --

function NR_ModalRichText:prerender()
    local hh = NR_Config.headerHeight
    NR_DrawUtils.prerenderPanelBody(self, hh)
    self:drawRect(0, hh - 1, self.width, 2, 1, 0, 0, 0)
end
