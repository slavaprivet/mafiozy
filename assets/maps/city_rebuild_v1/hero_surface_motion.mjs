// Compatibility name for the player host. NPCs import the pedestrian module
// directly so both actor classes consume identical passability semantics.
export {
 createPedestrianSurfaceMotion as createHeroSurfaceMotion,
 PEDESTRIAN_SURFACE_LIMITS as HERO_SURFACE_LIMITS,
} from './pedestrian_surface_passability.mjs';
