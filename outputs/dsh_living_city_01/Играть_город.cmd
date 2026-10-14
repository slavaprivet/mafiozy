@echo off
rem Zhivoy gorod "Mafiozi" - RABOCHAYA sborka: gorodok rezhim (ubrany obychnye doma),
rem svobodnye dveri, pravila potrebnostey, korrektnyy reliz banka, ispravlennyy detur.
rem VITRINA portovannyh korobok (--city-town-extras=1) NAMERENNO VYKLYUCHENA: u nih
rem poka net ni vladeltsa urona, ni igrovoy dveri, poetomu oni vyglyadyat kak zdaniya,
rem no ne vzryvayutsya i v nih nelzya voyti. Vklyuchat tolko dlya raboty konveyera porta.
start "" "%LOCALAPPDATA%\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0game" res://scenes/main_city.tscn -- --city-sim-lod=1 --city-admit-ttl=8 --city-sim-stride=3 --city-recover-ttl=3 --city-clear-cache=1 --city-nav-pump-every=2 --city-daily-slice=96 --city-motion-retry=8 --city-navstep-slim=1 --city-policy-slim=1 --city-timing=0 --city-health-lease --city-audit-cache=1 --city-audit-probe-defer=1 --city-load-reuse-probe=1 --city-town=1 --city-door-free-entry=1 --city-site-door-physics=1 --city-shop-handoff-anchor=1 --city-handoff-admit=1 --city-handoff-support-plate=1 --city-errand-off-map-m=1.0 --city-needs=1 --city-bank-visit-release=1
