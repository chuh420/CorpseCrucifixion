require "CorpseCrucifixion/CorpseCrucifixion"
require "TimedActions/ISTakeDownCrucifiedAction"
require "TimedActions/ISPickUpCrossAction"

CorpseCrucifixionMenu = {}

local GOOD = " <RGB:0,1,0> "
local BAD = " <RGB:1,0,0> "

local function notBroken(item)
    return not item:isBroken()
end

local function isPullTool(item)
    return item:hasTag(ItemTag.REMOVE_BARRICADE) and not item:isBroken()
end

local function findCorpse(worldobjects)
    local fetch = ISWorldObjectContextMenu.fetchVars
    if fetch and CorpseCrucifixion.isValidCorpse(fetch.body) then
        return fetch.body
    end
    for _, obj in ipairs(worldobjects) do
        local square = obj:getSquare()
        if square then
            local bodies = square:getDeadBodys()
            for i = 0, bodies:size() - 1 do
                local body = bodies:get(i)
                if CorpseCrucifixion.isValidCorpse(body) then
                    return body
                end
            end
        end
    end
    return nil
end

local function findOnClicked(worldobjects, finder)
    for _, obj in ipairs(worldobjects) do
        local square = obj:getSquare()
        local found = square and finder(square)
        if found then return found end
    end
    return nil
end

local function makeTooltip(option, title, description)
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip:setName(title)
    tooltip.description = description
    option.toolTip = tooltip
end

function CorpseCrucifixionMenu.onCrucify(playerObj, corpse)
    getCell():setDrag(PZCCrucifyCursor:new(playerObj, corpse), playerObj:getPlayerNum())
end

function CorpseCrucifixionMenu.onTakeDown(playerObj, crucified)
    local square = crucified:getSquare()
    if not square or not luautils.walkAdj(playerObj, square) then return end
    ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), isPullTool, true, false)
    ISTimedActionQueue.add(ISTakeDownCrucifiedAction:new(playerObj, crucified))
end

function CorpseCrucifixionMenu.onPickUpCross(playerObj, cross)
    local square = cross:getSquare()
    if not square or not luautils.walkAdj(playerObj, square) then return end
    ISTimedActionQueue.add(ISPickUpCrossAction:new(playerObj, cross))
end

function CorpseCrucifixionMenu.onPlaceCross(playerObj, item)
    getCell():setDrag(PZCCrossCursor:new(playerObj, item), playerObj:getPlayerNum())
end

local function addCrucifyOption(playerObj, context, corpse)
    local inv = playerObj:getInventory()
    local hasHammer = inv:getFirstTagEvalRecurse(ItemTag.HAMMER, notBroken) ~= nil
    local nailCount = inv:getItemCountRecurse(CorpseCrucifixion.NAILS_TYPE)
    local enough = nailCount >= CorpseCrucifixion.NAILS_REQUIRED
    local title = getText("ContextMenu_PZC_Crucify")
    local option = context:addOption(title, playerObj, CorpseCrucifixionMenu.onCrucify, corpse)
    local desc = getText("Tooltip_PZC_Description") .. " <LINE> <LINE> "
    desc = desc .. (hasHammer and GOOD or BAD) .. getText("Tooltip_PZC_Hammer") .. " <LINE> "
    desc = desc .. (enough and GOOD or BAD) .. getText("Tooltip_PZC_Nails", nailCount, CorpseCrucifixion.NAILS_REQUIRED)
    makeTooltip(option, title, desc)
    if not hasHammer or not enough then
        option.notAvailable = true
    end
end

local function addTakeDownOption(playerObj, context, crucified)
    local hasTool = playerObj:getInventory():getFirstEvalRecurse(isPullTool) ~= nil
    local title = getText("ContextMenu_PZC_TakeDown")
    local option = context:addOption(title, playerObj, CorpseCrucifixionMenu.onTakeDown, crucified)
    makeTooltip(option, title, getText("Tooltip_PZC_TakeDownDescription") .. " <LINE> <LINE> " .. (hasTool and GOOD or BAD) .. getText("Tooltip_PZC_PullTool"))
    if not hasTool then
        option.notAvailable = true
    end
end

function CorpseCrucifixionMenu.onFillWorld(player, context, worldobjects, test)
    local playerObj = getSpecificPlayer(player)
    if not playerObj or playerObj:getVehicle() or playerObj:isDraggingCorpse() then return end

    local crucified = findOnClicked(worldobjects, CorpseCrucifixion.getCrucified)
    local freeCross = findOnClicked(worldobjects, CorpseCrucifixion.getFreeCross)
    local corpse = findCorpse(worldobjects)
    if not crucified and not freeCross and not corpse then return end
    if test then return ISWorldObjectContextMenu.setTest() end

    if crucified then
        addTakeDownOption(playerObj, context, crucified)
    end
    if freeCross then
        context:addOption(getText("ContextMenu_PZC_PickUpCross"), playerObj, CorpseCrucifixionMenu.onPickUpCross, freeCross)
    end
    if corpse then
        addCrucifyOption(playerObj, context, corpse)
    end
end

function CorpseCrucifixionMenu.onFillInventory(player, context, items)
    local playerObj = getSpecificPlayer(player)
    if not playerObj or playerObj:getVehicle() then return end
    for _, entry in ipairs(items) do
        local item = entry
        if type(entry) == "table" then
            item = entry.items and entry.items[1]
        end
        if item and item:getFullType() == CorpseCrucifixion.CROSS_ITEM_TYPE then
            context:addOption(getText("ContextMenu_PZC_PlaceCross"), playerObj, CorpseCrucifixionMenu.onPlaceCross, item)
            return
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(CorpseCrucifixionMenu.onFillWorld)
Events.OnFillInventoryObjectContextMenu.Add(CorpseCrucifixionMenu.onFillInventory)
