require "Moveables/ISMoveableSpriteProps"
require "CorpseCrucifixion/CorpseCrucifixion"

local originalCanPickUp = ISMoveableSpriteProps.canPickUpMoveable

function ISMoveableSpriteProps:canPickUpMoveable(_character, _square, _object)
    if CorpseCrucifixion.isModObject(_object) then
        return false
    end
    return originalCanPickUp(self, _character, _square, _object)
end

local originalCanScrap = ISMoveableSpriteProps.canScrapObject

function ISMoveableSpriteProps:canScrapObject(_character)
    if self.object and CorpseCrucifixion.isModObject(self.object) then
        return { canScrap = false }, 0, nil
    end
    return originalCanScrap(self, _character)
end
