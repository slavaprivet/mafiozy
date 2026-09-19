export const COVER_MOVE_SPEED=2.35;
export const COVER_ENTRY_SECONDS=.14;

// The world's physics clock is capped at 40 ms. Cover uses swept movement,
// so it can follow elapsed time up to 100 ms without slowing at 10–25 FPS.
// Preserve the existing pause/QA time scale and cap a resumed-tab hitch.
export function coverElapsedTime(rawDt,simulationDt){
 if(!Number.isFinite(rawDt)||!Number.isFinite(simulationDt)||rawDt<=0||simulationDt<=0)return 0;
 const scale=Math.min(1,simulationDt/Math.min(rawDt,.04));
 return Math.min(rawDt,.1)*scale;
}
