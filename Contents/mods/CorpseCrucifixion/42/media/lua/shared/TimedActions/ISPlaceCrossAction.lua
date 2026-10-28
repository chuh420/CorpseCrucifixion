require "TimedActions/ISBaseTimedAction"
require "CorpseCrucifixion/CorpseCrucifixion"

ISPlaceCrossAction = ISBaseTimedAction:derive("ISPlaceCrossAction")

function ISPlaceCrossAction:isValid()
    if not self.character:getInventory():contains(self.item) then return false end
    return CorpseCrucifixion.isValidCrossSquare(self.square)
end

function ISPlaceCrossAction:waitToStart()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    return self.character:shouldBeTurning()
end

function ISPlaceCrossAction:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function ISPlaceCrossAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

function ISPlaceCrossAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISPlaceCrossAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISPlaceCrossAction:complete()
    return CorpseCrucifixion.placeCross(self.character, self.item, self.square, self.face)
end

function ISPlaceCrossAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 80
end

function ISPlaceCrossAction:new(character, item, square, face)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.square = square
    o.face = face
    o.maxTime = o:getDuration()
    return o
end
