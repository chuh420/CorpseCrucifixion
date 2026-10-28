require "TimedActions/ISBaseTimedAction"
require "CorpseCrucifixion/CorpseCrucifixion"

ISPickUpCrossAction = ISBaseTimedAction:derive("ISPickUpCrossAction")

function ISPickUpCrossAction:isValid()
    return CorpseCrucifixion.canPickUpCross(self.cross)
end

function ISPickUpCrossAction:waitToStart()
    self.character:faceThisObject(self.cross)
    return self.character:shouldBeTurning()
end

function ISPickUpCrossAction:update()
    self.character:faceThisObject(self.cross)
end

function ISPickUpCrossAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
end

function ISPickUpCrossAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISPickUpCrossAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISPickUpCrossAction:complete()
    return CorpseCrucifixion.pickUpCross(self.character, self.cross)
end

function ISPickUpCrossAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 80
end

function ISPickUpCrossAction:new(character, cross)
    local o = ISBaseTimedAction.new(self, character)
    o.cross = cross
    o.maxTime = o:getDuration()
    return o
end
