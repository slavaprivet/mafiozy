# Main checkpoint: saved preview, not completed game replacement

Run `python tools/city_rebuild_monitor.py` from the repository root.
Open http://127.0.0.1:18538/walk in one tab. Three.js requires CDN access.
No game token, database or artist workspace is needed for this saved 3D scene.
Source paths in manifests are provenance; regeneration may need those sources.

Saved: native map, 72 buildings, 164 decor objects and the Artist13 hero with
walking/running and following camera. WASD moves, Shift runs, mouse controls
camera, wheel zooms. Original 2D planning can use --plan and --addendum.

Normal world.html is not replaced. New-map economy, NPCs/bosses, interiors,
vehicles, train and ownership migration remain incomplete. Experimental paths
retain preview gates. Police is reserved, not a complete scene import. Forests,
landscaping and large bridge models remain unfinished.

Not production acceptance. Preserve ALL original mechanics and fixes;
see THIRD_PERSON_MIGRATION.md. No production data migration is included.
