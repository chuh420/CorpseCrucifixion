require "CorpseCrucifixion/CorpseCrucifixion"

PZCAutoTest = {}

local MARKER = "pzc_autotest.txt"
local START = { x = 10692, y = 9417, z = 0 }

local function log(msg)
    print("[PZC test] " .. msg)
end

function PZCAutoTest.isEnabled()
    if not getDebug() then return false end
    local ok, reader = pcall(getFileReader, MARKER, false)
    if ok and reader then
        reader:close()
        return true
    end
    return false
end

local function findWallSquares(cx, cy, z, count)
    local result = {}
    for dy = -6, 6 do
        for dx = -8, 8 do
            local sq = getCell():getGridSquare(cx + dx, cy + dy, z)
            if sq and CorpseCrucifixion.isSquareFreeForBody(sq) and sq:isFreeOrMidair(false)
                and CorpseCrucifixion.getSurfaceBehind(sq, "S") == "Wall" then
                table.insert(result, sq)
            end
        end
    end
    table.sort(result, function(a, b)
        if a:getY() ~= b:getY() then return a:getY() < b:getY() end
        return a:getX() < b:getX()
    end)
    local picked = {}
    for _, sq in ipairs(result) do
        local clash = false
        for _, p in ipairs(picked) do
            if math.abs(p:getX() - sq:getX()) < 2 and p:getY() == sq:getY() then clash = true end
        end
        if not clash then table.insert(picked, sq) end
        if #picked >= count then break end
    end
    return picked
end

local function below(sq)
    return getCell():getGridSquare(sq:getX(), sq:getY() + 1, sq:getZ())
end

local function countCorpses(sq)
    return sq and sq:getDeadBodys():size() or -1
end

local function runPipeline(player, squares)
    local inv = player:getInventory()
    for _ = 1, 16 do inv:AddItem(CorpseCrucifixion.NAILS_TYPE) end
    inv:AddItem("Base.Hammer")

    local wallSq = squares[1]
    if wallSq then
        local corpse = createRandomDeadBody(below(wallSq), 0)
        log("wall crucify at " .. wallSq:getX() .. "," .. wallSq:getY() .. " female=" .. tostring(corpse:isFemale()) .. " result=" .. tostring(CorpseCrucifixion.crucify(player, corpse, wallSq, "S")))
    end

    local crossSq = squares[2]
    if crossSq then
        local crossItem = inv:AddItem(CorpseCrucifixion.CROSS_ITEM_TYPE)
        log("cross placed at " .. crossSq:getX() .. "," .. crossSq:getY() .. " result=" .. tostring(CorpseCrucifixion.placeCross(player, crossItem, crossSq, "S")))
        local corpse = createRandomDeadBody(below(crossSq), 0)
        log("cross crucify female=" .. tostring(corpse:isFemale()) .. " result=" .. tostring(CorpseCrucifixion.crucify(player, corpse, crossSq, "S")))
    end

    local downSq = squares[3]
    if downSq then
        local corpse = createRandomDeadBody(below(downSq), 0)
        local nailsBefore = inv:getItemCount(CorpseCrucifixion.NAILS_TYPE)
        CorpseCrucifixion.crucify(player, corpse, downSq, "S")
        local crucified = CorpseCrucifixion.getCrucified(downSq)
        local ok = CorpseCrucifixion.takeDown(player, crucified)
        local nailsAfter = inv:getItemCount(CorpseCrucifixion.NAILS_TYPE)
        log("take down at " .. downSq:getX() .. "," .. downSq:getY() .. " result=" .. tostring(ok) .. " corpses on square=" .. countCorpses(downSq) .. " nails " .. nailsBefore .. "->" .. nailsAfter)
    end

    local spare = squares[4]
    if spare then
        PZCAutoTest.spareCorpse = createRandomDeadBody(below(spare), 0)
        PZCAutoTest.previewSquare = spare
        log("preview square " .. spare:getX() .. "," .. spare:getY())
    end
end

local ticks = 0

local function onTick()
    ticks = ticks + 1
    if ticks < 120 then return end
    Events.OnTick.Remove(onTick)
    local player = getPlayer()
    if not player then return end
    player:setGodMod(true, false)
    player:setInvisible(true)
    player:setGhostMode(true, false)
    getGameTime():setTimeOfDay(12)
    local squares = findWallSquares(START.x, START.y, START.z, 4)
    log("found " .. #squares .. " wall squares")
    local ok, err = pcall(runPipeline, player, squares)
    if not ok then log("pipeline error: " .. tostring(err)) end
    if PZCAutoTest.spareCorpse then
        getCell():setDrag(PZCCrucifyCursor:new(player, PZCAutoTest.spareCorpse), 0)
        log("cursor active")
    end
    log("ready")
end

if debugScenarios == nil then
    debugScenarios = {}
end

debugScenarios.PZCAutoTest = {
    name = "PZC Crucifixion Test",
    startLoc = START,
    setSandbox = function()
        SandboxVars.Zombies = 6
        SandboxVars.StartTime = 2
    end,
    onStart = function()
        Events.OnTick.Add(onTick)
    end,
}

local originalDoDebugScenarios = doDebugScenarios

function doDebugScenarios()
    originalDoDebugScenarios()
    if PZCAutoTest.isEnabled() and DebugScenarios.instance and not PZCAutoTest.launched then
        PZCAutoTest.launched = true
        log("auto launching")
        DebugScenarios.instance:launchScenario(debugScenarios.PZCAutoTest)
    end
end

local function closeGuide()
    if SurvivalGuide and SurvivalGuide.instance and SurvivalGuide.instance:isVisible() then
        SurvivalGuide.instance:onClose()
        Events.OnPreUIDraw.Remove(closeGuide)
        log("guide closed")
    end
end

Events.OnGameStart.Add(function()
    if PZCAutoTest.isEnabled() then
        Events.OnPreUIDraw.Add(closeGuide)
    end
end)

local lastCmd = nil
local cmdTicks = 0

local function readCommandFile()
    local ok, reader = pcall(getFileReader, "pzc_cmd.lua", false)
    if not ok or not reader then return nil end
    local lines = {}
    local line = reader:readLine()
    while line do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()
    return table.concat(lines, "\n")
end

local function pollCommands()
    cmdTicks = cmdTicks + 1
    if cmdTicks < 30 then return end
    cmdTicks = 0
    local src = readCommandFile()
    if not src or src == "" or src == lastCmd then return end
    lastCmd = src
    if not loadstring then
        log("cmd: loadstring unavailable")
        return
    end
    local fn, err = loadstring(src)
    if not fn then
        log("cmd compile error: " .. tostring(err))
        return
    end
    local ok, res = pcall(fn)
    log("cmd result ok=" .. tostring(ok) .. " res=" .. tostring(res))
end

Events.OnGameStart.Add(function()
    if PZCAutoTest.isEnabled() then
        Events.OnPreUIDraw.Add(pollCommands)
    end
end)
