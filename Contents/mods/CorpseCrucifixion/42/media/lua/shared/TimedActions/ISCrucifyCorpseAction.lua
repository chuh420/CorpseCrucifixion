require "TimedActions/ISBaseTimedAction"
require "CorpseCrucifixion/CorpseCrucifixion"

ISCrucifyCorpseAction = ISBaseTimedAction:derive("ISCrucifyCorpseAction")

function ISCrucifyCorpseAction:isValid()
    if not self.character:hasEquippedTag(ItemTag.HAMMER) then return false end
    if self.character:getInventory():getItemCount(CorpseCrucifixion.NAILS_TYPE) < CorpseCrucifixion.NAILS_REQUIRED then return false end
    return CorpseCrucifixion.isValidCrucifyTarget(self.corpse, self.square, self.face)
end

function ISCrucifyCorpseAction:waitToStart()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    return self.character:shouldBeTurning()
end

function ISCrucifyCorpseAction:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function ISCrucifyCorpseAction:start()
    self:setActionAnim("Build")
    self:setOverrideHandModels(self.character:getPrimaryHandItem(), nil)
    local radius = 20 * self.character:getHammerSoundMod()
    addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), radius, radius)
end

function ISCrucifyCorpseAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISCrucifyCorpseAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISCrucifyCorpseAction:complete()
    return CorpseCrucifixion.crucify(self.character, self.corpse, self.square, self.face)
end

function ISCrucifyCorpseAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    local time = 300 - self.character:getPerkLevel(Perks.Woodwork) * 15
    if self.character:hasTrait(CharacterTrait.HANDY) then
        time = time - 40
    end
    return time
end

function ISCrucifyCorpseAction:new(character, corpse, square, face)
    local o = ISBaseTimedAction.new(self, character)
    o.corpse = corpse
    o.square = square
    o.face = face
    o.maxTime = o:getDuration()
    o.caloriesModifier = 8
    return o
end
