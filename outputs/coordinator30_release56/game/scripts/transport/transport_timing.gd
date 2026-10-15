extends RefCounted

# User-approved native pacing. Keep logical authority and physical motion on
# this single clock contract so neither side can accept an early seat arrival.
const BOARD_DURATION_S := 1.2
const BOARD_DURATION_US := 1200000
const EXIT_RELEASE_S := .55
const EXIT_RELEASE_US := 550000
const EXIT_WALK_RECOVERY_S := .6
const EXIT_WALK_RECOVERY_US := 600000
const EXIT_TUMBLE_RECOVERY_S := 1.7
const EXIT_TUMBLE_RECOVERY_US := 1700000
