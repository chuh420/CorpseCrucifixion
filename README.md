# Corpse Crucifixion

A Project Zomboid Build 42 mod. Nail a corpse to a wall, a fence, a tree or a wooden cross you build yourself.

## Usage

- Right-click a corpse and pick **Crucify Corpse**. You need a hammer and 4 nails.
- Move the cursor to choose the spot. The body preview turns green where it fits and red where it does not. Press R to rotate it.
- Right-click the hanging body and pick **Take Down Corpse**. The same body drops back to the ground and you get your 4 nails back.
- The body keeps its face, hair, skin, clothes and backpack, and you can loot it while it hangs.

## Wooden cross

Craft it in the Carpentry section from 2 planks and 2 nails with a hammer. Right-click it in your inventory and pick **Place Cross**. You can pick it up again while nobody hangs on it.

## Install

Copy `Contents/mods/CorpseCrucifixion` into `~/Zomboid/mods/` and enable it in the mod list. The mod works on existing saves. Take the bodies down before you remove it, or you lose them.

## Notes

- Requires Build 42. Multiplayer is untested.
- `devtools/` holds the scripts that regenerate the animations and cross mesh, plus the in-game test helpers. The mod does not need them.
