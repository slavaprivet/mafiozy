@echo off
rem Zhivoy gorod "Mafiozi" - RABOCHAYA sborka dlya prosmotra i otladki.
rem Vazhno (zamereno na 286 zhitelyah): simuljacionnyj LOD I prorezhivanie shaga
rem MOROZILI povedenie - activity 145 -> 43, ochered' putey 203 -> 8 posle ih otklyuchenija.
rem Poetomu oni ZDES' VYKLYUCHENY. Cena - FPS (47 -> 19), no zhiteli real'no dejstvuyut.
rem Animacija dal'nih zHITELEJ tozhe polnaja (potolok 512 vmesto 48).
rem Vitrina portovannyh korobok (--city-town-extras=1) VYKLYUCHENA: u nih poka net ni
rem vladel'ca urona, ni igrovoj dveri - oni vyglyadyat kak zdanija, no ne vzryvayutsya
rem i v nih nel'zya vojti. Vklyuchat' tol'ko dlya raboty konvejera porta.
start "" "%LOCALAPPDATA%\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0game" res://scenes/main_city.tscn -- --city-town=1 --city-door-free-entry=1 --city-site-door-physics=1 --city-shop-handoff-anchor=1 --city-handoff-admit=1 --city-handoff-support-plate=1 --city-errand-off-map-m=1.0 --city-needs=1 --city-bank-visit-release=1 --city-walk-pose=1 --city-pose-far-m=0.18 --city-pose-far-cap=512 --city-daily-slice=286 --city-nav-pump-every=1 --city-motion-retry=8 --city-clear-cache=1 --city-timing=0 --city-health-lease --city-audit-cache=1 --city-audit-probe-defer=1 --city-load-reuse-probe=1
