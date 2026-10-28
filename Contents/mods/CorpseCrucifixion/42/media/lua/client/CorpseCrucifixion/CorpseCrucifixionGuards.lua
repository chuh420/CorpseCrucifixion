require "CorpseCrucifixion/CorpseCrucifixion"
require "TimedActions/ISInventoryTransferAction"
require "ISUI/LootWindow/Handlers/MannequinSwitchOutfit"

local originalIsValid = ISInventoryTransferAction.isValid

function ISInventoryTransferAction:isValid()
    if CorpseCrucifixion.isStoredBody(self.item) then
        return false
    end
    local dest = self.destContainer
    if dest and CorpseCrucifixion.isModObject(dest:getParent()) then
        return false
    end
    return originalIsValid(self)
end

local switchOutfit = ISLootWindowObjectControlHandler_MannequinSwitchOutfit
local originalShouldBeVisible = switchOutfit.shouldBeVisible

function switchOutfit:shouldBeVisible()
    if CorpseCrucifixion.isModObject(self.object) then
        return false
    end
    return originalShouldBeVisible(self)
end
