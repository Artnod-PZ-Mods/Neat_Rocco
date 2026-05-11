-- NR_BasePanel.lua
-- Base class for all Neat Rocco panels.
-- Provides shared boilerplate: progress textures, drawBar, prerender, joypad/keyboard handlers.
-- Panels derive from NR_BasePanel instead of ISPanelJoypad, and call NR_BasePanel.initBase(o)
-- in their new() after ISPanelJoypad.new().

require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_Header"
require "NeatRocco/NR_Utils/NR_DrawBar"
require "NeatRocco/NR_Utils/NR_DrawUtils"

NR_BasePanel = ISPanelJoypad:derive("NR_BasePanel")

-- ----------------------------------------------------------------------------------------------------- --
-- Init helper — call in new() after ISPanelJoypad.new() and setmetatable
-- ----------------------------------------------------------------------------------------------------- --

function NR_BasePanel.initBase(o)
    NR_DrawBar.initTextures(o)
    o.drawFrame  = false
    o.background = false
    o:setWantKeyEvents(true)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_BasePanel:initialise()
    ISPanelJoypad.initialise(self)
end

function NR_BasePanel:createChildren()
    local hh = NR_Config.headerHeight
    self.header = NR_Header:new(0, 0, self.width, hh, self)
    self.header:initialise()
    self:addChild(self.header)
    self.header:calculateLayout(self.width, hh)
    if self.header.width > self.width then
        self:setWidth(self.header.width)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Background
-- ----------------------------------------------------------------------------------------------------- --

function NR_BasePanel:prerender()
    NR_DrawUtils.prerenderPanelBody(self, NR_Config.headerHeight)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Draw helpers
-- ----------------------------------------------------------------------------------------------------- --

function NR_BasePanel:getBarColor(pct) return NR_DrawBar.getBarColor(pct) end
function NR_BasePanel:drawBar(x, y, w, h, pct, fr, fg, fb) NR_DrawBar.drawBar(self, x, y, w, h, pct, fr, fg, fb) end
function NR_BasePanel:drawBarWithLabel(x, y, w, h, pct, label, fr, fg, fb) NR_DrawBar.drawBarWithLabel(self, x, y, w, h, pct, label, fr, fg, fb) end
function NR_BasePanel:drawSeparator(y) NR_DrawUtils.drawSeparator(self, y) end
function NR_BasePanel:drawTabTooltips(buttons, count) NR_DrawUtils.drawTabTooltips(self, buttons, count) end
function NR_BasePanel:drawLabelValue(label, value, xPivot, valX, y, la, vr, vg, vb) NR_DrawUtils.drawLabelValue(self, label, value, xPivot, valX, y, la, vr, vg, vb) end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad / keyboard
-- ----------------------------------------------------------------------------------------------------- --

-- Common close tail: joypad cleanup. Call at end of each panel's close().
function NR_BasePanel:closeBase()
    self:setVisible(false)
    self:removeFromUIManager()
    if JoypadState.players[self.playerNum + 1] then
        if isJoypadFocusOnElementOrDescendant(self.playerNum, self) then
            setJoypadFocus(self.playerNum, nil)
        end
    end
end

-- Center panel o on player screen. Call in new() after ISPanelJoypad.new().
function NR_BasePanel.centerOnPlayer(o, player, width, height)
    local pn = player:getPlayerNum()
    if o.y == 0 then
        o.y = getPlayerScreenTop(pn) + (getPlayerScreenHeight(pn) - height) / 2
        o:setY(o.y)
    end
    if o.x == 0 then
        o.x = getPlayerScreenLeft(pn) + (getPlayerScreenWidth(pn) - width) / 2
        o:setX(o.x)
    end
end

function NR_BasePanel:onGainJoypadFocus(_) self.drawJoypadFocus = true  end
function NR_BasePanel:onLoseJoypadFocus(_) self.drawJoypadFocus = false end

function NR_BasePanel:onJoypadDown(button, joypadData)
    if button == Joypad.BButton then self:close() ; return end
    ISPanelJoypad.onJoypadDown(self, button, joypadData)
end

function NR_BasePanel:isKeyConsumed(_) return false end

function NR_BasePanel:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:close() ; return true end
end
