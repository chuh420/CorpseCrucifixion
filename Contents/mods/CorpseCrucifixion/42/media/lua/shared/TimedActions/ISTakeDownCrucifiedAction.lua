require "TimedActions/ISBaseTimedAction"
require "CorpseCrucifixion/CorpseCrucifixion"

ISTakeDownCrucifiedAction = ISBaseTimedAction:derive("ISTakeDownCrucifiedAction")

function ISTakeDownCrucifiedAction:isValid()
    if not CorpseCrucifixion.isCrucified(self.crucified) or not CorpseCrucifixion.isObjectInWorld(self.crucified) then return false end
    return self.character:hasEquippedTag(ItemTag.REMOVE_BARRICADE)
end

function ISTakeDownCrucifiedAction:waitToStart()
    self.character:faceThisObject(self.crucified)
    return self.character:shouldBeTurning()
end

function ISTakeDownCrucifiedAction:update()
    self.character:faceThisObject(self.crucified)
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function ISTakeDownCrucifiedAction:start()
    self:setActionAnim("RemoveBarricade")
    local tool = self.character:getPrimaryHandItem()
    if tool and (tool:hasTag(ItemTag.CROWBAR) or tool:hasTag(ItemTag.PRY_BAR)) then
        self:setAnimVariable("RemoveBarricade", "CrowbarMid")
        self:setOverrideHandModels(tool, nil)
        self.sound = self.character:playSound("BeginRemoveBarricadePlankCrowbar")
    else
        self.character:clearVariable("RemoveBarricade")
        self:setOverrideHandModels(nil, nil)
        self.sound = self.character:playSound("BeginRemoveBarricadePlank")
    end
    addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 10, 1)
end

function ISTakeDownCrucifiedAction:stopSound()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    self.sound = nil
end

function ISTakeDownCrucifiedAction:stop()
    self:stopSound()
    ISBaseTimedAction.stop(self)
end

function ISTakeDownCrucifiedAction:perform()
    self:stopSound()
    self.character:playSound("RemoveBarricadePlank")
    ISBaseTimedAction.perform(self)
end

function ISTakeDownCrucifiedAction:complete()
    return CorpseCrucifixion.takeDown(self.character, self.crucified)
end

function ISTakeDownCrucifiedAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 200 - self.character:getPerkLevel(Perks.Woodwork) * 10
end

function ISTakeDownCrucifiedAction:new(character, crucified)
    local o = ISBaseTimedAction.new(self, character)
    o.crucified = crucified
    o.maxTime = o:getDuration()
    o.caloriesModifier = 4
    return o
end
