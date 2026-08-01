-- NR_PowerRange.lua
-- World overlay : contour de la zone alimentée par le générateur.
-- Per-gen ring (générateur ouvert) + Union ring (tous les générateurs actifs).
-- Appelé chaque frame depuis NR_GeneratorPanel:render().

require "NeatRocco/NR_Config"

NR_PowerRange = {
    _enabled        = false,
    _targetGen      = nil,
    -- Stencil (précompilé pour le rayon R du sandbox)
    _stencilR       = nil,
    _poweredOffsets = {},
    _edgeOffsets    = {},
    -- Per-gen
    _perGenEdges    = {},
    _perGenDirty    = true,
    _lastGenOnState = nil,
    -- Union
    _unionEdges     = {},
    _unionDirty     = true,
    _unionPollTick  = 0,
    -- Registre de tous les générateurs chargés
    _registry       = {},
    _registryByKey  = {},
    -- Suivi du sol courant
    _lastPlayerZ    = nil,
}

local PR = NR_PowerRange

local NEIGHBORS = {
    {-1,-1},{0,-1},{1,-1},
    {-1, 0},       {1, 0},
    {-1, 1},{0, 1},{1, 1},
}

-- ----------------------------------------------------------------------------------------------------- --
-- Helpers sandbox / player
-- ----------------------------------------------------------------------------------------------------- --

local function getTileRange()
    local sv = rawget(_G, "SandboxVars")
    if sv and type(sv.GeneratorTileRange) == "number" then
        return math.max(1, math.floor(sv.GeneratorTileRange))
    end
    return 20
end

local function getVerticalRange()
    local sv = rawget(_G, "SandboxVars")
    if sv and type(sv.GeneratorVerticalPowerRange) == "number" then
        return math.max(0, math.floor(sv.GeneratorVerticalPowerRange))
    end
    return 3
end

local function getPlayer0()
    return (getSpecificPlayer and getSpecificPlayer(0)) or (getPlayer and getPlayer())
end

-- ----------------------------------------------------------------------------------------------------- --
-- Registre de générateurs
-- ----------------------------------------------------------------------------------------------------- --

local function key3(x, y, z) return x .. "|" .. y .. "|" .. z end
local function isGen(o) return o and instanceof and instanceof(o, "IsoGenerator") end

local function addGen(obj)
    if not isGen(obj) then return end
    local sq = obj:getSquare(); if not sq then return end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local k = key3(x, y, z)
    if PR._registryByKey[k] then return end
    local entry = { obj = obj, x = x, y = y, z = z, _lastState = nil }
    table.insert(PR._registry, entry)
    PR._registryByKey[k] = entry
    PR._unionDirty = true
end

local function removeGen(obj)
    if not isGen(obj) then return end
    local sq = obj:getSquare(); if not sq then return end
    local k = key3(sq:getX(), sq:getY(), sq:getZ())
    if not PR._registryByKey[k] then return end
    PR._registryByKey[k] = nil
    for i = #PR._registry, 1, -1 do
        if PR._registry[i].obj == obj then table.remove(PR._registry, i); break end
    end
    PR._unionDirty = true
end

Events.LoadGridsquare.Add(function(sq)
    if not sq then return end
    local objs = sq:getObjects(); if not objs then return end
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        if isGen(o) then addGen(o) end
    end
end)

Events.OnObjectAboutToBeRemoved.Add(function(o)
    if isGen(o) then removeGen(o) end
end)

-- ----------------------------------------------------------------------------------------------------- --
-- Stencil (précompilé une fois par rayon R)
-- ----------------------------------------------------------------------------------------------------- --

local function buildStencil(R)
    local reach = R + 2
    local powered = {}
    local poweredOffsets = {}
    local edgeOffsets    = {}

    -- Masque des cases alimentées centré sur l'origine
    for y = -reach, reach do
        powered[y] = {}
        for x = -reach, reach do
            local p = IsoGenerator.isPoweringSquare(0, 0, 0, x, y, 0) == true
            powered[y][x] = p
            if p then poweredOffsets[#poweredOffsets + 1] = {x, y} end
        end
    end

    -- Bord extérieur : cases non-alimentées adjacentes à une case alimentée
    for y = -reach, reach do
        for x = -reach, reach do
            if not powered[y][x] then
                for _, nb in ipairs(NEIGHBORS) do
                    local nx, ny = x + nb[1], y + nb[2]
                    if nx >= -reach and nx <= reach and ny >= -reach and ny <= reach
                       and powered[ny] and powered[ny][nx] then
                        edgeOffsets[#edgeOffsets + 1] = {x, y}
                        break
                    end
                end
            end
        end
    end

    PR._stencilR       = R
    PR._poweredOffsets = poweredOffsets
    PR._edgeOffsets    = edgeOffsets
end

local function ensureStencil()
    local R = getTileRange()
    if PR._stencilR ~= R then
        buildStencil(R)
        PR._perGenDirty = true
        PR._unionDirty  = true
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Reconstruction des bords
-- ----------------------------------------------------------------------------------------------------- --

local function rebuildPerGen()
    PR._perGenEdges = {}
    PR._perGenDirty = false
    local gen = PR._targetGen
    if not gen then return end
    local sq = gen:getSquare(); if not sq then return end
    local gx, gy = sq:getX(), sq:getY()
    local eo = PR._edgeOffsets
    for i = 1, #eo do
        PR._perGenEdges[#PR._perGenEdges + 1] = { gx + eo[i][1], gy + eo[i][2] }
    end
end

local function rebuildUnion(targetZ)
    PR._unionEdges = {}
    PR._unionDirty = false
    local vr = getVerticalRange()
    local powered = {}

    for _, entry in ipairs(PR._registry) do
        local obj = entry.obj
        if obj and obj.isActivated and obj:isActivated() and math.abs(entry.z - targetZ) <= vr then
            local gx, gy = entry.x, entry.y
            for i = 1, #PR._poweredOffsets do
                powered[(gx + PR._poweredOffsets[i][1]) .. "|" .. (gy + PR._poweredOffsets[i][2])] = true
            end
        end
    end

    -- Zone du gen ciblé (masque les bords union qui tombent dedans, même si éteint)
    local perGenPowered = {}
    local gen = PR._targetGen
    if gen then
        local sq = gen:getSquare()
        if sq then
            local gx, gy = sq:getX(), sq:getY()
            for i = 1, #PR._poweredOffsets do
                perGenPowered[(gx + PR._poweredOffsets[i][1]) .. "|" .. (gy + PR._poweredOffsets[i][2])] = true
            end
        end
    end

    -- Bord extérieur de l'union, masqué là où il tombe dans la zone per-gen
    local edgeSet = {}
    for k, _ in pairs(powered) do
        local sep = k:find("|")
        local x   = tonumber(k:sub(1, sep - 1))
        local y   = tonumber(k:sub(sep + 1))
        for _, nb in ipairs(NEIGHBORS) do
            local nk = (x + nb[1]) .. "|" .. (y + nb[2])
            if not powered[nk] then
                edgeSet[nk] = { x + nb[1], y + nb[2] }
            end
        end
    end

    for k, v in pairs(edgeSet) do
        if not perGenPowered[k] then
            PR._unionEdges[#PR._unionEdges + 1] = v
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Dessin
-- ----------------------------------------------------------------------------------------------------- --

local function drawEdges(edges, z, color)
    local r, g, b, a = color.r, color.g, color.b, color.a
    for i = 1, #edges do
        local e = edges[i]
        addAreaHighlight(e[1], e[2], e[1] + 1, e[2] + 1, z, r, g, b, a)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- API publique
-- ----------------------------------------------------------------------------------------------------- --

function NR_PowerRange.start(gen)
    PR._enabled        = true
    PR._targetGen      = gen
    PR._perGenDirty    = true
    PR._unionDirty     = true
    PR._lastGenOnState = nil
    PR._lastPlayerZ    = nil
end

function NR_PowerRange.stop()
    PR._enabled        = false
    PR._targetGen      = nil
    PR._perGenEdges    = {}
    PR._unionEdges     = {}
    PR._lastGenOnState = nil
end

-- Appelé chaque frame depuis NR_GeneratorPanel:render()
function NR_PowerRange.update()
    if not PR._enabled then return end
    if not NR_Config.showPerGenOverlay and not NR_Config.showUnionOverlay then return end

    local gen = PR._targetGen; if not gen then return end
    local p   = getPlayer0();  if not p   then return end
    local pz  = p:getZ()

    ensureStencil()

    -- Changement d'étage → reconstruction
    if pz ~= PR._lastPlayerZ then
        PR._lastPlayerZ = pz
        PR._perGenDirty = true
        PR._unionDirty  = true
    end

    -- Per-gen
    if NR_Config.showPerGenOverlay then
        local isOn = gen:isActivated()
        if PR._lastGenOnState ~= isOn then
            PR._lastGenOnState = isOn
            PR._perGenDirty    = true
            PR._unionDirty     = true
        end
        if PR._perGenDirty then rebuildPerGen() end
    end

    -- Union : reconstruction sur dirty + polling toutes les 120 frames
    if NR_Config.showUnionOverlay then
        PR._unionPollTick = PR._unionPollTick - 1
        if PR._unionPollTick <= 0 then
            PR._unionPollTick = 120
            for _, entry in ipairs(PR._registry) do
                local obj = entry.obj
                if obj and obj.isActivated then
                    local cur = obj:isActivated()
                    if entry._lastState ~= cur then
                        entry._lastState = cur
                        PR._unionDirty   = true
                    end
                end
            end
        end
        if PR._unionDirty then rebuildUnion(pz) end
    end

    -- Dessin union en premier (derrière per-gen)
    if NR_Config.showUnionOverlay and #PR._unionEdges > 0 then
        drawEdges(PR._unionEdges, pz, NR_Config.unionColor)
    end

    -- Dessin per-gen par-dessus (vert si allumé, rouge si éteint)
    if NR_Config.showPerGenOverlay and #PR._perGenEdges > 0 then
        local isOn = gen:isActivated()
        local bad   = getCore():getBadHighlitedColor()
        local color = isOn and NR_Config.perGenColor
            or { r = bad:getR(), g = bad:getG(), b = bad:getB(), a = NR_Config.perGenColor.a }
        drawEdges(PR._perGenEdges, pz, color)
    end
end
