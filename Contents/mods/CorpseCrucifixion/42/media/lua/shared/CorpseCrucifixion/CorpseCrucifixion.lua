CorpseCrucifixion = CorpseCrucifixion or {}

CorpseCrucifixion.NAILS_TYPE = "Base.Nails"
CorpseCrucifixion.NAILS_REQUIRED = 4
CorpseCrucifixion.STORED_BODY_TYPE = "Base.PZC_StoredBody"
CorpseCrucifixion.CROSS_ITEM_TYPE = "Base.PZC_WoodenCross"
CorpseCrucifixion.CROSS_SCRIPT = "PZC_Cross"
CorpseCrucifixion.MALE_SPRITE = "location_shop_mall_01_68"
CorpseCrucifixion.FEMALE_SPRITE = "location_shop_mall_01_65"
CorpseCrucifixion.MAX_CORPSE_DISTANCE = 2
CorpseCrucifixion.FACES = { "W", "N", "E", "S" }

CorpseCrucifixion.SIDES = {
    S = { dx = 0, dy = -1, edgeDx = 0, edgeDy = 0, edgeNorth = true },
    E = { dx = -1, dy = 0, edgeDx = 0, edgeDy = 0, edgeNorth = false },
    N = { dx = 0, dy = 1, edgeDx = 0, edgeDy = 1, edgeNorth = true },
    W = { dx = 1, dy = 0, edgeDx = 1, edgeDy = 0, edgeNorth = false },
}

local function getSquareAt(x, y, z)
    return getCell():getGridSquare(x, y, z)
end

local function collectItems(container)
    local list = {}
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        table.insert(list, items:get(i))
    end
    return list
end

function CorpseCrucifixion.isPreview(obj)
    return obj ~= nil and instanceof(obj, "IsoMannequin") and obj:getModData().pzcPreview == true
end

function CorpseCrucifixion.isCrucified(obj)
    return obj ~= nil and instanceof(obj, "IsoMannequin") and obj:getModData().corpseCrucified == true and obj:getModData().pzcPreview ~= true
end

function CorpseCrucifixion.isCross(obj)
    return obj ~= nil and instanceof(obj, "IsoMannequin") and obj:getModData().pzcCross == true and obj:getModData().pzcPreview ~= true
end

function CorpseCrucifixion.isModObject(obj)
    return CorpseCrucifixion.isCrucified(obj) or CorpseCrucifixion.isCross(obj)
end

function CorpseCrucifixion.isStoredBody(item)
    return item ~= nil and item:getFullType() == CorpseCrucifixion.STORED_BODY_TYPE
end

function CorpseCrucifixion.isObjectInWorld(obj)
    return obj ~= nil and obj:getSquare() ~= nil and obj:getObjectIndex() >= 0
end

local function findOnSquare(square, predicate)
    if not square then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if predicate(obj) then return obj end
    end
    return nil
end

function CorpseCrucifixion.getCrucified(square)
    return findOnSquare(square, CorpseCrucifixion.isCrucified)
end

function CorpseCrucifixion.getCross(square)
    return findOnSquare(square, CorpseCrucifixion.isCross)
end

function CorpseCrucifixion.getFreeCross(square)
    if CorpseCrucifixion.getCrucified(square) then return nil end
    return CorpseCrucifixion.getCross(square)
end

function CorpseCrucifixion.getObjectFace(obj)
    local face = obj:getModData().pzcFace
    if face then return face end
    local dir = obj:getForwardIsoDirection()
    return dir and tostring(dir) or "S"
end

local function edgeKind(square, north)
    if not square then return nil end
    if square:getWall(north) then return "Wall" end
    if square:getHoppable(north) then return "Fence" end
    return nil
end

local function blockKind(square)
    if not square then return nil end
    if square:getTree() then return "Tree" end
    if square:has(IsoFlagType.solid) then return "Object" end
    return nil
end

function CorpseCrucifixion.getSurfaceBehind(square, face)
    local info = CorpseCrucifixion.SIDES[face]
    if not square or not info then return nil end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local kind = edgeKind(getSquareAt(x + info.edgeDx, y + info.edgeDy, z), info.edgeNorth)
    if kind then return kind end
    return blockKind(getSquareAt(x + info.dx, y + info.dy, z))
end

function CorpseCrucifixion.isSquareFreeForBody(square)
    if not square then return false end
    if square:has(IsoFlagType.solid) or square:has(IsoFlagType.solidtrans) then return false end
    if square:getTree() then return false end
    if findOnSquare(square, function(o) return instanceof(o, "IsoMannequin") and not CorpseCrucifixion.isPreview(o) end) then return false end
    return true
end

function CorpseCrucifixion.isValidCorpse(corpse)
    if not corpse or not instanceof(corpse, "IsoDeadBody") then return false end
    if corpse:isAnimal() then return false end
    if not corpse:getSquare() then return false end
    return corpse:getStaticMovingObjectIndex() >= 0
end

function CorpseCrucifixion.isCorpseInRange(corpse, square)
    local cs = corpse:getSquare()
    if not cs or not square or cs:getZ() ~= square:getZ() then return false end
    local d = math.max(math.abs(cs:getX() - square:getX()), math.abs(cs:getY() - square:getY()))
    return d <= CorpseCrucifixion.MAX_CORPSE_DISTANCE
end

function CorpseCrucifixion.resolveTarget(square, face)
    if not square then return nil end
    local cross = CorpseCrucifixion.getCross(square)
    if cross then
        if CorpseCrucifixion.getCrucified(square) then return nil end
        return { onCross = true, face = CorpseCrucifixion.getObjectFace(cross), cross = cross }
    end
    if not CorpseCrucifixion.isSquareFreeForBody(square) then return nil end
    if face and CorpseCrucifixion.getSurfaceBehind(square, face) then
        return { onCross = false, face = face }
    end
    return nil
end

function CorpseCrucifixion.findAutoFace(square)
    for _, face in ipairs(CorpseCrucifixion.FACES) do
        if CorpseCrucifixion.getSurfaceBehind(square, face) then return face end
    end
    return nil
end

function CorpseCrucifixion.isValidCrucifyTarget(corpse, square, face)
    if not CorpseCrucifixion.isValidCorpse(corpse) then return false end
    if not CorpseCrucifixion.isCorpseInRange(corpse, square) then return false end
    return CorpseCrucifixion.resolveTarget(square, face) ~= nil
end

local function scriptExists(name)
    return getScriptManager():getMannequinScript(name) ~= nil
end

function CorpseCrucifixion.pickScriptName(female, visual, isZombie, onCross)
    local prefix = onCross and "PZC_X_" or "PZC_"
    local texture = visual and visual:getSkinTexture()
    if texture then
        texture = texture:match("([^/\\]+)$")
        local name = prefix .. texture
        if scriptExists(name) and getScriptManager():getMannequinScript(name):isFemale() == female then
            return name
        end
    end
    if isZombie then
        return prefix .. (female and "F_ZedBody01_level1" or "M_ZedBody01_level1")
    end
    return prefix .. (female and "FemaleBody01" or "MaleBody01")
end

function CorpseCrucifixion.newBodyMannequin(square, female, visual, isZombie, onCross, face)
    local sprite = getSprite(female and CorpseCrucifixion.FEMALE_SPRITE or CorpseCrucifixion.MALE_SPRITE)
    local obj = IsoMannequin.new(getCell(), square, sprite)
    if square then obj:setSquare(square) end
    obj:setMannequinScriptName(CorpseCrucifixion.pickScriptName(female, visual, isZombie, onCross))
    obj:getHumanVisual():copyFrom(visual)
    obj:setForwardIsoDirection(IsoDirections[face])
    return obj
end

function CorpseCrucifixion.newCrossMannequin(square, face)
    local obj = IsoMannequin.new(getCell(), square, getSprite(CorpseCrucifixion.MALE_SPRITE))
    if square then obj:setSquare(square) end
    obj:setMannequinScriptName(CorpseCrucifixion.CROSS_SCRIPT)
    obj:setForwardIsoDirection(IsoDirections[face])
    obj:getModData().pzcCross = true
    obj:getModData().pzcFace = face
    return obj
end

function CorpseCrucifixion.applyContainerName(obj)
    local container = obj and obj:getContainer()
    if not container then return end
    if CorpseCrucifixion.isCrucified(obj) then
        container:setCustomName(getText("IGUI_PZC_CrucifiedBody"))
    elseif CorpseCrucifixion.isCross(obj) then
        container:setCustomName(getText("IGUI_PZC_WoodenCross"))
    end
end

function CorpseCrucifixion.addObject(square, obj)
    CorpseCrucifixion.applyContainerName(obj)
    square:AddSpecialObject(obj)
    if isServer() then
        obj:transmitCompleteItemToClients()
    end
end

function CorpseCrucifixion.removeNails(character)
    local inv = character:getInventory()
    local nails = inv:RemoveAll("Nails", CorpseCrucifixion.NAILS_REQUIRED)
    sendRemoveItemsFromContainer(inv, nails)
end

function CorpseCrucifixion.returnNails(character)
    local inv = character:getInventory()
    for _ = 1, CorpseCrucifixion.NAILS_REQUIRED do
        local nail = inv:AddItem(CorpseCrucifixion.NAILS_TYPE)
        if nail then
            sendAddItemToContainer(inv, nail)
        end
    end
end

function CorpseCrucifixion.crucify(character, corpse, square, face)
    if not CorpseCrucifixion.isValidCrucifyTarget(corpse, square, face) then return false end
    local target = CorpseCrucifixion.resolveTarget(square, face)

    local obj = CorpseCrucifixion.newBodyMannequin(square, corpse:isFemale(), corpse:getHumanVisual(), corpse:isZombie(), target.onCross, target.face)
    local dst = obj:getContainer()
    if not dst then return false end

    local src = corpse:getContainer()
    if src then
        local worn = corpse:getWornItems()
        for _, item in ipairs(collectItems(src)) do
            local isWorn = worn and worn:contains(item)
            src:DoRemoveItem(item)
            item:setAttachedSlot(-1)
            item:setAttachedSlotType(nil)
            item:setAttachedToModel(nil)
            dst:AddItem(item)
            if isWorn then
                obj:wearItem(item, nil)
            end
        end
    end

    if corpse:getWornItems() then corpse:getWornItems():clear() end
    if corpse:getAttachedItems() then corpse:getAttachedItems():clear() end
    corpse:setPrimaryHandItem(nil)
    corpse:setSecondaryHandItem(nil)

    local stored = instanceItem(CorpseCrucifixion.STORED_BODY_TYPE)
    if stored then
        stored:storeInByteData(corpse)
        dst:AddItem(stored)
    end

    obj:getModData().corpseCrucified = true
    obj:getModData().pzcOnCross = target.onCross
    obj:getModData().pzcFace = target.face

    corpse:getSquare():removeCorpse(corpse, false)
    CorpseCrucifixion.addObject(square, obj)

    CorpseCrucifixion.removeNails(character)
    addXp(character, Perks.Woodwork, 2)
    return true
end

local function restoreBody(stored, square)
    local body = stored:loadCorpseFromByteData(square)
    if not body then return nil end
    body:setX(square:getX() + 0.5)
    body:setY(square:getY() + 0.5)
    body:setZ(square:getZ())
    body:setSquare(square)
    body:setCurrent(square)
    return body
end

local function dropOnFloor(square, item)
    square:AddWorldInventoryItem(item, ZombRandFloat(0.2, 0.8), ZombRandFloat(0.2, 0.8), 0, true)
end

function CorpseCrucifixion.takeDown(character, obj)
    if not CorpseCrucifixion.isCrucified(obj) or not CorpseCrucifixion.isObjectInWorld(obj) then return false end
    local square = obj:getSquare()
    local container = obj:getContainer()
    local items = container and collectItems(container) or {}

    local stored
    for _, item in ipairs(items) do
        if CorpseCrucifixion.isStoredBody(item) then
            stored = item
            break
        end
    end

    local body = stored and restoreBody(stored, square)
    local mannequinWorn = obj:getWornItems()

    for _, item in ipairs(items) do
        if item ~= stored then
            local isWorn = mannequinWorn and mannequinWorn:contains(item)
            container:DoRemoveItem(item)
            if body then
                body:getContainer():AddItem(item)
                local location = item:getBodyLocation() or item:canBeEquipped()
                if isWorn and location and body:getWornItems() then
                    body:getWornItems():setItem(location, item)
                end
            else
                dropOnFloor(square, item)
            end
        end
    end
    if stored then
        container:DoRemoveItem(stored)
    end

    square:transmitRemoveItemFromSquare(obj)

    if body then
        square:addCorpse(body, false)
        body:invalidateCorpse()
        body:setInvalidateNextRender(true)
        if isServer() then
            sendCorpse(body)
        end
    end

    CorpseCrucifixion.returnNails(character)
    return true
end

function CorpseCrucifixion.isValidCrossSquare(square)
    if not square then return false end
    if not CorpseCrucifixion.isSquareFreeForBody(square) then return false end
    return square:isFreeOrMidair(true)
end

function CorpseCrucifixion.placeCross(character, item, square, face)
    if not CorpseCrucifixion.isValidCrossSquare(square) then return false end
    local inv = character:getInventory()
    if not item or not inv:contains(item) then return false end
    inv:Remove(item)
    sendRemoveItemFromContainer(inv, item)
    CorpseCrucifixion.addObject(square, CorpseCrucifixion.newCrossMannequin(square, face))
    return true
end

function CorpseCrucifixion.canPickUpCross(cross)
    return CorpseCrucifixion.isCross(cross) and CorpseCrucifixion.isObjectInWorld(cross) and CorpseCrucifixion.getCrucified(cross:getSquare()) == nil
end

function CorpseCrucifixion.pickUpCross(character, cross)
    if not CorpseCrucifixion.canPickUpCross(cross) then return false end
    local square = cross:getSquare()
    square:transmitRemoveItemFromSquare(cross)
    local inv = character:getInventory()
    local item = inv:AddItem(CorpseCrucifixion.CROSS_ITEM_TYPE)
    if item then
        sendAddItemToContainer(inv, item)
    end
    return true
end

function CorpseCrucifixion.onLoadGridsquare(square)
    local objects = square:getObjects()
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoMannequin") then
            if CorpseCrucifixion.isPreview(obj) then
                square:RemoveTileObject(obj)
            else
                CorpseCrucifixion.applyContainerName(obj)
            end
        end
    end
end

Events.LoadGridsquare.Add(CorpseCrucifixion.onLoadGridsquare)
