extends RefCounted
## Shared layout of the gate-top defence work. The gallery, the stone hatch and the
## cauldron are built by three different owners, so their anchors live here instead of
## being repeated as magic numbers in each file.
##
## Coordinates are LOCAL to CastleSite. The gate is at z = 68, the wall-walk deck top is
## y = 19.02, and the hoarding floor sits one metre above it on the old gate pediment.

const FLOOR_Y := 20.0                  ## top of the hoarding deck
const DECK := 0.14                     ## plank thickness
const HALF_W := 3.4                    ## hoarding half width
const Z_IN := 69.0                     ## courtyard-side edge of the hoarding
const Z_OUT := 71.9                    ## battle edge, over the gate approach
const PARAPET_H := 0.95

const STAIR_Z0 := 67.9                 ## first step on the wall-walk
const STAIR_Z1 := 69.15                ## landing on the hoarding
const STAIR_W := 2.4

## The stone hatch is a real hole in the hoarding floor.
const HATCH_CENTRE := Vector3(1.40, FLOOR_Y, 70.60)
const HATCH_HALF := Vector2(0.60, 0.60)   ## x half, z half

## Cauldron: pushed by the player from the courtyard side toward the outer edge.
const CAULDRON_START := Vector3(-1.85, FLOOR_Y, 70.15)
const CAULDRON_END_Z := 70.95
const CAULDRON_RADIUS := 0.82

## Hatch lever, on a post at the entry so the player does not stand on the flaps.
const LEVER_POS := Vector3(2.88, FLOOR_Y, 69.48)

## Oil leaves the pot here, beyond the outer parapet, and lands on the approach.
const OIL_SPOUT := Vector3(-1.85, FLOOR_Y + 1.18, 71.15)
const OIL_IMPACT := Vector3(-1.85, 0.02, 72.15)
