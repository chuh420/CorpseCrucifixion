require "BuildingObjects/ISBuildingObject"
require "CorpseCrucifixion/CorpseCrucifixion"
require "TimedActions/ISCrucifyCorpseAction"
require "TimedActions/ISPlaceCrossAction"

PZCPreviewCursor = ISBuildingObject:derive("PZCPreviewCursor")

local function isHammer(item)
    return item:hasTag(ItemTag.HAMMER) and not item:isBroken()
end

function PZCPreviewCursor:init()
    ISBuildingObject.init(self)
    self.nSprite = 4
    self.dragNilAfterPlace = true
    self.noNeedHammer = true
    self.userRotated = false
end

function PZCPreviewCursor:getSprite()
    self.north = false
    return CorpseCrucifixion.MALE_SPRITE
end

function PZCPreviewCursor:getChosenFace()
    return CorpseCrucifixion.FACES[self.nSprite] or "S"
end

function PZCPreviewCursor:rotateKey(key)
    if getCore():isKey(KeybindId.ROTATE_BUILDING, key) then
        self.userRotated = true
    end
    ISBuildingObject.rotateKey(self, key)
end

function PZCPreviewCursor:rotateMouse(x, y)
    local before = self.nSprite
    ISBuildingObject.rotateMouse(self, x, y)
    if self.nSprite ~= before then
        self.userRotated = true
    end
end

function PZCPreviewCursor:renderFloor(x, y, z, valid)
    local sprite = self:getFloorCursorSprite()
    if valid then
        sprite:RenderGhostTileColor(x, y, z, 0.3, 1.0, 0.3, 0.6)
    else
        sprite:RenderGhostTileColor(x, y, z, 1.0, 0.25, 0.25, 0.6)
    end
end

function PZCPreviewCursor:hidePreview()
    local obj = self.previewObj
    self.previewObj = nil
    self.previewKey = nil
    if obj and obj:getSquare() then
        obj:getSquare():RemoveTileObject(obj)
    end
end

function PZCPreviewCursor:showPreview(square, key, builder)
    if not square then
        self:hidePreview()
        return
    end
    if self.previewKey ~= key then
        self:hidePreview()
        local obj = builder(square)
        if not obj then return end
        obj:getModData().pzcPreview = true
        square:AddSpecialObject(obj)
        self.previewObj = obj
        self.previewKey = key
    end
end

function PZCPreviewCursor:tintPreview(valid)
    local obj = self.previewObj
    if not obj then return end
    obj:setHighlighted(true, false)
    if valid then
        obj:setHighlightColor(0.4, 1.0, 0.4, 1.0)
    else
        obj:setHighlightColor(1.0, 0.3, 0.3, 1.0)
    end
end

function PZCPreviewCursor:deactivate()
    self:hidePreview()
end

function PZCPreviewCursor:isVisibleSquare(square)
    return square ~= nil and square:isCouldSee(self.player)
end

function PZCPreviewCursor:finish()
    self:hidePreview()
    getCell():setDrag(nil, self.player)
end

PZCCrucifyCursor = PZCPreviewCursor:derive("PZCCrucifyCursor")

function PZCCrucifyCursor:new(playerObj, corpse)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    o.player = playerObj:getPlayerNum()
    o.playerObj = playerObj
    o.corpse = corpse
    return o
end

function PZCCrucifyCursor:buildBody(square, onCross, face)
    local corpse = self.corpse
    local mannequin = CorpseCrucifixion.newBodyMannequin(square, corpse:isFemale(), corpse:getHumanVisual(), corpse:isZombie(), onCross, face)
    local visuals = ItemVisuals.new()
    corpse:getItemVisuals(visuals)
    local container = mannequin:getContainer()
    for i = 0, visuals:size() - 1 do
        local visual = visuals:get(i)
        local itemType = visual:getItemType()
        local item = itemType and instanceItem(itemType)
        if item and container then
            if item:getVisual() then
                item:getVisual():copyFrom(visual)
            end
            container:AddItem(item)
            mannequin:wearItem(item, nil)
        end
    end
    return mannequin
end

function PZCCrucifyCursor:resolveFace(square)
    if not square then return self:getChosenFace() end
    local cross = CorpseCrucifixion.getCross(square)
    if cross then return CorpseCrucifixion.getObjectFace(cross) end
    local chosen = self:getChosenFace()
    if self.userRotated then return chosen end
    if CorpseCrucifixion.getSurfaceBehind(square, chosen) then return chosen end
    return CorpseCrucifixion.findAutoFace(square) or chosen
end

function PZCCrucifyCursor:isValid(square)
    if not CorpseCrucifixion.isValidCorpse(self.corpse) then
        self:finish()
        return false
    end
    self.currentFace = self:resolveFace(square)
    if not self:isVisibleSquare(square) then return false end
    return CorpseCrucifixion.isValidCrucifyTarget(self.corpse, square, self.currentFace)
end

function PZCCrucifyCursor:render(x, y, z, square)
    local valid = self.canBeBuild
    self:renderFloor(x, y, z, valid)
    local face = self.currentFace or self:getChosenFace()
    local onCross = square ~= nil and CorpseCrucifixion.getFreeCross(square) ~= nil
    local key = x .. "," .. y .. "," .. z .. "," .. face .. "," .. tostring(onCross)
    self:showPreview(square, key, function(sq)
        return self:buildBody(sq, onCross, face)
    end)
    self:tintPreview(valid)
end

function PZCCrucifyCursor:tryBuild(x, y, z)
    local square = getCell():getGridSquare(x, y, z)
    local face = self:resolveFace(square)
    local playerObj = self.playerObj
    self:finish()
    if not CorpseCrucifixion.isValidCrucifyTarget(self.corpse, square, face) then return end
    if not luautils.walkAdj(playerObj, square) then return end
    ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), isHammer, true, false)
    local nails = playerObj:getInventory():getSomeTypeRecurse(CorpseCrucifixion.NAILS_TYPE, CorpseCrucifixion.NAILS_REQUIRED)
    for i = 0, nails:size() - 1 do
        ISWorldObjectContextMenu.transferIfNeeded(playerObj, nails:get(i))
    end
    ISTimedActionQueue.add(ISCrucifyCorpseAction:new(playerObj, self.corpse, square, face))
end

PZCCrossCursor = PZCPreviewCursor:derive("PZCCrossCursor")

function PZCCrossCursor:new(playerObj, item)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    o.player = playerObj:getPlayerNum()
    o.playerObj = playerObj
    o.item = item
    return o
end

function PZCCrossCursor:isValid(square)
    if not self.playerObj:getInventory():containsRecursive(self.item) then
        self:finish()
        return false
    end
    if not self:isVisibleSquare(square) then return false end
    return CorpseCrucifixion.isValidCrossSquare(square)
end

function PZCCrossCursor:render(x, y, z, square)
    local valid = self.canBeBuild
    self:renderFloor(x, y, z, valid)
    local face = self:getChosenFace()
    local key = x .. "," .. y .. "," .. z .. "," .. face
    self:showPreview(square, key, function(sq)
        local cross = CorpseCrucifixion.newCrossMannequin(sq, face)
        cross:getModData().pzcCross = nil
        return cross
    end)
    self:tintPreview(valid)
end

function PZCCrossCursor:tryBuild(x, y, z)
    local square = getCell():getGridSquare(x, y, z)
    local face = self:getChosenFace()
    local playerObj = self.playerObj
    self:finish()
    if not CorpseCrucifixion.isValidCrossSquare(square) then return end
    if not luautils.walkAdj(playerObj, square) then return end
    ISWorldObjectContextMenu.transferIfNeeded(playerObj, self.item)
    ISTimedActionQueue.add(ISPlaceCrossAction:new(playerObj, self.item, square, face))
end
