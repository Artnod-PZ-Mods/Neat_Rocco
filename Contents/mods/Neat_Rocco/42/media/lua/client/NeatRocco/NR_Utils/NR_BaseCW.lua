-- NR_BaseCW.lua
-- Utility module for ISCollapsableWindowJoypad-based NeatUI panels.
-- Provides the same factorization as NR_BasePanel, but as a module (not a class)
-- because these panels must derive from their vanilla ISCollapsableWindowJoypad class.
--
-- Required panel contract:
--   titleBarHeight()   → must return NR_Config.headerHeight (add to each panel)
--   getWindowTitle()   → string (consumed by NR_Header)
--   close()            → close handler (consumed by NR_Header)
-- Optional:
--   getWindowIcon()    → texture or nil
--   onClickInfo()      → shows info modal (triggers NR_Header info button)

require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_Header"
require "NeatRocco/NR_Utils/NR_DrawBar"
require "NeatRocco/NR_Utils/NR_DrawUtils"

NR_BaseCW = {}

-- ----------------------------------------------------------------------------------------------------- --
-- initBase — call in new() after setmetatable
-- ----------------------------------------------------------------------------------------------------- --

function NR_BaseCW.initBase(o)
    NR_DrawBar.initTextures(o)
    o.drawFrame  = false
    o.background = false
end

-- ----------------------------------------------------------------------------------------------------- --
-- createHeader — call in create() after ISXxx.create(self)
-- Hides vanilla title bar buttons and adds NR_Header as child.
-- NR_Header requires calculateLayout() to compute ISTableLayout columns
-- in ISCollapsableWindowJoypad context.
-- Result stored in panel.header.
-- ----------------------------------------------------------------------------------------------------- --

function NR_BaseCW.createHeader(panel)
    local hh = NR_Config.headerHeight
    panel.closeButton:setVisible(false)
    panel.collapseButton:setVisible(false)
    if panel.infoButton then panel.infoButton:setVisible(false) end
    panel.header = NR_Header:new(0, 0, panel.width, hh, panel)
    panel.header:initialise()
    panel:addChild(panel.header)
    panel.header:calculateLayout(panel.width, hh)
end

-- ----------------------------------------------------------------------------------------------------- --
-- prerenderBody — call in prerender() to draw the NeatUI body background
-- ----------------------------------------------------------------------------------------------------- --

function NR_BaseCW.prerenderBody(panel)
    NR_DrawUtils.prerenderPanelBody(panel, NR_Config.headerHeight)
end

NR_BaseCW.drawBar           = NR_DrawBar.drawBar
NR_BaseCW.drawBarWithLabel  = NR_DrawBar.drawBarWithLabel
NR_BaseCW.drawSeparator     = NR_DrawUtils.drawSeparator
NR_BaseCW.drawTabTooltips   = NR_DrawUtils.drawTabTooltips
NR_BaseCW.drawLabelValue    = NR_DrawUtils.drawLabelValue
